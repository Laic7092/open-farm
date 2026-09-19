class_name ItemSlot
extends PanelContainer
## 背包 / 商店里的一格道具：图标 + 名字 / 数量。
##
## 图标来自 [member ItemData.icon]，由 [code]tools/generate_sample_data.gd[/code]
## 按 id 从 [code]assets/sprites/items/<id>.png[/code] 挂上来，
## 所以这里不需要知道任何贴图路径。

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label


func _ready() -> void:
	clear()


## 显示一件道具。
func set_item(item_id: StringName, count: int, quality: int = 0) -> void:
	if item_id == &"" or count <= 0:
		clear()
		return

	var item := Database.get_item(item_id)
	var display_name := Text.item_name(item)
	var grade: int = QualityRules.clamp_grade(quality)
	if grade > 0:
		display_name = "%s(%s)" % [display_name, Text.key(QualityRules.label_key(grade))]

	modulate.a = 1.0
	icon.texture = item.icon if item != null else null
	icon.visible = icon.texture != null
	# 数量只在大于 1 时显示，否则一格萝卜写着"×1"很吵。
	label.text = ("%s×%d" % [display_name, count]) if count > 1 else display_name
	tooltip_text = display_name


## 显示为空格子。
func clear() -> void:
	modulate.a = 0.35
	icon.texture = null
	icon.visible = false
	label.text = Text.key(&"INVENTORY_EMPTY")
	tooltip_text = ""
