# AGENTS.md — open-farm 编码 Agent 上手说明

> 新会话读完这一页即可动手。字段、规则与数值的权威出处是 `README.md` 与 `docs/`；
> 若本文与其冲突，以文档为准并顺手更新本文。

## 速览

- **项目**：Godot **4.7.2** 的 2D 俯视角像素农场模拟；仓库根自带 `./godot`（已 gitignore）。
- **入口**：`scenes/title/title_screen.tscn` → `scenes/main/main.tscn`；`WorldHost` 换地图，`UiRoot` 常驻。
- **命令**：见 `README.md`「快速开始」；提交前必跑 `./tools/check.sh`。
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
5. **规范与测试同步**：`docs/art_pipeline.md` ↔ `tests/unit/test_assets.gd`，
   `docs/audio_pipeline.md` ↔ `tests/unit/test_audio.gd`；地图增删同步 `tests/unit/test_world_map.gd` 的 `MAPS`。

## 任务路由

| 任务 | 入口 |
| --- | --- |
| 加内容（作物 / 牲畜 / 植被 / 鱼种 / NPC / 节日 / 地图 / 音效 / UI） | `README.md`「扩展入口」 |
| 改玩法数值 | 优先只改 `data/**/*.tres` |
| 参与日结转 | `GameDateClock.register_day_hook(callable, DayPipeline.PRIORITY_*)`，并在 `_exit_tree` 注销 |
| 参与存档 | `to_dict/from_dict` + `Persistence.register(self, &"id")`；核心状态 / 服务在 `Main._bind_dependencies()` 注册 `SaveSection`；JSON 往返把 `StringName` 转回；槽位无上限，手动与日结自动存档统一走 `SaveManager.save_current()` |
| 改地图瓦片 / 外观 | `src/art/atlas_layout.gd` + `tools/art/generate_terrain.gd`；已发布格子只能往后追加 |
| 加水域 / 改岸线 | `src/world/water_layout.gd` 登记形状（`src/world/water_shape.gd` 造曲线）+ `tools/art/generate_water.gd` 烘贴图 + `src/world/water_field.gd` 显示 / 碰撞 / 波光 |
| 大文件怎么读 / 怎么改 | `docs/big_files.md`；先 `python3 tools/outline.py map` 定位 |
| Godot 命令与引擎坑 | `docs/architecture.md` §4 |

## 提交

`feat: …` / `fix: …` / `chore: …` 单行中文摘要。生成物（PNG / WAV / 字体 / `.import` / `.translation`）与代码一起提交。

