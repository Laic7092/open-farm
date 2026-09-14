class_name AnimalState
extends RefCounted
## 一头牲畜的运行时状态。
##
## 纯数据，可整体序列化；[AnimalHusbandry] 只读写这个对象。

## 对应的 [AnimalData.id]。
var animal_id: StringName = &""
## 累计喂养天数（决定是否成年）。
var days_grown: int = 0
## 好感度。
var affection: int = 0
## 距上次产出过去了几天。
var days_since_product: int = 0
## 今天是否喂过（日结转后重置）。
var fed_today: bool = false
## 今天是否摸过（日结转后重置）。
var petted_today: bool = false


func _init(p_animal_id: StringName = &"") -> void:
	animal_id = p_animal_id


func to_dict() -> Dictionary:
	return {
		"animal_id": String(animal_id),
		"days_grown": days_grown,
		"affection": affection,
		"days_since_product": days_since_product,
		"fed_today": fed_today,
		"petted_today": petted_today,
	}


func from_dict(data: Dictionary) -> void:
	animal_id = StringName(str(data.get("animal_id", "")))
	days_grown = maxi(int(data.get("days_grown", 0)), 0)
	affection = maxi(int(data.get("affection", 0)), 0)
	days_since_product = maxi(int(data.get("days_since_product", 0)), 0)
	fed_today = bool(data.get("fed_today", false))
	petted_today = bool(data.get("petted_today", false))


func duplicate_state() -> AnimalState:
	var copy := AnimalState.new(animal_id)
	copy.days_grown = days_grown
	copy.affection = affection
	copy.days_since_product = days_since_product
	copy.fed_today = fed_today
	copy.petted_today = petted_today
	return copy
