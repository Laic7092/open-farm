# AGENTS.md — open-farm 编码 Agent 上手说明

> 目的：新会话读完这一页就能动手，不必再逐文件侦察。
> 本文件由 harness 作为工作区指令在**首次请求前自动加载**；动手前先看「铁律」与「坑」。
>
> 本文只收录"动手前必须知道"的浓缩信息。字段、规则、数值的**权威出处**是
> [README 的文档地图](README.md#文档地图) 与 `docs/`；若本文与文档冲突，以文档为准，并顺手更新本文。

## 0. 一分钟速览

- **是什么**：Godot **4.7.2** 的 2D 俯视角像素农场模拟（牧场物语风格）。仓库根自带 `./godot`（已 gitignore）。
- **入口**：`scenes/title/title_screen.tscn` → `scenes/main/main.tscn`（`WorldHost` 换地图 + 常驻 `UiRoot`）。
- **现状**：核心循环 / 玩家 / 农场 / 畜牧 / 8 位 NPC / 好感度与恋爱（结婚生子）/ 节日与事件 / 6 张地图 / UI / 存档 / 本地化全部打通；**美术、字体、BGM、音效全部由脚本生成**，内容仍在扩充。
- **没有**：package.json / npm / 构建系统；一切走 Godot CLI。
- **语言与风格**：注释、文档、提交信息统一**中文**；GDScript 用 **Tab 缩进 + 类型标注 + `##` 文档注释**，`StringName` 用 `&"..."`。

## 1. 先跑这几条（都带超时，原因见「坑 1」）

```bash
timeout 800 ./tools/check.sh        # import + 单元测试(343) + 冒烟测试(286)，提交前必跑
timeout 800 ./tools/check.sh unit   # 只跑 gdUnit4 单元测试
timeout 800 ./tools/check.sh smoke  # 只跑端到端冒烟测试
timeout 800 ./tools/build_assets.sh # 重新生成全部 PNG / 字体 / WAV
```

可用 `GODOT_BIN=/path/to/godot` 指定引擎、`GODOT_TIMEOUT=120` 覆盖默认 60s 超时。

## 2. 铁律（改代码前必读）

1. **数据驱动**：作物 / 牲畜 / 道具 / NPC / 对话 / 商店都是 `res://data/**/*.tres`，脚本只认 id
   （`Database.get_crop(&"turnip")`），不要硬编码文件路径。
2. **静态数据 ↔ 运行时状态分离**：`XxxData`(Resource，不变) ↔ `XxxState`(RefCounted，会变)，
   生长规则写在 `XxxGrowth` / `XxxHusbandry` 的**纯静态函数**里，便于脱离引擎单测。
3. **EventBus 只声明信号**，不写逻辑；生产者 emit、消费者 connect。有顺序依赖的模拟走
   `GameClock.register_day_hook()`，不要依赖信号回调顺序。
4. **世界场景会被缓存复用**（`SceneRouter._world_cache`）：`_ready()` 一生只跑一次，
   所以"每次进图都要做一遍"的事情放 `_enter_tree()` / `WorldScene.on_world_enter()`。
5. **所有资源由脚本生成，仓库里不放手工二进制**：美术 `tools/art/*.gd`、音频 `tools/audio/*.gd`、
   字体也现场栅格化。生成物提交进仓库，但**永不手改**；生成必须**确定性**
   （跑两次 `build_assets.sh` 后 `git status` 干净；生成器禁用 RNG，用 `Art.noise` / `Synth.noise_at` 的位置哈希）。
6. **文档规则 = 可执行测试**：`docs/art_pipeline.md` ↔ `tests/unit/test_assets.gd`，
   `docs/audio_pipeline.md` ↔ `tests/unit/test_audio.gd`。改规范要同步测试。
7. 加了新文案 / 新汉字后**必须重跑 `build_assets.sh`**，否则像素字体缺字（`test_assets.gd` 会红）。

## 3. 任务 → 先看哪里（省掉侦察）

| 任务 | 入口 |
| --- | --- |
| 加作物 | `data/crops/` + `data/items/`（种子/收获）+ `strings.csv` + `tools/art/generate_crops.gd` + 商店 stock |
| 加牲畜 | `data/animals/` + `data/buildings/` + `data/items/` + `tools/art/generate_animals.gd` |
| 加野生植被 | `data/flora/` + `tools/art/generate_flora.gd` + `src/world/flora_field.gd`（`allowed_species` 可限定单张地图长哪些） |
| 加 NPC / 日程 | `tools/art/generate_actors.gd` 的 `NPC_LOOKS` + `data/npcs/` `data/dialogue/` `data/schedules/` + 场景里的 `SchedulePoint` |
| 加节日 / 事件 | 节日：`data/festivals/`（`FestivalData`）+ 地图里的 `FestivalGround`（`festival_ids`）；事件：`data/events/`（`EventData`）。判定规则 `src/event/*_rules.gd`，状态 / 存档在 `src/autoload/calendar.gd`；新文案记得重跑 `build_assets.sh` |
| 加恋爱对象 | `NpcData` 的 `romanceable` / `*_dialogue` / 礼物偏好 + `data/dialogue/` 五段对白 + `AffectionRules`（规则）与 `Relationships`（状态/存档） |
| 加地图 | 复制 `scenes/world/twon.tscn`（户外）或 `library.tscn`（室内），根用 `WorldScene`，地面用 `src/world/*_ground.gd`（铺地走 `GroundPainter`，主路压在地图纵向中线），放 `SpawnPoint`，用 `SceneDoor` 互连：地图边缘的乡道出口标 `auto_enter` + `road_exit`，建筑门口只按 E。改完补进 `tests/unit/test_world_map.gd` 的 `MAPS` |
| 加音效 / BGM | `src/audio/audio_catalog.gd` 加 id → `tools/audio/generate_*.gd` 写配方 → 需要触发就在 `src/autoload/audio_manager.gd` 订阅 `EventBus` → 重跑 `build_assets.sh` |
| 改 UI | `src/ui/*.gd` + `scenes/ui/*.tscn` + `src/ui/ui_root.gd`（模态栈 / 暂停） |
| 改玩法数值 | 只改 `data/**/*.tres`，不用动代码 |
| 加全局信号 | `src/autoload/event_bus.gd`（只声明） |
| 参与日结转 | `GameClock.register_day_hook(callable)`，并在 `_exit_tree` 注销 |
| 参与存档 | 节点实现 `to_dict/from_dict` + `Persistence.register(self, &"id")`（JSON 往返把 StringName 变 String，`from_dict` 要转回） |
| 连地图 / 改出口 | 场景里的 `SceneDoor`（`target_scene` + `target_spawn_id`；边缘出口再加 `auto_enter` + `road_exit`）+ `SpawnPoint`；新增 / 删除地图后同步 `tests/unit/test_world_map.gd` 的 `MAPS` |
| 改地图瓦片 / 外观 | `src/art/atlas_layout.gd`（坐标真相）+ `tools/art/generate_terrain.gd`；已发布格子**只能往后追加** |
| 改昼夜光照 | `src/world/day_night.gd`（时间 → 环境光曲线）+ `src/world/world_lighting.gd`（染色 / 路灯 / 雷暴闪光）+ 调色板 `AMBIENT_*` / `WEATHER_*`；路灯在场景里填 `WorldProp.light_radius` |

更细的"如何扩展"见 `README.md` 的「如何扩展」一节。

## 4. 代码地图

- **十一个单例（顺序 = `project.godot` 声明顺序）**：
  `EventBus` `AppTheme` `Database` `GameClock` `GameState` `WeatherSystem` `Relationships` `Calendar` `SaveManager` `SceneRouter` `Audio`。
  依赖图与约束见 `docs/architecture.md` §2。
- `src/art/` 调色板 + 图集排版表；`src/audio/` 音频 id/路径目录；`src/core/` 日期/季节/状态机/网格 A*；
  `src/data/` 资源类定义；`src/player/`；`src/farm/`；`src/npc/`；`src/event/`（节日与事件规则 + 会场节点）；`src/shop/`；`src/world/`；`src/ui/`；`src/main/`。
- 可存档状态资源：`src/core/player_profile.gd`、`game_date_clock.gd`、`weather_state.gd`、`relationship_store.gd`、`calendar_progress.gd`；由 `Main` 持有并注入对应 Autoload 门面。
- `tools/art/`、`tools/audio/` 生成器；`tools/build_assets.sh`（唯一编排入口）；`tools/check.sh`；
  `tools/smoke_test.gd` + `smoke_test.tscn`；`tools/generate_sample_data.gd`（重置示例数据）。
- `tests/unit/` gdUnit4（断言风格：`assert_int(x).override_failure_message("...").is_equal(y)`）。
- `docs/`：`architecture.md`（为什么这么设计）、`art_pipeline.md`、`audio_pipeline.md`。
  各文档的唯一职责见 [README 文档地图](README.md#文档地图)。

**推荐的深读顺序**：`README.md` → `docs/architecture.md` → 相关 pipeline 文档 → `tests/unit/test_assets.gd`。

## 5. 坑（都是已经踩过的）

1. **Godot 命令必须能自己退出**：`-s script.gd` 解析失败 → `_initialize()` 不执行 → `quit()` 不被调用
   → **永远挂住**。统一 `timeout 60 … --quit-after 3`；**不要用管道直接接 Godot**
   （管道会等进程退出、报错还会被缓冲吞掉），先重定向到文件再 `tail` / `grep`。
   `build_assets.sh` 与 `check.sh` 已内置；唯一原文见 `docs/art_pipeline.md` 的「命令必须能自己退出」。
2. **`-s` 脚本里不能用 autoload 全局名**（此时 autoload 尚未注册）。生成器用 `preload("res://...")`；
   要测 autoload 就跑**场景**（`tools/smoke_test.tscn`）。
3. **本沙箱里 `user://` 不可写**：`SaveManager` / `Audio` 写 `user://` 会失败，必须静默降级；
   测试不要依赖持久化。冒烟测试把 `SaveManager.save_root` 重定向到 `res://.tmp`。
4. **`.godot/` 不入库**：新 clone 或新增资源后必须 `--import`（`check.sh` 会自动做）。
5. **生成物永不手改**：下一次跑生成器就会覆盖；要改画面 / 声音，就改生成器与调色板 / 音频目录。
6. **确定性**：生成器尽量不用随机；判定标准是"连跑两次后 `git status` 干净"。
7. `assets/i18n/strings.csv` 里 `MENU_TITLE` **重复定义**（`菜单` 与 `回到标题`，后者生效）——
   改菜单文案时别改错行。
8. 世界场景常驻内存（为了跨场景保住农田进度），地图多起来要改成"卸载地图 + 状态外置"；
   完整的已知限制见 `README.md` 的「已知限制」。

## 6. 引擎行为（已在 4.7.2 实测，省得再写探针）

- `PackedFloat32Array` 传参后**就地修改对调用方可见**，可以直接"传入 buffer 原地叠加"。
- `PackedByteArray.encode_u32 / encode_u16 / encode_s16`、`String.to_ascii_buffer()` 可手写二进制
  （WAV 头就是这么写的）。
- `AudioStreamWAV`：`FORMAT_QOA=3`；WAV 导入默认 `compress/mode=2`(QOA)、
  `edit/loop_mode=0`(从 WAV 检测)；带 `smpl` 块会被识别成 `LOOP_FORWARD`。
- `AudioServer.add_bus() / set_bus_send() / get_bus_index()` 可在运行时建总线。
- `--quit-after <n>` 是主循环迭代数；`-s` 脚本的 `_initialize()` 在主循环开始前同步跑完。
- `.godot/imported/<file>-<hash>.<ext>` 的 hash **基于路径**：重新生成同名文件不会改 `.import`。
- `ItemList` 把 `focus` 样式画在**所有条目之上**：焦点样式只能画边（`list_focus.png`），
  填底色会把整张列表盖住（`Button` 的 `focus` 是背景，不受影响）。

## 7. 提交

`feat: …` / `fix: …` / `chore: …` 单行中文摘要（参考 `git log`）。
生成物（PNG / WAV / 字体 / `.import` / `.translation`）与代码一起提交。
