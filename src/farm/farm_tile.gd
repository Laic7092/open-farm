class_name FarmTile
extends RefCounted
## 一块农田格子的运行时状态。

## 格子坐标。
var cell: Vector2i = Vector2i.ZERO

## 是否已翻耕。
var tilled: bool = false

## 今天是否浇过水（每天日结转后重置）。
var watered: bool = false

## 上面的作物；为空表示这块地没种东西。
var crop: CropState = null


func _init(p_cell: Vector2i = Vector2i.ZERO) -> void:
	cell = p_cell


## 是否是"没有任何内容的空格子"（用于从字典里剔除，保持存档精简）。
func is_pristine() -> bool:
	return not tilled and not watered and crop == null


func has_crop() -> bool:
	return crop != null


func clear_crop() -> void:
	crop = null


func to_dict() -> Dictionary:
	return {
		"cell": [cell.x, cell.y],
		"tilled": tilled,
		"watered": watered,
		"crop": crop.to_dict() if crop != null else {},
	}


func from_dict(data: Dictionary) -> void:
	var raw_cell: Variant = data.get("cell", [0, 0])
	if raw_cell is Array and (raw_cell as Array).size() >= 2:
		cell = Vector2i(int((raw_cell as Array)[0]), int((raw_cell as Array)[1]))
	tilled = bool(data.get("tilled", false))
	watered = bool(data.get("watered", false))
	var raw_crop: Variant = data.get("crop", {})
	if raw_crop is Dictionary and not (raw_crop as Dictionary).is_empty():
		var state := CropState.new()
		state.from_dict(raw_crop)
		crop = state
	else:
		crop = null
