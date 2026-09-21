# 世界内容角色模型

> **状态**：设计稿（待评审）。本文件给"世界里的东西"定角色——新增内容时按判据归位，
> 而不是凭感觉在 Props / Decor / Flora / Crops 之间选。
> 摆件尺寸契约见 [附 A](#附-a摆件尺度表scenery-的尺寸契约)；可持有物品见 `data/items/`。

## 一、结论：5 个角色 + 1 个正交目录

现在的 `Props / Decor / Flora / Crops` **不在一个维度上**，所以看着乱：

- `Decor` 与 `Props` 是同一个角色（静态景），只是落位方式不同；
- `Flora` 与 `Crops` 是同一个角色（模拟实体），只是宿主规则不同；
- 真正的角色只有 5 个，外加 1 个不属于世界（物品目录）。

| 角色 | 一句话 | 现状实现 |
|---|---|---|
| **Terrain** 地形 | 地图的底，无状态、确定性 | GroundPainter、WaterField、InteriorWalls |
| **Entity** 模拟实体 | 有状态、参与日结、进存档 | Crop、Flora、Animal、NPC |
| **Scenery** 静态景 | 无状态，只画面与阻挡 | WorldProp（DecorPainter 是它的撒点器） |
| **Fixture** 交互件 | 固定位置 + 响应主操作键 | bed、shipping_bin、boards、counter… |
| **Trigger** 元信息 | 不渲染，只表达坐标 + 语义 | SpawnPoint、SceneDoor、Bounds、SchedulePoint |
| **Atmosphere** 氛围 | 影响整图表现的跨域服务 | WorldLighting、WeatherFx、SeasonLook、Bgm |
| *Items* 目录 | 正交轴，只按 id 被引用 | `data/items/*.tres` + `ItemData` |

## 二、判据：只问三个问题

1. **会不会变？** 有没有可变、要存档 / 日结的状态。
2. **怎么落位？** 按规则算，还是场景手工声明。
3. **响应按键吗？** 有没有主操作键交互。

再补一个范围问题：**它影响哪一层？** 单格 / 多格 / 自由坐标 / 整图表现。

## 三、角色契约

### 3.1 Terrain 地形

- **定义**：地图的"底"，无状态、确定性。含地板、水体、室内墙地、地图变体（矿洞 / 节日场地）。
- **唯一权威**：地图自己的 `*_ground.gd`（或 `FarmGrid.paint_ground`）。
- **落位**：按坐标算，**不用随机数**（或固定种子）；同一张图每次一样。
- **生命周期**：`_ready` 铺一次；换季只换 `TileSet`（`SeasonLook`），**不重铺、不重建**。
- **渲染 / 碰撞**：`TileMapLayer`（z<0）；水面 `WaterField`（z=-15，多边形碰撞 + `_draw` 动效）。
- **不做什么**：不持有可变状态、不进存档（瓦片是算出来的）、不发领域信号。
- **新增方式**：写一个 `*_ground.gd` 调 `GroundPainter`，或声明 `WaterLayout`。

### 3.2 Entity 模拟实体

- **定义**：有可变状态、参与日结、要存档的世界对象。
- **统一形状**（`AGENTS.md` 第一原则）：`Data(Resource) + State(RefCounted) + 规则(纯静态函数) + View(Node2D)`；宿主持有 State、注册日结钩子（`GameDateClock.register_day_hook`，`_exit_tree` 注销）、负责 `to_dict / from_dict`。
- **两个子型**：
  - **GridEntity**：按格存在、有生长 / 扩散 —— Crop（宿主 `FarmGrid`）、Flora（宿主 `FloraField`）；
  - **FreeEntity**：自由移动 / 按日程 —— Animal（`LivestockManager`）、NPC（`NpcField`）。
- **View 职责**：只读 State 渲染，不存游戏状态；状态变化由宿主驱动 `refresh()`。
- **不做什么**：不直接改别的域的状态；跨域只发领域信号（`EventBus.player/farm/world/ui`）。
- **新增方式**：Data `.tres` + State + 规则静态函数 + View + 在宿主 register。

### 3.3 Scenery 静态景

- **定义**：无状态、不变的摆件；只负责画面与阻挡（可能带遮挡 / 淡出 / 夜灯）。
- **实现**：`WorldProp`（贴图 + 尺寸表 + 碰撞 + 假影子 + 建筑身后淡出 + 夜灯）。
- **落位两种**：
  - **手工摆** → `.tscn` 里的 `WorldProp` 节点（房子 / 树 / 灯 / 石）；
  - **规则撒** → `DecorPainter`（1 格地被）。它**不是独立角色**，只是"按格子表生成 `WorldProp`"。
- **尺寸契约**：`AtlasLayout.PROPS`（见 [附 A](#附-a摆件尺度表scenery-的尺寸契约)）。
- **建筑**：多格 Scenery + `building` 组淡出；室内是另一张 world 场景 + Trigger 门，**不需要新角色**。
- **不做什么**：不持有状态、不进存档、不响应按键。

### 3.4 Fixture 交互件

- **定义**：固定位置 + 响应主操作键的功能物件。
- **目标实现**：`WorldProp`（拿渲染 / 碰撞 / 影子）+ `Interactable` 组件（响应主操作、发 `UiEvents` / 域请求）。
- **现有**：bed、shipping_bin、cooking_stand、museum_stand、commission_board、goal_board、upgrade_bench、shop_counter、mine_ladder、mine_elevator。
- **状态**：多数无；需要持久化的走所属域 State，**不自己存档**。
- **不做什么**：不直接改数值 / 背包 / 存档；只发请求，由领域单元处理（"界面只展示 / 发请求"同一条原则）。

### 3.5 Trigger 元信息

- **定义**：不渲染，只表达"坐标 + 语义"。
- **现有**：`SpawnPoint`、`SceneDoor`、`WorldBounds`、`SchedulePoint`。
- **归属**：场景标记；改出生点 / 门 / 日程锚点只动这些。
- **不做什么**：不持有状态、不渲染、不建碰撞（`WorldBounds` 除外，它就是边界碰撞）。

### 3.6 Atmosphere 氛围

- **定义**：影响整图表现的跨域服务。
- **现有**：`WorldLighting`（唯一 `CanvasModulate` + 统一灯能量）、`WeatherFx`（粒子，跟随相机）、`SeasonLook`（换 TileSet / 树贴图）、`Bgm` / `Ambience`。
- **挂载**：由 `WorldScene` 按 `*_effects` 开关自动挂载；订阅时钟 / 天气服务。
- **不做什么**：不持有玩法状态；**每张画布只允许一个 `CanvasModulate`**（项目已踩过坑）。

### 3.7 Items 目录（正交，不属于世界）

- **定义**：全游戏可持有物品总表 `data/items/*.tres`（`ItemData`），由 `Database` 按 id 索引。
- **谁消费**：背包 / 商店 / 出货箱 / 图鉴 / 委托 / 料理 / HUD。
- **与世界的关系**：只有 id 外键。Entity / Fixture 通过 `harvest_item_id` / `drop_item_id` / `product_item_id` / `item_id` 产出或引用物品；Terrain / Scenery / Trigger / Atmosphere 完全不碰。
- **别混**：对象定义（`CropData` / `FishData` / `FloraData` / `ToolData`…）≠ 物品（`ItemData`）；`ItemData.tool_id → ToolData`，"背包里的斧头"与"挥动规则"是两份资产。
- **别混贴图**：物品图标 `assets/sprites/items/*.png`（UI 16×16）≠ 世界贴图 `assets/sprites/props|flora/*.png` ≠ 手持 `assets/sprites/tools/*.png`。

## 四、现有系统 → 角色

| 现有实现 | 角色 | 备注 / 迁移 |
|---|---|---|
| `GroundPainter`、各 `*_ground.gd` | Terrain | 保持 |
| `WaterLayout` / `WaterField` / `WaterShape` | Terrain（水体） | 保持；是否独立成角色待定 |
| `InteriorGround` / `InteriorWalls` | Terrain（室内） | 保持 |
| `MineGround` / `FestivalGround` | Terrain（地图变体） | 保持 |
| `FarmGrid` + `Crop` | Entity / GridEntity | 与 Flora 抽同一契约（批次 F） |
| `FloraField` + `Flora` | Entity / GridEntity | 同上 |
| `LivestockManager` + `AnimalPen` / `Animal` | Entity / FreeEntity | 保持宿主，统一形状 |
| `NpcField` + `Npc` / `SchedulePoint` | Entity / FreeEntity + Trigger | SchedulePoint 是 Trigger |
| `WorldProp` | Scenery | 尺寸已收口到 `PROPS` |
| `DecorPainter` | Scenery 的**撒点器** | 尺寸表待并入 `PROPS`（批次 D） |
| bed / shipping_bin / boards / counter / … | Fixture | 目标统一为 `WorldProp + Interactable` |
| `SpawnPoint` / `SceneDoor` / `WorldBounds` / `SchedulePoint` | Trigger | 保持 |
| `WorldLighting` / `WeatherFx` / `SeasonLook` / `Bgm` | Atmosphere | 保持，由 `WorldScene` 挂载 |
| `data/items/*.tres` + `ItemData` | Items 目录 | 正交，不属于世界 |

## 五、放置决策树

```text
新增世界内容：
├─ 有可变状态、要存档 / 日结？ ── 是 ── Entity（Data + State + 规则静态函数）
│                                   ├─ 占格且按网格长 → GridEntity（Crop / Flora 式宿主）
│                                   └─ 自由移动       → FreeEntity（NPC / Animal 式宿主）
├─ 要按键交互？ ── 是 ── Fixture（WorldProp + Interactable）
├─ 纯静态、要挡人 / 遮挡？ ── 是 ── Scenery（WorldProp）
│                                   ├─ 手工摆位 → .tscn 节点
│                                   └─ 按规则撒 → DecorPainter
├─ 只是"从哪进 / 出生 / 日程点"？ ── Trigger（Marker / Area2D）
└─ 影响整图表现（光 / 天气 / 季节 / 声）？ ── Atmosphere（挂 WorldScene 的服务）
```

## 六、不变量（防止再乱）

1. **单一权威**：每份状态、行为、副作用有且只有一个主人，其余人只能请求（`AGENTS.md` 第一原则）。
2. **同一角色只实现一次**：`DecorPainter` 不得再自带一套尺寸表；Crop / Flora 不得各写一套日结。
3. **行为贴数据**：数值进 `data/**/*.tres`，规则写成纯静态函数，代码不写特例分支。
4. **依赖显式注入**：宿主从组合根 / 注入拿依赖，不做全树分组查找。
5. **跨域只走 EventBus 四个域对象**：`player / farm / world / ui`；不新增 Autoload。
6. **不混轴**：`ItemData` 不是世界对象，世界对象也不进背包；两者只按 id 关联。
7. **不合并角色**：Terrain 要绝对确定性、Entity 要存档、Scenery 零状态、Trigger 只是坐标——生命周期与失败代价不同，合了会互相拖累。

## 七、待定 / 需拍板

1. **Entity 契约**：现在就抽 `GridEntityField`（Crop / Flora 共用），还是先维持两个宿主、只统一形状？
2. **Fixture**：统一成 `WorldProp + Interactable` 组件，还是保留 10 个独立脚本？
3. **水体**：算 Terrain 子型，还是独立角色（它有独立碰撞与动效）？
4. **Decor 并入 PROPS** 的时间点（批次 D 可随时做）。
5. **FreeEntity** 把 NPC 与 Animal 归一类是否可接受（两者宿主与更新频率不同）。
6. 本文件是否升格为 `AGENTS.md` 的强制规范（新增内容必须按决策树归位）。

---

## 附 A：摆件尺度表（Scenery 的尺寸契约）

> 数值一律以 `src/art/atlas_layout.gd` 的 `PROPS` 为准，本文不重复。

- **基准**：1 格 = `TILE` = 16px；玩家 = 1×2 格，是全表唯一参照，不用现实单位。
- **表结构**：`prop_id -> { visual, footprint, solid, solid_offset, passable }`；
  `visual` = 贴图像素尺寸，`footprint` = 逻辑占地格数，`solid` = 实际阻挡盒（可与 footprint 不同，
  如房子占地 4×4 只挡底部一条）；读取接口 `prop_spec / prop_visual / prop_footprint / prop_passable`。
- **`WorldProp` 契约**：id 从贴图文件名推断并在 `_ready` 缓存；碰撞顺序 = 场景显式 `solid_size` > `PROPS` > 旧自动脚印；`solid_size / solid_offset` 只作特例逃生舱。
- **几何约定**：允许"视觉 > 占地"（树冠 / 灯头 / 玩家）；`footprint` 不得超过视觉覆盖的格数。

### 操作手册

改一个已有摆件尺寸：
1. 改 `AtlasLayout.PROPS[id]`；
2. `visual` 变了就回 `tools/art/generate_props.gd` 重画内部坐标（`_canvas` 只开画布）；
3. 按 `y -= (新高 - 旧高) / 2` 迁移 `.tscn` 节点，保持落地线不动；
4. `./tools/build_assets.sh` + `./tools/check.sh unit`。

新增摆件：生成器加画法并导出 PNG → `PROPS` 加一条 → 场景摆 `WorldProp`（不手填 `solid_size`）→ `test_prop_scale` 自动覆盖。

### 后续批次

| 批次 | 内容 | 风险 |
|---|---|---|
| B | 野外植被：`boulder` 视觉 + 2×2 多格占地（`FloraData.footprint` + `FloraField` 占位 / 落点 / 存档重算）；野外树视觉同步 | 中 |
| C | 建筑：门净高 ≥ 2 格、房子整体放大；重排地图坐标 | 高 |
| D | `DecorPainter` 的尺寸表并入 `PROPS` | 低 |
| E | 抽 `tools/art/` 共用美术模块（`generate_props` 与 `generate_flora` 现在各有一份树冠画法） | 低 |
| F | Entity 抽 `GridEntityField` 契约 | 大 |
