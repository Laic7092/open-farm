extends Node
## 全局事件总线（Autoload：`EventBus`）。
##
## [b]只保留跨域时间 / 场景 / 存档信号[/b]：这些信号没有单一状态拥有者，
## 且生产者与消费者分属不同域，放在全局对象上避免任意一方持有另一方。
##
## 各领域信号拆到由状态 / 宿主拥有的对象里：
## [br]- [PlayerEvents]：玩家档案、背包、关系进度，由 [PlayerProfile] 持有；
## [br]- [FarmEvents]：农田、作物、畜牧，由组合根创建给世界生产者使用；
## [br]- [WorldEvents]：天气、节日、事件、野生植被，由 [WorldHost] 持有；
## [br]- [UiEvents]：对话、商店、通知、暂停等交互 UI，由 [UiRoot] 持有。
##
## [b]使用约定[/b]
## [br]- 本脚本只声明跨域信号与领域对象访问点，不写逻辑；
## [br]- 一对一的父子通信仍直接用节点信号，不要绕道 EventBus；
## [br]- 需要确定性执行顺序的模拟逻辑请用
##   [method GameDateClock.register_day_hook] / [DayPipeline]，显式声明优先级。

# ---------------------------------------------------------------- 领域事件对象

## 玩家域事件；游戏运行时由 [Main] 绑定到 [member PlayerProfile.events]。
var player: PlayerEvents = PlayerEvents.new()
## 农场域事件；游戏运行时由 [Main] 创建并注入世界。
var farm: FarmEvents = FarmEvents.new()
## 世界域事件；游戏运行时由 [Main] 绑定到 [WorldHost.events]。
var world: WorldEvents = WorldEvents.new()
## UI 域事件；游戏运行时由 [Main] 绑定到 [UiRoot.events]。
var ui: UiEvents = UiEvents.new()

# ---------------------------------------------------------------- 时间 / 日历

## 游戏内分钟推进（用于时钟 UI 刷新）。
signal minute_changed(hour: int, minute: int)
## 整点。
signal hour_changed(hour: int)
## 日期推进（季节 / 年份变化时也会先发对应信号再发本信号）。
signal day_changed(date: GameDate)
## 季节变化。
signal season_changed(season: Season.Type)
## 年份变化。
signal year_changed(year: int)

# ---------------------------------------------------------------- 存档 / 场景

## 存档 / 读档完成。
signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
## 场景切换开始 / 结束。
signal scene_transition_started(target: StringName)
signal scene_transition_finished(target: StringName)
## 进入某个世界场景（包括从缓存里重新挂载）。音频等“按地图切换”的系统订阅它。
signal world_entered(world_id: StringName)
