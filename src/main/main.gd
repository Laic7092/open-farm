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

@onready var world_host: WorldHost = %WorldHost

## 本局玩家档案；由 Main 作为组合根持有并注入世界 / UI / 服务。
var player_profile: PlayerProfile = PlayerProfile.new()
## 本局时钟状态；由 Main 持有、每帧驱动，并注入给所有消费者。
var clock_state: GameDateClock = GameDateClock.new()
## 本局天气状态；由 Main 作为组合根持有。
var weather_state: WeatherState = WeatherState.new()
## 本局关系状态；由 Main 作为组合根持有。
var relationship_store: RelationshipStore = RelationshipStore.new()
## 本局节日 / 事件进度；由 Main 作为组合根持有。
var calendar_progress: CalendarProgress = CalendarProgress.new()

## 天气服务；由 Main 创建为子节点，不再是 Autoload。
var weather_service: WeatherService
## 关系服务；由 Main 创建为子节点，不再是 Autoload。
var relationship_service: RelationshipService
## 日历服务；由 Main 创建为子节点，不再是 Autoload。
var calendar_service: CalendarService
## 农场域事件；世界生产节点共享，生命周期跟随本局 Main。
var farm_events: FarmEvents = FarmEvents.new()
## 世界域事件；优先绑定到 WorldHost.events，找不到宿主时用本对象兜底。
var world_events: WorldEvents = WorldEvents.new()
## 本场景自带的音频节点；由 main.tscn 放置，Main 只负责注入时钟与共享引用。
var scene_audio: SceneAudio
## 本局核心存档节；Main 是唯一注册入口，SaveManager 只消费 [SaveSection]。
var save_sections: Array[SaveSection] = []

var _services_created: bool = false
var _dependencies_bound: bool = false


## 回到标题页。
##
## 会先清空世界场景缓存：标题页回来时 [Main] 整棵子树都会被释放，
## 缓存里的世界节点随之作废，留着只会在下一次开新档时被复用成"上一局的农场"。
static func return_to_title(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.paused = false
	var host := tree.get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host != null:
		host.clear_world_cache()
	tree.change_scene_to_file(TITLE_SCENE)


func _enter_tree() -> void:
	# 服务节点先作为 Main 的子节点建立；再把状态与互相依赖显式注入。
	# Main 的 _enter_tree() 早于世界 / UI 子树的对应回调，因此这里是最早的安全点。
	_ensure_services()
	_bind_dependencies()


func _ready() -> void:
	PointerInput.hide_cursor()
	player_profile.set_playtime_counting(true)
	EventBus.ui.pause_menu_toggle_requested.connect(_on_pause_menu_requested)

	if boot_mode == BootMode.LOAD_SLOT and await _boot_from_save():
		return
	_boot_new_game()


func _process(delta: float) -> void:
	# 时钟与游玩时长由组合根统一驱动。
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
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_SAVED", {"slot": QUICK_SLOT}
		)
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		_quick_load()


# ---------------------------------------------------------------- 组合根

## 创建本局服务节点；服务在 _ready() 里注册自己的核心存档节。
func _ensure_services() -> void:
	if _services_created:
		return
	_services_created = true

	weather_service = WeatherService.new()
	weather_service.name = "WeatherService"
	add_child(weather_service)

	relationship_service = RelationshipService.new()
	relationship_service.name = "RelationshipService"
	add_child(relationship_service)

	calendar_service = CalendarService.new()
	calendar_service.name = "CalendarService"
	add_child(calendar_service)


## 把本局状态注入服务与所有常驻 / 世界消费者。
func _bind_dependencies() -> void:
	if _dependencies_bound:
		return
	_dependencies_bound = true

	var host := get_node_or_null(^"WorldHost") as WorldHost
	var ui_root := get_node_or_null(^"UiRoot")

	# EventBus 的领域对象生命周期与 Autoload 一致；状态 / 宿主只持有同一引用。
	# 不在这里替换实例，避免音频 / UI 等常驻订阅者连着旧对象收不到事件。
	player_profile.events = EventBus.player
	farm_events = EventBus.farm
	world_events = EventBus.world
	if host != null:
		host.events = EventBus.world
	if ui_root != null:
		ui_root.set(&"events", EventBus.ui)

	Persistence.register_core_resource(clock_state, &"GameClock", 10)
	Persistence.register_core_resource(player_profile, &"GameState", 20)

	# 本局核心存档节由 Main 显式注册；旧 [Persistence] 注册只作为兼容回退。
	save_sections.clear()
	save_sections.append(SaveSection.new(clock_state, &"GameClock", 10, true))
	save_sections.append(SaveSection.new(player_profile, &"GameState", 20, true))
	save_sections.append(SaveSection.new(weather_service, &"WeatherSystem", 30, true))
	save_sections.append(SaveSection.new(relationship_service, &"Relationships", 40, true))
	save_sections.append(SaveSection.new(calendar_service, &"Calendar", 50, true))
	if host != null:
		save_sections.append(SaveSection.new(host, &"SceneRouter", 60, true))
	SaveManager.set_core_sections(save_sections)

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

	# 本局服务：状态 Resource 与彼此依赖全部在 Main 显式注入。
	weather_service.bind_dependencies(clock_state, weather_state)

	relationship_service.set_state(relationship_store)
	relationship_service.bind_dependencies(player_profile, clock_state)

	calendar_service.set_state(calendar_progress)
	calendar_service.bind_dependencies(
		player_profile, clock_state, weather_service, relationship_service
	)

	# 本场景的音频节点：注入时钟，并把引用转给需要音量滑杆的界面。
	scene_audio = get_node_or_null(^"SceneAudio") as SceneAudio
	if scene_audio != null:
		scene_audio.bind_clock(clock_state)

	# 世界宿主持有缓存与依赖；SceneRouter 不再保存任何世界节点。
	if host != null:
		host.bind_dependencies(player_profile, clock_state)
		host.bind_services(weather_service, relationship_service, calendar_service)

	# UI 子树也提前拿到同一份依赖。
	if ui_root != null and ui_root.has_method(&"bind_dependencies"):
		ui_root.call(&"bind_dependencies", player_profile, clock_state)
	if ui_root != null and ui_root.has_method(&"bind_services"):
		ui_root.call(&"bind_services", weather_service, relationship_service, calendar_service)
	if ui_root != null and scene_audio != null and ui_root.has_method(&"bind_audio"):
		ui_root.call(&"bind_audio", scene_audio)


# ---------------------------------------------------------------- 启动

## 读档启动；失败时返回 false，由调用方退回"开新档"。
func _boot_from_save() -> bool:
	if not SaveManager.has_save(boot_slot):
		push_warning("Main: 槽位 %d 没有存档，改为新游戏" % boot_slot)
		return false
	# 新游戏 / 读档都要丢掉上一局缓存的世界场景。
	if world_host != null:
		world_host.clear_world_cache()
	if await SaveManager.load_game_and_restore_world(boot_slot):
		return true
	push_warning("Main: 读取槽位 %d 失败，改为新游戏" % boot_slot)
	return false


func _boot_new_game() -> void:
	player_profile.reset()
	relationship_service.reset()
	clock_state.reset()
	weather_service.reroll(clock_state.date.season)
	calendar_service.reset()
	# 开局也要让 HUD / 音频节点看到完整状态，而不依赖某次日结转。
	clock_state.refresh_observers()
	world_host.clear_world_cache()
	await SceneRouter.change_scene_to(world_host, FIRST_WORLD, FIRST_SPAWN)


func _quick_load() -> void:
	if not await SaveManager.load_game_and_restore_world(QUICK_SLOT):
		EventBus.ui.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})
		return
	EventBus.ui.notification_requested.emit(&"NOTIFY_LOADED", {"slot": QUICK_SLOT})


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
	EventBus.player.money_changed.emit(money, delta)
