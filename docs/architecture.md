# 架构与设计决策

本文记录骨架的**为什么**。想快速上手看 [README](../README.md) 就够了；
想在此基础上继续开发、或者好奇某个写法为什么不按"常见教程"来，看这里。

---

## 1. 分层

```
        ┌──────────────────────────────────────────────┐
   UI   │ Hud / DialogueBox / InventoryUi / ShopUi /   │  只订阅 EventBus，
        │ PauseMenu            （UiRoot 统一管模态暂停）│  从不反向调用玩法代码
        └───────────────▲──────────────────────────────┘
                        │ EventBus（单向：玩法 → UI）
        ┌───────────────┴──────────────────────────────┐
  玩法  │ Player · FarmGrid · Npc · Shop · Bed · Door  │  场景内节点
        └───────────────▲──────────────────────────────┘
                        │ 直接调用（同步、可断言）
        ┌───────────────┴──────────────────────────────┐
  规则  │ CropGrowth · Season · Weather · GameDate ·   │  纯静态函数 / RefCounted
        │ Inventory · PlayerStats · ToolBelt · Shop    │  ✔ 不依赖场景树，可直接单测
        └───────────────▲──────────────────────────────┘
                        │ Database.get_xxx(id)
        ┌───────────────┴──────────────────────────────┐
  数据  │ CropData · ItemData · ToolData · NpcData ·   │  res://data/**/*.tres
        │ DialogueData · ShopData （Resource）          │  策划在 Inspector 里改
        └──────────────────────────────────────────────┘
```

**依赖方向永远向下**：UI 不知道玩法，玩法不知道规则实现，规则不知道数据从哪来。
唯一"向上"的通路是 `EventBus`，而它是单向广播，不构成循环依赖。

---

## 2. Autoload 依赖图

启动顺序即 `project.godot` 里的声明顺序，越靠前越早 `_ready()`：

```
EventBus      ← 无依赖
AppTheme      ← 无依赖（只碰 TranslationServer / ThemeDB）
Database      ← 无依赖（只读 res://data）
GameClock     ← EventBus
GameState     ← EventBus, GameClock
WeatherSystem ← GameClock（把自己注册成第一个日结转钩子）
SaveManager   ← EventBus, Persistence（鸭子类型找节点，不静态依赖任何游戏系统）
SceneRouter   ← EventBus, GameClock
```

**约束**：`WeatherSystem` 必须排在 `GameClock` 之后，否则 `_ready()` 里读
`GameClock.date` 会拿到 null。这个顺序在 `project.godot` 里有注释说明。

`SaveManager` 与其它单例之间刻意只有**按名字**的弱引用
（`get_tree().root.get_node_or_null("/root/GameClock")`），
所以某天把 `WeatherSystem` 拆成插件也不会编译失败，只会少存一段数据。

---

## 2.1 读档的完整流程

读档比存盘绕，因为"世界场景是在核心状态之后才加载的"：

```
Main/PauseMenu
  └─ await SaveManager.load_game_and_restore_world(slot)
       1. load_game(slot)
          ├─ 恢复核心单例：GameClock / GameState / WeatherSystem / SceneRouter
          └─ 暂存 payload["nodes"]，并对当前树上的节点 apply_node_state()
       2. await SceneRouter.restore_saved_world()
          ├─ 存档地图 == 当前地图 → 复用缓存实例，只重新放置玩家
          └─ 存档地图 != 当前地图 → 丢掉该地图的旧缓存 → change_scene_to()
       3. apply_node_state()
          └─ 新场景的节点这时才存在，把它们的 from_dict 灌进去
```

`load_game()` 保持**同步**，是为了单元测试能一行断言；
异步的部分（切场景）单独放在 `load_game_and_restore_world()` 里。

---

## 3. 关键设计决策

### 3.1 存档用 JSON，不用 `ResourceSaver`

`ResourceSaver` 会把脚本路径写进存档。脚本一改名、类一重构，旧存档全部报废。
JSON + 显式 `SAVE_VERSION` + 每个 `from_dict` 都给字段兜底默认值，
才能做到"两年前的存档今天照样读得回来"。

代价：JSON 没有类型信息。两条硬性约定：

1. **键统一当 `String` 处理**。`StringName` 键经过 `JSON.stringify` → `parse_string`
   会变成 `String`，`from_dict` 里必须 `StringName(str(key))` 转回来
   （`GameState.flags` 就是这么处理的）。
2. **版本号只增不减语义**：字段语义发生不兼容变化时才 `SAVE_VERSION += 1`，
   读取时拒绝比程序更新的存档，避免用旧代码解释新数据。

### 3.2 世界场景"换子节点"，不用 `change_scene_to_file`

`change_scene_to_file` 会释放当前场景的整棵树。如果 `Main`（含 `UiRoot`）就是当前场景，
一次传送就会把 HUD、对话框、存档系统全部销毁重建——UI 会闪、暂停状态会丢、
`SceneRouter` 自己也可能被释放。

改成 `WorldHost.add_child(新场景)` 之后，UI 和主入口成为**常驻节点**，
和世界场景解耦。这也让"读档后重载世界"变成一个普通的场景切换。

> 细节：换场景时必须先 `remove_child` 再 `queue_free`。
> `queue_free` 要到帧末才生效，期间旧玩家仍在 `player` 分组里，
> `_place_player` 会抓到已经作废的节点。

### 3.2.1 世界场景要缓存复用

农田的翻耕状态、作物长到第几天，全都存在世界场景的节点里。
如果每次传送都重建场景，"种好菜去趟小镇，回来地全荒了"。

所以 `SceneRouter` 用 `_world_cache: Dictionary[String, Node]` 保留切过的地图实例，
切出时只 `remove_child`，切回时直接 `add_child` 挂回去，状态自然还在。

代价与边界：

- 常驻内存。地图数量多了要改成"卸载 + 状态外置到存档层"。
- **`_ready()` 不会重跑**（见 3.2.2），所有"每次进入都要做"的事情必须另行安排。
- 读档到别的地图时，目标地图在本局的旧缓存必须 `_discard_world()` 丢掉再重建，
  否则会把上一段进度的残留带进新存档。

### 3.2.2 `_ready()` 一生只跑一次

这是 Godot 里最容易踩、又最难查的坑之一：

```
add_child → _enter_tree → _ready
remove_child → _exit_tree
add_child（同一个实例）→ _enter_tree     ← 没有 _ready 了
```

实测确认（`_ready` 计数始终为 1）。因此本项目有两条硬性约定：

| 要做的事 | 放哪里 | 例子 |
| --- | --- | --- |
| 每次进出树都要生效 | `_enter_tree()` / `_exit_tree()` | `GameClock.register_day_hook()`、`add_to_group()`、`Persistence.register()` |
| 只做一次的初始化 | `_init()` 或 `_ready()` | 背包/体力的构造（`_init`）、铺地面（`_ready`） |
| 只跑一次但要能重跑 | 显式方法 | `FarmGrid.paint_ground()` 是幂等的，重跑无害 |

`Player` 的 `stats`/`inventory`/`tool_belt` 放在 `_init()` 而不是 `_ready()`，
就是为了让"多次进出树"这件事永远不会意外重置玩家状态。

### 3.3 用有序钩子而不是信号做日结转

Godot **不保证同名信号的多个回调按连接顺序执行**。但日结转是有真实依赖的：

```
天气掷点  →  作物按"今天有没有水"生长  →  体力恢复
```

如果靠信号，某个版本改了回调排序，作物就会用昨天的天气生长，而且这种 bug
极难复现。所以 `GameClock` 提供 `register_day_hook(callable)`，
按注册顺序同步执行；钩子跑完之后才 emit `day_changed` 给 UI 这类观察者。

### 3.4 状态机的初始状态必须延后一帧

Godot 的生命周期是**子节点 `_ready()` 先于父节点**。`StateMachine` 是宿主的子节点，
如果在自己的 `_ready()` 里立刻切换状态，状态的 `enter()` 会去访问宿主上
还没被 `@onready` 赋值的引用（`sprite`、`stats`……），拿到一堆 null。

所以 `StateMachine._ready()` 用的是 `transition_to.call_deferred(initial_state_name)`。

同样的原因，**任何"子节点在 `_ready` 里回调父节点"的设计都要小心**。

### 3.5 数据驱动，脚本里只出现 id

`FarmInteractor` 不需要知道"萝卜长什么样"，它只知道
`ToolData.Kind.HOE → FarmGrid.till(cell)`。
`FarmGrid` 不需要知道萝卜，它只知道 `Database.get_crop(state.crop_id)`。

结果：**新增内容 = 新增 `.tres`，零脚本改动**。这也是让"内容量"能线性增长的前提。

### 3.6 工具的目标格在"抬手瞬间"锁定

`player_state_use_tool.gd` 在 `enter()` 里就把 `tool` 和 `cell` 存下来，
挥动过程中转身或切工具都不会改变这次判定。玩家的输入意图不会被中途改写——
这是操作手感的关键，也让这个状态变成纯函数式的、可预测的。

### 3.7 农田状态放在 `Dictionary`，不放在节点上

`FarmGrid.tiles: Dictionary[Vector2i, FarmTile]` 是农田的唯一权威状态。
好处：

- 存档 = 一次 `to_dict()`，不用遍历场景树
- 空格子会被 `_prune_tile()` 剔除，长期游玩不会无限膨胀
- `TileMapLayer` 退化成纯绘制层，随时可以 `clear()` 重建

### 3.8 UI 统一在 `UiRoot` 管"模态栈"

各界面自己不管暂停。`UiRoot` 维护一个模态栈，栈非空就 `get_tree().paused = true`。
这样不会出现"对话和商店同时开着、时间还在流逝"这类状态泄漏；
`close_all()` 则保证传送/读档时不会残留菜单导致时间被永久暂停。

`UiRoot` 自身 `process_mode = PROCESS_MODE_ALWAYS`，否则暂停后就按不动了。

---

## 4. 手写 `.tscn` 的两个坑

这两个坑都是实际踩过、并且在冒烟测试里回归覆盖的。

### 4.1 导出的节点引用必须声明 `node_paths`

```ini
; ✗ 加载后 ground_layer 是 null
[node name="FarmGrid" type="Node2D" parent="."]
script = ExtResource("3_farm_grid")
ground_layer = NodePath("../Ground")
```

```ini
; ✔ 节点头部的 node_paths 告诉场景加载器"这个属性是节点引用，需要延迟解析"
[node name="FarmGrid" type="Node2D" parent="." node_paths=PackedStringArray("ground_layer", "soil_layer", "crops_root")]
script = ExtResource("3_farm_grid")
ground_layer = NodePath("../Ground")
```

编辑器保存场景时会自动写上，但手写时极容易漏——漏了不会报错，
只会在运行时拿到 null 然后静默什么都不做。

### 4.2 `%UniqueName` 需要 `unique_name_in_owner = true`

`@onready var sprite = %Sprite` 依赖节点上显式设置了这个标志。
漏掉的症状同样是"运行时 null"，而不是加载失败。

**建议**：手写 `.tscn` 之后一定要跑一次 `tools/smoke_test.tscn`，
它会实例化真实场景并断言关键节点/状态，比肉眼检查可靠。

---

## 5. `-s` 脚本与 autoload 的坑

`godot -s res://xxx.gd` 会在 **autoload 注册全局标识符之前**编译该脚本。
所以在 `-s` 脚本里直接写 `GameClock.reset()` 会得到：

```
SCRIPT ERROR: Compile Error: Identifier not found: GameClock
```

（同一个脚本作为**场景**运行则完全正常。）

因此本仓库的约定是：

- 需要 autoload 的工具（`tools/smoke_test.gd`、`tools/screenshot.gd`、
  `tools/ui_preview.gd`）都做成**场景**，用 `godot --path . res://tools/xxx.tscn` 运行。
- 不依赖 autoload 的工具（美术/数据生成器）才用 `-s`。

---

## 6. 命名与代码规范

| 对象 | 规范 | 例子 |
| --- | --- | --- |
| 文件 / 目录 | `snake_case` | `farm_grid.gd`、`player_state_walk.gd` |
| 类名（`class_name`） | `PascalCase` | `FarmGrid`、`CropGrowth` |
| 节点名 | `PascalCase` | `WorldHost`、`DialogueBox` |
| 变量 / 函数 | `snake_case` | `days_grown`、`try_interact()` |
| 常量 / 枚举值 | `SCREAMING_SNAKE` | `DAYS_PER_SEASON`、`Type.SPRING` |
| 私有成员 | 前缀 `_` | `_states`、`_prune_tile()` |
| 信号 | 过去式 / 名词短语 | `day_changed`、`transition_requested` |

其他约定：

- **全部显式标注类型**。`var count: int = 0` 而不是 `var count = 0`。
  项目把 `inferred_declaration` 之类的 GDScript 警告当作错误（gdUnit4 的默认设置），
  这能挡掉一大批"从 Variant 推断出 Variant"的隐性类型错误。
- **注释解释"为什么"，不复述"做了什么"**。`# 先收集再移除：遍历过程中修改背包容易漏项`
  比 `# 遍历背包` 有用得多。
- **公开 API 用 `##` 文档注释**，编辑器里能直接看到。
- 逻辑层不出现任何中文字面量；所有面向玩家的文本走 `Text.key()` / `Text.format()`。

---

## 7. 测试策略

| 层次 | 做什么 | 不做什么 |
| --- | --- | --- |
| 单元测试（gdUnit4） | 纯逻辑：数值、边界、序列化往返、状态机 | 不加载场景、不模拟输入 |
| 冒烟测试（场景） | 把游戏真的跑起来：autoload 接线、场景加载、`node_paths`、完整玩法链路 | 不逐个断言表现细节 |
| 视觉预览（截图） | 人眼确认布局与画面 | 不做像素级 diff（尚未需要） |

**为什么冒烟测试不可省**：单元测试全绿但游戏起不来是常态——
导出的节点引用为 null、`%UniqueName` 拼错、autoload 顺序不对，
这些都不会让任何单元测试变红，只会让游戏静默地不工作。
`tools/smoke_test.tscn` 就是为这一类问题存在的。

---

## 8. 性能上的取舍（当前阶段）

骨架阶段刻意**不做**过早优化，但避免会堵死后路的设计：

- 农田逐格 `set_cell`：格子数量在几百级别，完全够用。
  真要画几万格再换成 `TileMapLayer` 的批量 API 或分块加载。
- 作物每株一个 `Sprite2D`：和玩家用同一套 Y 排序。
  数量上千时再考虑 `MultiMeshInstance2D`。
- 存档一次性全量序列化：农场规模小时最简单可靠。
  真要存几万格再引入分块差量存档。
- `Database` 启动时全量加载 `.tres`：几十个资源无所谓，
  上千个时再改成按需 `load` + 缓存。


---

## 9. 美术资源为什么也走"脚本生成"

（完整规范见 [美术资源规范](art_pipeline.md)，这里只记决策本身。）

骨架阶段没有美术，常见的做法是先塞一堆来路不明的占位 PNG。
这里选择**把像素写成代码**，理由是三条工程性质而不是审美：

1. **可复现**：`./tools/build_assets.sh` 在任何机器上跑出逐像素相同的结果。
   为此生成器里禁止 `RandomNumberGenerator`，噪点一律用坐标哈希。
   验收标准很硬：连跑两次，`git status` 必须是干净的。
2. **单一定义**：颜色只在 `src/art/palette.gd`，图集坐标只在 `src/art/atlas_layout.gd`，
   生成器与运行时**引用同一批常量**。"图集改了但代码没跟着改"在结构上不可能发生。
3. **可替换**：运行时只通过数据资源的字段拿贴图
   （`ItemData.icon` / `CropData.sprite_sheet` / `NpcData.frames`），
   所以真美术到位后是"删生成器、放同名 PNG"，而不是"全局搜路径"。

代价也说清楚：脚本画的像素画细节有限（没有手绘光影、逐帧动画），
它换来的是"整个画面都在版本控制里可审查"。

### 9.1 像素中文字体为什么是"生成"的

小字号中文必须关抗锯齿才不糊，而系统里的中文矢量字体在 12px 下必然带灰边。
所以 `generate_font.gd` 用 TextServer 现场栅格化、阈值化，打包成 BMFont。
只收项目里**真正会显示**的字符（约 1100 个），图集 544×528，随仓库提交——
于是运行时既不需要系统装中文字体，也不需要额外的字体文件。

### 9.2 踩过的坑：BMFont 的基线

Godot 从 `.fnt` 建出来的 `FontFile`，在 TextServer 侧取不到 ascent，
行内基线会贴到行顶，表现为**所有文字整体上移一个字高**
（HUD 第一行被屏幕顶边裁掉、标题文字盖到面板外面）。
生成器把 `ascent` 预先折进每个字形的 `yoffset` 来抵消；
因为 yoffset 与字号同比缩放，放大字号时依然对齐。
