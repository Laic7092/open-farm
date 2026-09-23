class_name TouchControls
extends Control
## 触控控件层：左下角虚拟摇杆 + 右下角 A / B 动作键，Y（背包）单独钉在右上角。
##
## 世界模式：
## [br]- A：主操作（收获 / 送礼 / 交互 / 使用工具 / 钓鱼）
## [br]- B：菜单
## [br]- Y：背包（右上角，远离拇指的常用区）
## [br]- 摇杆推到底自动奔跑
##
## 切换手持物品不再占键位：直接点底部物品栏的格子选中（[HudItemBarView]）。
##
## 模态模式（背包 / 商店 / 对话 / 菜单等暂停场景树时）：
## [br]- 保留 A 确认、B 返回[b]与摇杆[/b]，只隐藏 Y
## [br]- A 注入 [code]ui_accept[/code]，B 注入 [code]ui_cancel[/code]
## [br]- 摇杆注入 [code]ui_left/right/up/down[/code]：触控没有方向键，模态导航全靠它
##
## 因此本层[b]不能[/b]在暂停时整层隐藏：那样模态里既没有触控键、也没有触控导航。
## 上下文切换时会统一释放连续动作与已按下的离散动作，并把按钮高亮复位。

## 摇杆方向要落到哪四个动作上（顺序固定，便于逐个释放）。
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"
]

## 奔跑动作：摇杆推到底自动触发（触控没有第二根手指去按 Shift）。
const RUN_ACTION: StringName = &"run"

## 模态导航：到达方向后首次自动重复的延迟（秒）；太短会因为一次推杆连跳好几格。
const NAV_REPEAT_DELAY: float = 0.35
## 之后每次自动重复的间隔（秒）。
const NAV_REPEAT_INTERVAL: float = 0.12

@onready var joystick: TouchStick = %Joystick
## A（下）：世界主操作；模态确认。
@onready var a_button: TouchButton = %AButton
## B（右）：世界菜单；模态返回。
@onready var b_button: TouchButton = %BButton
## Y（右上角）：背包。
@onready var y_button: TouchButton = %YButton
## A / B 缩放的宿主：围绕屏幕右下角点等比放大，才不会互相重叠。
@onready var action_pad: Control = %ActionPad
## 右上角独立动作键（Y / 背包）的宿主：钉右上角，放大只朝左下长。
@onready var top_pad: Control = %TopPad

## 是否处于触控模式（设置值）。
var _enabled: bool = false
## 当前是否被模态界面压住（暂停中）。
var _paused: bool = false
## 本层按下（且需要由本层松开）的连续动作。
var _injected: Dictionary[StringName, bool] = {}
## 本层送出过按下事件的离散动作。
var _held_actions: Dictionary[StringName, bool] = {}
## 当前 UI 缩放；由设置广播驱动，只作用于本层。
var _ui_scale: float = 1.0
## 显示安全区换算后的四周内边距（虚拟画布单位）。
var _safe: Vector4 = Vector4.ZERO
## 模态下已注入的导航动作（摇杆方向 → [code]ui_*[/code]）。
var _nav_actions: Dictionary[StringName, bool] = {}
## 距离下一次自动重复导航还剩多少秒。
var _nav_repeat: float = 0.0


## 方向 → 各 [code]move_*[/code] 动作的强度；零分量不入表（调用方据此释放该动作）。
static func action_strengths(direction: Vector2) -> Dictionary[StringName, float]:
	var strengths: Dictionary[StringName, float] = {}
	_add_strength(strengths, &"move_left", -direction.x)
	_add_strength(strengths, &"move_right", direction.x)
	_add_strength(strengths, &"move_up", -direction.y)
	_add_strength(strengths, &"move_down", direction.y)
	return strengths


## 摇杆方向 → 模态导航动作；只取主轴，避免一次推杆同时触发两个方向。
static func navigation_actions(direction: Vector2) -> Array[StringName]:
	var actions: Array[StringName] = []
	if direction.is_zero_approx():
		return actions
	if absf(direction.x) >= absf(direction.y):
		actions.append(&"ui_right" if direction.x > 0.0 else &"ui_left")
	elif direction.y > 0.0:
		actions.append(&"ui_down")
	else:
		actions.append(&"ui_up")
	return actions


func _ready() -> void:
	set_process(false)
	joystick.direction_changed.connect(set_stick)
	_bind_button(a_button)
	_bind_button(b_button)
	_bind_button(y_button)

	EventBus.ui.touch_controls_toggled.connect(_on_touch_controls_toggled)
	EventBus.ui.game_paused_changed.connect(_on_game_paused_changed)
	EventBus.ui.ui_scale_changed.connect(_apply_ui_scale)
	EventBus.ui.safe_insets_changed.connect(_on_safe_insets_changed)
	_layout()
	# pivot 依赖控件的 size，等布局完成后再套用存盘值。
	joystick.resized.connect(_refresh_ui_scale)
	action_pad.resized.connect(_refresh_ui_scale)
	top_pad.resized.connect(_refresh_ui_scale)
	apply_enabled(TouchSettings.is_enabled())
	_apply_ui_scale.call_deferred(UiSettings.scale())


## 切换触控模式；[param enabled] 为 false 时立刻释放所有注入的按键。
func apply_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_release_all()
	_sync_visible()
	_publish_insets()


func _on_safe_insets_changed(insets: Vector4) -> void:
	_safe = insets
	_layout()


## 按令牌把摇杆钉左下、A / B 钉右下、Y 钉右上，并让开安全区。
##
## 尺寸全部来自 [UiLayout]，场景里不写裸偏移；同一角点上的键围绕该角点等比放大。
func _layout() -> void:
	var stick := UiLayout.TOUCH_STICK_SIZE
	var pad := UiLayout.TOUCH_PAD_SIZE
	var a_size := UiLayout.TOUCH_A_SIZE
	var b_size := UiLayout.TOUCH_B_SIZE
	var y_size := UiLayout.TOUCH_Y_SIZE
	var left := UiLayout.TOUCH_PAD_MARGIN + UiLayout.edge_inset(_safe.x, UiLayout.EDGE_PADDING)
	var right := UiLayout.TOUCH_PAD_MARGIN + UiLayout.edge_inset(_safe.z, UiLayout.EDGE_PADDING)
	var bottom := UiLayout.TOUCH_PAD_MARGIN + _safe.w
	joystick.offset_left = left
	joystick.offset_right = left + stick
	joystick.offset_bottom = -bottom
	joystick.offset_top = joystick.offset_bottom - stick
	action_pad.offset_right = -right
	action_pad.offset_left = action_pad.offset_right - pad
	action_pad.offset_bottom = -bottom
	action_pad.offset_top = action_pad.offset_bottom - pad
	# 右上角 Y（背包）：横向与触控面板同档留白，纵向只让开上下安全区。
	var top := UiLayout.TOUCH_PAD_MARGIN + _safe.y
	top_pad.offset_right = -right
	top_pad.offset_left = top_pad.offset_right - y_size
	top_pad.offset_top = top
	top_pad.offset_bottom = top + y_size
	# A 最大、贴右下角；B 较小，堆在 A 上方、右对齐，中间留一个 GAP。
	var a_origin := Vector2(pad - a_size, pad - a_size)
	_place_button(y_button, Vector2.ZERO, y_size)
	_place_button(a_button, a_origin, a_size)
	_place_button(
		b_button, Vector2(pad - b_size, a_origin.y - UiLayout.GAP - b_size), b_size
	)
	_refresh_ui_scale()


func _place_button(button_node: Control, origin: Vector2, size: float) -> void:
	button_node.offset_left = origin.x
	button_node.offset_top = origin.y
	button_node.offset_right = origin.x + size
	button_node.offset_bottom = origin.y + size


## 触控层缩放：摇杆钉左下角、A / B 整体钉屏幕右下角、Y 钉右上角，放大只朝屏幕内侧长。
func _apply_ui_scale(value: float) -> void:
	_ui_scale = value
	_refresh_ui_scale()


## pivot 依赖控件尺寸；尺寸变化后重算，保证缩放始终绕屏幕角点。
func _refresh_ui_scale() -> void:
	var factor := Vector2(_ui_scale, _ui_scale)
	joystick.pivot_offset = Vector2(0.0, joystick.size.y)
	joystick.scale = factor
	action_pad.pivot_offset = action_pad.size
	action_pad.scale = factor
	top_pad.pivot_offset = Vector2(top_pad.size.x, 0.0)
	top_pad.scale = factor
	_publish_insets()


## 本层当前占用的左右两侧宽度（虚拟画布坐标）：模态界面据此给内容让位。
##
## 不是控件本身的 [member Control.size]——摇杆钉左下角、A / B 钉右下角，
## 放大只朝屏幕内侧长，所以要从各自角点算到屏幕边缘（含安全区 / 横向留白）。
func side_insets() -> Vector2:
	if not _enabled or joystick == null or action_pad == null:
		return Vector2.ZERO
	return Vector2(
		joystick.position.x + joystick.size.x * _ui_scale,
		absf(action_pad.offset_right) + action_pad.size.x * _ui_scale
	)


## 右上角独立键（Y / 背包）占用的边距：[code]x[/code] 从右边缘、[code]y[/code] 从顶边缘；
## 隐藏（模态 / 关触控）时为零。顶部内容据此避开右上角。
func top_insets() -> Vector2:
	if not _enabled or top_pad == null or y_button == null or not y_button.visible:
		return Vector2.ZERO
	return Vector2(
		absf(top_pad.offset_right) + top_pad.size.x * _ui_scale,
		top_pad.offset_top + top_pad.size.y * _ui_scale
	)


## 广播本层占用的边距：左右宽度（模态 / 对话框 / HUD 让位）与右上角占位（顶部提示避开）。
func _publish_insets() -> void:
	EventBus.ui.touch_insets_changed.emit(side_insets())
	EventBus.ui.touch_top_insets_changed.emit(top_insets())


## 摇杆方向 → 输入动作；静止请传 [constant Vector2.ZERO]。
##
## 模态里改为翻译成方向键（[method navigation_actions]）：世界移动被暂停，
## 但摇杆是这个模式下唯一的方向输入，界面导航还得靠它。
func set_stick(direction: Vector2) -> void:
	if not _enabled:
		direction = Vector2.ZERO
	if _paused:
		_set_navigation(direction)
		return
	var strengths := action_strengths(direction)
	for action: StringName in MOVE_ACTIONS:
		if strengths.has(action):
			_injected[action] = true
			Input.action_press(action, strengths[action])
		elif _injected.has(action):
			_injected.erase(action)
			Input.action_release(action)
	_set_continuous(RUN_ACTION, direction.length() >= TouchStick.RUN_THRESHOLD)


## 按下 / 松开一个离散动作（动作按钮用）。
func hold_action(action: StringName, pressed: bool) -> void:
	if action == &"":
		return
	if pressed:
		if _held_actions.has(action):
			return
		_held_actions[action] = true
	elif not _held_actions.erase(action):
		return
	_send_action_event(action, pressed)


func _on_touch_controls_toggled(enabled: bool) -> void:
	apply_enabled(enabled)


func _on_game_paused_changed(paused: bool) -> void:
	_paused = paused
	set_process(paused)
	_release_all()
	_sync_visible()
	# Y 在模态里隐藏，右上角占位随之归零，要让订阅者重排。
	_publish_insets()


func _sync_visible() -> void:
	visible = _enabled
	var world_controls: bool = _enabled and not _paused
	# 摇杆在模态里[b]不[/b]隐藏：模态方向导航只能靠它，没有物理方向键兜底。
	joystick.visible = _enabled
	y_button.visible = world_controls
	a_button.visible = _enabled
	b_button.visible = _enabled


## 释放本层注入过的所有输入。
##
## 界面切上下文 / 关掉触控时必须调用：注入的按键没有对应的物理按键兜底，
## 不回收就会永远停在按下状态。
func _release_all() -> void:
	_clear_navigation()
	for action: StringName in _injected:
		Input.action_release(action)
	_injected.clear()
	for action: StringName in _held_actions.keys():
		_send_action_event(action, false)
	_held_actions.clear()
	joystick.reset()
	a_button.reset_held()
	b_button.reset_held()
	y_button.reset_held()


## 模态导航：摇杆方向变化时切换注入的 [code]ui_*[/code] 动作。
##
## 一次方向只送一次按下事件（按下即生效）；按住由 [method _process] 自动重复。
func _set_navigation(direction: Vector2) -> void:
	var desired := navigation_actions(direction)
	var changed := false
	for action: StringName in _nav_actions.keys():
		if not desired.has(action):
			_nav_actions.erase(action)
			_send_action_event(action, false)
			changed = true
	for action: StringName in desired:
		if not _nav_actions.has(action):
			_nav_actions[action] = true
			_send_action_event(action, true)
			changed = true
	if changed:
		_nav_repeat = NAV_REPEAT_DELAY


## 松开所有导航动作（离开模态 / 关掉触控时必须调用）。
func _clear_navigation() -> void:
	for action: StringName in _nav_actions.keys():
		_send_action_event(action, false)
	_nav_actions.clear()
	_nav_repeat = 0.0


## 模态里按住摇杆要能连续走格：按固定间隔重发方向键按下事件。
func _process(delta: float) -> void:
	if _nav_actions.is_empty():
		return
	_nav_repeat -= delta
	if _nav_repeat > 0.0:
		return
	_nav_repeat = NAV_REPEAT_INTERVAL
	for action: StringName in _nav_actions:
		_send_action_event(action, true)


## 按下 / 松开的连续动作（[method Input.action_press] 那一类）。
func _set_continuous(action: StringName, pressed: bool) -> void:
	if pressed:
		_injected[action] = true
		Input.action_press(action)
	elif _injected.has(action):
		_injected.erase(action)
		Input.action_release(action)


func _bind_button(button: TouchButton) -> void:
	button.pressed.connect(func() -> void: hold_action(_action_for(button), true))
	button.released.connect(func() -> void: hold_action(_action_for(button), false))


## 当前上下文下，按钮应该注入哪个动作。
func _action_for(button: TouchButton) -> StringName:
	if _paused:
		if button == a_button:
			return &"ui_accept"
		if button == b_button:
			return &"ui_cancel"
		return &""
	if button == a_button:
		return &"primary_action"
	if button == b_button:
		return &"open_menu"
	if button == y_button:
		return &"open_inventory"
	return &""


func _send_action_event(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


static func _add_strength(
	into: Dictionary[StringName, float], action: StringName, value: float
) -> void:
	var strength: float = maxf(value, 0.0)
	if strength > 0.0:
		into[action] = strength
