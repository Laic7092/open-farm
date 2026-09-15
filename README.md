# open-farm · 牧场物语复刻

用 **Godot 4.7.2** 制作的 2D 俯视角像素农场生活模拟。核心循环、玩家、农场、畜牧、8 位 NPC、
好感度与恋爱（结婚生子）、节日与事件、6 张地图、UI、存档、本地化与自动化测试均已打通。
**美术、字体、BGM、音效全部由脚本生成**；仓库里不放手工二进制素材。

## 快速开始

```bash
./godot --path .                        # 运行游戏
./godot --path . -e                     # 用编辑器打开
timeout 800 ./tools/check.sh            # 导入缓存 + 单元测试 + 冒烟测试（提交前必跑）
timeout 800 ./tools/check.sh unit       # 只跑单元测试
timeout 800 ./tools/check.sh smoke      # 只跑冒烟测试
timeout 800 ./tools/build_assets.sh     # 重新生成全部 PNG / 字体 / WAV
```

`GODOT_BIN=/path/to/godot` 可指定引擎，`GODOT_TIMEOUT=120` 可覆盖默认命令超时。
生成物必须确定性：连跑两次 `build_assets.sh` 后 `git status` 应保持干净。

## 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动；按住 `Shift` 奔跑 |
| `空格` | 使用当前工具 |
| `E` / `回车` | 交互 / 对话 / 收获 |
| `Q` / `R` | 切换手持工具 |
| `G` | 给面前 NPC 送礼物 |
| `Tab` / `I` | 背包 |
| `Esc` | 系统菜单 |
| `F5` / `F9` | 快捷存档 / 读档（槽位 0） |

纯键盘操作：鼠标隐藏。菜单、商店、标题页均可用方向键或 `WASD` 导航，回车/空格/E 确认，Esc 返回；
商店内 `A` / `D` 切换购买与卖出列表。

## 玩法

完整开局指引、农场与畜牧循环、地图与 NPC 日程、恋爱和节日事件见 [docs/gameplay.md](docs/gameplay.md)。

## 目录结构

- `src/`：按玩法分层（`autoload` / `services` / `core` / `data` / `player` / `farm` / `npc` / `event` / `shop` / `world` / `ui` / `main`），规则尽量写成可脱离引擎测试的纯静态函数。
- `scenes/`、`data/`、`assets/`、`tests/unit/`、`tools/`：场景、`.tres` 数据、生成物、单元测试、开发与生成脚本。
- `docs/`：跨系统流程与美术/音频规范；`project.godot` 配置 autoload、InputMap、像素渲染与本地化。

## 架构

分层、Autoload / 组合根、关键设计决策与 Godot 跨系统坑见 [docs/architecture.md](docs/architecture.md)。
日常最常用的三条规则：内容数据只认 id；静态数据与运行时状态分离；世界场景会被缓存，`_ready()` 一生只跑一次。

## 扩展入口

| 任务 | 主要入口 |
| --- | --- |
| 加作物 | `data/crops/` + `data/items/` + `data/shops/*.tres` + `tools/art/generate_crops.gd` + `strings.csv` |
| 加牲畜 | `data/animals/` + `data/buildings/` + `data/items/` + `tools/art/generate_animals.gd` |
| 加野生植被 | `data/flora/` + `tools/art/generate_flora.gd` + `src/world/flora_field.gd` |
| 加 NPC / 日程 | `tools/art/generate_actors.gd` + `data/npcs/` + `data/dialogue/` + `data/schedules/` + 场景 `SchedulePoint` |
| 加商店 / 柜台 | `data/shops/*.tres` + `NpcData.shop_id` + 场景里摆 `ShopCounter`（`src/shop/shop_counter.gd`）并填 `shop_id` / `clerk_id` |
| 加节日 / 事件 | `data/festivals/` + `data/events/` + 地图 `FestivalGround` + `src/event/*_rules.gd` + `src/services/calendar_service.gd` |
| 加恋爱线 | `NpcData` 的 `romanceable` / `*_dialogue` / 礼物偏好 + 五段对白 + `AffectionRules` + `src/services/relationship_service.gd` |
| 加地图 | 复制 `scenes/world/twon.tscn` 或 `library.tscn`；地面用 `src/world/*_ground.gd`；放 `SpawnPoint` 并用 `SceneDoor` 互连；同步 `tests/unit/test_world_map.gd` 的 `MAPS` |
| 加音效 / BGM | `src/audio/audio_catalog.gd` + `tools/audio/generate_*.gd` + `src/autoload/audio_manager.gd` |
| 改 UI | `src/ui/*.gd` + `scenes/ui/*.tscn` + `src/ui/ui_root.gd` |
| 参与存档 | 节点实现 `to_dict/from_dict`，并 `Persistence.register(self, &"id")`；JSON 往返后 `StringName` 要转回 |

数值与外观优先只改 `data/**/*.tres`；新增汉字或文案后必须重跑 `build_assets.sh`。

## 测试

- `./tools/check.sh` = gdUnit4 单元测试 + `tools/smoke_test.tscn` 端到端冒烟测试。
- 规范测试：`tests/unit/test_assets.gd`、`tests/unit/test_audio.gd`；视觉回归：`tools/screenshot.tscn`、`tools/ui_preview.tscn`。
- 为什么这样分 unit / smoke：见 [architecture §6](docs/architecture.md#6-测试策略)。

## 已知限制

- 美术与音频均由脚本生成，细节和动态表现有限；中文像素字体是约 1100 字形子集，容器无系统 CJK 字体时生僻字可能显示方块。
- 世界场景切过后常驻内存；地图继续增加后需改成“按需卸载 + 状态外置”。
- 水域没有碰撞；NPC 只走固定时刻表，不会互相避让；事件只在日结转时判定。
- 恋爱是满足条件自动推进的里程碑；牲畜不会死亡或繁殖；存档只有一个槽位。
- 更完整的限制、跨系统架构和生成规范见 `docs/`；单点设计原因看代码中的 `##` 注释。

## 文档地图

设计原因优先看对应脚本顶部的 `##` 注释；跨系统流程和扩展说明看下列文档。

| 文档 | 内容 |
| --- | --- |
| `docs/architecture.md` | 跨系统架构速览：分层、组合根、关键决策、Godot 坑与测试策略 |
| `docs/art_pipeline.md` | 美术生成规范；“Godot 命令必须能自己退出”原文 |
| `docs/audio_pipeline.md` | 音频合成规范 |
| `docs/gameplay.md` | 玩家向玩法指南：开局、农场/畜牧、地图/NPC、恋爱、节日、存档 |
| `AGENTS.md` | 给编码 Agent 的最短上手说明 |
