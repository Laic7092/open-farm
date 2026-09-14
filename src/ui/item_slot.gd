class_name ItemSlot
extends PanelContainer
## 背包 / 商店里的一格道具。

@onready var label: Label = %Label


func _ready() -> void:
	clear()


## 显示一件道具。
func set_item(item_id: StringName, count: int) -> void:
	if item_id == &"" or count <= 0:
		clear()
		return
	modulate.a = 1.0
	var display_name := Text.item_name(item_id)
	label.text = ("%s ×%d" % [display_name, count]) if count > 1 else display_name
	tooltip_text = display_name


## 显示为空格子。
func clear() -> void:
	modulate.a = 0.35
	label.text = Text.key(&"INVENTORY_EMPTY")
	tooltip_text = ""
