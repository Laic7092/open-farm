# 世界摆件尺度（设计约定）

> **状态**：约定已生效，未完成批次见 [§后续](#后续批次)。
> 本文件只写"为什么这样设计、怎么用、接下来做什么"；
> **数值一律以 `src/art/atlas_layout.gd` 的 `PROPS` 为准，本文不重复**。

## 一、基准

- **1 格 = `TILE` = 16px**；玩家 = **1×2 格**（`PLAYER_FOOTPRINT` / `PLAYER_VISUAL`），是全表唯一参照物。
- 尺寸一律用"格 + 玩家比例"表达，**不使用现实单位**——这是俯视角像素游戏，"真实"= 相对玩家可读。

## 二、表结构

唯一来源：`AtlasLayout.PROPS`，`prop_id -> { visual, footprint, solid, solid_offset, passable }`。

| 字段 | 含义 | 约定 |
|---|---|---|
| `visual: Vector2i` | 贴图像素尺寸 | 生成器出图、测试校验都用它 |
| `footprint: Vector2i` | 逻辑占地**格数** | 正整数格；"占几格" |
| `solid: Vector2` | 实际阻挡盒像素尺寸 | **可与 footprint 不同**：房子占地 4×4，只挡底部一条 |
| `solid_offset: Vector2` | 阻挡盒相对精灵中心偏移 | 用表值，不逐场景手调 |
| `passable: bool` | 能否穿过 | 唯一可穿标记 |

读取接口：`prop_spec` / `prop_visual` / `prop_footprint` / `prop_passable`；未知 id 一律安全回退。

**两条几何约定**
1. 允许 **视觉 > 占地**（树冠、灯头、玩家都如此）：`visual.y` 可以大于 `footprint.y × TILE`。
2. `footprint` 不允许超过视觉覆盖的格数；`test_prop_scale` 会断言。

## 三、归属边界

本表**只收"场景摆放的 `WorldProp`"**，避免变成大泥球：

| 内容 | 归谁 |
|---|---|
| 场景摆放的静态摆件 / 建筑 | `AtlasLayout.PROPS` + `WorldProp` |
| 野生植被（会生长 / 采集 / 存档） | `data/flora/*.tres`（`FloraData`）+ `FloraField` |
| 1 格地被装饰 | `DecorPainter`（批次 D 计划并入 `PROPS`） |
| 可持有物品 | `data/items/*.tres`（正交轴，只按 id 被引用） |

不新增 Autoload；不引入现实单位；不在别处重复尺寸数值。

## 四、`WorldProp` 契约

- **id 推断**：显式 `prop_id` 优先，否则取贴图文件名（`props/lamp.png -> lamp`）；在 `_ready()` 缓存，季节换图后仍稳定。
- **碰撞顺序**：场景显式 `solid_size` → `PROPS[id].solid` → 旧的按贴图底部自动脚印（兜底）。
- **通行**：场景显式 `passable` 或表标记。
- `solid_size` / `solid_offset` 保留为**特例逃生舱**：只在某个场景确实要单独偏移时用，常规节点不填。

## 五、操作手册

### 改一个已有摆件尺寸
1. 改 `src/art/atlas_layout.gd` 的 `PROPS[id]`（`visual` / `footprint` / `solid` / `solid_offset`）；
2. 若 `visual` 变了，回 `tools/art/generate_props.gd` 对应 `_xxx()` 重画内部像素坐标（`_canvas` 只开画布）；
3. 节点原点 = 贴图中心，视觉变高后按 `y -= (新高 - 旧高) / 2` 迁移 `.tscn` 节点，保持落地线不动；
4. `./tools/build_assets.sh`，再 `./tools/check.sh unit`。

### 新增一个摆件
1. `tools/art/generate_props.gd` 加画法并导出 PNG；
2. `PROPS` 加一条；
3. 场景里摆 `WorldProp`（不要手填 `solid_size`）；
4. `test_prop_scale` 自动覆盖（断言 PNG 尺寸 = `visual`、footprint 合法）。

### 命令
```bash
./tools/build_assets.sh     # 重新生成美术并刷新导入
./tools/check.sh unit       # 单元测试
./tools/check.sh smoke      # 冒烟
```

## 六、后续批次

| 批次 | 内容 | 风险 |
|---|---|---|
| B | **野外植被**：`boulder` 视觉 + **2×2 多格占地**（需 `FloraData.footprint` + `FloraField` 占位/落点/存档重算）；`tree_oak` / `tree_pine` 视觉同步，消除同图高矮不一 | 中 |
| C | **建筑**：门净高 ≥ 2 格、房子整体放大；需重排所有地图坐标 | 高 |
| D | **Decor 并入 `PROPS`**：`DecorPainter` 自带的 `TEXTURES/PASSABLE/SOLID_*` 收口到 `PROPS`，它只保留"按格子表撒" | 低 |
| E | **共用美术模块**：`generate_props` 与 `generate_flora` 各有一份 `_oak_canopy` / `_pine_canopy`，抽成 `tools/art/` 共享模块 | 低 |
| F | **放置角色模型**与 `GridEntityField` 契约 | 大 |

## 七、世界内容角色模型（讨论稿）

用三个问题决定归属：**会不会变？怎么落位？响应按键吗？**

| 角色 | 会变? | 落位 | 现状实现 |
|---|---|---|---|
| Terrain 地形 | 否 | 规则算 | `GroundPainter`、`WaterField` |
| Entity 模拟实体 | 是（存档/日结） | 规则算 | Crop / Flora / Animal / NPC |
| Scenery 静态景 | 否 | 手工摆 / 规则撒 | `WorldProp`；`DecorPainter` 只是"规则撒 `WorldProp`" |
| Fixture 交互件 | 少量 | 手工摆 | bed / shipping_bin / boards / counter… |
| Trigger 元信息 | 否 | 手工摆 | SpawnPoint / SceneDoor / Bounds / SchedulePoint |
| Atmosphere 氛围 | 跨域服务 | 自动挂载 | WorldLighting / WeatherFx / SeasonLook / Bgm |
| **Items 目录** | 无位置 | 扁平 id | `data/items/*.tres`（正交轴，被 Entity/Fixture 按 id 引用） |

**放置决策树**

```text
新增世界内容：
├─ 有可变状态、要存档 / 日结？ ── 是 ── Entity（Data + State + 规则静态函数）
│                                   ├─ 占格且按网格长 → Crop / Flora 式宿主
│                                   └─ 自由移动       → NPC / Animal 式宿主
├─ 要按键交互？ ── 是 ── Fixture（WorldProp + Interactable）
├─ 纯静态、要挡人 / 遮挡？ ── 是 ── Scenery（WorldProp）
│                                   ├─ 手工摆位 → .tscn 节点
│                                   └─ 按规则撒 → DecorPainter
├─ 只是"从哪进 / 出生 / 日程点"？ ── Trigger（Marker / Area2D）
└─ 影响整图表现（光 / 天气 / 季节 / 声）？ ── Atmosphere（挂 WorldScene 的服务）
```

> 不建议把 5 个角色合成一个框架：它们的生命周期与失败代价不同（Terrain 要绝对确定性、Entity 要存档、Scenery 零状态、Trigger 只是坐标）。要统一的是"同一角色只实现一次"，不是"所有东西一个系统"。
