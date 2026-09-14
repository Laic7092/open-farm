class_name FloraState
extends RefCounted
## 一株野生植被的运行时状态（存档对象）。
##
## 与 [FloraData] 严格分离：静态数值在资源里，会变化的部分在这里。
## 格子坐标不进本类——它是 [FloraField] 里 [code]Dictionary[Vector2i, FloraState][/code]
## 的 key，这样"长在哪里"和"长成什么样"各自只有一个来源。

## 对应的 [FloraData.id]。
var flora_id: StringName = &""

## 累计获得的生长天数。
var days_grown: int = 0

## 外观变体（同一种树的两套画法），纯表现。
var variant: int = 0

## 是否枯死（冬季冻死 / 被清掉前的中间态）。
var dead: bool = false


func _init(p_flora_id: StringName = &"") -> void:
	flora_id = p_flora_id


func is_empty() -> bool:
	return flora_id == &""


func to_dict() -> Dictionary:
	return {
		"flora_id": String(flora_id),
		"days_grown": days_grown,
		"variant": variant,
		"dead": dead,
	}


func from_dict(data: Dictionary) -> void:
	flora_id = StringName(str(data.get("flora_id", "")))
	days_grown = maxi(int(data.get("days_grown", 0)), 0)
	variant = maxi(int(data.get("variant", 0)), 0)
	dead = bool(data.get("dead", false))


func duplicate_state() -> FloraState:
	var copy := FloraState.new(flora_id)
	copy.days_grown = days_grown
	copy.variant = variant
	copy.dead = dead
	return copy
