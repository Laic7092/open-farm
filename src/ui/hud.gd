class_name Hud
extends Control
## 常驻 HUD 的容器。
##
## 它[b]只负责组装[/b]：左上角状态卡（日期 / 时间 / 金钱 / 体力）与底部物品栏
## 各由自己的小视图（[HudTimeView] / [HudPlayerView] / [HudItemBarView]）
## 订阅自己域的信号并渲染，容器不认识它们的状态，也不替它们保存一份。
##
## 交互提示与浮动提示是 UI 域自己的东西，所以留在这里。
##
## 底部常驻物品栏只是背包前几格的[b]快捷访问视图[/b]，不存放任何道具；
## 工具与种子都放在背包里。Q / R 在装有可用道具的格子之间切换，
## 触控下点物品栏格子选中；空闲后它会自动缩小（见 [HudItemBarView]）。

## 浮动提示停留时长（秒）。
const TOAST_DURATION: float = 2.2
## 专属音效之后这段时间内的通用通知音会被抑制，避免"一个动作两声"（毫秒）。
const NOTIFY_SUPPRESS_MS: int = 140
## 这些通知意味着"没做成"，用低沉的失败音。
const NEGATIVE_NOTIFICATIONS: Array[StringName] = [
	&"NOTIFY_NOTHING_TO_SHIP",
	&"NOTIFY_NO_FEED",
	&"NOTIFY_LOAD_FAILED",
]

@onready var status_panel: PanelContainer = $StatusPanel
@onready var inventory_bar: HBoxContainer = %InventoryBar
## 顶部提示行（浮动提示 + 交互提示）；两块一起缩放，行距才不会在放大时挤到一起。
@onready var top_hints: VBoxContainer = %TopHints
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel
@onready var stamina_row: HBoxContainer = %StaminaRow
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var divider: Panel = %Divider

var _toast_tween: Tween
## 本界面自己的音效播放器：通知音由显示通知的界面发出。
var sfx: SfxPlayer
## 当前 UI 缩放（顶部提示行按它缩放）。
var _ui_scale: float = 1.0
## 右上角独立键占用的边距（从右 / 从上）；无该键时为零。
var _touch_top: Vector2 = Vector2.ZERO
## 显示安全区换算后的四周内边距（虚拟画布单位）。
var _safe: Vector4 = Vector4.ZERO


## 由 [UiRoot] 转发的组合根依赖；继续下发给各小视图。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_dispatch(&"bind_dependencies", [profile, clock])


## 由 [UiRoot] 转发的领域服务；继续下发给各小视图。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_dispatch(&"bind_services", [weather, relationships, calendar])


## 由 [UiRoot] 转发的"当前物品栏"提供者；下发给物品栏视图。
func bind_item_bar(provider: Callable) -> void:
	_dispatch(&"bind_item_bar", [provider])


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	EventBus.ui.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.ui.notification_requested.connect(_on_notification)
	EventBus.ui.ui_scale_changed.connect(_apply_ui_scale)
	EventBus.ui.touch_top_insets_changed.connect(_on_touch_top_insets_changed)
	EventBus.ui.safe_insets_changed.connect(_on_safe_insets_changed)
	toast_label.modulate.a = 0.0
	prompt_label.text = ""
	stamina_bar.custom_minimum_size = UiLayout.BAR_SIZE
	divider.custom_minimum_size = Vector2(0.0, UiLayout.DIVIDER_HEIGHT)
	resized.connect(_apply_layout)
	status_panel.resized.connect(_apply_layout)
	_apply_layout()
	# 顶部提示行的 pivot 要等布局拿到 size 才能算。
	top_hints.resized.connect(_refresh_ui_scale_pivots)
	_apply_ui_scale.call_deferred(UiSettings.scale())


func _on_touch_top_insets_changed(insets: Vector2) -> void:
	_touch_top = insets
	_apply_layout()


func _on_safe_insets_changed(insets: Vector4) -> void:
	_safe = insets
	_apply_layout()


## HUD 左右留白：显示安全区或默认值（与触控面板同档）。
func _side_padding() -> Vector2:
	return Vector2(
		UiLayout.edge_inset(_safe.x, UiLayout.EDGE_PADDING),
		UiLayout.edge_inset(_safe.z, UiLayout.EDGE_PADDING)
	)


## 按视口与安全区摆好三块常驻 UI。
##
## 触发源是窗口尺寸 / 安全区变化；[method UiLayout.is_compact] 决定窄高比下是否隐藏
## 次要信息（顶部提示行），避免与左上状态卡重叠。
func _apply_layout() -> void:
	# 窄屏只收起次要数值（体力条），交互提示必须保留。
	var compact := UiLayout.is_compact(size)
	stamina_row.visible = not compact
	# 左右留白与触控面板同档：安全区或默认值。
	var pad := _side_padding()
	status_panel.position = UiLayout.HUD_STATUS_MARGIN + Vector2(pad.x, _safe.y)
	# 提示行铺满整宽（左右锚点 0/1），长提示居中也不会压到状态卡。
	top_hints.anchor_left = 0.0
	top_hints.anchor_right = 1.0
	top_hints.offset_left = UiLayout.HUD_HINTS_SIDE + pad.x
	top_hints.offset_right = -(UiLayout.HUD_HINTS_SIDE + pad.y)
	# 提示行放到状态卡下方，避免长提示 / 浮动提示压到日期与金钱上。
	var status_bottom := status_panel.position.y + status_panel.size.y * _ui_scale
	# 右上角 Y 键占了顶边一段：提示行落到它下方，避免长提示压到按键上。
	top_hints.offset_top = maxf(
		maxf(UiLayout.HUD_HINTS_TOP + _safe.y, status_bottom + UiLayout.GAP),
		_touch_top.y + UiLayout.GAP
	)
	top_hints.offset_bottom = top_hints.offset_top
	# 物品栏自己管缩放与避让（见 [HudItemBarView]）：这里只把它钉在底边中点。
	inventory_bar.offset_left = 0.0
	inventory_bar.offset_right = 0.0
	inventory_bar.offset_bottom = -(UiLayout.HUD_BAR_BOTTOM + _safe.w)
	inventory_bar.offset_top = inventory_bar.offset_bottom
	_refresh_ui_scale_pivots()


## 常驻 UI 缩放：左上状态卡钉左上角；顶部提示钉顶边中点（朝下长），
## 放大只朝屏幕内侧长，不会被推出画面。物品栏缩放由 [HudItemBarView] 自管。
func _apply_ui_scale(value: float) -> void:
	_ui_scale = value
	var factor := Vector2(value, value)
	status_panel.pivot_offset = UiLayout.grow_pivot(Vector2.ZERO, status_panel.size)
	status_panel.scale = factor
	top_hints.scale = factor
	_apply_layout()


## 顶部提示重算顶边中点。
func _refresh_ui_scale_pivots() -> void:
	top_hints.pivot_offset = UiLayout.grow_pivot(Vector2(0.5, 0.0), top_hints.size)


## 把注入原样转给实现了该方法的子视图；视图自己决定要不要读、什么时候读。
func _dispatch(method: StringName, args: Array) -> void:
	var container := get_node_or_null(^"Views")
	if container == null:
		return
	for view: Node in container.get_children():
		if view.has_method(method):
			view.callv(method, args)


func _on_prompt_changed(prompt_key: StringName) -> void:
	prompt_label.text = Text.key(prompt_key)


func _on_notification(text_key: StringName, args: Dictionary) -> void:
	var message := Text.format(text_key, args)
	if message.is_empty():
		return

	toast_label.text = message

	if sfx != null and AudioBus.since_last_sfx_ms() >= NOTIFY_SUPPRESS_MS:
		if NEGATIVE_NOTIFICATIONS.has(text_key):
			sfx.play(AudioCatalog.SFX_ERROR, 1.0, -2.0)
		else:
			sfx.play(AudioCatalog.SFX_NOTIFY, 1.0, -3.0)

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)
