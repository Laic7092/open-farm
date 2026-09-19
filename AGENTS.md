# AGENTS.md — open-farm 编码 Agent 上手说明

> 只写代码 / 测试 / 配置里读不出来的约束与坑。其余指向源头：玩法 `README.md`，
> 数值 `data/**/*.tres`，规则 `tests/`，单点设计读脚本顶部 `##`，历史 `git log`。

## 铁律（测试兜不住，靠自觉）

1. **只加数据，不改结构**：内容进 `res://data/**/*.tres`，脚本只认 id；`XxxData`（`Resource`）↔ `XxxState`（`RefCounted`），规则写成纯静态函数。
2. **不再新增 Autoload**：全局只留跨域时间 / 场景 / 存档信号，领域信号走 `EventBus.player/farm/world/ui`；其余状态与服务挂 `Main` 组合根注入。
3. **日结转按显式顺序**：`GameDateClock.register_day_hook(callable, DayPipeline.PRIORITY_*)`，在 `_exit_tree` 注销；不依赖信号回调顺序。
4. **缓存复用的世界场景不重跑 `_ready()`**：每次进图逻辑放 `_enter_tree()` / `WorldScene.on_world_enter()`。
5. **生成物只改生成器**：`assets/**` 永不手改，改 `tools/` 后重跑 `./tools/build_assets.sh`；确定性判据是连跑两次 `git status` 干净。
6. **测试输出收口**：Godot 输出重定向到 `.tmp/check/*.log`，控制台只回统计与失败明细。

## 任务路由

| 任务 | 入口 |
| --- | --- |
| 加物品 | `data/items/`（全游戏可持有物品的**总表**；图标 = `assets/sprites/items/<id>.png`）|
| 加对象 / 系统内容 | 同名 `data/<域>/` + `tools/art/generate_<域>.gd`，重跑 `build_assets.sh` |
| 上架 / 定价 | `data/shops/` |
| 加文案 / 汉字 | `assets/i18n/*.csv` |
| 加地图 | `SceneDoor` / `SpawnPoint` + `test_world_map.gd` 的 `MAPS` |
| 改数值 | `data/**/*.tres` |
| 审阅内容 | `./tools/build_wiki.sh --open`（Godot 导出 `.tmp/wiki/data.json` → `build_wiki.py` 渲染静态 HTML）|
| 读 / 改大文件 | `python3 tools/outline.py map / outline / sym / callers` |

## Godot 坑（4.7.2 实测，代码里没有）

- 命令必须自己能退出：套 `timeout` + 末尾 `--quit-after 3`；输出先重定向到文件再 `grep`。
- `-s script.gd` 在 autoload 注册前编译：只能用 `preload()`，依赖 autoload 的工具做成场景。
- 手写 `.tscn`：导出节点引用要 `node_paths=PackedStringArray(...)`，`%UniqueName` 要 `unique_name_in_owner = true`。
- 每张画布只允许一个 `CanvasModulate`；子节点 `_ready()` 先于父节点，初始状态切换用 `call_deferred()`。
- `user://` 可能不可写，存档 / 音频要静默降级；`.godot/` 不入库，新 clone 先 `--import`。
- `PackedFloat32Array` 传参可原地改；`PackedByteArray.encode_u32/_u16/_s16` 可手写二进制；`AudioStreamWAV` 默认 QOA；`ItemList` focus 样式只能画边。

## 测试 / 大文件 / 提交

- 跑 `./tools/check.sh [unit|smoke]`；规范断言在 `tests/unit/test_{assets,audio,i18n,world_map}.gd`。
- 大文件阈值 400 / 800（文件）、80 / 120（函数），`python3 tools/outline.py lint`；改共享函数前先 `callers`。
- 提交 `feat:` / `fix:` / `chore:` 单行中文；生成物与代码一起提交。
