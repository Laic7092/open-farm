# 架构与设计决策

本文是**设计决策的权威出处**：记录骨架的"为什么"。
想快速上手看 [README](../README.md) 就够了；
想在此基础上继续开发、或者好奇某个写法为什么不按"常见教程"来，看这里。

与其它文档的分工见 [README 的「文档地图」](../README.md#文档地图)；
运行 Godot 命令的超时规范原文在 [art_pipeline.md](art_pipeline.md#命令必须能自己退出)。

**目录**

- [1. 分层](#1-分层)
- [2. Autoload 依赖图](#2-autoload-依赖图)
  - [2.1 读档的完整流程](#21-读档的完整流程)
- [3. 关键设计决策](#3-关键设计决策)
- [4. 手写 `.tscn` 的两个坑](#4-手写-tscn-的两个坑)
- [5. `-s` 脚本与 autoload 的坑](#5--s-脚本与-autoload-的坑)
- [6. 命名与代码规范](#6-命名与代码规范)
- [7. 测试策略](#7-测试策略)
- [8. 性能上的取舍（当前阶段）](#8-性能上的取舍当前阶段)
- [9. 美术资源为什么也走"脚本生成"](#9-美术资源为什么也走脚本生成)
- [10. 世界自然生长（野生植被）](#10-世界自然生长野生植被)
- [11. NPC 日程与寻路](#11-npc-日程与寻路)
- [12. 昼夜光照](#12-昼夜光照)
- [13. 好感度与恋爱（结婚生子）](#13-好感度与恋爱结婚生子)

> 改章节标题时请同步本节链接（GitHub 锚点由标题自动生成）。

---

## 1. 分层

```
        ┌──────────────────────────────────────────────┐
   UI   │ Hud / DialogueBox / InventoryUi / ShopUi /   │  只订阅 EventBus，
        │ PauseMenu            （UiRoot 统一管模态暂停）│  从不反向调用玩法代码
        └───────────────▲──────────────────────────────┘
                        │ EventBus（单向：玩法 → UI）
        ┌───────────────┴──────────────────────────────┐
  玩法  │ Player · FarmGrid · Livestock · Npc · Shop   │  场景内节点
        └───────────────▲──────────────────────────────┘
                        │ 直接调用（同步、可断言）
        ┌───────────────┴──────────────────────────────┐
  规则  │ CropGrowth · AnimalHusbandry · Season ·      │  纯静态函数 / RefCounted
        │ Weather · Inventory · PlayerStats · Shop ·   │  ✔ 不依赖场景树，可直接单测
        │ GridPathfinder                               │
        └───────────────▲──────────────────────────────┘
                        │ Database.get_xxx(id)
        ┌───────────────┴──────────────────────────────┐
  数据  │ CropData · AnimalData · BuildingData ·       │  res://data/**/*.tres
        │ ItemData · ToolData · NpcData · ShopData ·   │  策划在 Inspector 里改
        │ DialogueData （Resource）                    │
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
Relationships ← EventBus, GameClock, Database, GameState（排在 WeatherSystem 之后注册日结转钩子）
Calendar      ← EventBus, GameClock, Database, GameState, WeatherSystem, Relationships
                （节日与事件：同样把自己的日结转钩子排在 Relationships 之后）
SaveManager   ← EventBus, Persistence（鸭子类型找节点，不静态依赖任何游戏系统）
SceneRouter   ← EventBus, GameClock
Audio         ← EventBus, GameClock, SceneRouter（按场景 / 时间换曲，订阅信号播音效）
```

**约束**：`WeatherSystem` 必须排在 `GameClock` 之后，否则 `_ready()` 里读
`GameClock.date` 会拿到 null。`Audio` 排在最后，因为它要在 `_ready()` 里
把前面几个单例的信号接上。这个顺序在 `project.godot` 里有注释说明。

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
          ├─ 恢复核心单例：GameClock / GameState / WeatherSystem / Relationships / SceneRouter
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

`Main.tscn` 只有两个常驻子节点，世界场景在 `WorldHost` 下换进换出：

```
Main
├── WorldHost   ← 世界场景在这里换进换出（组 world_host）
└── UiRoot      ← CanvasLayer，常驻
```

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

`Player` 的 `stats`/`inventory`/`item_bar` 放在 `_init()` 而不是 `_ready()`，
就是为了让"多次进出树"这件事永远不会意外重置玩家状态。

### 3.3 用有序钩子而不是信号做日结转

Godot **不保证同名信号的多个回调按连接顺序执行**。但日结转是有真实依赖的：

```
1. WeatherSystem  掷出当天天气
2. FarmGrid       作物生长 / 枯死 / 浇水标记重置
3. FloraField     野生植被生长 / 扩散（树、杂草、石头……）
4. Player         恢复体力
```

如果靠信号，某个版本改了回调排序，作物就会用昨天的天气生长，而且这种 bug
极难复现。所以 `GameClock` 提供 `register_day_hook(callable)`，
按注册顺序同步执行；钩子跑完之后才 emit `day_changed` 给 UI 这类观察者。

新增参与日结转的系统时，在 `_enter_tree()` 注册、在 `_exit_tree()` 注销，
并把这个列表当作**权威顺序**同步更新。

### 3.3.1 畜舍为什么是 FarmGrid 的翻版

牲畜养殖和作物是同一套骨架：`LivestockManager` 就是农田的 `FarmGrid`，
`AnimalState` 就是 `CropState`，`AnimalHusbandry` 就是 `CropGrowth`。

- 状态在 `LivestockManager.buildings` 里，视图 `Animal` 节点随时可以丢弃重建；
- 日结转同样注册在 `_enter_tree()`，不在场的地图不跑；
- 规则层是纯静态函数，喂食 / 好感度 / 产出计时全部可以脱离场景单测。

和作物不同的一点：**牲畜不会死**。不喂食只会掉好感度并停止产出，
因为牲畜是“资产”而不是“一季的投入”；是否成年、能不能收都由数据里的
`mature_days` / `produce_days` 决定，代码里没有针对具体动物的分支。

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

一句话：骨架期宁可用**代码画像素**，也不要一堆来路不明的占位 PNG。
完整的决策、代价与五条硬性规则由 [美术资源规范](art_pipeline.md) 定义，
这里只记它对架构的两个约束：

- **单一事实来源**：颜色只在 `src/art/palette.gd`、图集坐标只在
  `src/art/atlas_layout.gd`，生成器与运行时引用同一批常量；已发布坐标只能往后追加。
- **贴图经数据字段注入**：运行时只通过 `ItemData.icon` / `CropData.sprite_sheet` /
  `NpcData.frames` 等字段拿资源；因此改画面只需改生成器并重跑，玩法代码不受影响。

像素中文字体同理由脚本现场栅格化并随仓库提交；
栅格化流程与 BMFont 基线坑见 [art_pipeline.md §5](art_pipeline.md#5-像素中文字体)。

---

## 10. 世界自然生长（野生植被）

`FloraField` 是"世界自然生长"的唯一权威状态，和 `FarmGrid` 完全同构：
每天先让已长出的植被**长大**，再按季节 / 天气权重**撒新芽**；
每张地图用 `initial_budget` / `daily_budget` / `max_total` 控制密度；
`allowed_species` 留空时所有物种都能长，填了就只保留列出的物种——
矿洞因此只长石头与蘑菇，而不会冒出一片树林。
不在场的地图不跑日结转（钩子在 `_exit_tree` 注销），
而是下次进图时把离开的天数一次性补算（单次上限 60 天）——
这就是"去小镇待三天，回来树苗长高了"。

### 10.1 为什么它和 `FarmGrid` 长得一模一样

"树、杂草、石头会随时间自己长"这件事，本质上和作物生长是同一类问题：
**一片格子区域上有一组会随时间变化的状态，需要在日结转时推进，并且必须存档。**

既然 `FarmGrid` 已经把这条路走通了（状态放 `Dictionary`、视图按需生成、
`Persistence.register` + `to_dict/from_dict`、钩子注册在 `_enter_tree`），
`FloraField` 就照抄同一套骨架，而不是发明第二套生命周期。
后果是：世界场景**缓存复用**的性质自动继承——走开再回来，森林还在。

分层也照抄：`FloraData`（Resource，不变）↔ `FloraState`（RefCounted，会变），
中间夹一层纯静态的 `FloraGrowth`，于是所有数值规则都能脱离场景树单测。

### 10.2 "石头不会变"为什么是数据而不是代码

`FloraData.days_per_stage` 是空数组时，`stage_count()` 为 1、`can_grow()` 为 false，
生长函数直接返回"什么都没发生"。石头因此不需要在 `FloraField` 里有一条
`if kind == ROCK` 的分支——`kind` 只用于表现与产出，不参与生长判定。
这是"数据驱动"在细节上的一次兑现：特殊行为用**数据退化**表达，而不是用枚举分叉。

### 10.3 落点判定为什么全是"查"而不是"猜"

长东西的位置不能靠硬编码坐标表，否则每改一次地图布局都要重排一遍。
这里用四条互不重叠的查询：

| 关卡 | 手段 | 自动覆盖了 |
| --- | --- | --- |
| 自然地表 | 读 `ground_layer` 的瓦片，比对 `NATURAL_GROUND` 白名单 | 路 / 石板 / 水 / 木地板 / 栅栏 / 花圃 / 干草 / 木箱 |
| 实心占位 | `intersect_shape`（mask = layer 1） | 房子、谷仓、水井、边界墙、已经长成的大树 |
| 农田规则 | 问 `FarmGrid`：翻过没有、有没有作物 | "田里长草但不长树" |
| 保护区 | 出生点分组 + `Interactable` 分组 + 玩家脚边 | 门口被堵、睡觉时被顶住 |

白名单而不是黑名单，是这里最关键的一步：黑名单每加一种新地表都要回来补一行，
而白名单让"没被允许的地方一律不长"成为默认。

### 10.4 物理查询为什么要等一帧

静态道具的 `StaticBody2D` 是在它们自己的 `_ready()` 里挂上去的。
而 `_ready()` 期间物理空间还没刷新，此时做形状查询可能什么都查不到，
树就会长进房子里。所以初始播种不是直接在 `_ready()` 里跑，而是
`await get_tree().physics_frame` 之后再跑；同时用 `_loaded` 标记保证
"读档时不要用初始播种覆盖存档状态"。

### 10.5 连通性守卫：只在会挡路的时候付钱

全图 BFS 很便宜（几千格），但没必要每次播撒都做。只有当一个新芽
**一落地就是实心**（石头），或者某一株**刚好长到实心阶段**（树），
才做一次"可达格数前后比较"：只看植被造成的阻挡，房子/边界墙这些常量不参与。
如果可达格数骤减，就撤销这次生长（树退回上一阶段，明天再试）。
这样既不会出现"一夜之间被树封死"，也不会为了不可能发生的情况天天做全图搜索。

---

## 11. NPC 日程与寻路

一次完整的"走起来"分三步：`Npc` 每帧问日程"现在该去哪"，地点变化时把目标格交给
导航网格；`NpcNavigator` 用 `GridPathfinder` 跑 A*，可通行性来自物理查询、结果按格缓存，
由日结转钩子刷新；NPC 再沿路径逐格 `move_toward`，走路 / 待机动画随朝向切换。

### 11.1 为什么日程是"循环的时间表"

`NpcSchedule.entry_at(minute)` 不返回"下一段"，而是返回"当前生效段"：
开始时间不晚于当前分钟的最后一条；凌晨早于第一条时回退到最后一条。
于是"22:00 回家"这一段会一直生效到第二天 06:00，查询端不需要任何跨天分支。
排序放在查询时做，策划可以随便往数组里加条目。

### 11.2 为什么导航网格挂在世界场景上

`NpcNavigator` 由 `WorldScene._ready()` 自动挂载，和 `WeatherFx` 同一套做法：
新地图只要根节点是 `WorldScene`，上面的 NPC 就自动有路可走。

可通行性是**物理查询**出来的（layer 1），不是手工标注的：
房子、水井、长成的大树、边界墙自动成为障碍。这与植被落点判定用的是同一条原则——
"查"而不是"猜"。区别在于导航按格缓存结果，因为 A* 会反复问同一格；
世界基本不变，只有植被会生长，所以缓存由日结转钩子刷新。

### 11.3 A* 为什么不用 `AStarGrid2D`

`GridPathfinder` 是纯静态函数，`solid` 是一个 `Callable`，因此：

- 可以完全脱离场景树单测（喂一张内存地图即可）；
- 可通行性可以**惰性查询**：只有 A* 访问到的格子才付物理查询的钱，
  而不是先把整张 96×60 的图问一遍。

八方向会拒绝从两个障碍之间斜穿（有一侧挡住就不许斜着过），
`merge_collinear` 再把连续同方向的步子并成一个路径点，
NPC 因此走的是折线而不是"格子锯齿"。

### 11.4 移动为什么不需要 `CharacterBody2D`

NPC 是 `Area2D`（`Interactable` 的子类），不参与物理碰撞。
既然路径本身已经保证每一步都落在可行走格上，逐格 `move_toward` 就够了，
不需要 `move_and_slide()`，也不用把 NPC 从交互层搬到物理层。
代价是 NPC 之间不会互相阻挡——当前阶段刻意接受，记在 README 的"已知边界"里。

### 11.5 日程地点为什么也是标记节点

`SchedulePoint` 和 `SpawnPoint` 是同一套思路：数据里写名字（`location_id`），
场景里放标记（`point_id`）。重排地图只挪标记，不碰任何日程数据；
找不到地点时 NPC 只 `push_warning` 然后原地不动，而不是传送到一个坏坐标。

---

## 12. 昼夜光照

一条从"一天中的分钟"到"画面多亮"的曲线，加上会随时间亮的点光源。

```
GameClock.minute_of_day
        │
        ▼
  DayNight.ambient_color ──┐
                           ├─ 相乘 ─► WorldLighting 的 CanvasModulate
  WeatherSystem.current ───┘                 │
                                             ▼
                             DayNight.lamp_energy ──► WorldProp 的 PointLight2D
```

### 12.1 为什么天气与昼夜必须共用一个 CanvasModulate

Godot 每张画布只认一个 `CanvasModulate`（官方文档："Only one can be used to tint a canvas"）。
改造前天气自己挂了一个，如果再给昼夜加一个，结果是其中一个**完全失效**——不是叠加，是后者胜出。
于是把"染色"的唯一所有权收归 `WorldLighting`：天气只提供染色系数（`WEATHER_TINTS`），
`WeatherFx` 退回到只负责粒子与阳光。这样"雨天的夜晚更暗"由乘法自动成立，两个系统也不必互相知道。

### 12.2 为什么曲线是纯静态的 DayNight

`ambient_color` / `lamp_energy` 不碰场景树、不注册 autoload，于是可以在
`tests/unit/test_day_night.gd` 里逐分钟采样、检查连续性与边界。
颜色全部来自 `ArtPalette`（`AMBIENT_*` / `WEATHER_*`），
要调"几点钟看起来像几点"只改关键帧，不碰任何玩法代码。

### 12.3 为什么路灯是 WorldProp 的属性

和静态碰撞体同一个理由：场景里只填 `light_radius`，光的形状（径向渐变）与亮度曲线由代码统一给，
复制摆件就能发光。`WorldLighting` 按 `DayNight.lamp_energy` 统一调 `night_lights` 组里所有灯的
能量，因此"现在几点"只在这一个地方被翻译成亮度。

### 12.4 生命周期

`WeatherFx` / `WorldLighting` 都挂在会被缓存复用的世界场景上，所以信号在
`_enter_tree` 连接、`_exit_tree` 断开，并在重新进图时补一次刷新，`_ready()` 只负责建节点。
这条规则的原因见 §3.2.2。
---

## 13. 好感度与恋爱（结婚生子）

### 13.1 为什么单独一个 Relationships 单例

好感度、恋爱阶段、配偶与孩子都是**跨场景**状态：玩家在小镇和书雅聊天，换到矿洞时书雅并不在场上，
但关系必须还在，存档也要一次拿全。最初的雏形把 `affection` 挂在 `Npc` 节点上，
一旦 NPC 不在场（或孩子还没出生）状态就无从谈起。

所以关系不再属于"某个节点"，而是按 `npc_id` 集中放在 `Relationships` 里：
`Npc` 只是它的一个视图，`_ready()` 时读取、变化时通过 `EventBus` 同步。
它作为核心单例参与 `SaveManager` 的读档流程，因此换地图 / 读档都不会丢。

### 13.2 为什么规则在 AffectionRules（纯静态）

心数换算、礼物收益、表白 / 求婚门槛这些"数值怎么算"全在 `AffectionRules` 的静态函数里：
不碰场景树、不注册 autoload、不读写存档。于是 `tests/unit/test_affection_rules.gd`
可以穷举边界，和 `CropGrowth` / `AnimalHusbandry` 是同一种拆分。
运行时状态在 `RelationshipState`（RefCounted），持久化在 `Relationships`。

礼物偏好（最爱 / 喜欢 / 讨厌）写在 `NpcData` 里，是数据而不是代码：
加一位可攻略 NPC 只需改 `.tres`，`AffectionRules.gift_gain()` 对谁都一样。

### 13.3 表白 / 求婚为什么做成"自动里程碑"

`DialogueLine` 预留了 `choices` 字段，但真正做一套多分支选项 UI 成本不小，
而"恋爱"的核心体验是**关系随好感成长**，不是菜单操作。于是把里程碑交给
`Npc.interact()` 判断：好感达到 4 心就播表白对白、5 心且带着蓝色羽毛就播求婚对白，
对白播完由 `_on_dialogue_finished()` 落地状态。这样：
[br]- 触发条件、对白、副作用各自只有一处；
[br]- 单元测试可以直接驱动 `Relationships`，不需要构造 UI；
[br]- 将来接入选项界面时，只需替换"谁来选"，规则层不变。

### 13.4 孩子为什么用 required_flag 门控

孩子出生前不应该参与日程与寻路。`Npc` 新增 `required_flag`
（这里是 `child_born`）：不满足时节点隐藏、退出 `npc` 组并停掉 `_physics_process`，
于是未出生的孩子不会出现在日程、寻路与"该怎么走"的逻辑里；
出生后由 `child_born` 信号触发一次刷新即可出场。
`SchedulePoint` 的 `home` 与孩子的 `our_child_schedule` 都在 `farm.tscn` 里，无需特殊分支。

### 13.5 生命周期

`Relationships` 是常驻 autoload，日结转钩子在 `_ready()` 注册一次即可，
不存在世界场景那种"进图 / 出图"的注册时机问题；
它注册在 `WeatherSystem` 之后的钩子顺序里，先让天气就位，再推进婚育倒计时。

---

## 14. 节日与事件

### 14.1 为什么是"节日 + 事件"两类数据

两者都是"某个时刻发生的事"，但**触发方式与状态**完全不同：

| | 节日 `FestivalData` | 事件 `EventData` |
| --- | --- | --- |
| 触发 | 固定季节 + 日期，到点自动开幕 | 条件组合（季节 / 日期 / 天气 / 旗标 / 好感） |
| 表现 | 地图上有会场、村民聚集、玩家按 E 参加 | 日结转时结算一次，弹提示、打旗标、给钱 |
| 状态 | "今年参加过没有"（每年一次） | "发生过没有"（`once` 为 false 时每年一次） |
| 时长 | 有开门 / 关门时间窗口 | 结算即结束 |

硬塞进一张表就得用一堆互斥字段（`window` 对事件无意义、`conditions` 对节日多余），
所以分成两个 `Resource`，共享同一个 `Calendar` 单例与同一套日结转钩子。

### 14.2 为什么规则在 FestivalRules / EventRules（纯静态）

"哪天办、现在开不开门、条件命中没有"全是纯函数：不碰场景树、不读 autoload
（`EventRules.matches()` 收的是"已经查好的事实"，不是 `GameState` 本体）。
于是 `tests/unit/test_festival_rules.gd` / `test_event_rules.gd` 可以穷举边界，
和 `CropGrowth` / `AffectionRules` 是同一种拆分。

### 14.3 为什么会场是场景节点，而"办不办"是单例

会场 `FestivalGround` 是地图上的 `Area2D`：它属于某张地图，只负责"玩家按 E 时找谁结账"。
而"今天是不是花祭""现在几点了""今年参加过没有"是跨场景的日历状态，放在 `Calendar`。

节点只暴露 `festival_ids`（这个地点轮办哪些节日），`can_interact()` 每次现问 `Calendar`。
好处：同一张地图可以摆多个会场（广场 / 花园），加节日不用改脚本；
不在地图上的会场自然不参与判定，也不需要"进入地图时启用"这类同步逻辑。

### 14.4 为什么节日能盖掉 NPC 日程

牧场物语里节日最直观的表现是"全村人都聚在广场"。实现上没有给每个 NPC 写一份节日日程，
而是在 `Npc._refresh_schedule()` 里加了一层**覆盖**：

```text
日程表给出当前时段的地点
  → Calendar.gather_point_for(npc_id)   # 节日进行中且这位 NPC 参加？
      → 有：改去会场集合点（复用一条临时 ScheduleEntry）
      → 无：用日程表的地点
```

节日只写"哪些 NPC 参加"（`npc_ids`）与集合点（`gather_point`），
"谁在什么时辰放下手里的活儿"由规则推导；节日结束后下一帧自然回到原日程。
商人的 `activity == "shop"` 判定随之失效，于是节日期间店铺自动关门——这是想要的效果。

### 14.5 为什么事件只在日结转判定

"条件 + 一次性结算"的最小实现是挂在日结转钩子上：顺序在 `WeatherSystem` 之后，
所以事件可以拿天气当条件；在 `Relationships` 之后，所以还能拿当天刷新过的好感当条件。

代价是**没有区域事件**：不存在"走进矿洞触发剧情"这类按玩家位置判定的触发点。
要做那种事件，需要一个"进图时判定"的钩子（`WorldScene.on_world_enter`），
但"事件是否已发生"的状态仍然应该留在 `Calendar`。

### 14.6 生命周期

`Calendar` 是常驻 autoload：日结转钩子在 `_ready()` 注册一次，
"已参加 / 已触发"随 `SaveManager` 的核心单例流程存档。
`today_festivals()` 的结果按**绝对天数**缓存，读档 / 开新档 / 跨天时置脏重算，
所以"读档后 HUD 上的今日节日"不需要任何额外同步。


