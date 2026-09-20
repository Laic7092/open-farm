class_name TouchControls
extends Control
## 触控控件层：左下角虚拟摇杆 + 右下角 ABXY 四个动作键。
##
## 世界模式：
## [br]- A：主操作（收获 / 送礼 / 交互 / 使用工具 / 钓鱼）
## [br]- B：菜单
## [br]- X：切换手持物品
## [br]- Y：背包
## [br]- 摇杆推到底自动奔跑
##
## 模态模式（背包 / 商店 / 对话 / 菜单等暂停场景树时）：
## [br]- 只保留 A 确认、B 返回，隐藏摇杆与 X / Y
## [br]- A 注入 [code]ui_accept[/code]，B 注入 [code]ui_cancel[/code]
##
## 因此本层[b]不能[/b]在暂停时整层隐藏：那样模态里就没有触控键可用了。
## 上下文切换时会统一释放连续动作与已按下的离散动作，并把按钮高亮复位。

## 摇杆方向要落到哪四个动作上（顺序固定，便于逐个释放）。
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"
]

## 奔跑动作：摇杆推到底自动触发（触控没有第二根手指去按 Shift）。
const RUN_ACTION: StringName = &"run"

@onready var joystick: TouchStick = %Joystick
## A（下）：世界主操作；模态确认。
@onready var a_button: TouchButton = %AButton
## B（右）：世界菜单；模态返回。
@onready var b_button: TouchButton = %BButton
## X（左）：切换手持物品。
@onready var x_button: TouchButton = %XButton
## Y（上）：背包。
@onready var y_button: TouchButton = %YButton

## 是否处于触控模式（设置值）。
var _enabled: bool = false
## 当前是否被模态界面压住（暂停中）。
var _paused: bool = false
## 本层按下（且需要由本层松开）的连续动作。
var _injected: Dictionary[StringName, bool] = {}
## 本层送出过按下事件的离散动作。
var _held_actions: Dictionary[StringName, bool] = {}


## 方向 → 各 [code]move_*[/code] 动作的强度；零分量不入表（调用方据此释放该动作）。
static func action_strengths(direction: Vector2) -> Dictionary[StringName, float]:
	var strengths: Dictionary[StringName, float] = {}
	_add_strength(strengths, &"move_left", -direction.x)
	_add_strength(strengths, &"move_right", direction.x)
	_add_strength(strengths, &"move_up", -direction.y)
	_add_strength(strengths, &"move_down", direction.y)
	return strengths


func _ready() -> void:
	joystick.direction_changed.connect(set_stick)
	_bind_button(a_button)
	_bind_button(b_button)
	_bind_button(x_button)
	_bind_button(y_button)

	EventBus.ui.touch_controls_toggled.connect(_on_touch_controls_toggled)
	EventBus.ui.game_paused_changed.connect(_on_game_paused_changed)
	apply_enabled(TouchSettings.is_enabled())


## 切换触控模式；[param enabled] 为 false 时立刻释放所有注入的按键。
func apply_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_release_all()
	_sync_visible()


## 摇杆方向 → 输入动作；静止请传 [constant Vector2.ZERO]。
func set_stick(direction: Vector2) -> void:
	if not _enabled or _paused:
		direction = Vector2.ZERO
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
	_release_all()
	_sync_visible()


func _sync_visible() -> void:
	visible = _enabled
	var world_controls: bool = _enabled and not _paused
	joystick.visible = world_controls
	x_button.visible = world_controls
	y_button.visible = world_controls
	a_button.visible = _enabled
	b_button.visible = _enabled


## 释放本层注入过的所有输入。
##
## 界面切上下文 / 关掉触控时必须调用：注入的按键没有对应的物理按键兜底，
## 不回收就会永远停在按下状态。
func _release_all() -> void:
	for action: StringName in _injected:
		Input.action_release(action)
	_injected.clear()
	for action: StringName in _held_actions.keys():
		_send_action_event(action, false)
	_held_actions.clear()
	joystick.reset()
	a_button.reset_held()
	b_button.reset_held()
	x_button.reset_held()
	y_button.reset_held()


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
	if button == x_button:
		return &"tool_next"
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
