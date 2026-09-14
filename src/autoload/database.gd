extends Node
## 静态数据仓库（Autoload：`Database`）。
##
## 启动时扫描 [code]res://data/[/code] 下的所有 [code].tres[/code]，
## 按 [code]id[/code] 建索引。业务代码只通过 id 取数据，永远不写死文件路径，
## 于是"新增一种作物"就只是往目录里丢一个资源文件。
##
## 该节点不持有任何运行时状态，可以安全地在单元测试里反复调用 [method reload]。

const CROP_DIR: String = "res://data/crops"
const ANIMAL_DIR: String = "res://data/animals"
const BUILDING_DIR: String = "res://data/buildings"
const FLORA_DIR: String = "res://data/flora"
const ITEM_DIR: String = "res://data/items"
const TOOL_DIR: String = "res://data/tools"
const NPC_DIR: String = "res://data/npcs"
const SHOP_DIR: String = "res://data/shops"
const DIALOGUE_DIR: String = "res://data/dialogue"
const FESTIVAL_DIR: String = "res://data/festivals"
const EVENT_DIR: String = "res://data/events"

## 数据装载完成后发出。
signal reloaded()

var crops: Dictionary[StringName, CropData] = {}
var animals: Dictionary[StringName, AnimalData] = {}
var buildings: Dictionary[StringName, BuildingData] = {}
var floras: Dictionary[StringName, FloraData] = {}
var items: Dictionary[StringName, ItemData] = {}
var tools: Dictionary[StringName, ToolData] = {}
var npcs: Dictionary[StringName, NpcData] = {}
var shops: Dictionary[StringName, ShopData] = {}
var dialogues: Dictionary[StringName, DialogueData] = {}
var festivals: Dictionary[StringName, FestivalData] = {}
var events: Dictionary[StringName, EventData] = {}


func _ready() -> void:
	reload()


## 重新扫描全部数据目录。
func reload() -> void:
	crops.clear()
	animals.clear()
	buildings.clear()
	floras.clear()
	items.clear()
	tools.clear()
	npcs.clear()
	shops.clear()
	dialogues.clear()
	festivals.clear()
	events.clear()

	_index(CROP_DIR, crops, "CropData")
	_index(ANIMAL_DIR, animals, "AnimalData")
	_index(BUILDING_DIR, buildings, "BuildingData")
	_index(FLORA_DIR, floras, "FloraData")
	_index(ITEM_DIR, items, "ItemData")
	_index(TOOL_DIR, tools, "ToolData")
	_index(NPC_DIR, npcs, "NpcData")
	_index(SHOP_DIR, shops, "ShopData")
	_index(DIALOGUE_DIR, dialogues, "DialogueData")
	_index(FESTIVAL_DIR, festivals, "FestivalData")
	_index(EVENT_DIR, events, "EventData")

	reloaded.emit()


# ---------------------------------------------------------------- 查询

func get_crop(id: StringName) -> CropData:
	return crops.get(id) as CropData


func get_animal(id: StringName) -> AnimalData:
	return animals.get(id) as AnimalData


func get_building(id: StringName) -> BuildingData:
	return buildings.get(id) as BuildingData


func get_flora(id: StringName) -> FloraData:
	return floras.get(id) as FloraData


func get_item(id: StringName) -> ItemData:
	return items.get(id) as ItemData


func get_tool(id: StringName) -> ToolData:
	return tools.get(id) as ToolData


func get_npc(id: StringName) -> NpcData:
	return npcs.get(id) as NpcData


func get_shop(id: StringName) -> ShopData:
	return shops.get(id) as ShopData


func get_dialogue(id: StringName) -> DialogueData:
	return dialogues.get(id) as DialogueData


func get_festival(id: StringName) -> FestivalData:
	return festivals.get(id) as FestivalData


func get_event(id: StringName) -> EventData:
	return events.get(id) as EventData


## 全部节日，按 id 排序（节日日历要求输出稳定，不依赖字典的迭代顺序）。
func festival_list() -> Array[FestivalData]:
	var result: Array[FestivalData] = []
	for id: StringName in festivals:
		result.append(festivals[id])
	result.sort_custom(func(a: FestivalData, b: FestivalData) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## 全部事件，按 id 排序。
func event_list() -> Array[EventData]:
	var result: Array[EventData] = []
	for id: StringName in events:
		result.append(events[id])
	result.sort_custom(func(a: EventData, b: EventData) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## 取道具；缺失时打印错误并返回 null（用于"这里必须有数据"的场景）。
func require_item(id: StringName) -> ItemData:
	var item := get_item(id)
	if item == null:
		push_error("Database: 找不到道具 '%s'" % id)
	return item


func require_animal(id: StringName) -> AnimalData:
	var data := get_animal(id)
	if data == null:
		push_error("Database: 找不到动物 '%s'" % id)
	return data


func require_building(id: StringName) -> BuildingData:
	var data := get_building(id)
	if data == null:
		push_error("Database: 找不到畜舍 '%s'" % id)
	return data


func require_crop(id: StringName) -> CropData:
	var crop := get_crop(id)
	if crop == null:
		push_error("Database: 找不到作物 '%s'" % id)
	return crop


func require_flora(id: StringName) -> FloraData:
	var data := get_flora(id)
	if data == null:
		push_error("Database: 找不到野生植被 '%s'" % id)
	return data


func require_shop(id: StringName) -> ShopData:
	var shop := get_shop(id)
	if shop == null:
		push_error("Database: 找不到商店 '%s'" % id)
	return shop


## 所有数据资源的总数，便于进度校验与测试。
func total_count() -> int:
	return (
		crops.size() + animals.size() + buildings.size() + floras.size()
		+ items.size() + tools.size() + npcs.size() + shops.size() + dialogues.size()
		+ festivals.size() + events.size()
	)


## 对全部资源跑一遍自检；返回形如 ["CropData(turnip): id 不能为空"] 的问题列表。
func validate_all() -> PackedStringArray:
	var problems := PackedStringArray()
	for bucket: Dictionary in [
		crops, animals, buildings, floras, items, tools, npcs, shops, dialogues,
		festivals, events
	]:
		for key: StringName in bucket:
			var resource: Resource = bucket[key]
			if not resource.has_method(&"validate"):
				continue
			for problem: String in resource.call(&"validate"):
				problems.append("%s: %s" % [resource, problem])
	return problems


# ---------------------------------------------------------------- 内部

func _index(dir_path: String, target: Dictionary, expected_type: String) -> void:
	for resource: Resource in _load_resources(dir_path):
		var actual_type: String = _global_class_of(resource)
		if actual_type != expected_type:
			push_warning(
				"Database: %s 的全局类名是 '%s'，期望 '%s'，已跳过"
				% [resource.resource_path, actual_type, expected_type]
			)
			continue
		var id: StringName = resource.get(&"id")
		if id == &"":
			push_warning("Database: %s 缺少 id，已跳过" % resource.resource_path)
			continue
		target[id] = resource


## 读取资源脚本的 [code]class_name[/code]；[code]Object.is_class()[/code]
## 只认引擎原生类，所以这里用全局类名做类型校验。
func _global_class_of(resource: Resource) -> String:
	var script: Script = resource.get_script() as Script
	if script == null:
		return ""
	return script.get_global_name()


func _load_resources(dir_path: String) -> Array[Resource]:
	var found: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# 目录不存在是合法情况（例如还没添加任何商店）。
		return found
	for file_name: String in dir.get_files():
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource: Resource = ResourceLoader.load(dir_path.path_join(clean_name))
		if resource != null:
			found.append(resource)
	return found
