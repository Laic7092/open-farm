class_name InventorySlot
extends RefCounted
## 背包中的一格。

## 道具 id；空字符串表示空格。
var item_id: StringName = &""
## 数量。
var count: int = 0
## 品质等级（[enum QualityRules.Grade]）；0 = 普通。
var quality: int = 0


func _init(p_item_id: StringName = &"", p_count: int = 0, p_quality: int = 0) -> void:
	item_id = p_item_id
	count = maxi(p_count, 0)
	quality = QualityRules.clamp_grade(p_quality)


func is_empty() -> bool:
	return item_id == &"" or count <= 0


func clear() -> void:
	item_id = &""
	count = 0
	quality = 0


func to_dict() -> Dictionary:
	return {"item_id": String(item_id), "count": count, "quality": quality}


func from_dict(data: Dictionary) -> void:
	item_id = StringName(str(data.get("item_id", "")))
	count = maxi(int(data.get("count", 0)), 0)
	quality = QualityRules.clamp_grade(int(data.get("quality", 0)))
