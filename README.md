# open-farm · 牧场物语复刻

用 **Godot 4.7.2** 制作的 2D 俯视角像素农场生活模拟：农场 / 畜牧 / 钓鱼、NPC 与好感度恋爱、节日与事件、
多张地图、UI、存档、本地化与自动化测试均已打通。
**美术、字体、BGM、音效全部由脚本生成**，仓库不放手工二进制素材。

## 快速开始

```bash
./godot --path .                        # 运行游戏
./godot --path . -e                     # 用编辑器打开
timeout 800 ./tools/check.sh            # 导入缓存 + 单元测试 + 冒烟测试（提交前必跑）
timeout 800 ./tools/check.sh unit       # 只跑单元测试
timeout 800 ./tools/check.sh smoke      # 只跑冒烟测试
timeout 800 ./tools/build_assets.sh     # 重新生成全部 PNG / 字体 / WAV
```

`GODOT_BIN=/path/to/godot` 可指定引擎，`GODOT_TIMEOUT=120` 可覆盖默认 60s 命令超时。

## 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动；按住 `Shift` 奔跑 |
| `空格` | 使用当前工具；水边手持钓竿时按住蓄力抛竿，咬钩后按住收线 |
| `E` / `回车` | 交互 / 对话 / 收获 |
| `Q` / `R` | 切换手持工具 |
| `G` | 给面前 NPC 送礼物 |
| `Tab` / `I` | 背包 |
| `Esc` | 系统菜单 |
| `F5` / `F9` | 快捷存档 / 读档（当前这一局） |

纯键盘操作，鼠标隐藏：菜单、商店、标题页均可用方向键或 `WASD` 导航，回车 / 空格 / `E` 确认，
`Esc` 返回；商店内 `A` / `D` 切换购买与卖出列表。

## 目录结构

- `src/`：按玩法分层（`autoload` / `services` / `core` / `data` / `player` / `farm` / `npc` / `event` / `shop` / `world` / `ui` / `main`），规则尽量写成可脱离引擎测试的纯静态函数。
- `scenes/`、`data/`、`assets/`、`tests/unit/`、`tools/`：场景、`.tres` 数据、生成物、单元测试、开发与生成脚本；`tools/smoke/` 是冒烟域检查器，`tools/sample/` 是示例数据域构建器。
- `docs/`：跨系统流程与美术 / 音频规范；`project.godot` 配置 autoload、InputMap、像素渲染与本地化。

## 扩展入口

数值与外观优先只改 `data/**/*.tres`；新增汉字或文案后必须重跑 `build_assets.sh`。

| 任务 | 主要入口 |
| --- | --- |
| 加作物 | `data/crops/` + `data/items/` + `data/shops/*.tres` + `tools/art/generate_crops.gd` + `assets/i18n/content.csv` |
| 加牲畜 | `data/animals/` + `data/buildings/` + `data/items/` + `tools/art/generate_animals.gd` |
| 加鱼种 | `data/fish/` + `data/items/` + `tools/art/generate_items.gd` + `assets/i18n/content.csv` |
| 加野生植被 | `data/flora/` + `tools/art/generate_flora.gd` + `src/world/flora_field.gd` |
| 加 NPC / 日程 | `tools/art/generate_actors.gd` + `data/npcs/` + `data/dialogue/` + `data/schedules/` + 场景 `SchedulePoint` |
| 加商店 / 柜台 | `data/shops/*.tres` + `NpcData.shop_id` + 场景摆 `ShopCounter`（`src/shop/shop_counter.gd`）并填 `shop_id` / `clerk_id` |
| 加节日 / 事件 | `data/festivals/` + `data/events/` + 地图 `FestivalGround` + `src/event/*_rules.gd` + `src/services/calendar_service.gd` |
| 加恋爱线 | `NpcData` 的 `romanceable` / `*_dialogue` / 礼物偏好 + 五段对白 + `AffectionRules` + `src/services/relationship_service.gd` |
| 加地图 | 复制 `scenes/world/twon.tscn` 或 `library.tscn`；地面用 `src/world/*_ground.gd`；放 `SpawnPoint` 并用 `SceneDoor` 互连；同步 `tests/unit/test_world_map.gd` 的 `MAPS` |
| 加音效 / BGM | `src/audio/audio_catalog.gd` + `tools/audio/generate_*.gd` + 场景里的 `SceneAudio`（`src/audio/scene_audio.gd`）|
| 改 UI | `src/ui/*.gd` + `scenes/ui/*.tscn` + `src/ui/ui_root.gd` |
| 参与存档 | 节点实现 `to_dict/from_dict`，并 `Persistence.register(self, &"id")`；JSON 往返后 `StringName` 要转回。槽位无上限，手动与日结自动存档都走 `SaveManager.save_current()` |

## 测试

- `./tools/check.sh` = gdUnit4 单元测试 + `tools/smoke_test.tscn` 端到端冒烟测试。
- 规范测试：`tests/unit/test_assets.gd`、`tests/unit/test_audio.gd`；视觉回归：`tools/screenshot.tscn`、`tools/ui_preview.tscn`。
- 单元测试与冒烟测试的分工见 [architecture §6](docs/architecture.md#6-测试策略)。

## 已知限制

- 美术与音频由脚本生成，细节和动态表现有限；中文像素字体是字符子集，容器缺字时生僻字会显示方块。
- 世界场景切过后常驻内存；地图继续增加后需改成「按需卸载 + 状态外置」。
- 水域没有碰撞；NPC 只走固定时刻表，不会互相避让；事件只在日结转时判定。
- 恋爱是满足条件自动推进的里程碑；牲畜不会死亡或繁殖。
- 钓鱼有蓄力抛竿与拉扯小游戏（按住 / 松开 `空格` 控制钩子深度），但落点距离不影响能钓到的水域；鱼仍只按水域 / 季节 / 天气 / 时段筛选，蓄力只放大难钓鱼的权重。
- 鱼线是逐帧算出的下垂折线（`FishingRules.cast_arc` / `line_curve`），不是 Physics2D 绳索：不会绕障碍物，也不会垂到景深遮档后面。
- 偿还顺序见 [docs/roadmap.md](docs/roadmap.md)；单点设计原因看代码中的 `##` 注释。

## 文档地图

| 文档 | 内容 |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | 分层、组合根、关键决策、Godot 坑与引擎事实、子系统索引、测试策略 |
| [docs/gameplay.md](docs/gameplay.md) | 玩家向玩法指南：开局、农场 / 畜牧、地图 / NPC、恋爱、节日、存档 |
| [docs/art_pipeline.md](docs/art_pipeline.md) | 美术生成规范：调色板 / 图集坐标 / 确定性 / 字体 / 强制测试 |
| [docs/audio_pipeline.md](docs/audio_pipeline.md) | 音频合成规范：格式 / 原语 / 循环 / 场景接线 / 强制测试 |
| [docs/big_files.md](docs/big_files.md) | 大文件规范：阈值、阅读 / 修改协议、特别注意的文件 |
| [docs/roadmap.md](docs/roadmap.md) | 未来方向：循环深度、内容广度、技术债、平台化与里程碑 |
| [AGENTS.md](AGENTS.md) | 给编码 Agent 的最短上手说明 |

