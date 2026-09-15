class_name Main
extends Node2D
## 游戏主入口（常驻节点），也是本局的组合根。
##
## 结构：
## [codeblock]
## Main
## ├── WorldHost   ← 世界场景在这里被换进换出（组 world_host）
## └── UiRoot      ← CanvasLayer，常驻不销毁
## [/codeblock]
##
## 世界场景用"换子节点"而不是 [method SceneTree.change_scene_to_file]，
## 这样 UI、全局输入、存档系统都不会因为一次传送被重建。
##
## [b]入口参数[/b]：标题页在切换场景之前设置 [member boot_mode] / [member boot_slot]，
## 本节点据此决定"开新档"还是"继续上次的档"。
## 用静态变量而不是新增一个 autoload，是因为这两个值
## 只在"标题页 → 游戏"这一瞬间有意义，没有跨系统共享的必要。

## 启动方式。
enum BootMode {
	NEW_GAME,   ## 从零开始
	LOAD_SLOT,  ## 读取指定槽位
}

## 本次启动的方式，由标题页设置。
static var boot_mode: BootMode = BootMode.NEW_GAME
## [constant BootMode.LOAD_SLOT] 时要读取的槽位。
static var boot_slot: int = 0

## 新游戏从哪个世界开始。
const FIRST_WORLD: String = "res://scenes/world/farm.tscn"
## 新游戏落地的出生点。
const FIRST_SPAWN: StringName = &"start"
## 快捷存 / 读档使用的槽位。
const QUICK_SLOT: int = 0
## 标题页场景路径（"回到标题"要知道回到哪）。
const TITLE_SCENE: String = "res://scenes/title/title_screen.tscn"

@onready var world_host: Node2D = %WorldHost

## 本局玩家档案；由 Main 作为组合根持有并注入世界 / UI / Autoload 服务。
var player_profile: PlayerProfile = PlayerProfile.new()
## 本局时钟状态；由 Main 持有、每帧驱动，并注入给所有消费者。
var clock_state: GameDateClock = GameDateClock.new()
## 本局天气状态；由 Main 作为组合根持有。
var weather_state: WeatherState = WeatherState.new()
## 本局关系状态；由 Main 作为组合根持有。
var relationship_store: RelationshipStore = RelationshipStore.new()
## 本局节日 / 事件进度；由 Main 作为组合根持有。
var calendar_progress: CalendarProgress = CalendarProgress.new()

var _dependencies_bound: bool = false


## 回到标题页。
##
## 会先清空世界场景缓存：标题页回来时 [Main] 整棵子树都会被释放，
## 缓存里的世界节点随之作废，留着只会在下一次开新档时被复用成"上一局的农场"。
static func return_to_title(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.paused = false
	SceneRouter.clear_world_cache()
	tree.change_scene_to_file(TITLE_SCENE)


func _enter_tree() -> void:
	# 组合根依赖要在世界 / UI 子树的 _enter_tree() 之前下发；Main 的
	# _enter_tree() 早于子节点的对应回调，因此这里是最早的安全点。
	_bind_dependencies()


func _ready() -> void:
	PointerInput.hide_cursor()
	player_profile.set_playtime_counting(true)
	EventBus.pause_menu_toggle_requested.connect(_on_pause_menu_requested)

	if boot_mode == BootMode.LOAD_SLOT and await _boot_from_save():
		return
	_boot_new_game()


func _process(delta: float) -> void:
	# Autoload 消失后，时钟与游玩时长由组合根统一驱动。
	clock_state.tick(delta)
	player_profile.tick(delta)


func _input(event: InputEvent) -> void:
	# 纯键盘操作：指针事件一律吞掉，避免隐藏的光标误触 UI。
	if PointerInput.is_pointer(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		SaveManager.save_game(QUICK_SLOT)
		EventBus.notification_requested.emit(
			&"NOTIFY_SAVED", {"slot": QUICK_SLOT}
		)
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		_quick_load()


# ---------------------------------------------------------------- 组合根

## 把本局状态注册为核心存档节，并注入到所有常驻 / 世界消费者。
func _bind_dependencies() -> void:
	if _dependencies_bound:
		return
	_dependencies_bound = true

	Persistence.register_core_resource(clock_state, &"GameClock", 10)
	Persistence.register_core_resource(player_profile, &"GameState", 20)

	# 时钟信号由 Main 作为 presenter 转发到 EventBus；消费者继续只订阅 EventBus。
	if not clock_state.minute_changed.is_connected(_on_clock_minute_changed):
		clock_state.minute_changed.connect(_on_clock_minute_changed)
	if not clock_state.hour_changed.is_connected(_on_clock_hour_changed):
		clock_state.hour_changed.connect(_on_clock_hour_changed)
	if not clock_state.day_changed.is_connected(_on_clock_day_changed):
		clock_state.day_changed.connect(_on_clock_day_changed)
	if not clock_state.season_changed.is_connected(_on_clock_season_changed):
		clock_state.season_changed.connect(_on_clock_season_changed)
	if not clock_state.year_changed.is_connected(_on_clock_year_changed):
		clock_state.year_changed.connect(_on_clock_year_changed)
	if not player_profile.money_changed.is_connected(_on_profile_money_changed):
		player_profile.money_changed.connect(_on_profile_money_changed)

	# 常驻 Autoload 服务：状态 Resource 由 Main 注入，方法通过显式接口接线。
	WeatherSystem.set_state(weather_state)
	WeatherSystem.bind_clock(clock_state)
	Relationships.set_state(relationship_store)
	Relationships.bind_dependencies(player_profile, clock_state)
	Calendar.set_state(calendar_progress)
	Calendar.bind_dependencies(player_profile, clock_state)
	Audio.bind_clock(clock_state)

	# 世界路由保存同一份引用，在挂载世界场景前注入给世界根节点。
	SceneRouter.bind_dependencies(player_profile, clock_state)

	# UI 子树也提前拿到同一份依赖。
	var ui_root := get_node_or_null(^"UiRoot")
	if ui_root != null and ui_root.has_method(&"bind_dependencies"):
		ui_root.call(&"bind_dependencies", player_profile, clock_state)


# ---------------------------------------------------------------- 启动

## 读档启动；失败时返回 false，由调用方退回"开新档"。
func _boot_from_save() -> bool:
	if not SaveManager.has_save(boot_slot):
		push_warning("Main: 槽位 %d 没有存档，改为新游戏" % boot_slot)
		return false
	# 新游戏 / 读档都要丢掉上一局缓存的世界场景。
	SceneRouter.clear_world_cache()
	if await SaveManager.load_game_and_restore_world(boot_slot):
		return true
	push_warning("Main: 读取槽位 %d 失败，改为新游戏" % boot_slot)
	return false


func _boot_new_game() -> void:
	player_profile.reset()
	Relationships.reset()
	clock_state.reset()
	WeatherSystem.reroll(clock_state.date.season)
	Calendar.reset()
	# 开局也要让 HUD / Audio 看到完整状态，而不依赖某次日结转。
	clock_state.refresh_observers()
	SceneRouter.clear_world_cache()
	await SceneRouter.change_scene_to(FIRST_WORLD, FIRST_SPAWN)


func _quick_load() -> void:
	if not await SaveManager.load_game_and_restore_world(QUICK_SLOT):
		EventBus.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})
		return
	EventBus.notification_requested.emit(&"NOTIFY_LOADED", {"slot": QUICK_SLOT})


func _on_pause_menu_requested() -> void:
	# UiRoot 已经负责开关菜单与暂停，这里只留一个扩展点（例如自动存档）。
	pass


# ---------------------------------------------------------------- 信号转发

func _on_clock_minute_changed(hour: int, minute: int) -> void:
	EventBus.minute_changed.emit(hour, minute)


func _on_clock_hour_changed(hour: int) -> void:
	EventBus.hour_changed.emit(hour)


func _on_clock_day_changed(date: GameDate) -> void:
	player_profile.set_playtime_counting(true)
	EventBus.day_changed.emit(date)


func _on_clock_season_changed(season: Season.Type) -> void:
	EventBus.season_changed.emit(season)


func _on_clock_year_changed(year: int) -> void:
	EventBus.year_changed.emit(year)


func _on_profile_money_changed(money: int, delta: int) -> void:
	EventBus.money_changed.emit(money, delta)
