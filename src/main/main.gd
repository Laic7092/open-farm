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
## 本局博物馆单元；持有图鉴状态并在新道具入包时自动入册。
var museum: Museum = Museum.new()
## 本局委托单元；持有委托板状态，负责出题、刷新与交付结算。
var commission: Commission = Commission.new()

## 天气服务；由 Main 创建为子节点，不再是 Autoload。
var weather_service: WeatherService
## 关系服务；由 Main 创建为子节点，不再是 Autoload。
var relationship_service: RelationshipService
## 日历服务；由 Main 创建为子节点，不再是 Autoload。
var calendar_service: CalendarService
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
	# 回到标题就不再持有“本局”，否则下一次开新档会误写进上一局的槽位。
	SaveManager.begin_new_game()
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
	PointerInput.sync_cursor()
	player_profile.set_playtime_counting(true)
	EventBus.ui.pause_menu_toggle_requested.connect(_on_pause_menu_requested)
	EventBus.ui.touch_controls_toggled.connect(_on_touch_controls_toggled)

	if boot_mode == BootMode.LOAD_SLOT and await _boot_from_save():
		return
	_boot_new_game()


func _process(delta: float) -> void:
	# 时钟与游玩时长由组合根统一驱动。
	clock_state.tick(delta)
	player_profile.tick(delta)


func _input(event: InputEvent) -> void:
	# 纯键盘操作：指针事件一律吞掉，避免隐藏的光标误触 UI；
	# 触控模式下必须放行，否则虚拟摇杆与屏幕按钮收不到任何指针事件。
	if PointerInput.swallows_pointer() and PointerInput.is_pointer(event):
		get_viewport().set_input_as_handled()


## 触控开关可能在游戏里被改（系统菜单），光标要跟着切。
func _on_touch_controls_toggled(_enabled: bool) -> void:
	PointerInput.sync_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		_quick_save()
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

	# 领域事件对象由 [EventBus] 单点持有；[PlayerProfile] / [WorldHost] / [UiRoot]
	# 上的 events 字段只是同一实例的别名，这里不再替换，避免常驻订阅者连着旧对象。

	# 本局核心存档节只由组合根这一处声明；服务不再各自注册一遍。
	save_sections.clear()
	save_sections.append(SaveSection.new(clock_state, &"GameClock", 10, true))
	save_sections.append(SaveSection.new(player_profile, &"GameState", 20, true))
	save_sections.append(SaveSection.new(weather_service, &"WeatherSystem", 30, true))
	save_sections.append(SaveSection.new(relationship_service, &"Relationships", 40, true))
	save_sections.append(SaveSection.new(calendar_service, &"Calendar", 50, true))
	save_sections.append(SaveSection.new(museum.state, &"Museum", 55, true))
	save_sections.append(SaveSection.new(commission.state, &"Commissions", 56, true))
	if host != null:
		save_sections.append(SaveSection.new(host, &"SceneRouter", 60, true))
	SaveManager.set_core_sections(save_sections)

	# 日结自动存档：排在所有模拟钩子之后，落盘的是新一天开始的状态。
	clock_state.register_day_hook(
		_on_day_rollover_autosave, DayPipeline.PRIORITY_AUTOSAVE
	)

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

	# 图鉴：订阅被注入的玩家事件，新道具一入包就入册（钓到 / 收获 / 买到 / 采集都会经过背包）。
	museum.bind(player_profile.events, clock_state)
	# 委托：注入档案 / 时钟 / "当前背包"提供者；出题与结算都由委托单元负责。
	commission.bind(player_profile, clock_state, Callable(self, &"_current_inventory"))

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
	if ui_root != null and ui_root.has_method(&"bind_progress"):
		ui_root.call(&"bind_progress", museum.state, commission.state)
	if ui_root != null and ui_root.has_method(&"bind_commission"):
		ui_root.call(&"bind_commission", commission)
	if ui_root != null and ui_root.has_method(&"bind_fishing"):
		ui_root.call(&"bind_fishing", Callable(self, &"_current_fishing"))
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
	SaveManager.begin_new_game()
	player_profile.reset()
	relationship_service.reset()
	clock_state.reset()
	weather_service.reroll(clock_state.date.season)
	calendar_service.reset()
	museum.state.reset()
	commission.state.reset()
	# 开局也要让 HUD / 音频节点看到完整状态，而不依赖某次日结转。
	clock_state.refresh_observers()
	world_host.clear_world_cache()
	await SceneRouter.change_scene_to(world_host, FIRST_WORLD, FIRST_SPAWN)


## 快捷存档：写到本局槽位；新游戏第一次存档时才分配槽位号。
func _quick_save() -> void:
	if SaveManager.save_current():
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_SAVED", {"slot": SaveManager.current_slot + 1}
		)
	else:
		EventBus.ui.notification_requested.emit(&"NOTIFY_SAVE_FAILED", {})


func _quick_load() -> void:
	if not await SaveManager.load_current_and_restore_world():
		EventBus.ui.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})
		return
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_LOADED", {"slot": SaveManager.current_slot + 1}
	)


## 日结自动存档：日结转流水线的最后一棒，存下的是"新一天刚开始"的状态。
func _on_day_rollover_autosave(_date: GameDate) -> void:
	if SaveManager.save_current():
		EventBus.ui.notification_requested.emit(&"NOTIFY_AUTO_SAVED", {})


func _on_pause_menu_requested() -> void:
	# UiRoot 已经负责开关菜单与暂停，这里只留一个扩展点。
	pass


## 当前世界里的玩家背包；在世界宿主持有的那张图内查找，不做全树搜索。
func _current_inventory() -> Inventory:
	if world_host == null:
		return null
	var player := world_host.current_player()
	return player.inventory if player != null else null


## 当前世界里的钓鱼单元；同上，供界面只读快照。
func _current_fishing() -> FishingSession:
	if world_host == null:
		return null
	var player := world_host.current_player()
	return player.fishing if player != null else null



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
