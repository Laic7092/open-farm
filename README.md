# open-farm · 牧场物语复刻

用 **Godot 4.7** 搭建的 2D 俯视角像素风农场生活模拟游戏（牧场物语 / 矿石镇风格）。
当前进度：**整体骨架已完成并可运行** —— 核心循环、玩家、农场、畜牧、NPC/经济、UI、存档、
本地化、测试全部打通，等待填充内容与美术。

---

## 快速开始

```bash
# 运行游戏
./godot --path .

# 一键校验（导入缓存 + 235 个单元测试 + 100+ 项端到端冒烟检查）
./tools/check.sh

# 只跑单元测试 / 只跑冒烟测试
./tools/check.sh unit
./tools/check.sh smoke
```

用编辑器打开：

```bash
./godot --path . -e
```

### 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动（按住 `Shift` 奔跑） |
| `空格` | 使用当前工具 |
| `E` / `回车` | 交互 / 对话 / 收获 |
| `Q` / `R` | 切换手持工具 |
| `Tab` / `I` | 背包 |
| `Esc` | 系统菜单 |
| `F5` / `F9` | 快捷存档 / 读档（槽位 0） |

### 标题页

启动后先进入**标题页**：脚本生成的日出农场背景 + 飘动的云，
菜单可以继续最近的存档 / 开新游戏 / 切换中英文 / 退出。
方向键或 `W S` 选择，`Enter` 确认；存档摘要（日期 + 金钱）直接印在"继续游戏"下面。

### 开局能做什么

出生在自家农场（左下角）。往右走有出货箱，往上是农田区（带栅栏的那片）。
用锄头翻地 → 浇水 → 用 `seed_bag`（工具带第 4 格）播种 → 等作物成熟后按 `E` 徒手收获。
农舍右边是**鸡舍**、右上是**牛舍**：去 twon 的杂货店买 `鸡` / `奶牛` 与 `干草`，
回农场对着畜舍按 `E` 把牲畜放养进去；对着**饲料槽**按 `E` 一次性喂饱全舍。
喂够天数会成年，成年后每隔几天产出**鸡蛋** / **牛奶**，对着牲畜按 `E` 收走；
每天第一次按 `E` 还会抚摸它、提升好感度（好感高时产出更多）。
现有 NPC（商人会开店、村长会聊天）已经搬进新的大场景 **twon**。
农场右侧边缘的传送点通往小镇，农场上方的传送门通往 twon；两张图都通过场景切换独立进入，两个 NPC 都在 twon 里。
按 `Esc` 打开菜单可以存读档、也可以回到标题页。

---

## 目录结构

```
open-farm/
├── project.godot              # autoload / InputMap / 像素渲染 / 本地化 / gdUnit4 配置
├── src/
│   ├── art/                   # 调色板与图集排版表（生成器与运行时共用的事实来源）
│   ├── autoload/              # 全局单例（见下方"八大单例"）
│   ├── core/                  # 与玩法无关的基础设施：日期、季节、朝向、状态机、交互基类
│   ├── data/                  # 数据资源的类定义（CropData / FloraData / ItemData / …）
│   ├── player/                # 玩家实体、体力、背包、工具带、状态机状态
│   ├── farm/                  # 农田网格、作物/牲畜生长规则、工具→农场的翻译层
│   │                          #   以及畜舍系统（AnimalData/State/Husbandry/Manager）
│   ├── npc/                   # NPC
│   ├── shop/                  # 商店交易规则（纯逻辑，可单测）
│   ├── world/                 # 世界场景基类、天气、边界墙、传送门、床、出货箱
│   │                          #   以及野生植被系统（FloraData/State/Growth/Field）
│   ├── ui/                    # HUD、对话框、背包、商店、系统菜单、UI 总入口
│   └── main/                  # 游戏主入口
├── scenes/                    # 场景文件，目录结构与 src/ 一一对应
├── data/                      # 实际的数据资源（.tres），策划直接在编辑器里改
├── assets/                    # 全部由 tools/art/*.gd 生成（见 docs/art_pipeline.md）
│   ├── i18n/strings.csv       # 翻译表（zh_CN / en）
│   ├── fonts/pixel_cjk.fnt    # 像素中文字体（1100 字形子集 + PNG 图集）
│   ├── fonts/ui_font.tres     # 子集外字符的系统字体兜底
│   ├── sprites/{actors,crops,animals,flora,items,props,weather}/
│   ├── ui/                    # UI 九宫格与图标
│   ├── title/                 # 标题页背景与云
│   ├── tilesets/              # 组装出来的 TileSet
│   └── themes/game_theme.tres # 组装出来的 Theme（字体 + 皮肤）
├── tests/unit/                # gdUnit4 单元测试（含美术规范测试）
└── tools/                     # 资源生成、校验、截图等开发工具
```

---

## 架构

### 八大单例（Autoload）

| 名称 | 职责 | 关键点 |
| --- | --- | --- |
| `EventBus` | 全局信号总线 | **只声明信号**，不写逻辑。生产者 emit、消费者 connect，双方互不相识 |
| `AppTheme` | 语言与字体引导 | 语言匹配 + 缺中文字体时自动兜底，避免"豆腐块" |
| `Database` | 静态数据仓库 | 启动扫描 `res://data/`，按 id 建索引。业务代码永不硬编码文件路径 |
| `GameClock` | 游戏时钟 | 06:00 起床、次日 02:00 强制结束；**有序日结转钩子**驱动模拟流水线 |
| `GameState` | 跨场景状态 | 金钱、剧情旗标、统计。玩家体力/背包属于 `Player`，不放这里 |
| `WeatherSystem` | 天气 | 作为**第一个**日结转钩子，保证其它系统读到的天气已是当天的 |
| `SaveManager` | 存档 | JSON + 版本号；鸭子类型收集 `persistent` 组节点；支持跨地图读档 |
| `SceneRouter` | 场景路由 | 淡入淡出 + 出生点定位；世界场景**缓存复用**，UI 常驻不销毁 |

### 三条贯穿全局的设计原则

**1. 数据驱动，而不是代码驱动**
作物、野生植被、道具、工具、NPC、对话、商店全部是 `Resource`（`res://data/**/*.tres`）。
新增一种作物 = 往 `data/crops/` 丢一个 `.tres`，**不需要改任何脚本**。

```gdscript
# 脚本里只认 id
var crop := Database.get_crop(&"turnip")
var tree := Database.get_flora(&"tree_oak")
```

**2. 静态数据与运行时状态严格分离**
`CropData`（`Resource`，不变）↔ `CropState`（`RefCounted`，会变）。
生长规则全在 `CropGrowth` 的纯静态函数里，因此可以脱离引擎循环直接单测。

**3. 用信号解耦，但要顺序的地方显式排序**
UI 通过 `EventBus` 单向订阅，从不主动查询游戏状态；
而"天气 → 作物生长 → 体力恢复"这类**有依赖顺序**的模拟逻辑走
`GameClock.register_day_hook()` 的有序列表，不依赖信号回调顺序
（Godot 不保证信号回调顺序）。

```gdscript
# 日结转流水线（顺序即依赖顺序）
1. WeatherSystem  掷出当天天气
2. FarmGrid       作物生长 / 枯死 / 浇水标记重置
3. FloraField     野生植被生长 / 扩散（树、杂草、石头……）
4. Player         恢复体力
```

### 世界为什么会自己长东西

`FloraField` 是"世界自然生长"的唯一权威状态，和 `FarmGrid` 完全同构：
格子状态放在 `Dictionary[Vector2i, FloraState]` 里、视图节点按需生成、存档就是一次 `to_dict`。
区别在于农田是"玩家种、玩家管"，而它是"自己长、自己扩散"。

每天按顺序做两件事：**先让已经长出来的植被长大，再按季节/天气权重撒新芽**。
能不能落在某一格，要过四道关：

1. 在 `growth_area` 内，且该格还没东西；
2. 地表必须是**自然地表**（`FloraGrowth.NATURAL_GROUND` 白名单）——
   路、石板、水、木地板、栅栏、花圃自动被排除，因为它们被画进了地面图层；
3. 一次 `intersect_shape` 物理查询不能碰到任何实心东西（房子、水井、手摆的家具都在 layer 1）；
4. 不在出生点 / 门（所有 `Interactable`）附近，也不在玩家脚边。

另外还有一道**连通性守卫**：只有当一个新芽/一次生长会变成"挡路"的时候，
才做一次 BFS 比较可达格数；如果它会把地图切成两半，这次生长就被撤销。
于是"一夜之间树把门口堵死"在结构上不会发生。

不在场的地图不跑日结转（钩子在 `_exit_tree` 里注销），而是下次进图时把离开的天数
一次性补算（单次上限 60 天）——这就是"去小镇待三天，回来树苗长高了"。

### 场景切换为什么不用 `change_scene_to_file`

`Main.tscn` 的结构是：

```
Main
├── WorldHost   ← 世界场景在这里换进换出（组 world_host）
└── UiRoot      ← CanvasLayer，常驻
```

用 `change_scene_to_file` 会把整个当前场景顶掉，UI 和主入口跟着被销毁重建。
改成"换 `WorldHost` 的子节点"之后，UI、全局输入、存档系统都不会因为一次传送被重建。

更进一步，切过的地图会**保留实例**（只是移出场景树），再回去时直接挂回来。
原因很直接：翻好的地、种下的作物就存在世界场景的节点里，
每次传送都重建场景会让"种好菜去趟小镇，回来地全荒了"。
代价是常驻内存——地图真的多起来时要改成"卸载地图 + 状态外置到存档层"。

> 注意：Godot 的 `_ready()` 一个节点**一生只跑一次**，而世界场景会多次进出场景树。
> 所以"每次进入都要做一遍"的事情必须放在 `_enter_tree()`；
> 需要对外暴露的进入/离开时机，用 `WorldScene.on_world_enter()/on_world_exit()`。
> 日结转钩子的注册就在 `_enter_tree()` 里，否则离开一次地图后就再也不会生长。

---

## 如何扩展

### 加一种作物

1. 在 `data/crops/` 新建 `CropData` 资源（或跑 `tools/generate_sample_data.gd` 看示例）。
2. 在 `data/items/` 加对应的种子道具（`category = SEED`、`crop_id` 指向它）和收获物。
3. 在 `assets/i18n/strings.csv` 加名字翻译键。
4. 商店上架：在 `data/shops/general_store.tres` 的 `stock` 里加一条 `ShopStock`。

### 加一种牲畜

1. 在 `data/animals/` 新建 `AnimalData`（或看 `tools/generate_sample_data.gd` 里
   `_build_animals()` 的示例）。关键字段：`species`（物种标签，畜舍据此决定能不能养）、
   `mature_days`（成年所需喂养天数）、`produce_days`（成年后的产出周期）、
   `product_item_id` / `feed_item_id`、好感度相关数值。
2. 在 `data/buildings/` 新建 `BuildingData`，把 `allowed_species` 填成新物种（或往已有畜舍里加一种）。
3. 在 `tools/art/generate_animals.gd` 里加一行外观 → 跑一次 `./tools/build_assets.sh`。
4. 在 `data/items/` 加"牲畜道具"（`category = ANIMAL`、`animal_id` 指向它）与产出 / 饲料道具，
   并在 `assets/i18n/strings.csv` 加翻译键（重跑 `build_assets.sh` 会把新汉字打进像素字体）。
5. 场景里已经有鸡舍 / 牛舍；要加一座就在 `scenes/world/farm.tscn` 的 `Livestock` 下加一个
   `AnimalPen`（填 `building_id` 与 `wander_area`）和它的 `FeedTrough` 子节点。

### 加一种野生植被

1. 在 `data/flora/` 新建 `FloraData`（或看 `tools/generate_sample_data.gd` 里 `_build_flora()` 的示例）。
   关键字段：`spawn_weight`（四个季节的扩散权重，0 = 该季不长）、
   `initial_weight`（新地图开局播种权重）、`days_per_stage`（空数组 = 不生长，石头就是这样）、
   `solid_from_stage`（从第几阶段开始挡人）、`tool_kind`（用什么工具清）。
2. 在 `tools/art/generate_flora.gd` 里加一行外观 → 跑一次 `./tools/build_assets.sh`。
3. 在 `assets/i18n/strings.csv` 加名字翻译键（重跑 `build_assets.sh` 会把新汉字打进像素字体）。
4. 想让某张地图多长/少长：改那张地图 `FloraField` 的 `initial_budget` / `daily_budget` / `max_total`。

### 加一个 NPC

1. `data/dialogue/` 加 `DialogueData`（`lines` 里每句一个 `DialogueLine`）。
2. `data/npcs/` 加 `NpcData`，`default_dialogue` 指向它；如果是商人再填 `shop_id`。
3. 在 `scenes/world/*.tscn` 里实例化 `scenes/npc/npc.tscn`，改 `npc_id`。

### 加一个世界场景

1. 复制 `scenes/world/twon.tscn`，根节点脚本用 `WorldScene`，填 `world_id` / `camera_limits`。
2. 放至少一个 `SpawnPoint` 标记（`spawn_id` 要有意义，例如 `from_farm`）。
3. 在两边用 `SceneDoor` 互相连接（`target_scene` + `target_spawn_id`）。

### 让新系统参与存档

任何节点只要实现两个方法并注册一次即可，**不需要修改 `SaveManager`**：

```gdscript
func _ready() -> void:
    Persistence.register(self, &"my_system")   # id 必须全局唯一且稳定

func to_dict() -> Dictionary: ...
func from_dict(data: Dictionary) -> void: ...
```

> 注意：`SaveManager` 用 JSON 存盘。JSON 往返会把 `StringName` 键变成 `String`，
> `from_dict` 里要用 `StringName(str(key))` 转回来。

---

## 测试

| 层次 | 工具 | 覆盖 |
| --- | --- | --- |
| 单元测试 | gdUnit4（`tests/unit/`，235 例） | 日期进位、季节/天气、网格换算、背包堆叠、体力、工具带、作物生长（含枯死/多次收获）、牲畜养殖（成年/产出/喂食/好感度）、商店经济、状态机、时钟与日结转钩子、数据完整性、存档往返与容错 |
| 冒烟测试 | `tools/smoke_test.tscn`（100+ 项） | 真的把游戏跑起来：场景加载、玩家落点、翻地→播种→生长→收获全链路、放养→喂食→成长→收产出、买/卖、存读档、HUD 内容、**农场 ↔ 小镇 / 农场 ↔ twon 往返后农田与畜舍进度、日结转钩子仍然有效** |
| 美术规范 | `tests/unit/test_assets.gd` | 生成物存在、尺寸与 `AtlasLayout` 一致、瓦片齐全、字体覆盖翻译表全部字符、数据都挂上了贴图 |
| 视觉回归 | `tools/screenshot.tscn` / `tools/ui_preview.tscn` | 标题页 + 农场 + 小镇 + twon 截图、各界面布局截图 |

```bash
./tools/check.sh          # 全部
./tools/check.sh unit     # 只要单元测试
```

---

## 美术资源：全部由脚本生成

[b]仓库里不放手工二进制素材。[/b] 每一个像素、包括中文字体，都由
`tools/art/*.gd` 生成；颜色只在 `src/art/palette.gd`、图集坐标只在
`src/art/atlas_layout.gd`，生成器与运行时引用同一份常量。

完整规范见 **[docs/art_pipeline.md](docs/art_pipeline.md)**，核心是五条硬性规则：
颜色只来自调色板、坐标只来自排版表、生成必须确定性（跑两次 `git status` 要干净）、
贴图挂在数据资源上、生成物提交但永不手改。

```bash
# 重新生成全部美术与字体（14 步，约 20 秒）
./tools/build_assets.sh

# 只重跑某一个生成器（例如只调了树的形状）
./godot --headless --path . -s res://tools/art/generate_props.gd
./godot --headless --path . --import

# 重置示例数据（作物 / 牲畜 / 道具 / 商店 / NPC / 对话；会顺带挂上贴图）
./godot --headless --path . -s res://tools/generate_sample_data.gd

# 截图（需要真实渲染后端，--headless 不可用）
./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn   # 标题页 + 农场 + 小镇 + twon
./godot --path . --rendering-driver opengl3 res://tools/ui_preview.tscn   # 各界面布局
```

真美术到位后：**删掉对应的生成器、把图放到同名路径，游戏代码零改动**
（运行时只认数据资源里的贴图字段与 `AtlasLayout` 的坐标）。

---

## 已知限制

- **美术是脚本画的**：像素画由 `tools/art/*.gd` 生成，风格统一但细节有限——
  没有手绘的光影、渐变与逐帧动画，角色只有 3 个朝向 × 4 个姿势。
- **中文只覆盖"用到的字"**：像素字体是子集（约 1100 字形），
  玩家名一类运行期才出现的生僻字要走系统字体兜底；
  精简容器里没有系统 CJK 字体时仍会显示方块。加了新文案请重跑 `build_assets.sh`。
- **农场渲染层级**：作物统一在玩家之下绘制（`Crops` 容器整体参与 Y 排序）。
  要做到"玩家能走到高杆作物后面"，需要把作物挂到与玩家同一层再逐株 Y 排序。
- **世界场景常驻内存**：切过的地图实例会一直保留（这是为了让农田进度跨场景不丢）。
  地图数量上来之后需要改成"按需卸载 + 状态外置到存档层"。
- **NPC 没有日程与寻路**：目前是站桩 + 按季节切换对白。
- **野生植被是"进图补算"而不是后台模拟**：不在场的地图不跑日结转，
  而是在重新进入时把离开的天数一次性补算掉（单次最多 60 天）。
  要做到真正连续的后台模拟，需要把状态外置到 autoload，和当前"状态在场景里"的架构冲突。
- **野草会侵占农田空地**：没翻耕的地上会长草，清掉才能翻地——这是刻意的设计，不是 bug。
- **牲畜也不会在离开地图时成长**：与作物一致，畜舍只在当前地图跑日结转；
  也没有繁殖 / 生病 / 放牧到草地，牲畜住进畜舍后固定在自己那片围栏里活动。
- **出货箱是"一键全卖"**：原作是逐件投放 + 次日结算，接口已预留。
- **存档只有一个槽位**：标题页的"继续游戏"读最近的存档，快捷存读档固定在槽位 0，
  还没有多槽位的选择界面。
- **`assets/i18n/*.translation`** 是 CSV 导入产生的文件，被 `project.godot` 直接引用，
  因此需要一并提交（Godot 对 CSV 翻译的既定行为）。

---

## 后续里程碑建议

1. **内容**：更多作物 / 季节作物、更多牲畜（鸭 / 羊）与畜舍升级、钓鱼、采矿。
2. **表现**：手绘美术替换脚本生成物、Tilemap 地形自动过渡、昼夜光照、音效与 BGM。
3. **系统**：NPC 日程与寻路、好感度与恋爱、节日与事件、工具升级与体力上限成长。
4. **流程**：多存档槽选择界面、新手引导、结局与结算。
5. **工程**：导出预设（Windows / Linux / macOS）、GitHub Actions 跑 `tools/check.sh`、帧率与内存基线。

---

## 参考

- [Godot 官方最佳实践](https://docs.godotengine.org/en/stable/tutorials/best_practices/introduction_best_practices.html)
- [gdUnit4 文档](https://mikeschulze.github.io/gdUnit4/)
- 本仓库的 [架构与设计决策](docs/architecture.md) —— 每个"为什么不按常见教程写"的答案、以及踩过的 Godot 坑
- 本仓库的 [美术资源规范](docs/art_pipeline.md) —— 为什么美术也应当是代码，以及怎么加新素材
