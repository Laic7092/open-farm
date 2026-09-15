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

- Autoload 仍是 `EventBus` `AppTheme` `Database` `SaveManager` `SceneRouter`；
  其中 `Database` 只暴露只读 getter 快照，`EventBus` 只保留 10 个跨域时间 / 场景 / 存档信号。
- 领域事件拆为 `EventBus.player` / `EventBus.farm` / `EventBus.world` / `EventBus.ui`：
  `PlayerProfile.events`、组合根 `farm_events`、`WorldHost.events`、`UiRoot.events`
  持有同一对象引用；节点连接仍走 `EventBus.<domain>.<signal>`。
- 天气 / 关系 / 日历已从 Autoload 收口为 `Main` 组合根拥有的服务节点：
  `WeatherService`、`RelationshipService`、`CalendarService`；
  对应状态 `WeatherState` / `RelationshipStore` / `CalendarProgress` 仍由 `Main` 持有并注入。
- 音频也去掉了全局 Autoload：标题页与 `Main` 各自在场景里挂一个 `SceneAudio` 节点，
  世界曲目 / 脚步音由各 `WorldScene` 的导出字段声明。
- 玩家 / 时钟状态由 `Main` 持有并显式注入：`PlayerProfile`、`GameDateClock`。
- `Main` 在 `_enter_tree()` 里创建服务并注入依赖，保证早于世界 / UI 子树；
  核心存档节由 `Main` 显式注册为 `Array[SaveSection]`，场景节点继续用
  `Persistence.register()` 自注册，`SaveManager` 统一包装成 `SaveSection`。
- 世界实例缓存与待恢复目标移到 `WorldHost`；`SceneRouter.change_scene_to(host, path, spawn)`
  只做无状态过渡，不再保存任何世界节点。
- 详细代码入口：`src/main/main.gd`、`src/main/world_host.gd`、`src/services/*.gd`、
  `src/core/save_section.gd`、`src/core/persistence.gd`、`src/autoload/save_manager.gd`。

## 3. 关键设计决策

| 决策 | 要点 | 代码入口 |
| --- | --- | --- |
| 存档用 JSON | 避免 `ResourceSaver` 写入脚本路径；显式版本号 + `from_dict` 字段兜底 | `save_manager.gd` |
| 世界场景换子节点 | `Main` 常驻 `WorldHost` / `UiRoot`，不用 `change_scene_to_file`；缓存与当前实例在 `WorldHost`，`SceneRouter` 只做无状态过渡 | `main.gd`、`world_host.gd`、`scene_router.gd` |
| 领域事件 | 全局只留时间 / 场景 / 存档信号；玩家 / 农场 / 世界 / UI 信号挂在由状态或宿主持有的领域对象上 | `event_bus.gd`、`src/events/*.gd` |
| `_ready()` 一生只跑一次 | 缓存复用场景不重跑 `_ready()`；每次进图逻辑放 `_enter_tree()` / `_exit_tree()` | `world_scene.gd` |
| 有序日结转 | 不依赖信号回调顺序；`GameDateClock` 委托给 `DayPipeline`，按显式 `priority` 同步执行 | `game_date_clock.gd`、`day_pipeline.gd` |
| 数据驱动 | 内容都在 `.tres`，脚本只认 id；静态数据与运行时状态分离 | `database.gd` |
| UI 模态栈 | `UiRoot` 统一管理暂停与 `close_all()`，避免读档 / 传送残留菜单 | `ui_root.gd` |

## 4. Godot 踩坑

- 手写 `.tscn`：导出的节点引用要声明 `node_paths=PackedStringArray(...)`；`%UniqueName` 要设置 `unique_name_in_owner = true`。
- `godot -s script.gd` 在 autoload 注册前编译脚本；生成器用 `preload()`，依赖 autoload 的工具做成场景运行。
- Godot 每张画布只允许一个 `CanvasModulate`；天气与昼夜必须由 `WorldLighting` 统一相乘，否则只有一个生效。
- 子节点 `_ready()` 先于父节点；状态机初始切换用 `call_deferred()`，避免父节点 `@onready` 还是 null。
- Godot 命令必须能自己退出：统一套 `timeout` 并在末尾带 `--quit-after 3`（脚本解析失败时不会调用 `quit()`，会挂死在主循环）；不要用管道直连，先重定向到文件再 `tail` / `grep`。

## 5. 子系统索引

“怎么加内容”见 [README 的扩展入口](../README.md#扩展入口)；下表只负责理解现有子系统。

| 子系统 | 代码入口 | 先看什么 |
| --- | --- | --- |
| 野生植被 | `src/world/flora_field.gd`、`flora_growth.gd` | 状态在 `Dictionary`；日结转生长 + 进图补算；`allowed_species` 控制物种 |
| NPC 日程 / 寻路 | `src/npc/npc.gd`、`npc_navigator.gd`、`src/core/grid_pathfinder.gd` | 日程返回“当前生效段”；可通行性来自物理查询并按格缓存 |
| 昼夜光照 | `src/world/day_night.gd`、`world_lighting.gd` | 分钟到环境光的静态曲线；灯由 `WorldProp.light_radius` 生成 |
| 好感度 / 恋爱 | `src/services/relationship_service.gd`、`src/npc/affection_rules.gd`、`src/npc/marriage_rules.gd` | 跨场景状态集中在 `RelationshipStore`；规则纯静态；孩子用 `required_flag` 门控 |
| 节日 / 事件 | `src/services/calendar_service.gd`、`festival_rules.gd`、`event_rules.gd` | 节日与事件是两类数据；规则纯静态；事件只在日结转按显式事实输入判定 |
| 天气 | `src/services/weather_service.gd`、`src/core/weather.gd`、`src/core/weather_state.gd` | 状态在 `WeatherState`；服务注册最高优先级日结转，先掷天气再让日历 / 农场读取 |
| 世界连接 | `src/autoload/scene_router.gd`、`src/world/scene_door.gd`、`ground_painter.gd` | 链式地图；`auto_enter` / `road_exit`；乡道压纵向中线由 `test_world_map.gd` 守 |
| 畜舍 | `src/farm/livestock_manager.gd`、`animal_husbandry.gd` | 与 `FarmGrid` 同构：状态字典、视图可重建、规则纯静态 |

## 6. 测试策略

- `tests/unit/`：只测纯逻辑，不加载场景、不模拟输入。
- `tools/smoke_test.tscn`：真实场景 + autoload 接线 + 完整玩法链路；检查按域拆在 `tools/smoke/`（世界 / 农场 / 巡游 / 钓鱼），公共断言在 `smoke_base.gd`。
- `tests/unit/test_assets.gd` / `test_audio.gd`：把美术 / 音频规范写成可执行断言。
- `tools/screenshot.tscn` / `ui_preview.tscn`：视觉回归预览，不做像素级 diff。
