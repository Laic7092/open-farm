# open-farm · 牧场物语复刻

用 **Godot 4.7.2** 搭建的 2D 俯视角像素风农场生活模拟游戏（牧场物语 / 矿石镇风格）。
当前进度：**整体骨架已完成并可运行** —— 核心循环、玩家、农场、畜牧、NPC/经济、UI、存档、
本地化、测试全部打通；**美术、字体、BGM、音效全部由脚本生成**，内容可以继续扩展。

---

## 文档地图

本文档体系按"**每件事只有一个权威出处**"组织。修改某个主题时只改它的归属文档，
其它文档只写一句话概述 + 链接，**不要复制正文**——复制是文档漂移的头号来源。

| 文档 | 唯一职责（权威内容） | 读者 |
| --- | --- | --- |
| `README.md`（本文） | 项目是什么、怎么跑 / 怎么玩、目录结构、扩展步骤、测试覆盖、已知限制、里程碑 | 人类开发者 |
| [AGENTS.md](AGENTS.md) | 编码 Agent 的最短上手：铁律、速查表、踩过的坑 | AI / 自动化 |
| [docs/architecture.md](docs/architecture.md) | 设计决策的**为什么**：分层、Autoload 依赖、生命周期、引擎坑的原理 | 维护者 |
| [docs/art_pipeline.md](docs/art_pipeline.md) | 美术生成规范；**「Godot 命令必须能自己退出」的规范原文** | 改美术的人 |
| [docs/audio_pipeline.md](docs/audio_pipeline.md) | 音频合成规范 | 改音频的人 |

> **维护约定**：易漂移的内容（数值、命令、硬性规则、引擎事实）只在归属文档里写一次；
> 能写成断言的规则，同时落进 `tests/unit/`（见「[规范如何被强制](docs/art_pipeline.md#7-规范如何被强制)」）。

---

## 快速开始

```bash
# 运行游戏
./godot --path .

# 一键校验：导入缓存 + 单元测试 + 端到端冒烟测试
# （测试数与覆盖见「测试」一节；外层 timeout 兜底，避免挂死）
timeout 800 ./tools/check.sh

# 只跑单元测试 / 只跑冒烟测试
timeout 800 ./tools/check.sh unit
timeout 800 ./tools/check.sh smoke
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
现有 8 位 NPC 都有自己的作息：**大场景 `twon`** 里住着杂货店老板、村长、铁匠、
花婆婆和小满，到点各自走去商店 / 镇公所 / 铁匠铺 / 花摊 / 广场；
商人上班时才开店，花婆婆还经营一家**花店**。
地图网络：农场 → 小镇 `town` → 海滩 `beach` → 矿洞 `mine`，
农场 → `twon` → 图书馆 `library`；每张图由 `SceneRouter` 独立进入，
渔夫、矿工、图书管理员分别住在海滩 / 矿洞 / 图书馆。
按 `Esc` 打开菜单可以存读档、也可以回到标题页。

---

## 目录结构

```
open-farm/
├── project.godot              # autoload / InputMap / 像素渲染 / 本地化 / gdUnit4 配置
├── src/
│   ├── art/                   # 调色板与图集排版表（生成器与运行时共用的事实来源）
│   ├── audio/                 # 音频 id / 路径目录（生成器与运行时共用）
│   ├── autoload/              # 全局单例（见下方"九大单例"）
│   ├── core/                  # 与玩法无关的基础设施：日期、季节、朝向、状态机、交互基类、网格 A*
│   ├── data/                  # 数据资源的类定义（CropData / FloraData / ItemData / …）
│   ├── player/                # 玩家实体、体力、背包、工具带、状态机状态
│   ├── farm/                  # 农田网格、作物/牲畜生长规则、工具→农场的翻译层
│   │                          #   以及畜舍系统（AnimalData/State/Husbandry/Manager）
│   ├── npc/                   # NPC 实体、日程表（NpcSchedule）与行走网格（NpcNavigator）
│   ├── shop/                  # 商店交易规则（纯逻辑，可单测）
│   ├── world/                 # 世界场景基类、天气、边界墙、传送门、床、出货箱
│   │                          #   以及野生植被系统（FloraData/State/Growth/Field）
│   ├── ui/                    # HUD、对话框、背包、商店、系统菜单、UI 总入口
│   └── main/                  # 游戏主入口
├── scenes/                    # 场景文件，目录结构与 src/ 一一对应
├── data/                      # 实际的数据资源（.tres）：作物/牲畜/道具/NPC/对话/商店/日程，策划直接在编辑器里改
├── assets/                    # 全部由 tools/*.gd 生成（见 docs/art_pipeline.md、audio_pipeline.md）
│   ├── audio/                 # BGM 与音效（标题 / 农场 / 小镇 / 夜晚 + 26 个音效）
│   ├── i18n/strings.csv       # 翻译表（zh_CN / en）
│   ├── fonts/pixel_cjk.fnt    # 像素中文字体（1100 字形子集 + PNG 图集）
│   ├── fonts/ui_font.tres     # 子集外字符的系统字体兜底
│   ├── sprites/{actors,crops,animals,flora,items,props,weather}/
│   ├── ui/                    # UI 九宫格与图标
│   ├── title/                 # 标题页背景与云
│   ├── tilesets/              # 组装出来的 TileSet
│   └── themes/game_theme.tres # 组装出来的 Theme（字体 + 皮肤）
├── tests/unit/                # gdUnit4 单元测试（含美术 / 音频规范测试）
└── tools/                     # 资源生成（美术 / 音频）、校验、截图等开发工具
```

---

## 架构概览

本节只回答"是什么、在哪"；每个设计**为什么**这么写，见
[docs/architecture.md](docs/architecture.md)（关键决策见 §3，子系统见 §10 / §11）。

### 九大单例（Autoload）

启动顺序 = `project.godot` 的声明顺序；依赖图与约束见
[architecture §2](docs/architecture.md#2-autoload-依赖图)。

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
| `Audio` | 音频总管 | 合成 BGM / 音效的唯一播放出口；按场景与时间换曲，订阅 `EventBus` 播音效 |

### 三条贯穿全局的设计原则

1. **数据驱动**：作物 / 植被 / 道具 / 工具 / NPC / 对话 / 商店都是 `res://data/**/*.tres`，
   脚本只认 id（`Database.get_crop(&"turnip")`）。新增内容 = 新增 `.tres`，零脚本改动。
2. **静态数据 ↔ 运行时状态分离**：`XxxData`（`Resource`，不变）↔ `XxxState`
   （`RefCounted`，会变）；规则写在 `XxxGrowth` / `XxxHusbandry` 的纯静态函数里，可脱离引擎单测。
3. **信号解耦，顺序显式化**：UI 单向订阅 `EventBus`；有依赖顺序的日结转走
   `GameClock.register_day_hook()` 的有序列表——顺序即流水线
   （[architecture §3.3](docs/architecture.md#33-用有序钩子而不是信号做日结转)）。

展开与代码示例见 [architecture §3](docs/architecture.md#3-关键设计决策)。

### 子系统速查

| 子系统 | 权威状态 | 一句话 | 详见 |
| --- | --- | --- | --- |
| 世界自然生长 | `FloraField` | 每天"先长大、再按季节/天气撒新芽"；落点靠四道查询，连通性守卫防止堵门 | [§10](docs/architecture.md#10-世界自然生长野生植被) |
| NPC 日程与寻路 | `NpcSchedule` + `NpcNavigator` | 日程返回"当前生效段"；通行性来自物理查询，A* 惰性查格、按格缓存 | [§11](docs/architecture.md#11-npc-日程与寻路) |
| 场景切换 | `SceneRouter._world_cache` | 换 `WorldHost` 子节点而非 `change_scene_to_file`；地图实例缓存复用 | [§3.2](docs/architecture.md#32-世界场景换子节点不用-change_scene_to_file) |
| 畜舍养殖 | `LivestockManager` | 与 `FarmGrid` 同构：状态在字典、视图可重建、规则纯静态、牲畜不会死 | [§3.3.1](docs/architecture.md#331-畜舍为什么是-farmgrid-的翻版) |
| 昼夜光照 | `DayNight` + `WorldLighting` | 一条"分钟 → 环境光"曲线；天气染色与昼夜染色必须在同一个 `CanvasModulate` 相乘，路灯由 `WorldProp.light_radius` 生成 | [§12](docs/architecture.md#12-昼夜光照) |

> **生命周期铁律**：世界场景会缓存复用，`_ready()` 一生只跑一次。
> "每次进图都要做一遍"的事情放 `_enter_tree()` / `WorldScene.on_world_enter()`；
> 日结转钩子在 `_enter_tree()` 注册、`_exit_tree()` 注销，否则离开一次地图后就不再生长。
> 原理见 [architecture §3.2.2](docs/architecture.md#322-_ready-一生只跑一次)。

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
4. 想让某张地图多长/少长：改那张地图 `FloraField` 的 `initial_budget` / `daily_budget` / `max_total`；
   只想长指定几种就填 `allowed_species`（矿洞就是这么只长石头与蘑菇的）。

### 加一个 NPC

1. 在 `tools/art/generate_actors.gd` 的 `NPC_LOOKS` 里加一条外观（换衣服 / 头发 / 帽子），
   跑 `./tools/build_assets.sh`：`generate_resources.gd` 会自动扫描 `npc_*.png`
   并生成 `npc_<id>_frames.tres`，不需要再登记名单。
2. `data/dialogue/` 加 `DialogueData`（`lines` 里每句一个 `DialogueLine`），
   并在 `assets/i18n/strings.csv` 补名字 / 对白翻译键。
3. `data/schedules/` 加 `NpcSchedule`（可先看 `tools/generate_sample_data.gd` 的示例），
   每条 `ScheduleEntry` 填 `start_minute` / `location_id` / `activity`。
4. `data/npcs/` 加 `NpcData`，`default_dialogue` 指向对白、`schedule` 指向日程；
   如果是商人再填 `shop_id`，并用 `activity = "shop"` 表示上班时段。
5. 在 `scenes/world/*.tscn` 里放好 `SchedulePoint`（`point_id` 对应日程的 `location_id`），
   再实例化 `scenes/npc/npc.tscn`，改 `npc_id`。找不到地点时 NPC 会 `push_warning` 并原地不动。

### 加一个世界场景

1. 复制 `scenes/world/twon.tscn`（户外）或 `scenes/world/library.tscn`（室内），
   根节点脚本用 `WorldScene`，填 `world_id` / `camera_limits`。
2. 地面用脚本铺：户外参考 `src/world/beach_ground.gd` / `mine_ground.gd`，
   室内用 `src/world/interior_ground.gd`；改 `ground_area` 就换了地图大小。
3. 放至少一个 `SpawnPoint` 标记（`spawn_id` 要有意义，例如 `from_farm`）。
4. 在两边用 `SceneDoor` 互相连接（`target_scene` + `target_spawn_id`）。
5. 想让地图只长某些植被，填对应 `FloraField` 的 `allowed_species`。

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
| 单元测试 | gdUnit4（`tests/unit/`，283 例） | 日期进位、季节/天气、网格换算、背包堆叠、体力、工具带、作物生长（含枯死/多次收获）、牲畜养殖（成年/产出/喂食/好感度）、NPC 日程表与网格 A*、商店经济、状态机、时钟与日结转钩子、数据完整性、存档往返与容错 |
| 冒烟测试 | `tools/smoke_test.tscn`（189 项） | 真的把游戏跑起来：场景加载、玩家落点、翻地→播种→生长→收获全链路、放养→喂食→成长→收产出、买/卖、存读档、HUD 内容、**NPC 日程与寻路（导航网格、路径、真的走起来）**、**昼夜光照（环境光随时刻变化、路灯白天灭夜里亮）**、**农场 ↔ 小镇 / 农场 ↔ twon 往返后农田与畜舍进度、日结转钩子仍然有效**、**六张地图加载与 NPC 导航可达性** |
| 美术规范 | `tests/unit/test_assets.gd` | 生成物存在、尺寸与 `AtlasLayout` 一致、瓦片齐全、字体覆盖翻译表全部字符、数据都挂上了贴图 |
| 音频规范 | `tests/unit/test_audio.gd` | WAV 真的是 22050 Hz / 16 bit / 单声道；BGM 带 `smpl` 循环点、音效不带；运行时总线就位、音量可调 |
| 视觉回归 | `tools/screenshot.tscn` / `tools/ui_preview.tscn` | 标题页 + 农场 + 小镇 + twon + 海滩 + 矿洞 + 图书馆截图、各界面布局截图 |

各层"做什么 / 不做什么"的策略见 [architecture §7](docs/architecture.md#7-测试策略)。

```bash
timeout 800 ./tools/check.sh          # 全部（导入 + 单元 + 冒烟）
timeout 800 ./tools/check.sh unit     # 只要单元测试
timeout 800 ./tools/check.sh smoke    # 只要冒烟测试
```

---

## 美术资源：全部由脚本生成

**仓库里不放手工二进制素材。** 每一个像素、包括中文字体，都由 `tools/art/*.gd` 生成；
生成物提交进仓库，但**永不手改**。颜色只在 `src/art/palette.gd`、图集坐标只在
`src/art/atlas_layout.gd`，生成器与运行时引用同一批常量。

五条硬性规则、目录职责与修改流程见
**[docs/art_pipeline.md](docs/art_pipeline.md)**。

```bash
# 重新生成全部美术、音频与字体（16 步）
./tools/build_assets.sh

# 重置示例数据（作物 / 牲畜 / 道具 / 商店 / NPC / 对话；会顺带挂上贴图）
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/generate_sample_data.gd
```

改画面就改生成器与 `palette.gd` / `atlas_layout.gd` 后重跑 `build_assets.sh`；生成物永不手改。
运行 Godot 命令的超时规范见
[art_pipeline.md「命令必须能自己退出」](docs/art_pipeline.md#命令必须能自己退出)。

---

## 音频资源：同样由脚本生成

**仓库里也不放手工音频素材。** 4 首 BGM（标题 / 农场 / 小镇 / 夜晚）与 26 个音效
全部由 `tools/audio/*.gd` 合成；格式统一 22050 Hz / 16 bit / 单声道。
运行时由 `Audio` 单例唯一播放，玩法代码里没有任何播放调用。

格式约定、循环块处理、目录职责与运行时接线见
**[docs/audio_pipeline.md](docs/audio_pipeline.md)**。

```bash
./tools/build_assets.sh     # 连音频一起重新生成
```

改声音就改 `tools/audio/*.gd` 与 `AudioCatalog` 后重跑 `build_assets.sh`；生成物永不手改。

---

## 已知限制

- **美术是脚本画的**：像素画由 `tools/art/*.gd` 生成，风格统一但细节有限——
  没有手绘的光影、渐变与逐帧动画，角色只有 3 个朝向 × 4 个姿势。
- **音频也是脚本合成的**：BGM 是固定 BPM 的循环段、音效是振荡器 + 噪声，
  没有真实乐器采样、没有人声，也不会随剧情动态配乐——这是刻意的芯片音风格。
- **中文只覆盖"用到的字"**：像素字体是子集（约 1100 字形），
  玩家名一类运行期才出现的生僻字要走系统字体兜底；
  精简容器里没有系统 CJK 字体时仍会显示方块。加了新文案请重跑 `build_assets.sh`。
- **农场渲染层级**：作物统一在玩家之下绘制（`Crops` 容器整体参与 Y 排序）。
  要做到"玩家能走到高杆作物后面"，需要把作物挂到与玩家同一层再逐株 Y 排序。
- **昼夜光照是"整体染色 + 加色点光"**：环境光是整张画布一个 `CanvasModulate`，
  没有逐格明暗、没有影子；夜里只有摆了灯的地方亮（`WorldProp.light_radius`），
  室内外共用同一条时间曲线，也没有"不同区域不同光照"这类分区光照。
- **世界场景常驻内存**：切过的地图实例会一直保留（这是为了让农田进度跨场景不丢）。
  目前 6 张地图都会常驻；地图数量继续增长后需要改成"按需卸载 + 状态外置到存档层"。
- **水域没有碰撞**：`WATER` 只是地表瓦片，海滩的海水与小镇的池塘都能直接走进去
  （农田靠范围判定，不受影响）。
- **NPC 日程是固定时刻表**：只按时辰切换地点，没有工作日 / 天气 / 节日差异，
  也不会互相避让或绕开玩家；路上被新长出来的障碍挡住会重算一次，但不排队。
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
2. **表现**：更丰富的生成器画法（光影 / 更多逐帧动画）、Tilemap 地形自动过渡。
3. **系统**：好感度与恋爱、节日与事件、NPC 之间的避让与排队、工具升级与体力上限成长。
4. **流程**：多存档槽选择界面、新手引导、结局与结算。
5. **工程**：导出预设（Windows / Linux / macOS）、GitHub Actions 跑 `tools/check.sh`、帧率与内存基线。

---

## 参考

- [Godot 官方最佳实践](https://docs.godotengine.org/en/stable/tutorials/best_practices/introduction_best_practices.html)
- [gdUnit4 文档](https://mikeschulze.github.io/gdUnit4/)
- 本仓库的 [架构与设计决策](docs/architecture.md) —— 每个"为什么不按常见教程写"的答案、以及踩过的 Godot 坑
- 本仓库的 [美术资源规范](docs/art_pipeline.md) —— 为什么美术也应当是代码，以及怎么加新素材
- 本仓库的 [音频资源规范](docs/audio_pipeline.md) —— 为什么音频也应当是代码，以及怎么加新音色
- [AGENTS.md](AGENTS.md) —— 给编码 Agent 的项目速览（新会话自动加载，少做侦察）
