class_name CropState
extends RefCounted
## 一株作物的运行时状态（存档对象）。
##
## 与 [CropData] 严格分离：静态数值在资源里，会变化的部分在这里。
## 生长规则全部由 [CropGrowth] 的纯静态函数实现，本类只存字段。

## 对应的 [CropData.id]。
var crop_id: StringName = &""

## 累计获得的"有效生长天数"。
var days_grown: int = 0

## 连续未浇水的天数。
var days_without_water: int = 0

## 已收获次数（用于多次收获作物）。
var harvests: int = 0

## 是否枯死。
var dead: bool = false


func _init(p_crop_id: StringName = &"") -> void:
	crop_id = p_crop_id


func is_empty() -> bool:
	return crop_id == &""


func to_dict() -> Dictionary:
	return {
		"crop_id": String(crop_id),
		"days_grown": days_grown,
		"days_without_water": days_without_water,
		"harvests": harvests,
		"dead": dead,
	}


func from_dict(data: Dictionary) -> void:
	crop_id = StringName(str(data.get("crop_id", "")))
	days_grown = maxi(int(data.get("days_grown", 0)), 0)
	days_without_water = maxi(int(data.get("days_without_water", 0)), 0)
	harvests = maxi(int(data.get("harvests", 0)), 0)
	dead = bool(data.get("dead", false))


func duplicate_state() -> CropState:
	var copy := CropState.new(crop_id)
	copy.days_grown = days_grown
	copy.days_without_water = days_without_water
	copy.harvests = harvests
	copy.dead = dead
	return copy
