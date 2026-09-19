class_name TouchControls
extends Control
## 触控控件层：左下角虚拟摇杆 + 右下角 ABXY 圆形动作键（外加一个菜单键）。
##
## 作用是把屏幕输入翻译成[b]既有动作名[/b]（[code]move_* / run / use_tool / interact …
## [/code]），于是摇杆和键盘走同一条输入通路：玩法代码、状态机、钓鱼蓄力都不用改一行。
##
## 键位按手柄习惯排：A 使用工具（最常用，放在拇指最顺的右下）、B 交互、
## X 换具、Y 背包，菜单（三条杠）单独放在左侧，不跟四个字母挤在一起。
## 文字提示写在系统菜单里（见 [PauseMenu]），因为圆里塞不下中文。
##
## 开 / 关由 [TouchSettings] 决定（系统菜单里的开关）；
## 任一模态界面打开时整层隐藏并释放所有按键，避免"在菜单里点了一下，
## 回到游戏人还在往前走"。释放必须走 [method _release_all]：
## 注入过的按键如果没人回收，会一直卡在按下状态。
##
## 注入方式分两类（[method Input.action_press] 单独一条不够用）：
## [br]- 每帧轮询的连续动作（[code]move_* / run[/code]）：[method Input.action_press]，
##   当场改状态，没有一帧延迟；
## [br]- 事件驱动的离散动作（[code]use_tool / interact / open_menu[/code] …）：
##   [method Input.parse_input_event] 送一条 [InputEventAction]——
##   只有它会被 [code]_unhandled_input()[/code] 里的处理器收到，
##   而 [method Input.action_press] 只改状态、不发事件。

## 摇杆方向要落到哪四个动作上（顺序固定，便于逐个释放）。
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down"
]

## 奔跑动作：摇杆推到底自动触发（触控没有第二根手指去按 Shift）。
const RUN_ACTION: StringName = &"run"

@onready var joystick: TouchStick = %Joystick
## A（下）：使用工具。最常用的动作放在拇指最顺的位置。
@onready var a_button: TouchButton = %AButton
## B（右）：交互 / 对话 / 收获。
@onready var b_button: TouchButton = %BButton
## X（左）：切换手持工具。
@onready var x_button: TouchButton = %XButton
## Y（上）：背包。
@onready var y_button: TouchButton = %YButton
## 菜单：放在字母键左侧，与手台的 Select 键同位。
@onready var menu_button: TouchButton = %MenuButton

## 由 [UiRoot] 注入：触控模式下把 HUD 左下角抬高，给摇杆让位。
var _hud: Hud
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
	_bind_button(a_button, &"use_tool")
	_bind_button(b_button, &"interact")
	_bind_button(x_button, &"tool_next")
	_bind_button(y_button, &"open_inventory")
	_bind_button(menu_button, &"open_menu")

	EventBus.ui.touch_controls_toggled.connect(_on_touch_controls_toggled)
	EventBus.ui.game_paused_changed.connect(_on_game_paused_changed)
	apply_enabled(TouchSettings.is_enabled())


## 注入 HUD：触控模式下 HUD 左下角要腾出摇杆的位置。
func bind_hud(hud: Hud) -> void:
	_hud = hud
	_sync_hud_layout()


## 切换触控模式；[param enabled] 为 false 时立刻释放所有注入的按键。
func apply_enabled(enabled: bool) -> void:
	_enabled = enabled
	_sync_hud_layout()
	_sync_visible()


## 摇杆方向 → 输入动作；静止请传 [constant Vector2.ZERO]。
func set_stick(direction: Vector2) -> void:
	var strengths := action_strengths(direction)
	for action: StringName in MOVE_ACTIONS:
		if strengths.has(action):
			_injected[action] = true
			Input.action_press(action, strengths[action])
		elif _injected.has(action):
			_injected.erase(action)
			Input.action_release(action)
	_set_continuous(RUN_ACTION, direction.length() >= TouchStick.RUN_THRESHOLD)


## 按下 / 松开一个事件驱动动作（动作按钮用）。
func hold_action(action: StringName, pressed: bool) -> void:
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
	_sync_visible()


func _sync_visible() -> void:
	var show := _enabled and not _paused
	if visible == show:
		return
	visible = show
	if not show:
		_release_all()


func _sync_hud_layout() -> void:
	if _hud != null:
		_hud.set_touch_layout(_enabled)


## 释放本层注入过的所有输入。
##
## 界面隐藏 / 关掉触控时必须调用：注入的按键没有对应的物理按键兜底，
## 不回收就会永远停在按下状态。
func _release_all() -> void:
	for action: StringName in _injected:
		Input.action_release(action)
	_injected.clear()
	for action: StringName in _held_actions.keys():
		_send_action_event(action, false)
	_held_actions.clear()
	joystick.reset()


## 按下 / 松开的连续动作（[method Input.action_press] 那一类）。
func _set_continuous(action: StringName, pressed: bool) -> void:
	if pressed:
		_injected[action] = true
		Input.action_press(action)
	elif _injected.has(action):
		_injected.erase(action)
		Input.action_release(action)


func _bind_button(button: TouchButton, action: StringName) -> void:
	button.pressed.connect(func() -> void: hold_action(action, true))
	button.released.connect(func() -> void: hold_action(action, false))


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
