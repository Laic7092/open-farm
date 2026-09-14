class_name BuildingState
extends RefCounted
## 一座畜舍的运行时状态：里面住了哪些牲畜。
##
## 与 [FarmGrid.tiles] 一样，这是"存档即一次 to_dict"的纯数据容器。

## 对应的 [BuildingData.id]。
var building_id: StringName = &""
## 舍内牲畜，顺序即界面/交互顺序。
var animals: Array[AnimalState] = []


func _init(p_building_id: StringName = &"") -> void:
	building_id = p_building_id


func size() -> int:
	return animals.size()


func is_empty() -> bool:
	return animals.is_empty()


## 是否已满。
func is_full(data: BuildingData) -> bool:
	if data == null:
		return false
	return animals.size() >= data.capacity


func add(state: AnimalState) -> void:
	if state != null:
		animals.append(state)


## 移除并返回下标处的牲畜；越界返回 null。
func remove_at(index: int) -> AnimalState:
	if index < 0 or index >= animals.size():
		return null
	var removed: AnimalState = animals[index]
	animals.remove_at(index)
	return removed


func to_dict() -> Dictionary:
	var entries: Array = []
	for animal: AnimalState in animals:
		entries.append(animal.to_dict())
	return {"building_id": String(building_id), "animals": entries}


func from_dict(data: Dictionary) -> void:
	building_id = StringName(str(data.get("building_id", building_id)))
	animals.clear()
	var raw: Variant = data.get("animals", [])
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary:
				continue
			var state := AnimalState.new()
			state.from_dict(entry)
			animals.append(state)


func duplicate_state() -> BuildingState:
	var copy := BuildingState.new(building_id)
	for animal: AnimalState in animals:
		copy.add(animal.duplicate_state())
	return copy
