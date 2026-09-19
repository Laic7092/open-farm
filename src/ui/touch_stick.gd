class_name TouchStick
extends Control
## 屏幕虚拟摇杆：把手指（触控模式下的鼠标）位置翻译成一个归一化方向向量。
##
## 不叫 [code]VirtualJoystick[/code]：那是 Godot 4.5 起的内建节点，重名会直接编译不过。
##
## 只做"位置 → 方向"这一件事，不碰 [Input]：方向交给 [TouchControls] 统一翻译成动作，
## 于是"界面被关掉时要释放哪些按键"只有一个地方需要维护，
## 也让它能脱离场景单独测（[method direction_of] 是纯函数）。
##
## 采用[b]固定底座[/b]：底座不动，触点落在底座外的部分按半径截断，
## 于是在控件覆盖的角落里蹭一下就能立刻得到满偏方向，不用先摸到中心。
## 控件的矩形比底座半径大一圈（[constant TOUCH_MARGIN]），拇指贴边也能操作。

## 方向变化（已含死区与截断）；[param direction] 长度 0~1，静止时为零向量。
signal direction_changed(direction: Vector2)

## 底座半径占控件短边的比例：控件越大，底座越小、可擦边操作的范围越大。
const TOUCH_MARGIN: float = 1.5
## 死区（占半径比例）：小于它的抖动一律当没动，避免站着微微飘。
const DEADZONE: float = 0.15
## 推到这个长度视为奔跑；与 [TouchControls] 的 run 注入共用。
const RUN_THRESHOLD: float = 0.9
## 摇杆头半径占底座半径的比例。
const KNOB_RATIO: float = 0.42

## 当前方向；静止（含未触摸）时为零向量。
var direction: Vector2 = Vector2.ZERO

## 正在操作本摇杆的手指 / 鼠标（-1 表示空闲）。
var _pointer_index: int = -1


## 手指偏移 → 方向：死区内为零，超出半径按长度 1 截断。
static func direction_of(
	offset: Vector2, radius: float, deadzone: float = DEADZONE
) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var length: float = offset.length()
	if length <= radius * deadzone:
		return Vector2.ZERO
	return offset.normalized() * minf(length / radius, 1.0)


## 当前底座半径（随控件尺寸变化）。
func base_radius() -> float:
	return minf(size.x, size.y) * 0.5 / TOUCH_MARGIN


## 放开摇杆：清空方向并忘掉正在操作的手指（界面隐藏 / 被暂停时调用）。
func reset() -> void:
	_pointer_index = -1
	_set_direction(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_handle_press(touch.index, touch.position, touch.pressed)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _pointer_index:
			_set_from_position(drag.position)
	elif PointerInput.accepts_mouse():
		# 桌面只有鼠标：按键按下 / 拖动也当成"一根手指"，方便调试与网页版。
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_LEFT:
				_handle_press(0, button.position, button.pressed)
		elif event is InputEventMouseMotion and _pointer_index >= 0:
			_set_from_position((event as InputEventMouseMotion).position)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = base_radius()
	if radius <= 0.0:
		return
	var active: bool = _pointer_index >= 0
	draw_circle(center, radius, Color(ArtPalette.UI_PANEL_DARK, 0.5 if active else 0.35))
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		32,
		Color(ArtPalette.UI_PANEL_LIGHT, 0.7 if active else 0.45),
		2.0,
		false
	)
	var knob_color := Color(ArtPalette.UI_GOLD, 0.75 if active else 0.45)
	draw_circle(center + direction * radius, radius * KNOB_RATIO, knob_color)


func _handle_press(index: int, position: Vector2, pressed: bool) -> void:
	if not pressed:
		if index == _pointer_index:
			reset()
		return
	# 已经有手指占着摇杆：后来的手指不抢，避免多指操作时方向乱跳。
	if _pointer_index >= 0:
		return
	_pointer_index = index
	_set_from_position(position)


func _set_from_position(position: Vector2) -> void:
	_set_direction(direction_of(position - size * 0.5, base_radius()))


func _set_direction(value: Vector2) -> void:
	if value.is_equal_approx(direction):
		return
	direction = value
	queue_redraw()
	direction_changed.emit(direction)
