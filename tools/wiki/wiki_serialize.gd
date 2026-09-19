extends RefCounted
## wiki 导出用的资源序列化器（纯静态函数）。
##
## 把 [Resource] 的 [code]@export[/code] 字段转成 JSON 可写的 Variant：
## [br]- [StringName] → [String]，[Vector2] / [Vector2i] → [code]{x, y}[/code]
## [br]- [Texture2D] / [SpriteFrames] → [code]{"$texture": "res://..."}[/code]
## [br]- 顶层数据资源（有 [code]id[/code]）→ [code]{"$ref": 类名, "id": ...}[/code]，
##   交给 Python 侧按 id 连表，避免同一份数据被复制两遍
## [br]- 匿名子资源（[DialogueLine] / [ShopStock] / [ScheduleEntry]）→ 原地递归
##
## 字段集合直接来自 [method Object.get_property_list]，所以数据类加一个
## [code]@export[/code]，wiki 就自动多一列，不需要同步改这里。

## 有 [code]id[/code] 且被 [Database] 索引的类：这些引用走 [code]$ref[/code]。
const INDEXED: Array[String] = [
	"CropData", "AnimalData", "BuildingData", "FloraData", "FishData",
	"ItemData", "ToolData", "NpcData", "ShopData", "DialogueData",
	"FestivalData", "EventData", "CommissionData", "MineStratumData",
	"RecipeData", "FestivalGameData", "VillageGoalData",
]


## 资源的全局类名（[code]class_name[/code]）。
static func kind_of(resource: Resource) -> String:
	var script: Script = resource.get_script() as Script
	if script == null:
		return ""
	return script.get_global_name()


## 序列化一个资源：类名 + 全部脚本导出字段。
static func serialize(resource: Resource) -> Dictionary:
	var data: Dictionary = {"$class": kind_of(resource)}
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		data[String(property["name"])] = value(resource.get(property["name"]))
	return data


## 递归序列化任意值。
static func value(input: Variant) -> Variant:
	match typeof(input):
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return input
		TYPE_STRING_NAME:
			return String(input)
		TYPE_VECTOR2:
			return {"x": input.x, "y": input.y}
		TYPE_VECTOR2I:
			return {"x": input.x, "y": input.y}
		TYPE_COLOR:
			return {"r": input.r, "g": input.g, "b": input.b, "a": input.a}
		TYPE_ARRAY:
			var list: Array = []
			for item: Variant in input:
				list.append(value(item))
			return list
		TYPE_DICTIONARY:
			var table: Dictionary = {}
			for key: Variant in input:
				# 字典的键可能是 int（如 NpcData.seasonal_dialogue 的季节下标）；
				# String(int) 不是合法构造，必须用 str() 转。
				table[str(key)] = value(input[key])
			return table
		TYPE_OBJECT:
			return object(input)
	return str(input)


## 序列化对象：贴图取路径，顶层数据资源取 id 引用，其余原地展开。
static func object(input: Variant) -> Variant:
	if input == null:
		return null
	if input is Texture2D:
		return {"$texture": (input as Texture2D).resource_path}
	if input is SpriteFrames:
		return {"$frames": (input as SpriteFrames).resource_path}
	if input is Resource:
		var resource: Resource = input
		var kind: String = kind_of(resource)
		var id: Variant = resource.get(&"id")
		if id != null and String(id) != "" and INDEXED.has(kind):
			return {"$ref": kind, "id": String(id)}
		return serialize(resource)
	return str(input)
