class_name MineElevatorUi
extends CanvasLayer
## 矿洞电梯的楼层选择界面（纯代码构建，不占一份场景）。
##
## 只列出"已经解锁的电梯层"——也就是玩家到达过的 5 的倍数层，外加地面。
## 打开时暂停场景树，选择后 [signal floor_selected] 把结果交回 [MineFloor]。

## 选择了某一层（1 表示地面）。
signal floor_selected(depth: int)

const LAYER: int = 40

var _root: Control
var _list: VBoxContainer
var _floors: VBoxContainer
var _title: Label


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## 打开界面；[param current] 当前层，[param deepest] 已解锁的最深电梯层。
func open(current: int, deepest: int) -> void:
	_title.text = Text.key(&"MINE_ELEVATOR_TITLE")
	for child: Node in _floors.get_children():
		child.queue_free()

	_add_floor(1, Text.key(&"MINE_SURFACE"), current)
	var top: int = maxi(deepest, MineRules.ELEVATOR_EVERY)
	var depth: int = MineRules.ELEVATOR_EVERY
	while depth <= top:
		_add_floor(depth, Text.format(&"MINE_FLOOR", {"n": depth}), current)
		depth += MineRules.ELEVATOR_EVERY

	visible = true
	get_tree().paused = true
	var first := _floors.get_child(0) as Button
	if first != null:
		first.grab_focus()


## 关闭界面并恢复时间。
func close() -> void:
	visible = false
	get_tree().paused = false


func _add_floor(depth: int, label: String, current: int) -> void:
	var button := Button.new()
	button.text = label + (Text.key(&"MINE_CURRENT") if depth == current else "")
	button.pressed.connect(_on_floor_pressed.bind(depth))
	_floors.add_child(button)


func _on_floor_pressed(depth: int) -> void:
	close()
	floor_selected.emit(depth)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	panel.add_child(margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 4)
	margin.add_child(_list)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(_title)

	var hint := Label.new()
	hint.text = Text.key(&"MINE_ELEVATOR_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(hint)

	_floors = VBoxContainer.new()
	_floors.add_theme_constant_override(&"separation", 4)
	_list.add_child(_floors)
