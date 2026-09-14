@tool
class_name BuildingData
extends Resource
## 畜舍的静态定义。
##
## 只描述"能养多少、能养哪种"，具体怎么放养 / 喂食 / 收获由
## [LivestockManager] 与 [AnimalHusbandry] 负责。

## 唯一标识。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
## 可容纳的动物数量。
@export_range(1, 99) var capacity: int = 4
## 允许的物种；为空表示不限制。
@export var allowed_species: Array[StringName] = []


## 这种畜舍是否接受 [param animal]。
func allows(animal: AnimalData) -> bool:
	if animal == null:
		return false
	return allowed_species.is_empty() or allowed_species.has(animal.species)


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if capacity < 1:
		problems.append("capacity 必须 >= 1")
	return problems


func _to_string() -> String:
	return "BuildingData(%s, %d)" % [id, capacity]
