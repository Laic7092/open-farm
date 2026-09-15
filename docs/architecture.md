# 架构速览

本文只保留**跨模块、难以从单个文件看出的约定**；单个系统的设计原因写在对应脚本顶部的 `##` 注释里。
需要完整历史版本时看 git 历史，不再维护 700 行长文。

## 1. 分层与依赖方向

```text
UI        只订阅 EventBus，从不反向调用玩法代码
玩法      场景节点：Player / FarmGrid / Livestock / Npc / Shop
规则      纯静态函数或 RefCounted：CropGrowth / AnimalHusbandry / AffectionRules / GridPathfinder
数据      res://data/**/*.tres：CropData / AnimalData / ItemData / NpcData / ...
```

依赖方向永远向下：UI 不知道玩法，玩法不知道规则实现，规则不知道数据从哪来。
唯一向上的通路是 `EventBus`，它是单向广播，不构成循环依赖。

## 2. Autoload 与组合根

- 当前 9 个 Autoload，声明顺序即 `_ready()` 顺序：
  `EventBus` `AppTheme` `Database` `WeatherSystem` `Relationships` `Calendar` `SaveManager` `SceneRouter` `Audio`。
- 玩家 / 时钟 / 天气 / 关系 / 日历进度状态都由 `Main` 作为组合根持有并显式注入：
  `PlayerProfile`、`GameDateClock`、`WeatherState`、`RelationshipStore`、`CalendarProgress`。
- `Main` 在 `_enter_tree()` 里注入依赖，保证早于世界 / UI 子树；
  核心存档参与者通过 `Persistence.register_core*()` 自注册，`SaveManager` 不维护名单。
- 详细代码入口：`src/main/main.gd`、`src/core/persistence.gd`、`src/autoload/save_manager.gd`。

## 3. 关键设计决策

| 决策 | 要点 | 代码入口 |
| --- | --- | --- |
| 存档用 JSON | 避免 `ResourceSaver` 写入脚本路径；显式版本号 + `from_dict` 字段兜底 | `save_manager.gd` |
| 世界场景换子节点 | `Main` 常驻 `WorldHost` / `UiRoot`，不用 `change_scene_to_file`；`SceneRouter` 缓存地图实例 | `main.gd`、`scene_router.gd` |
| `_ready()` 一生只跑一次 | 缓存复用场景不重跑 `_ready()`；每次进图逻辑放 `_enter_tree()` / `_exit_tree()` | `world_scene.gd` |
| 有序日结转 | 不依赖信号回调顺序；`GameDateClock.register_day_hook()` 按注册顺序同步执行 | `game_date_clock.gd` |
| 数据驱动 | 内容都在 `.tres`，脚本只认 id；静态数据与运行时状态分离 | `database.gd` |
| UI 模态栈 | `UiRoot` 统一管理暂停与 `close_all()`，避免读档 / 传送残留菜单 | `ui_root.gd` |

## 4. Godot 踩坑

- 手写 `.tscn`：导出的节点引用要声明 `node_paths=PackedStringArray(...)`；`%UniqueName` 要设置 `unique_name_in_owner = true`。
- `godot -s script.gd` 在 autoload 注册前编译脚本；生成器用 `preload()`，依赖 autoload 的工具做成场景运行。
- Godot 每张画布只允许一个 `CanvasModulate`；天气与昼夜必须由 `WorldLighting` 统一相乘，否则只有一个生效。
- 子节点 `_ready()` 先于父节点；状态机初始切换用 `call_deferred()`，避免父节点 `@onready` 还是 null。
- Godot 命令统一 `timeout ... --quit-after 3`，不要用管道直连；规范原文见 `art_pipeline.md`。

## 5. 子系统索引

“怎么加内容”见 [README 的扩展入口](../README.md#扩展入口)；下表只负责理解现有子系统。

| 子系统 | 代码入口 | 先看什么 |
| --- | --- | --- |
| 野生植被 | `src/world/flora_field.gd`、`flora_growth.gd` | 状态在 `Dictionary`；日结转生长 + 进图补算；`allowed_species` 控制物种 |
| NPC 日程 / 寻路 | `src/npc/npc.gd`、`npc_navigator.gd`、`src/core/grid_pathfinder.gd` | 日程返回“当前生效段”；可通行性来自物理查询并按格缓存 |
| 昼夜光照 | `src/world/day_night.gd`、`world_lighting.gd` | 分钟到环境光的静态曲线；灯由 `WorldProp.light_radius` 生成 |
| 好感度 / 恋爱 | `src/autoload/relationships.gd`、`src/npc/affection_rules.gd` | 跨场景状态集中在 `RelationshipStore`；规则纯静态；孩子用 `required_flag` 门控 |
| 节日 / 事件 | `src/autoload/calendar.gd`、`festival_rules.gd`、`event_rules.gd` | 节日与事件是两类数据；规则纯静态；事件只在日结转判定 |
| 世界连接 | `src/autoload/scene_router.gd`、`src/world/scene_door.gd`、`ground_painter.gd` | 链式地图；`auto_enter` / `road_exit`；乡道压纵向中线由 `test_world_map.gd` 守 |
| 畜舍 | `src/farm/livestock_manager.gd`、`animal_husbandry.gd` | 与 `FarmGrid` 同构：状态字典、视图可重建、规则纯静态 |

## 6. 测试策略

- `tests/unit/`：只测纯逻辑，不加载场景、不模拟输入。
- `tools/smoke_test.tscn`：真实场景 + autoload 接线 + 完整玩法链路。
- `tests/unit/test_assets.gd` / `test_audio.gd`：把美术 / 音频规范写成可执行断言。
- `tools/screenshot.tscn` / `ui_preview.tscn`：视觉回归预览，不做像素级 diff。
