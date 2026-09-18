# 架构速览

本文只保留**跨模块、难以从单个文件看出的约定**；单个系统的设计原因写在对应脚本顶部的 `##` 注释里，
完整历史版本看 git 历史。

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

- Autoload：`EventBus` `AppTheme` `Database` `SaveManager` `SceneRouter`。
  `Database` 只暴露只读 getter 快照；`EventBus` 只保留跨域时间 / 场景 / 存档信号。
- 领域事件拆为 `EventBus.player` / `EventBus.farm` / `EventBus.world` / `EventBus.ui`：
  `PlayerProfile.events`、组合根 `farm_events`、`WorldHost.events`、`UiRoot.events` 持有同一对象引用；
  节点连接仍走 `EventBus.<domain>.<signal>`。
- 天气 / 关系 / 日历不是 Autoload，而是 `Main` 组合根拥有的服务节点：`WeatherService`、
  `RelationshipService`、`CalendarService`；对应状态 `WeatherState` / `RelationshipStore` / `CalendarProgress`
  由 `Main` 持有并注入。
- 音频没有全局 Autoload：标题页与 `Main` 各自在场景里挂一个 `SceneAudio` 节点，
  世界曲目 / 脚步音由各 `WorldScene` 的导出字段声明。
- 玩家 / 时钟状态由 `Main` 持有并显式注入：`PlayerProfile`、`GameDateClock`。
- `Main` 在 `_enter_tree()` 里创建服务并注入依赖，保证早于世界 / UI 子树；核心存档节由 `Main` 显式注册为
  `Array[SaveSection]`，场景节点继续用 `Persistence.register()` 自注册，`SaveManager` 统一包装成 `SaveSection`。
  日结自动存档是 `Main` 注册的最高优先级日结转钩子，跑在所有模拟钩子之后。
- 世界实例缓存与待恢复目标在 `WorldHost`；`SceneRouter.change_scene_to(host, path, spawn)` 只做无状态过渡。

## 3. 关键设计决策

| 决策 | 要点 |
| --- | --- |
| 存档用 JSON，槽位无上限 | 避免 `ResourceSaver` 写入脚本路径；槽位号进文件名，目录扫描即槽位列表；显式版本号 + `from_dict` 字段兜底 |
| 世界场景换子节点 | `Main` 常驻 `WorldHost` / `UiRoot`，不用 `change_scene_to_file`；缓存与当前实例在 `WorldHost`，`SceneRouter` 只做无状态过渡 |
| 领域事件 | 全局只留时间 / 场景 / 存档信号；玩家 / 农场 / 世界 / UI 信号挂在由状态或宿主持有的领域对象上 |
| `_ready()` 一生只跑一次 | 缓存复用场景不重跑 `_ready()`；每次进图逻辑放 `_enter_tree()` / `_exit_tree()` |
| 有序日结转 | 不依赖信号回调顺序；`GameDateClock` 委托给 `DayPipeline`，按显式 `priority` 同步执行 |
| 数据驱动 | 内容都在 `.tres`，脚本只认 id；静态数据与运行时状态分离 |
| 文案按域拆 CSV | `assets/i18n/` 下按域分 `ui.csv` / `content.csv` / `dialogue.csv`；每个 CSV 导入出的 `.translation` 必须登记进 `project.godot` 的 `locale/translations`（`--import` 不会自动加），字库扫整个目录 |
| UI 模态栈 | `UiRoot` 统一管理暂停与 `close_all()`，避免读档 / 传送残留菜单 |

## 4. Godot 踩坑与引擎事实

踩坑：

- 手写 `.tscn`：导出的节点引用要声明 `node_paths=PackedStringArray(...)`；`%UniqueName` 要设置 `unique_name_in_owner = true`。
- `godot -s script.gd` 在 autoload 注册前编译脚本；生成器用 `preload()`，依赖 autoload 的工具做成场景运行。
- Godot 每张画布只允许一个 `CanvasModulate`；天气与昼夜必须由 `WorldLighting` 统一相乘，否则只有一个生效。
- 子节点 `_ready()` 先于父节点；状态机初始切换用 `call_deferred()`，避免父节点 `@onready` 还是 null。
- Godot 命令必须能自己退出：统一套 `timeout` 并在末尾带 `--quit-after 3`（脚本解析失败时不会调用 `quit()`，
  会挂死在主循环）；不要用管道直连，先重定向到文件再 `tail` / `grep`。
- `user://` 可能不可写：`SaveManager` / `SceneAudio` 必须静默降级；测试不要依赖持久化。
- `.godot/` 不入库：新 clone 或新增资源后先 `--import`（`check.sh` 已自动处理）。

引擎事实（4.7.2 实测）：

- `PackedFloat32Array` 传参后原地修改对调用方可见，可直接传入 buffer 做原地叠加。
- `PackedByteArray.encode_u32 / encode_u16 / encode_s16`、`String.to_ascii_buffer()` 可手写二进制。
- `AudioStreamWAV` 导入默认 QOA；`--quit-after <n>` 是主循环迭代数；`-s` 脚本的 `_initialize()` 在主循环前同步跑完。
- `ItemList` 的 focus 样式画在所有条目之上，焦点样式只能画边，填底色会盖住整张列表。

## 5. 测试

两层自动化 + 一层人工预览：

| 层 | 入口 | 规模 | 管什么 |
| --- | --- | --- | --- |
| 单元 | `tests/unit/test_*.gd` | 35 套件 / 440 用例 | 纯逻辑与数据契约：不加载场景、不模拟输入 |
| 冒烟 | `tools/smoke_test.tscn` + `tools/smoke/` | 320 项检查 | 真实场景 + autoload 接线 + 完整玩法链路 |
| 视觉 | `tools/screenshot.tscn`、`tools/ui_preview.tscn` | — | 出图人工看，不做像素 diff |

- 规范即测试：`test_assets.gd` / `test_audio.gd` / `test_i18n.gd` 把美术 / 音频 / 本地化规范写成断言；地图增删同步 `test_world_map.gd` 的 `MAPS`。
- 颗粒度：单元测试细到「一条断言一个行为边界」，很多是遍历 `Database` 全量数据的数据驱动契约测试；冒烟细到「一条玩法链路一个 `_check*` 函数」。
- 跑法统一走 `./tools/check.sh [unit|smoke]`。
- **输出约定**：跑测试的 Godot 输出一律重定向到 `.tmp/check/*.log`，控制台只留统计与失败明细（`tools/summarize_tests.py` 解析 gdUnit4 的 JUnit 报告，冒烟只 grep `SMOKE` 行）。新增测试入口也要照此收口，不逐条回显 `PASSED`。

## 6. 大文件与阅读协议

> 三句核心：≥400 行的文件先看结构、不整读；改共享函数前先查调用方；生成物只改生成器。
> 阈值可执行：`python3 tools/outline.py lint`（`--strict` 有红线时非 0）。

| 对象 | 黄线：先看结构 | 红线：禁止整读 |
| --- | --- | --- |
| 文件 | 400 行 | 800 行 |
| 函数 | 80 行 | 120 行 |

- **定位**：`map`（索引）/ `grep`（搜词）/ `outline`（文件结构）/ `sym`（单函数）/ `refs` `callers`（调用关系）；
  完整子命令见 `python3 tools/outline.py --help`。
- **动手前**：共享函数先 `callers` + `grep`；生成物改生成器后重跑 `build_assets.sh`；场景改完用 `outline` 复查父路径。
- **收尾**：规则 / 数据 → `check.sh unit`；交互 / 场景 → `check.sh smoke`；全量 → `check.sh`。
- **别制造新的大文件**：新文件顶部写 `##` 说明；单函数 ≤ 80 行；入口型大文件在顶部 `##` 写「调度地图」。
  出现「3 个以上分节 / 要滚动找函数 / 一个文件因两件不相关的事被改」就按规则 / 状态 / 视图 / 数据拆分。

**特别注意的文件**：

| 文件 | 为什么 | 姿势 |
| --- | --- | --- |
| `tools/smoke_test.gd` + `tools/smoke/` | 根脚本只留生命周期与相位机，域检查器继承 `smoke_base.gd` | 加农场检查 → 根 `_run_checks()`；别的图 → 对应相位；公共工具加在 `smoke_base.gd` |
| `tools/generate_sample_data.gd` + `tools/sample/` | 入口按依赖顺序调用各域 `build()`，生成 `data/**/*.tres` | 改数据 = 改 `tools/sample/build_*.gd` 再重跑 |
| `src/world/flora_field.gd` | 状态权威 + 存档 + 被交互 / 冒烟 / 生成器调用 | 改 `clear()` 之类共享方法前先 `callers` + `grep` |
| `src/autoload/database.gd` | 每个数据域要动 10+ 处样板 | 加域时逐项对齐，别漏 `validate_all` |
| `src/audio/scene_audio.gd` | 靠导出字段决定订阅哪些事件 / 跟不跟世界曲目 | 改字段前先看 `main.tscn` 与 `title_screen.tscn` 的接线 |
| `scenes/world/twon.tscn` `farm.tscn` | 节点树 + `parent` 路径手改易错位 | 先用 `outline` 看层级，改完复查 |
| `reports/**` | gdUnit4 报告（几百个 HTML） | 已 gitignore；不要读、不要提交 |

豁免：`addons/**` 与生成物（`assets/**`、`reports/**`、`.godot/**`、`target/**`）不适用本文。

