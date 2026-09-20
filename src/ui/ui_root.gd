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
@onready var museum_ui: MuseumUi = %MuseumUi
@onready var commission_ui: CommissionUi = %CommissionUi
@onready var cooking_ui: CookingUi = %CookingUi
@onready var festival_game_ui: FestivalGameUi = %FestivalGameUi
@onready var village_goal_ui: VillageGoalUi = %VillageGoalUi
@onready var pause_menu: PauseMenu = %PauseMenu
@onready var fishing_ui: FishingUi = %FishingUi
@onready var hud: Hud = %Hud
@onready var touch_controls: TouchControls = %TouchControls

var _modals: Array[Control] = []
## 本界面根节点的音效播放器（模态开合声）。
var sfx: SfxPlayer
## 组合根注入的玩家档案；转发给 Hud / ShopUi。
var _player_profile: PlayerProfile
## 组合根注入的时钟；转发给 Hud / ShopUi。
var _clock_state: GameDateClock
## 组合根注入的领域服务；转发给 Hud 等只读界面。
var _weather_service: WeatherService
var _relationship_service: RelationshipService
var _calendar_service: CalendarService
## UI / 交互域事件对象；与 [code]EventBus.ui[/code] 是同一实例，常驻订阅者共用一份。
var events: UiEvents = EventBus.ui


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


## 由 [Main] 注入本局进度状态（图鉴 / 委托）；下发给需要它们的界面。
func bind_progress(museum: MuseumState, commissions: CommissionState) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_progress"):
			child.call(&"bind_progress", museum, commissions)


## 由 [Main] 注入委托单元；下发给需要它的界面。
func bind_commission(commission: Commission) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_commission"):
			child.call(&"bind_commission", commission)


## 由 [Main] 注入料理单元；下发给料理台界面。
func bind_cooking(cooking: Cooking) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_cooking"):
			child.call(&"bind_cooking", cooking)


## 由 [Main] 注入节日小游戏单元；下发给品评会界面。
func bind_festival_game(game: FestivalGame) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_festival_game"):
			child.call(&"bind_festival_game", game)


## 由 [Main] 注入长期村庄目标单元；下发给目标板界面。
func bind_goals(goals: VillageGoals) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_goals"):
			child.call(&"bind_goals", goals)


## 由 [Main] 注入"当前钓鱼单元"的提供者；下发给需要它的界面。
func bind_fishing(provider: Callable) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_fishing"):
			child.call(&"bind_fishing", provider)


## 由 [Main] 注入"当前物品栏"的提供者；下发给需要它的界面（HUD 底部的物品栏）。
func bind_item_bar(provider: Callable) -> void:
	for child: Node in get_children():
		if child.has_method(&"bind_item_bar"):
			child.call(&"bind_item_bar", provider)


func _ready() -> void:
	# 界面必须能在暂停时继续响应输入（否则暂停后就按不动了）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = SfxPlayer.attach(self)

	# 组合根注入：界面层仍可使用 EventBus，但商店逻辑依赖由此显式传入。
	shop_ui.configure(_player_profile, Database, EventBus, _clock_state)

	EventBus.ui.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.ui.shop_requested.connect(_on_shop_requested)
	EventBus.ui.museum_requested.connect(_on_museum_requested)
	EventBus.ui.commission_requested.connect(_on_commission_requested)
	EventBus.ui.cooking_requested.connect(_on_cooking_requested)
	EventBus.ui.festival_game_requested.connect(_on_festival_game_requested)
	EventBus.ui.village_goals_requested.connect(_on_village_goals_requested)
	EventBus.ui.inventory_toggle_requested.connect(_on_inventory_toggle)
	EventBus.ui.pause_menu_toggle_requested.connect(_on_pause_menu_toggle)

	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
	pause_menu.close_requested.connect(func() -> void: _close(pause_menu))


func _unhandled_input(event: InputEvent) -> void:
	# 背包 / 菜单都在本层处理：即使模态已经暂停场景树，本节点仍能收到输入。
	if event.is_action_pressed(&"open_inventory"):
		get_viewport().set_input_as_handled()
		# 对话不能被背包打断；其他模态也不允许再叠一层背包。
		if dialogue_box.visible:
			return
		if is_modal_open() and not inventory_ui.visible:
			return
		_on_inventory_toggle()
		return

	# 世界里的菜单键与界面里的取消键共用同一个物理键（Esc / 触控 B），
	# 但进入这里后都按“关闭当前模态，没有模态就开菜单”处理。
	var menu_pressed := (
		event.is_action_pressed(&"open_menu") or event.is_action_pressed(&"ui_cancel")
	)
	if not menu_pressed:
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
	if museum_ui.visible:
		museum_ui.close()
		_close(museum_ui)
		return
	if commission_ui.visible:
		commission_ui.close()
		_close(commission_ui)
		return
	if cooking_ui.visible:
		cooking_ui.close()
		_close(cooking_ui)
		return
	if festival_game_ui.visible:
		festival_game_ui.close()
		_close(festival_game_ui)
		return
	if village_goal_ui.visible:
		village_goal_ui.close()
		_close(village_goal_ui)
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
	museum_ui.close()
	commission_ui.close()
	cooking_ui.close()
	festival_game_ui.close()
	village_goal_ui.close()
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
	EventBus.ui.game_paused_changed.emit(paused)
	# 打开模态（暂停）= 向上滑音；关闭 = 向下滑音。
	if sfx != null:
		sfx.play(AudioCatalog.SFX_UI_OPEN if paused else AudioCatalog.SFX_UI_CLOSE, 1.0, -2.0)


# ---------------------------------------------------------------- 事件

func _on_dialogue_requested(dialogue: DialogueData) -> void:
	_open(dialogue_box)
	dialogue_box.open(dialogue)


func _on_dialogue_finished(_dialogue: DialogueData) -> void:
	_close(dialogue_box)


## 选项本身不含副作用；转发到事件总线，由发起对话的 [Npc] 结算。
func _on_dialogue_choice_selected(
	dialogue: DialogueData, choice: DialogueChoice
) -> void:
	EventBus.ui.dialogue_choice_made.emit(dialogue, choice)


func _on_shop_requested(shop_id: StringName) -> void:
	var shop_data := Database.require_shop(shop_id)
	if shop_data == null:
		return
	_open(shop_ui)
	shop_ui.open(shop_data)
	EventBus.ui.shop_opened.emit(shop_data)


func _on_museum_requested() -> void:
	if museum_ui.visible:
		return
	_open(museum_ui)
	museum_ui.open()


func _on_commission_requested() -> void:
	if commission_ui.visible:
		return
	_open(commission_ui)
	commission_ui.open()


func _on_cooking_requested() -> void:
	if cooking_ui.visible:
		return
	_open(cooking_ui)
	cooking_ui.open()


func _on_festival_game_requested(festival_id: StringName) -> void:
	if festival_game_ui.visible:
		return
	_open(festival_game_ui)
	festival_game_ui.open(festival_id)


func _on_village_goals_requested() -> void:
	if village_goal_ui.visible:
		return
	_open(village_goal_ui)
	village_goal_ui.open()


func _close_shop() -> void:
	shop_ui.close()
	_close(shop_ui)
	EventBus.ui.shop_closed.emit()


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
