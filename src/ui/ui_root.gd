class_name UiRoot
extends CanvasLayer
## UI 总入口。
##
## 所有界面都挂在这一层下面，[b]不随世界场景销毁[/b]——
## 因为世界场景是在 [Main] 的 WorldHost 下换的，UI 层是它的兄弟节点。
##
## 本节点只做两件事：
## - 把组合根依赖下发给各界面；
## - 路由全局输入到“当前上下文”。
##
## 模态栈与 [SceneTree.paused] 由 [UiModalHost] 统一持有；具体界面的关闭逻辑由
## [UiModal] 自己负责，因此新增模态不需要再改本文件里的模态分支。

@onready var modal_host: UiModalHost = %ModalHost
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
## 组合根注入的“当前背包”提供者；界面只读它，不按分组找玩家。
var _inventory_provider: Callable
## UI / 交互域事件对象；与 [code]EventBus.ui[/code] 是同一实例，常驻订阅者共用一份。
var events: UiEvents = EventBus.ui
## 用来在退出时断开窗口尺寸信号。
var _window: Window


## 由 [Main] 在 UI 子树进入树之前调用；依赖会继续下发给各界面。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
    _player_profile = profile
    _clock_state = clock
    _dispatch(&"bind_dependencies", [profile, clock])


## 由 [Main] 在 UI 子树进入树之前调用；领域服务继续下发给各界面。
func bind_services(
    weather: WeatherService,
    relationships: RelationshipService,
    calendar: CalendarService
) -> void:
    _weather_service = weather
    _relationship_service = relationships
    _calendar_service = calendar
    _dispatch(&"bind_services", [weather, relationships, calendar])


## 由 [Main] 注入本局进度状态（图鉴 / 委托）；下发给需要它们的界面。
func bind_progress(museum: MuseumState, commissions: CommissionState) -> void:
    _dispatch(&"bind_progress", [museum, commissions])


## 由 [Main] 注入委托单元；下发给需要它的界面。
func bind_commission(commission: Commission) -> void:
    _dispatch(&"bind_commission", [commission])


## 由 [Main] 注入料理单元；下发给料理台界面。
func bind_cooking(cooking: Cooking) -> void:
    _dispatch(&"bind_cooking", [cooking])


## 由 [Main] 注入节日小游戏单元；下发给品评会界面。
func bind_festival_game(game: FestivalGame) -> void:
    _dispatch(&"bind_festival_game", [game])


## 由 [Main] 注入长期村庄目标单元；下发给目标板界面。
func bind_goals(goals: VillageGoals) -> void:
    _dispatch(&"bind_goals", [goals])


## 由 [Main] 注入“当前钓鱼单元”的提供者；下发给需要它的界面。
func bind_fishing(provider: Callable) -> void:
    _dispatch(&"bind_fishing", [provider])


## 由 [Main] 注入“当前物品栏”的提供者；下发给需要它的界面（HUD 底部的物品栏）。
func bind_item_bar(provider: Callable) -> void:
    _dispatch(&"bind_item_bar", [provider])


## 由 [Main] 注入“当前背包”提供者；背包 / 商店界面据此读写当前世界的背包。
func bind_inventory_provider(provider: Callable) -> void:
    _inventory_provider = provider
    _dispatch(&"bind_inventory_provider", [provider])


func _ready() -> void:
    # 界面必须能在暂停时继续响应输入（否则暂停后就按不动了）。
    process_mode = Node.PROCESS_MODE_ALWAYS
    sfx = SfxPlayer.attach(self)
    modal_host.pause_changed.connect(_on_modal_pause_changed)

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
    # 世界切换是跨域事件；UI 只在这里统一熔断，避免模态跨图残留。
    EventBus.scene_transition_started.connect(_on_scene_transition_started)

    dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
    pause_menu.close_requested.connect(_on_pause_menu_close_requested)

    # 窗口尺寸 / 安全区是全局显示事实，由本层统一换算后广播给贴边界面。
    _window = get_window()
    if _window != null and not _window.size_changed.is_connected(_refresh_safe_insets):
        _window.size_changed.connect(_refresh_safe_insets)
    _refresh_safe_insets.call_deferred()


func _exit_tree() -> void:
    if _window != null and _window.size_changed.is_connected(_refresh_safe_insets):
        _window.size_changed.disconnect(_refresh_safe_insets)
    _window = null
    if EventBus.scene_transition_started.is_connected(_on_scene_transition_started):
        EventBus.scene_transition_started.disconnect(_on_scene_transition_started)


## 把显示安全区（刘海 / 圆角）换算成虚拟画布边距并广播。
##
## headless（测试 / CI）没有真实安全区，一律为零；桌面窗口也通常得到零向量。
func _refresh_safe_insets() -> void:
    if DisplayServer.get_name() == "headless":
        EventBus.ui.safe_insets_changed.emit(Vector4.ZERO)
        return
    var window := _window
    if window == null:
        EventBus.ui.safe_insets_changed.emit(Vector4.ZERO)
        return
    var safe := DisplayServer.get_display_safe_area()
    var viewport := get_viewport().get_visible_rect().size
    EventBus.ui.safe_insets_changed.emit(UiLayout.safe_insets(safe, window.size, viewport))


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

    # 世界里的菜单键与界面里的取消键共用同一个物理键（Esc / 触控 B）。
    var menu_pressed := (
        event.is_action_pressed(&"open_menu") or event.is_action_pressed(&"ui_cancel")
    )
    if not menu_pressed:
        return
    get_viewport().set_input_as_handled()

    # 对话只能用推进键结束，Esc 不打断它。
    if dialogue_box.visible:
        return

    var top := modal_host.top()
    if top != null:
        top.request_cancel()
        return
    _on_pause_menu_toggle()


# ---------------------------------------------------------------- 模态栈

func is_modal_open() -> bool:
    return modal_host.has_modal()


## 关闭所有模态界面。
##
## 场景切换、读档、回到标题界面时都应该调用它，
## 否则会出现“菜单跨场景残留、时间被永久暂停”这类难查的状态泄漏。
func close_all() -> void:
    modal_host.close_all()


## 打开一个已经配置好的模态（只负责入栈，不调用具体 open）。
func _open(modal: UiModal) -> void:
    modal_host.open(modal)


## 请求关闭一个模态；真正隐藏由具体界面自己的 [method UiModal.close] 完成。
func _close(modal: UiModal) -> void:
    modal_host.close(modal)


## 先打开具体界面，确认可见后才入栈。
##
## 这样依赖未注入、界面拒绝打开时不会留下“看不见的模态”把游戏永久暂停。
func _open_modal(modal: UiModal, opener: Callable) -> bool:
    if modal == null or not opener.is_valid():
        return false
    opener.call()
    if not modal.visible:
        return false
    modal_host.open(modal)
    return true


func _on_modal_pause_changed(paused: bool) -> void:
    EventBus.ui.game_paused_changed.emit(paused)
    # 打开模态（暂停）= 向上滑音；关闭 = 向下滑音。
    if sfx != null:
        sfx.play(AudioCatalog.SFX_UI_OPEN if paused else AudioCatalog.SFX_UI_CLOSE, 1.0, -2.0)


func _on_scene_transition_started(_target: StringName) -> void:
    close_all()


## 把注入原样转给实现了该方法的子节点。
func _dispatch(method: StringName, args: Array) -> void:
    for child: Node in get_children():
        if child.has_method(method):
            child.callv(method, args)


# ---------------------------------------------------------------- 事件

func _on_dialogue_requested(dialogue: DialogueData) -> void:
    # 空对话直接结束，不进入模态栈。
    if dialogue == null or dialogue.is_empty():
        dialogue_box.open(dialogue)
        return
    _open_modal(dialogue_box, Callable(dialogue_box, &"open").bind(dialogue))


## 选项本身不含副作用；转发到事件总线，由发起对话的 [Npc] 结算。
func _on_dialogue_choice_selected(
    dialogue: DialogueData, choice: DialogueChoice
) -> void:
    EventBus.ui.dialogue_choice_made.emit(dialogue, choice)


func _on_shop_requested(shop_id: StringName) -> void:
    var shop_data := Database.require_shop(shop_id)
    if shop_data == null:
        return
    if _open_modal(shop_ui, Callable(shop_ui, &"open").bind(shop_data)):
        EventBus.ui.shop_opened.emit(shop_data)


func _on_museum_requested() -> void:
    if museum_ui.visible:
        return
    _open_modal(museum_ui, Callable(museum_ui, &"open"))


func _on_commission_requested() -> void:
    if commission_ui.visible:
        return
    _open_modal(commission_ui, Callable(commission_ui, &"open"))


func _on_cooking_requested() -> void:
    if cooking_ui.visible:
        return
    _open_modal(cooking_ui, Callable(cooking_ui, &"open"))


func _on_festival_game_requested(festival_id: StringName) -> void:
    if festival_game_ui.visible:
        return
    _open_modal(
        festival_game_ui, Callable(festival_game_ui, &"open").bind(festival_id)
    )


func _on_village_goals_requested() -> void:
    if village_goal_ui.visible:
        return
    _open_modal(village_goal_ui, Callable(village_goal_ui, &"open"))


func _on_inventory_toggle() -> void:
    if is_modal_open() and not inventory_ui.visible:
        return
    if inventory_ui.visible:
        inventory_ui.close()
        return
    _open_modal(inventory_ui, Callable(inventory_ui, &"open"))


func _on_pause_menu_toggle() -> void:
    if pause_menu.visible:
        pause_menu.close()
        return
    if _open_modal(pause_menu, Callable(pause_menu, &"open")):
        EventBus.ui.pause_menu_toggled.emit(true)


## 菜单内“继续”：先关面板再出栈（与 Esc / 触控 B 走同一条关闭路径）。
##
## [method close] 会触发 [UiModal.closed]，宿主据此出栈；漏掉界面自身的 close
## 就会出现“游戏已恢复、菜单还贴在屏幕上”。
func _on_pause_menu_close_requested() -> void:
    pause_menu.close()
