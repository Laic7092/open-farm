# open-farm 重构交接文档

> 本文件描述本次 P0 修复后的现状，以及把 11 个 Autoload 继续收敛为组合根架构的完整计划。
> 代码事实以 `project.godot`、`src/**/*.gd`、`scenes/**/*.tscn`、`tests/**` 为准。

---

## 1. 本次提交已经完成的内容

### 1.1 P0-3：SaveManager 去字符串反射

- 删除 `CORE_PARTICIPANTS` 硬编码名单。
- 删除 `_core_participant(id)` 与 `get_node_or_null("/root/<Name>")`。
- `Persistence` 新增：
  - `CORE_GROUP`
  - `register_core(node, id, order)`
  - `core_order_of(node)`
- 核心单例在各自 `_ready()` 自注册：
  - `GameClock / GameState / WeatherSystem / Relationships / Calendar / SceneRouter`
- `SaveManager.collect()` / `apply()`：
  - 按 `order` 排序；
  - 调用 `to_dict/from_dict` 前先 `Persistence.validate()`；
  - 不再把参与者写进 `payload["nodes"]`。
- 存档格式、旧存档键名保持不变。

### 1.2 P0-2：目标纯逻辑类去 Service Locator

- `Text`：
  - 不再调用 `Database.get_*`。
  - 名称查询改为接收 `ItemData / ToolData / CropData / AnimalData / BuildingData`。
- `Shop`：
  - 构造函数改为 `Shop.new(data, wallet, catalog, events)`。
  - `ShopUi` 由 `UiRoot` 在组合根注入依赖。
- `PlayerStats`：
  - 不再直接 emit `EventBus`；改为本地 `changed / depleted`。
  - `Player` 负责转发到 `EventBus`。
- `Inventory`：
  - 不再直接调用 `Database.get_item`；堆叠上限查询器由拥有者注入。
  - 不再直接 emit `EventBus.inventory_full`；改为本地 `full`，由 `Player` 转发。

### 1.3 P0-1：可存档状态迁出 Autoload

新增 5 个 Resource：

| 资源 | 接管的旧状态 |
| --- | --- |
| `src/core/player_profile.gd` | `GameState` 姓名 / 金钱 / 旗标 / 统计 / 游玩时长 |
| `src/core/game_date_clock.gd` | `GameClock` 日期 / 分钟 / 时间倍率 / 暂停标记 |
| `src/core/weather_state.gd` | `WeatherSystem` 当日 / 明日天气 |
| `src/core/relationship_store.gd` | `Relationships` 每 NPC 关系 / 配偶 / 婚育进度 |
| `src/core/calendar_progress.gd` | `Calendar` 已参加节日 / 已触发事件 |

`Main` 现在是组合根，持有这些资源并在 `_ready()` 中注入：

```gdscript
GameState.set_profile(player_profile)
GameClock.set_state(clock_state)
WeatherSystem.set_state(weather_state)
Relationships.set_state(relationship_store)
Calendar.set_state(calendar_progress)
```

Autoload 仍保留公开 API，但只做：

- 查询 / 门面
- 规则编排
- `EventBus` 广播
- 存档核心节

状态所有权已经从 Autoload 转移到 `Main`。

---

## 2. 当前验证基线

```bash
GODOT_TIMEOUT=240 timeout 900 ./tools/check.sh
```

当前结果：

- 单元测试：343/343 通过
- 冒烟测试：286/286 通过
- `git diff --check` 通过

每次提交前都必须跑全量 `check.sh`。

---

## 3. 目标终态

推荐目标不是“所有 Autoload 一律删除”，而是：

```text
Main（组合根）
├── PlayerProfile        Resource
├── GameDateClock        Resource
├── WeatherState         Resource
├── RelationshipStore    Resource
├── CalendarProgress     Resource
├── DataCatalog          Resource
├── SaveRegistry         Resource / 普通对象
├── WorldHost            Node
│   └── 世界场景 + 世界内服务节点
└── UiRoot               Node
    └── Hud / ShopUi / InventoryUi / DialogueBox / PauseMenu
```

规则层继续保持无 Autoload 的静态类：

```text
AffectionRules / EventRules / FestivalRules
CropGrowth / AnimalHusbandry / FloraGrowth
Weather / DayNight / GridPathfinder
```

Autoload 只允许保留：

- `EventBus`：跨域、无状态、已收窄的信号节点。
- `Audio`：纯表现层、无游戏状态、不反向依赖场景路由。
- 可选 `Database`：只读目录；更彻底方案是改成 `DataCatalog` Resource 由 `Main` 注入。

目标数量：**0–2 个 Autoload**。数量不是判据，状态是否归组合根、依赖是否显式才是。

---

## 4. 分阶段重构计划

### 阶段 A：已完成

状态 Resource 化 + SaveManager 去反射 + 目标纯逻辑类注入。

产物：

- 5 个状态 Resource。
- `Main` 组合根字段与注入。
- `Persistence.register_core()`。
- 对应的文档与测试更新。

### 阶段 B：删除 `GameState / GameClock` 门面

目标：消费者不再通过全局名访问玩家 / 时钟状态。

步骤：

1. 给所有 `GameState` 消费者加显式依赖：
   - `Npc`
   - `SceneDoor`
   - `ShippingBin`
   - `Hud`
   - `Calendar`
   - `Relationships`
   - `Shop`（已注入 `wallet`）
   - 测试
2. `Main` 把 `player_profile` 注入到世界场景根 / UI 根，而不是只注入 `GameState`。
3. `GameClock` 消费者注入 `GameDateClock`：
   - `Calendar`
   - `Audio`
   - `Npc`（`schedule_entry`）
   - `WorldLighting` / `WeatherFx` / `FloraField` / `FarmGrid` / `Player` / `Hud`
4. 删除 `project.godot` 中的 `GameState`、`GameClock`。
5. 把原门面里的信号转发逻辑移到状态拥有者或更小的 presenter 中。

关键验收：

- `rg "GameState\.|GameClock\." src tests tools` 归零。
- 新游戏 / 读档 / 日结转 / 存档仍全绿。
- 单独 new `PlayerProfile` / `GameDateClock` 即可测试，不启动 Autoload。

### 阶段 C：删除 `WeatherSystem / Relationships / Calendar` 门面

目标：把跨场景领域服务从 Autoload 转为组合根拥有的节点或 Service 对象。

步骤：

1. `WeatherSystem` 服务节点化：
   - 持有 `WeatherState`。
   - 订阅日结转；由 `Main` 或世界管线显式调用。
   - 删除全局名依赖。
2. `Relationships` 服务节点化：
   - `RelationshipStore` 仍为 Resource。
   - 婚育推进改为 `MarriageRules.advance_day(store, date)` 纯函数 + 服务层发信号。
   - 从 `Npc`、`Calendar`、`Player` 显式注入。
3. `Calendar` 服务节点化：
   - `CalendarProgress` 为 Resource。
   - 节日 / 事件匹配改为纯函数输入：`Date + Weather + Flags + Affection`。
   - `Calendar` 只保留“查表 + 状态 + 广播”。
4. 把有序日结转钩子从 `GameClock` 拆成显式 `DayPipeline`：
   - 注册接口带 `priority`
   - `Main` 或组合根显式按序注册
   - 不再依赖 `project.godot` 声明顺序

关键验收：

- `WeatherSystem` / `Relationships` / `Calendar` 不再是全局名。
- `Calendar._matches()` 不再直接读 5 个 Autoload。
- 日结转顺序由显式优先级或组合根代码决定。

### 阶段 D：`SceneRouter / SaveManager / Audio` 收口

目标：消除单例持有场景节点、字符串路径与不可追踪连接。

`SceneRouter`：

1. 世界缓存 `_world_cache` 移到 `WorldHost` 或 `Main` 持有的 `WorldCache`。
2. `SceneRouter` 改为无状态方法：
   ```gdscript
   change_scene_to(host: Node, path: String, spawn: StringName)
   ```
3. `_pending_world_path / _pending_spawn_id` 改为显式 `WorldTarget` 参数。
4. 删除 `GameClock.paused` 与 `SceneTree.paused` 的双真值，统一暂停控制器。

`SaveManager`：

1. 用 `SaveSection` 契约统一核心节与场景节。
2. `Main` 注册 `Array[SaveSection]`。
3. 可选：把 JSON I/O 与注册表拆开，标题页只用静态 `SaveCodec.read_meta()`。

`Audio`：

1. 删除反向依赖 `SceneRouter.current_world()`。
2. 改为订阅 `EventBus.world_entered(world_id)`。
3. 所有 lambda 连接改成具名方法 + `is_connected` 守卫。
4. UI 不再直接调 `Audio.play_sfx`，改为发 `ui_sound_requested` 事件。

关键验收：

- `SceneRouter` 不再保存 `Node` 引用。
- `SaveManager` 不再用 `NodePath` 反射核心单例。
- `Audio` 无 `get_tree().paused` 之外的全局游戏状态访问。

### 阶段 E：收窄 EventBus / Database

`EventBus`：

- 按域拆为 `PlayerEvents / FarmEvents / UiEvents / WorldEvents`；
- 每个事件对象由状态拥有者持有；
- 只保留跨域时间 / 场景信号为全局。

`Database`：

- 改为 `DataCatalog extends Resource`，`Main` 注入；
- 或至少把公开字典改为 `_private + getters`，禁止直接迭代内表。

关键验收：

- `EventBus` 信号数从 54 降到约 8–12。
- `Database.*` 直接字段访问归零。
- `src/core/text.gd`、`Shop`、`Inventory` 可完全脱离 Autoload 单测。

---

## 5. 推荐提交边界

不要一次提交一个巨型“完全重构”。建议按以下边界提交：

1. `refactor: 状态 Resource 化并迁移 Main 组合根`（本次提交）
2. `refactor: 移除 GameState / GameClock 全局门面`
3. `refactor: 移除 WeatherSystem / Relationships / Calendar 全局门面`
4. `refactor: SceneRouter / SaveManager / Audio 去单例耦合`
5. `refactor: 收窄 EventBus 与 Database`
6. `test: 补充组合根与纯逻辑隔离测试`

每次提交都必须全量 `./tools/check.sh` 通过。

---

## 6. 风险与注意事项

1. **旧存档兼容**：`SAVE_VERSION` 不因内部重构递增；核心节键名和字段格式保持不变。
2. **`Main` 重建**：标题页 → 游戏会创建新的 `Main`，新的 Resource；Autoload 门面必须重新注入。
3. **世界场景缓存**：`_ready()` 一生只跑一次，注入如果只放在 `_ready()` 会漏掉缓存复用场景；用 `_enter_tree()` 或 `on_world_enter()`。
4. **信号连接泄漏**：Resource 不负责连接；所有连接必须由节点在 `_enter_tree/_exit_tree` 成对管理。
5. **日结转顺序**：当前仍依赖注册顺序；阶段 C 必须显式优先级。
6. **测试隔离**：新 Resource 让 `before_test` 可以 `new` 干净实例；不要再用“重置 5 个单例”作为默认方案。
7. **文档同步**：改依赖图 / 状态归属必须同步 `docs/architecture.md`、`README.md`、`AGENTS.md`。

---

## 7. 当前遗留问题（已知）

- 11 个 Autoload 仍然存在，其中 5 个已退化为门面，但消费者仍通过全局名访问。
- `SceneRouter` 仍持有 `_world_cache / _current_world`，是场景节点生命周期错配。
- `Audio` 仍反向依赖 `SceneRouter`、`GameClock`，且部分 lambda 连接不可追踪。
- `EventBus` 54 个全局信号尚未按域拆分。
- `Database` 的公开字典仍可被直接迭代。
- `Npc.affection` 与 `RelationshipStore` 仍存在双真值同步。
- `GameClock.paused` 与 `SceneTree.paused` 双暂停真值尚未统一。

---

## 8. 快速定位

- 状态资源：`src/core/{player_profile,game_date_clock,weather_state,relationship_store,calendar_progress}.gd`
- 组合根：`src/main/main.gd`
- 存档注册：`src/core/persistence.gd`、`src/autoload/save_manager.gd`
- 纯逻辑：`src/core/text.gd`、`src/shop/shop.gd`、`src/player/player_stats.gd`、`src/player/inventory.gd`
- 架构文档：`docs/architecture.md` §2.0 / §2.1
