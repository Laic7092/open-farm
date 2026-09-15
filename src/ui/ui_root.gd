class_name UiRoot
extends CanvasLayer
## UI 总入口。
##
## 所有界面都挂在这一层下面，[b]不随世界场景销毁[/b]——
## 因为世界场景是在 [Main] 的 WorldHost 下换的，UI 层是它的兄弟节点。
##
## 统一在这里管理"模态栈"：只要有一个模态界面（对话 / 背包 / 商店 / 菜单）打开，
## 就暂停整棵场景树，关闭后恢复。这样各界面自己不需要关心暂停逻辑，
## 也不会出现"对话和商店同时开着、时间还在流逝"这类状态泄漏。

@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var inventory_ui: InventoryUi = %InventoryUi
@onready var shop_ui: ShopUi = %ShopUi
@onready var pause_menu: PauseMenu = %PauseMenu

var _modals: Array[Control] = []
## 组合根注入的玩家档案；转发给 Hud / ShopUi。
var _player_profile: PlayerProfile
## 组合根注入的时钟；转发给 Hud / ShopUi。
var _clock_state: GameDateClock
## 组合根注入的领域服务；转发给 Hud 等只读界面。
var _weather_service: WeatherService
var _relationship_service: RelationshipService
var _calendar_service: CalendarService


## 由 [Main] 在 UI 子树进入树之前调用；依赖会继续下发给各界面。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_player_profile = profile
	_clock_state = clock
	for child: Node in get_children():
		if child.has_method(&"bind_dependencies"):
			child.call(&"bind_dependencies", profile, clock)


## 由 [Main] 在 UI 子树进入树之前调用；领域服务继续下发给各界面。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_weather_service = weather
	_relationship_service = relationships
	_calendar_service = calendar
	for child: Node in get_children():
		if child.has_method(&"bind_services"):
			child.call(&"bind_services", weather, relationships, calendar)


func _ready() -> void:
	# 界面必须能在暂停时继续响应输入（否则暂停后就按不动了）。
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 组合根注入：界面层仍可使用 EventBus，但商店逻辑依赖由此显式传入。
	shop_ui.configure(_player_profile, Database, EventBus, _clock_state)

	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.inventory_toggle_requested.connect(_on_inventory_toggle)
	EventBus.pause_menu_toggle_requested.connect(_on_pause_menu_toggle)

	dialogue_box.finished.connect(_on_dialogue_finished)
	pause_menu.close_requested.connect(func() -> void: _close(pause_menu))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"open_menu"):
		return
	get_viewport().set_input_as_handled()

	# 对话只能用推进键结束，Esc 不打断它。
	if dialogue_box.visible:
		return
	if inventory_ui.visible:
		_on_inventory_toggle()
		return
	if shop_ui.visible:
		_close_shop()
		return
	_on_pause_menu_toggle()


# ---------------------------------------------------------------- 模态栈

func is_modal_open() -> bool:
	return not _modals.is_empty()


## 关闭所有模态界面。
##
## 场景切换、读档、回到标题界面时都应该调用它，
## 否则会出现"菜单跨场景残留、时间被永久暂停"这类难查的状态泄漏。
func close_all() -> void:
	dialogue_box.visible = false
	inventory_ui.close()
	shop_ui.close()
	pause_menu.close()
	_modals.clear()
	_sync_pause()


func _open(modal: Control) -> void:
	if _modals.has(modal):
		return
	_modals.append(modal)
	_sync_pause()


func _close(modal: Control) -> void:
	if not _modals.has(modal):
		return
	_modals.erase(modal)
	_sync_pause()


func _sync_pause() -> void:
	var paused := is_modal_open()
	get_tree().paused = paused
	EventBus.game_paused_changed.emit(paused)


# ---------------------------------------------------------------- 事件

func _on_dialogue_requested(dialogue: DialogueData) -> void:
	_open(dialogue_box)
	dialogue_box.open(dialogue)


func _on_dialogue_finished(_dialogue: DialogueData) -> void:
	_close(dialogue_box)


func _on_shop_requested(shop_id: StringName) -> void:
	var shop_data := Database.require_shop(shop_id)
	if shop_data == null:
		return
	_open(shop_ui)
	shop_ui.open(shop_data)
	EventBus.shop_opened.emit(shop_data)


func _close_shop() -> void:
	shop_ui.close()
	_close(shop_ui)
	EventBus.shop_closed.emit()


func _on_inventory_toggle() -> void:
	if inventory_ui.visible:
		inventory_ui.close()
		_close(inventory_ui)
		return
	_open(inventory_ui)
	inventory_ui.open()


func _on_pause_menu_toggle() -> void:
	if pause_menu.visible:
		pause_menu.close()
		_close(pause_menu)
		return
	_open(pause_menu)
	pause_menu.open()
