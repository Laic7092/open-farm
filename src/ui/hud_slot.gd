class_name HudSlot
extends PanelContainer
## HUD 物品栏中的一格：图标 + 数量，可点按选中。
##
## 与 [ItemSlot] 的区别是这个格子只占 22×22 像素，因此不显示道具名，
## 道具名放进 tooltip；数量大等于 2 时才显示数字，避免刺眼的“×1”。
##
## 只报告“被点按”，选中哪一格、算不算可用道具由 [HudItemBarView] / [ItemBar] 决定。

## 被点按（触摸或鼠标左键按下）；外层据此请求选中这一格。
signal pressed()

@onready var icon: TextureRect = %Icon
@onready var count_label: Label = %CountLabel

var _normal_style: StyleBox
var _selected_style: StyleBox
## 图标左上角的品质星（普通品质时自动隐藏）。
var _stars: QualityStars


func _ready() -> void:
	custom_minimum_size = UiLayout.HUD_SLOT_SIZE
	# 触控选中要能收到点按：父容器是 IGNORE，格子自己必须 STOP。
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal_style = get_theme_stylebox(&"panel", &"HudSlot")
	_selected_style = get_theme_stylebox(&"selected", &"HudSlot")
	add_theme_stylebox_override(&"panel", _normal_style)
	_stars = QualityStars.new()
	_stars.name = "Stars"
	icon.add_child(_stars)
	clear()


## 显示一件道具。[param selected] 为 true 时使用选中底色。
func set_item(item_id: StringName, count: int, selected: bool = false, quality: int = 0) -> void:
	if item_id == &"" or count <= 0:
		clear(selected)
		return

	var item := Database.get_item(item_id)
	icon.texture = item.icon if item != null else null
	icon.visible = icon.texture != null
	count_label.text = str(count) if count > 1 else ""
	var display_name := Text.item_name(item) if item != null else String(item_id)
	var grade: int = QualityRules.clamp_grade(quality)
	if grade > 0:
		display_name = "%s(%s)" % [display_name, Text.key(QualityRules.label_key(grade))]
	tooltip_text = display_name
	_stars.set_grade(grade)
	_set_selected(selected)


## 清空为空格子。[param selected] 为 true 时仍保留选中框。
func clear(selected: bool = false) -> void:
	icon.texture = null
	icon.visible = false
	count_label.text = ""
	tooltip_text = ""
	_stars.set_grade(QualityRules.Grade.NORMAL)
	_set_selected(selected)


func _set_selected(selected: bool) -> void:
	add_theme_stylebox_override(&"panel", _selected_style if selected else _normal_style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			pressed.emit()
	elif PointerInput.accepts_mouse() and event is InputEventMouseButton:
		# 桌面（含触屏笔记本调试 / 网页版）用鼠标也能点选。
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
