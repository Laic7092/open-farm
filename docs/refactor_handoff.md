# open-farm 重构交接文档

> 本文件只保留当前基线、剩余计划和风险；阶段 A/B/C 的历史细节不再维护，
> 需要时看 git 历史与 `docs/architecture.md`。
> 代码事实以 `project.godot`、`src/**/*.gd`、`scenes/**/*.tscn`、`tests/**` 为准。

---

## 1. 当前基线

阶段 A / B / C 已完成：

- A：5 个状态 Resource（`PlayerProfile` / `GameDateClock` / `WeatherState` /
  `RelationshipStore` / `CalendarProgress`）；`Main` 成为组合根；`SaveManager`
  不再做字符串反射。
- B：删除 `GameState` / `GameClock` 门面；世界 / UI 节点改为 `bind_dependencies()`。
- C：删除 `WeatherSystem` / `Relationships` / `Calendar` 门面，改为
  `WeatherService` / `RelationshipService` / `CalendarService` 服务节点；
  新增 `DayPipeline` 与 `MarriageRules`。

当前 6 个 Autoload：

```text
EventBus / AppTheme / Database / SaveManager / SceneRouter / Audio
```

组合根结构：

```text
Main
├── PlayerProfile / GameDateClock              Resource
├── WeatherState / RelationshipStore /
│   CalendarProgress                           Resource
├── WeatherService / RelationshipService /
│   CalendarService                            服务节点
├── WorldHost                                  世界场景换入换出
└── UiRoot                                     HUD / 菜单 / 商店等
```

依赖与日结转约定：

- `Main._enter_tree()` 创建服务节点，并注入状态、服务与 `WorldScene` / `UiRoot`；
  世界 / UI 节点通过 `bind_dependencies()` 与 `bind_services()` 接收依赖。
- 日结转走 `DayPipeline`，按显式 `priority` 执行：
  `PRIORITY_WEATHER` → `PRIORITY_RELATIONSHIPS` → `PRIORITY_CALENDAR` → `PRIORITY_WORLD`。
- 规则层保持无 Autoload 的静态类：`AffectionRules` / `EventRules` / `FestivalRules` /
  `CropGrowth` / `AnimalHusbandry` / `FloraGrowth` / `Weather` / `DayNight` /
  `GridPathfinder` / `MarriageRules`。
- 旧存档键名保持 `GameClock` / `GameState` / `WeatherSystem` / `Relationships` /
  `Calendar`；`SAVE_VERSION` 不因内部重构递增。

验证基线：

```bash
GODOT_TIMEOUT=240 timeout 900 ./tools/check.sh
```

- 单元测试：345/345 通过
- 冒烟测试：286/286 通过
- `git diff --check` 通过

---

## 2. 目标终态

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

Autoload 只允许保留：

- `EventBus`：跨域、无状态、已收窄的信号节点。
- `Audio`：纯表现层、无游戏状态、不反向依赖场景路由。
- 可选 `Database`：只读目录；更彻底方案是改成 `DataCatalog` Resource 由 `Main` 注入。

目标数量：**0–2 个 Autoload**。数量不是判据，状态是否归组合根、依赖是否显式才是。

---

## 3. 剩余阶段 D：SceneRouter / SaveManager 收口

> `Audio` 子项已完成，不再重复。
> 目标：消除单例持有场景节点、字符串路径与不可追踪连接。

`SceneRouter`：

1. 世界缓存 `_world_cache` 移到 `WorldHost` 或 `Main` 持有的 `WorldCache`。
2. `SceneRouter` 改为无状态方法：
   ```gdscript
   change_scene_to(host: Node, path: String, spawn: StringName)
   ```
3. `_pending_world_path / _pending_spawn_id` 改为显式 `WorldTarget` 参数。
4. 删除 `GameDateClock.paused` 与 `SceneTree.paused` 的双真值，统一暂停控制器。

`SaveManager`：

1. 用 `SaveSection` 契约统一核心节与场景节。
2. `Main` 注册 `Array[SaveSection]`。
3. 可选：把 JSON I/O 与注册表拆开，标题页只用静态 `SaveCodec.read_meta()`。

关键验收：

- `SceneRouter` 不再保存 `Node` 引用。
- `SaveManager` 不再用 `NodePath` 反射核心单例。
- `Audio` 无 `get_tree().paused` 之外的全局游戏状态访问。

---

## 4. 剩余阶段 E：收窄 EventBus / Database

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

剩余工作不要一次提交成巨型“完全重构”，建议按以下边界：

1. `refactor: SceneRouter / SaveManager 去单例耦合`
2. `refactor: 收窄 EventBus 与 Database`
3. `test: 补充组合根与纯逻辑隔离测试`

每次提交都必须全量 `./tools/check.sh` 通过。

---

## 6. 风险与注意事项

1. **旧存档兼容**：`SAVE_VERSION` 不因内部重构递增；核心节键名和字段格式保持不变。
2. **`Main` 重建**：标题页 → 游戏会创建新的 `Main` 与新的 Resource；服务 / 世界 /
   UI 都必须由新 Main 重新显式注入，不能保留上一局引用。
3. **世界场景缓存**：`_ready()` 一生只跑一次；注入如果只放在 `_ready()` 会漏掉缓存复用
   场景，必须用 `_enter_tree()` 或 `on_world_enter()`。
4. **信号连接泄漏**：Resource 不负责连接；所有连接必须由节点在
   `_enter_tree/_exit_tree` 成对管理。
5. **日结转顺序**：新增钩子必须显式传 `DayPipeline.PRIORITY_*`，不要依赖注册顺序。
6. **测试隔离**：状态 Resource 可以让 `before_test` 直接 `new` 干净实例；
   不要再用“重置多个单例”作为默认方案。
7. **文档同步**：改依赖图 / 状态归属时，同步更新 `docs/architecture.md`、
   `README.md` / `AGENTS.md` 与相关脚本的 `##` 设计注释。

---

## 7. 当前遗留问题（已知）

- 6 个 Autoload 仍然存在；`WeatherService` / `RelationshipService` /
  `CalendarService` 已收口为 `Main` 持有的服务节点。
- `SceneRouter` 仍持有 `_world_cache / _current_world`，是场景节点生命周期错配。
- `SaveManager` 仍用节点组 / 元数据混合注册核心节，尚未统一为 `SaveSection`。
- `EventBus` 54 个全局信号尚未按域拆分。
- `Database` 的公开字典仍可被直接迭代。
- `Npc.affection` 与 `RelationshipStore` 仍存在双真值同步。
- `GameDateClock.paused` 与 `SceneTree.paused` 双暂停真值尚未统一。

---

## 8. 快速定位

- 状态资源：`src/core/{player_profile,game_date_clock,weather_state,relationship_store,calendar_progress}.gd`
- 服务节点：`src/services/{weather,relationship,calendar}_service.gd`
- 日结转流水线：`src/core/day_pipeline.gd`、`src/core/game_date_clock.gd`
- 婚育规则：`src/npc/marriage_rules.gd`
- 组合根：`src/main/main.gd`
- 存档注册：`src/core/persistence.gd`、`src/autoload/save_manager.gd`
- 纯逻辑：`src/core/text.gd`、`src/shop/shop.gd`、`src/player/player_stats.gd`、`src/player/inventory.gd`
- 组合根与状态注入：`src/main/main.gd` 顶部注释与 `_bind_dependencies()`
