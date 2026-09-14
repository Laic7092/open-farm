# open-farm · 牧场物语复刻

用 **Godot 4.7** 搭建的 2D 俯视角像素风农场生活模拟游戏（牧场物语 / 矿石镇风格）。
当前进度：**整体骨架已完成并可运行** —— 核心循环、玩家、农场、NPC/经济、UI、存档、
本地化、测试全部打通，等待填充内容与美术。

---

## 快速开始

```bash
# 运行游戏
./godot --path .

# 一键校验（导入缓存 + 176 个单元测试 + 61 项端到端冒烟检查）
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

### 开局能做什么

出生在自家农场（左下角）。往右走有出货箱，往上是农田区（带栅栏的那片）。
用锄头翻地 → 浇水 → 用 `seed_bag`（工具带第 4 格）播种 → 等作物成熟后按 `E` 徒手收获。
农场右上角和小镇里有 NPC（商人会开店、村长会聊天），农场右侧边缘的传送点通往小镇。
按 `Esc` 打开菜单可以存读档。

---

## 目录结构

```
open-farm/
├── project.godot              # autoload / InputMap / 像素渲染 / 本地化 / gdUnit4 配置
├── src/
│   ├── autoload/              # 全局单例（见下方"七大单例"）
│   ├── core/                  # 与玩法无关的基础设施：日期、季节、朝向、状态机、交互基类
│   ├── data/                  # 数据资源的类定义（CropData / ItemData / …）
│   ├── player/                # 玩家实体、体力、背包、工具带、状态机状态
│   ├── farm/                  # 农田网格、作物生长规则、工具→农场的翻译层
│   ├── npc/                   # NPC
│   ├── shop/                  # 商店交易规则（纯逻辑，可单测）
│   ├── world/                 # 世界场景基类、天气、边界墙、传送门、床、出货箱
│   ├── ui/                    # HUD、对话框、背包、商店、系统菜单、UI 总入口
│   └── main/                  # 游戏主入口
├── scenes/                    # 场景文件，目录结构与 src/ 一一对应
├── data/                      # 实际的数据资源（.tres），策划直接在编辑器里改
├── assets/
│   ├── i18n/strings.csv       # 翻译表（zh_CN / en）
│   ├── fonts/ui_font.tres     # 默认字体（SystemFont + 中文兜底）
│   └── sprites|tilesets/      # 占位美术（由脚本生成）
├── tests/unit/                # gdUnit4 单元测试
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
作物、道具、工具、NPC、对话、商店全部是 `Resource`（`res://data/**/*.tres`）。
新增一种作物 = 往 `data/crops/` 丢一个 `.tres`，**不需要改任何脚本**。

```gdscript
# 脚本里只认 id
var crop := Database.get_crop(&"turnip")
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
3. Player         恢复体力
```

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

### 加一个 NPC

1. `data/dialogue/` 加 `DialogueData`（`lines` 里每句一个 `DialogueLine`）。
2. `data/npcs/` 加 `NpcData`，`default_dialogue` 指向它；如果是商人再填 `shop_id`。
3. 在 `scenes/world/*.tscn` 里实例化 `scenes/npc/npc.tscn`，改 `npc_id`。

### 加一个世界场景

1. 复制 `scenes/world/town.tscn`，根节点脚本用 `WorldScene`，填 `world_id` / `camera_limits`。
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
| 单元测试 | gdUnit4（`tests/unit/`，176 例） | 日期进位、季节/天气、网格换算、背包堆叠、体力、工具带、作物生长（含枯死/多次收获）、商店经济、状态机、时钟与日结转钩子、数据完整性、存档往返与容错 |
| 冒烟测试 | `tools/smoke_test.tscn`（61 项） | 真的把游戏跑起来：场景加载、玩家落点、翻地→播种→生长→收获全链路、买/卖、存读档、HUD 内容、**农场 ↔ 小镇往返后农田进度与日结转钩子仍然有效** |
| 视觉回归 | `tools/screenshot.tscn` / `tools/ui_preview.tscn` | 截图检查画面与各界面布局 |

```bash
./tools/check.sh          # 全部
./tools/check.sh unit     # 只要单元测试
```

---

## 资源生成工具

仓库里的占位美术和示例数据都是**用脚本生成**的，而不是塞一堆来路不明的二进制：

```bash
# 重新生成占位美术（PNG + TileSet + SpriteFrames）
./tools/build_assets.sh

# 重置示例数据（作物 / 道具 / 商店 / NPC / 对话）
./godot --headless --path . -s res://tools/generate_sample_data.gd

# 截图（需要真实渲染后端，--headless 不可用）
./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn
./godot --path . --rendering-driver opengl3 res://tools/ui_preview.tscn
```

真正的美术到位后，**删掉 `tools/generate_placeholder_art.gd`、换成同名 PNG 即可，游戏代码零改动**。

---

## 已知限制

- **占位美术**：所有贴图都是 16×16 的色块小人。像素画与动画是纯粹的占位，UI 也没有做主题皮肤。
- **中文字体**：`assets/fonts/ui_font.tres` 是 `SystemFont`，会向操作系统要字体。
  精简 Linux 容器 / WSL 里 fontconfig 可能没有中文字体，此时 `AppTheme` 会从
  `CJK_FONT_CANDIDATES`（含 WSL 的 `/mnt/c/Windows/Fonts`）里兜底加载；
  都找不到就会打印警告并显示方块。
  想彻底解决请装中文字体（`sudo apt install fonts-noto-cjk`），
  或把像素中文字体放进 `assets/fonts/` 并让 `ui_font.tres` 指向它。
- **农场渲染层级**：作物统一在玩家之下绘制（`Crops` 容器整体参与 Y 排序）。
  要做到"玩家能走到高杆作物后面"，需要把作物挂到与玩家同一层再逐株 Y 排序。
- **世界场景常驻内存**：切过的地图实例会一直保留（这是为了让农田进度跨场景不丢）。
  地图数量上来之后需要改成"按需卸载 + 状态外置到存档层"。
- **NPC 没有日程与寻路**：目前是站桩 + 按季节切换对白。
- **出货箱是"一键全卖"**：原作是逐件投放 + 次日结算，接口已预留。
- **没有标题界面 / 存档槽选择界面**：目前直接进农场，快捷存读档固定在槽位 0。
- **`assets/i18n/*.translation`** 是 CSV 导入产生的文件，被 `project.godot` 直接引用，
  因此需要一并提交（Godot 对 CSV 翻译的既定行为）。

---

## 后续里程碑建议

1. **内容**：更多作物 / 季节作物、畜牧（鸡舍牛舍）、钓鱼、采矿。
2. **表现**：像素美术与动画、Tilemap 地形自动过渡、昼夜光照、音效与 BGM、UI 主题皮肤。
3. **系统**：NPC 日程与寻路、好感度与恋爱、节日与事件、工具升级与体力上限成长。
4. **流程**：标题界面、存档槽 UI、新手引导、结局与结算。
5. **工程**：导出预设（Windows / Linux / macOS）、GitHub Actions 跑 `tools/check.sh`、帧率与内存基线。

---

## 参考

- [Godot 官方最佳实践](https://docs.godotengine.org/en/stable/tutorials/best_practices/introduction_best_practices.html)
- [gdUnit4 文档](https://mikeschulze.github.io/gdUnit4/)
- 本仓库的 [架构与设计决策](docs/architecture.md) —— 每个"为什么不按常见教程写"的答案、以及踩过的 Godot 坑
