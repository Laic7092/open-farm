# AGENTS.md — open-farm 编码 Agent 上手说明

> 本页只讲 Agent 必须遵守的约束；命令、操作、扩展入口看 `README.md`，数值与规则以 `docs/` 为准。

## 速览

- **项目**：Godot **4.7.2** 的 2D 俯视角像素农场模拟；仓库根自带 `./godot`（已 gitignore）。
- **入口**：`scenes/title/title_screen.tscn` → `scenes/main/main.tscn`；`WorldHost` 换地图，`UiRoot` 常驻。
- **命令**：见 `README.md`「快速开始」；提交前必跑 `./tools/check.sh`（控制台只回统计与失败明细，完整日志在 `.tmp/check/`）。
- **风格**：注释、文档、提交信息用中文；GDScript 用 Tab 缩进 + 类型标注 + `##` 文档注释，`StringName` 写 `&"..."`。
- **设计原因**：跨系统看 `docs/architecture.md`；单点原因优先读相关脚本顶部的 `##` 注释。

## 铁律

1. **数据驱动 + 静态 / 运行时分离**：内容都在 `res://data/**/*.tres`，脚本只认 id；`XxxData`（`Resource`）
   ↔ `XxxState`（`RefCounted`），规则写进 `XxxGrowth` / `XxxHusbandry` 这类纯静态函数。
2. **事件分层**：`EventBus` 全局只留跨域时间 / 场景 / 存档信号；玩家 / 农场 / 世界 / UI 信号走
   `EventBus.player / farm / world / ui` 领域对象。有顺序依赖的日结转走
   `GameDateClock.register_day_hook(callable, priority)`，不依赖信号回调顺序或 Autoload 加载顺序。
3. **世界场景缓存复用**：`_ready()` 一生只跑一次；每次进图逻辑放 `_enter_tree()` / `WorldScene.on_world_enter()`，
   日结转钩子在 `_exit_tree()` 注销。
4. **生成物永不手改**：美术 / 音频 / 字体必须确定性；新增文案或汉字必须重跑 `build_assets.sh`。
5. **规范与测试同步**：`docs/generated_assets.md` ↔ `tests/unit/test_assets.gd` / `test_audio.gd`；
   地图增删同步 `tests/unit/test_world_map.gd` 的 `MAPS`。
6. **测试输出收口**：新增测试入口必须把 Godot 输出重定向到日志，控制台只回统计与失败明细；
   约定见 `docs/architecture.md` §5。

## 任务路由

| 任务 | 入口 |
| --- | --- |
| 加内容（作物 / 牲畜 / 植被 / 鱼种 / NPC / 节日 / 地图 / 音效 / UI） | `README.md`「扩展入口」 |
| 改玩法数值 | 优先只改 `data/**/*.tres` |
| 参与日结转 | `GameDateClock.register_day_hook(callable, DayPipeline.PRIORITY_*)`，并在 `_exit_tree` 注销 |
| 参与存档 | `to_dict` / `from_dict` + `Persistence.register(self, &"id")`；核心状态 / 服务在 `Main._bind_dependencies()` 注册 `SaveSection`；JSON 往返把 `StringName` 转回；槽位无上限，统一走 `SaveManager.save_current()` |
| 大文件怎么读 / 怎么改 | `docs/architecture.md` §6；先 `python3 tools/outline.py map` 定位 |
| Godot 命令与引擎坑 | `docs/architecture.md` §4 |

## 提交

`feat: …` / `fix: …` / `chore: …` 单行中文摘要。生成物（PNG / WAV / 字体 / `.import` / `.translation`）与代码一起提交。
