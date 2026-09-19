class_name HudSlot
extends PanelContainer
## HUD 物品栏中的一格：图标 + 数量。
##
## 与 [ItemSlot] 的区别是这个格子只占 22×22 像素，因此不显示道具名，
## 道具名放进 tooltip；数量大等于 2 时才显示数字，避免刺眼的“×1”。

const SLOT_TEXTURE: Texture2D = preload("res://assets/ui/slot.png")
const SELECTED_TEXTURE: Texture2D = preload("res://assets/ui/slot_selected.png")

@onready var icon: TextureRect = %Icon
@onready var count_label: Label = %CountLabel

var _normal_style: StyleBoxTexture
var _selected_style: StyleBoxTexture
## 图标左上角的品质星（普通品质时自动隐藏）。
var _stars: QualityStars


func _ready() -> void:
	_normal_style = _make_style(SLOT_TEXTURE)
	_selected_style = _make_style(SELECTED_TEXTURE)
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


func _make_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 3.0
	style.texture_margin_top = 3.0
	style.texture_margin_right = 3.0
	style.texture_margin_bottom = 3.0
	return style
