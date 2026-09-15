# AGENTS.md — open-farm 编码 Agent 上手说明

> 新会话读完这一页即可动手。字段、规则、数值的权威出处是 `README.md` 与 `docs/`；若本文冲突，以文档为准并顺手更新本文。

## 速览

- **项目**：Godot **4.7.2** 的 2D 俯视角像素农场模拟；仓库根自带 `./godot`（已 gitignore）。
- **入口**：`scenes/title/title_screen.tscn` → `scenes/main/main.tscn`；`WorldHost` 换地图，`UiRoot` 常驻。
- **现状**：核心循环、玩家、农场、畜牧、钓鱼、8 位 NPC、好感度与恋爱（结婚生子）、节日与事件、6 张地图、UI、存档、本地化全部打通。
- **风格**：注释、文档、提交信息用中文；GDScript 用 Tab 缩进 + 类型标注 + `##` 文档注释，`StringName` 写 `&"..."`。
- **设计原因**：跨系统速览看 `docs/architecture.md`；单点原因优先读相关脚本顶部的 `##` 注释。

## 常用命令

```bash
timeout 800 ./tools/check.sh        # 导入缓存 + 单元测试 + 冒烟测试，提交前必跑
timeout 800 ./tools/check.sh unit   # 只跑单元测试
timeout 800 ./tools/check.sh smoke  # 只跑冒烟测试
timeout 800 ./tools/build_assets.sh # 重新生成全部 PNG / 字体 / WAV
```

可用 `GODOT_BIN=/path/to/godot` 指定引擎，`GODOT_TIMEOUT=120` 覆盖默认 60s 超时。

## 铁律

1. **数据驱动 + 静态 / 运行时分离**：内容都在 `res://data/**/*.tres`，脚本只认 id；`XxxData`（`Resource`）↔ `XxxState`（`RefCounted`），规则写进 `XxxGrowth` / `XxxHusbandry` 的纯静态函数。
2. **EventBus 全局只保留跨域时间 / 场景 / 存档信号**；玩家 / 农场 / 世界 / UI 信号走 `EventBus.player / farm / world / ui` 领域对象。有顺序依赖的日结转走 `GameDateClock.register_day_hook(callable, priority)` / `DayPipeline`，不要依赖信号回调顺序或 Autoload 加载顺序。
3. **世界场景会缓存复用**：`_ready()` 一生只跑一次；每次进图逻辑放 `_enter_tree()` / `WorldScene.on_world_enter()`，日结转钩子要在 `_exit_tree()` 注销。
4. **生成物永不手改**：美术 / 音频 / 字体必须确定性；新增文案或汉字必须重跑 `build_assets.sh`，否则像素字体缺字。
5. **文档规范要同步测试**：`docs/art_pipeline.md` ↔ `tests/unit/test_assets.gd`，`docs/audio_pipeline.md` ↔ `tests/unit/test_audio.gd`。
6. 新增或删除地图后，同步 `tests/unit/test_world_map.gd` 的 `MAPS`。

## 任务路由

- 加内容（作物 / 牲畜 / 植被 / 鱼种 / NPC / 节日 / 地图 / 音效 / UI）：先看 `README.md` 的「扩展入口」。
- 改玩法数值：优先只改 `data/**/*.tres`。
- 参与日结转：`GameDateClock.register_day_hook(callable, DayPipeline.PRIORITY_*)`，并在 `_exit_tree` 注销。
- 参与存档：场景节点实现 `to_dict/from_dict` + `Persistence.register(self, &"id")`；核心状态 / 服务在 `Main._bind_dependencies()` 注册 `SaveSection`。JSON 往返要把 `StringName` 转回。
- 改地图瓦片 / 外观：`src/art/atlas_layout.gd` + `tools/art/generate_terrain.gd`；已发布格子只能往后追加。

## 坑

1. **Godot 命令必须能自己退出**：统一 `timeout 60 … --quit-after 3`；不要用管道直连 Godot，先重定向到文件再 `tail` / `grep`。
2. **`-s` 脚本里不能用 autoload 全局名**：生成器用 `preload("res://...")`；要测 autoload 就跑场景 `tools/smoke_test.tscn`。
3. **`user://` 可能不可写**：`SaveManager` / `Audio` 必须静默降级；测试不要依赖持久化。
4. **`.godot/` 不入库**：新 clone 或新增资源后先 `--import`（`check.sh` 已自动处理）。
5. `assets/i18n/strings.csv` 里 `MENU_TITLE` 重复定义，当前生效的是“回到标题”。
6. 世界场景常驻内存（为保住跨场景农田进度）；地图多起来后要改成“卸载地图 + 状态外置”。

## 引擎事实（4.7.2 实测）

- `PackedFloat32Array` 传参后原地修改对调用方可见，可直接传入 buffer 做原地叠加。
- `PackedByteArray.encode_u32 / encode_u16 / encode_s16`、`String.to_ascii_buffer()` 可手写二进制。
- `AudioStreamWAV` 导入默认 QOA；`--quit-after <n>` 是主循环迭代数；`-s` 脚本的 `_initialize()` 在主循环前同步跑完。
- `ItemList` 的 focus 样式画在所有条目之上，焦点样式只能画边，填底色会盖住整张列表。

## 提交

`feat: …` / `fix: …` / `chore: …` 单行中文摘要。生成物（PNG / WAV / 字体 / `.import` / `.translation`）与代码一起提交。
