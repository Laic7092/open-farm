# AGENTS.md — open-farm 编码 Agent 上手说明

> 只写代码 / 测试 / 配置里读不出来的约束与坑。玩法 `README.md`，数值 `data/**/*.tres`，
> 规则 `tests/`，单点设计读脚本顶部 `##`，历史 `git log`。

## 铁律

1. **禁止整读文件**：先按 `## 定位` 取一条，取到就动手。
2. **只加数据，不改结构**：内容进 `data/**/*.tres`，脚本只认 id；`XxxData`（`Resource`）↔ `XxxState`（`RefCounted`），规则写成纯静态函数。
3. **不再新增 Autoload**：全局只留跨域时间 / 场景 / 存档信号，领域信号走 `EventBus.player/farm/world/ui`；其余状态与服务挂 `Main` 组合根注入。
4. **日结转按显式顺序**：`GameDateClock.register_day_hook(callable, DayPipeline.PRIORITY_*)`，在 `_exit_tree` 注销；不依赖信号回调顺序。
5. **缓存复用的世界场景不重跑 `_ready()`**：进图逻辑放 `_enter_tree()` / `WorldScene.on_world_enter()`。
6. **生成物只改生成器**：`assets/**` 永不手改，改 `tools/` 后重跑 `./tools/build_assets.sh`；判据是连跑两次 `git status` 干净。
7. **测试输出收口**：Godot 输出重定向到 `.tmp/check/*.log`，控制台只回统计与失败明细。
8. **禁止反复验证**：逻辑 / 生成物变了才跑测试，同一批改动只跑一次；纯布局 / 配色 / 注释一律不重跑。

## 定位（缺什么信息，取哪条）

| 要找什么 | 用什么 |
| --- | --- |
| 跨文件符号 / 定义 / 影响面 | `codegraph search` / `def` / `impact <名>` |
| 本文件结构 / 函数体 / 文本 / 调用方 | `python3 tools/outline.py outline` / `sym` / `grep` / `callers` |

一次只取最便宜的那条，实现细节才 `read`（带 `offset/limit`）。

## 任务路由

| 任务 | 入口 |
| --- | --- |
| 加物品 | `data/items/`（可持有物品总表；图标 = `assets/sprites/items/<id>.png`） |
| 加对象 / 系统内容 | 同名 `data/<域>/` + `tools/art/generate_<域>.gd`，重跑 `build_assets.sh` |
| 改摆件尺寸 / 占地 | `src/art/atlas_layout.gd` 的 `PROPS`（唯一来源），改完重跑 `build_assets.sh`；设计见 `docs/world-content-model.md` |
| 新增世界内容（该放哪层） | 先读 `docs/world-content-model.md` 的角色判据与决策树，再动手 |
| 上架 / 定价 | `data/shops/` |
| 加 / 改对话 | `data/dialogue/<npc_id>/`（四季 + 恋爱），共享节日 / 事件放 `data/dialogue/shared/`；生成器 `tools/sample/build_dialogues.gd`，文案进 `assets/i18n/dialogue.csv` |
| 加文案 / 汉字 | `assets/i18n/*.csv` |
| 加地图 | `SceneDoor` / `SpawnPoint` + `test_world_map.gd` 的 `MAPS` |
| 改数值 | `data/**/*.tres` |
| 审阅内容 | `./tools/build_wiki.sh --open` |

## 归属（第一原则，动手前过一遍）

**每份状态、行为、副作用（声音 / 画面 / 界面）都有且只有一个主人**——它所属的域。主人负责创建 / 持有 / 修改 / 销毁，其余人只能通过接口请求；只有真正跨域的时间 / 场景 / 存档信号可以无主。

判断口诀：**单一权威、行为贴着数据走、依赖显式注入**。答不上「是谁的状态 / 要绕过谁 / 协作者从哪来 / 住在哪个宿主」，或需要全局扫描，就是设计缺口。

已定边界（改到先看）：

- **世界上下文**：地图内的东西（农田 / 植被 / 水面 / 日程点）在所属世界场景内解析；跨世界 / 会话级的（背包 / 钓鱼 / 物品栏）由组合根注入。禁止全树分组查找。
- **进世界**：进图是显式生命周期事件，地图表现（音乐 / 光照 / 季节）在该事件恢复；不另造触发点，不为广播加全局单例。
- **可存档状态**：宿主显式登记自己持有的对象，登记即归属，不扫描全场。
- **谁产生谁负责**：声音由制造者持有播放器直接播；常驻界面只是容器，各域小视图订阅自己域的信号渲染，界面只展示 / 发请求，不碰数值与存档。

跨域决策追加到本文件，单点设计写脚本 `##`。

## Godot 坑（4.7.2 实测，代码里没有）

- 命令必须自己能退出：套 `timeout` + 末尾 `--quit-after 3`；输出先重定向到文件再 `grep`。
- `-s script.gd` 在 autoload 注册前编译：只能用 `preload()`；依赖 autoload 的工具做成场景。
- 手写 `.tscn`：导出节点引用要 `node_paths=PackedStringArray(...)`，`%UniqueName` 要 `unique_name_in_owner = true`。
- 每张画布只允许一个 `CanvasModulate`；子节点 `_ready()` 先于父节点，初始切换用 `call_deferred()`。
- `user://` 可能不可写，存档 / 音频要静默降级；`.godot/` 不入库，新 clone 先 `--import`。
- `PackedFloat32Array` 传参可原地改；`PackedByteArray.encode_u32/_u16/_s16` 可手写二进制；`AudioStreamWAV` 默认 QOA；`ItemList` focus 样式只能画边。
- 音频总线必须在 `default_bus_layout.tres` 预建：运行时 `AudioServer.add_bus()` 在 Web 导出不生效（godot#115560）；代码只按名字查找。

## 测试 / 提交

- 跑 `./tools/check.sh [unit|smoke]`；规范断言在 `tests/unit/test_{assets,audio,i18n,world_map}.gd`。
- 大文件阈值 400 / 800（文件）、80 / 120（函数）：`python3 tools/outline.py lint`。
- 提交 `feat:` / `fix:` / `chore:` 单行中文；生成物与代码一起提交。
