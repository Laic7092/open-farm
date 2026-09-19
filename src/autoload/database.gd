extends Node
## 静态数据仓库（Autoload：`Database`）。
##
## 启动时扫描 [code]res://data/[/code] 下的所有 [code].tres[/code]，
## 按 [code]id[/code] 建索引。业务代码只通过 id 取数据，永远不写死文件路径，
## 于是"新增一种作物"就只是往目录里丢一个资源文件。
##
## [b]两层数据[/b]——别把「物品」和「对象」混为一谈：
## [br]- [b]物品[/b]（[ItemData]，[constant ITEM_DIR]）：全游戏可持有物品的[b]总表[/b]。
##   背包 / 商店 / 出货箱 / 图鉴 / 委托板只认这里的 id。
## [br]- [b]对象 / 定义[/b]（[CropData] / [FishData] / [AnimalData] / [FloraData] /
##   [ToolData]…）：有生长或行为规则的领域实体，通过 [code]harvest_item_id[/code] /
##   [code]item_id[/code] / [code]product_item_id[/code] 等字段[b]产出或引用[/b]物品。
## [br]所以「鱼」不是物品，「钓上来的那条鱼」才是；两者按 id 关联，不是重复。
##
## 该节点不持有任何运行时状态，可以安全地在单元测试里反复调用 [method reload]。

const CROP_DIR: String = "res://data/crops"
const ANIMAL_DIR: String = "res://data/animals"
const BUILDING_DIR: String = "res://data/buildings"
const FLORA_DIR: String = "res://data/flora"
const FISH_DIR: String = "res://data/fish"
const ITEM_DIR: String = "res://data/items"
const TOOL_DIR: String = "res://data/tools"
const NPC_DIR: String = "res://data/npcs"
const SHOP_DIR: String = "res://data/shops"
const DIALOGUE_DIR: String = "res://data/dialogue"
const FESTIVAL_DIR: String = "res://data/festivals"
const EVENT_DIR: String = "res://data/events"
const COMMISSION_DIR: String = "res://data/commissions"
const MINE_DIR: String = "res://data/mine"

## 数据装载完成后发出。
signal reloaded()

var _crops: Dictionary[StringName, CropData] = {}
var _animals: Dictionary[StringName, AnimalData] = {}
var _buildings: Dictionary[StringName, BuildingData] = {}
var _floras: Dictionary[StringName, FloraData] = {}
var _fish: Dictionary[StringName, FishData] = {}
var _items: Dictionary[StringName, ItemData] = {}
var _tools: Dictionary[StringName, ToolData] = {}
var _npcs: Dictionary[StringName, NpcData] = {}
var _shops: Dictionary[StringName, ShopData] = {}
var _dialogues: Dictionary[StringName, DialogueData] = {}
var _festivals: Dictionary[StringName, FestivalData] = {}
var _events: Dictionary[StringName, EventData] = {}
var _commissions: Dictionary[StringName, CommissionData] = {}
var _strata: Dictionary[StringName, MineStratumData] = {}


func _ready() -> void:
	reload()


## 重新扫描全部数据目录。
func reload() -> void:
	_crops.clear()
	_animals.clear()
	_buildings.clear()
	_floras.clear()
	_fish.clear()
	_items.clear()
	_tools.clear()
	_npcs.clear()
	_shops.clear()
	_dialogues.clear()
	_festivals.clear()
	_events.clear()
	_commissions.clear()
	_strata.clear()

	_index(CROP_DIR, _crops, "CropData")
	_index(ANIMAL_DIR, _animals, "AnimalData")
	_index(BUILDING_DIR, _buildings, "BuildingData")
	_index(FLORA_DIR, _floras, "FloraData")
	_index(FISH_DIR, _fish, "FishData")
	_index(ITEM_DIR, _items, "ItemData")
	_index(TOOL_DIR, _tools, "ToolData")
	_index(NPC_DIR, _npcs, "NpcData")
	_index(SHOP_DIR, _shops, "ShopData")
	_index(DIALOGUE_DIR, _dialogues, "DialogueData")
	_index(FESTIVAL_DIR, _festivals, "FestivalData")
	_index(EVENT_DIR, _events, "EventData")
	_index(COMMISSION_DIR, _commissions, "CommissionData")
	_index(MINE_DIR, _strata, "MineStratumData")

	reloaded.emit()


# ---------------------------------------------------------------- 查询

func get_crop(id: StringName) -> CropData:
	return _crops.get(id) as CropData


func get_animal(id: StringName) -> AnimalData:
	return _animals.get(id) as AnimalData


func get_building(id: StringName) -> BuildingData:
	return _buildings.get(id) as BuildingData


func get_flora(id: StringName) -> FloraData:
	return _floras.get(id) as FloraData

func get_fish(id: StringName) -> FishData:
	return _fish.get(id) as FishData


func get_item(id: StringName) -> ItemData:
	return _items.get(id) as ItemData


func get_tool(id: StringName) -> ToolData:
	return _tools.get(id) as ToolData


func get_npc(id: StringName) -> NpcData:
	return _npcs.get(id) as NpcData


func get_shop(id: StringName) -> ShopData:
	return _shops.get(id) as ShopData


func get_dialogue(id: StringName) -> DialogueData:
	return _dialogues.get(id) as DialogueData


func get_festival(id: StringName) -> FestivalData:
	return _festivals.get(id) as FestivalData


func get_event(id: StringName) -> EventData:
	return _events.get(id) as EventData


func get_commission(id: StringName) -> CommissionData:
	return _commissions.get(id) as CommissionData


func get_stratum(id: StringName) -> MineStratumData:
	return _strata.get(id) as MineStratumData


## 全部数据桶的只读快照；调用方不应直接迭代内部字典。
func crops() -> Dictionary:
	return _crops.duplicate()

## 全部鱼种的只读快照（键为 id）。
func fish() -> Dictionary:
	return _fish.duplicate()


## [method crops] 的 get_* 别名。
func get_crops() -> Dictionary:
	return crops()


## 是否存在指定 id 的crop数据。
func has_crop(id: StringName) -> bool:
	return _crops.has(id)


func animals() -> Dictionary:
	return _animals.duplicate()


## [method animals] 的 get_* 别名。
func get_animals() -> Dictionary:
	return animals()


## 是否存在指定 id 的animal数据。
func has_animal(id: StringName) -> bool:
	return _animals.has(id)


func buildings() -> Dictionary:
	return _buildings.duplicate()


## [method buildings] 的 get_* 别名。
func get_buildings() -> Dictionary:
	return buildings()


## 是否存在指定 id 的building数据。
func has_building(id: StringName) -> bool:
	return _buildings.has(id)


func floras() -> Dictionary:
	return _floras.duplicate()


## [method floras] 的 get_* 别名。
func get_floras() -> Dictionary:
	return floras()


## 是否存在指定 id 的flora数据。
func has_flora(id: StringName) -> bool:
	return _floras.has(id)


func items() -> Dictionary:
	return _items.duplicate()


## [method items] 的 get_* 别名。
func get_items() -> Dictionary:
	return items()


## 是否存在指定 id 的item数据。
func has_item(id: StringName) -> bool:
	return _items.has(id)


func tools() -> Dictionary:
	return _tools.duplicate()


## [method tools] 的 get_* 别名。
func get_tools() -> Dictionary:
	return tools()


## 是否存在指定 id 的tool数据。
func has_tool(id: StringName) -> bool:
	return _tools.has(id)


func npcs() -> Dictionary:
	return _npcs.duplicate()


## [method npcs] 的 get_* 别名。
func get_npcs() -> Dictionary:
	return npcs()


## 是否存在指定 id 的npc数据。
func has_npc(id: StringName) -> bool:
	return _npcs.has(id)


func shops() -> Dictionary:
	return _shops.duplicate()


## [method shops] 的 get_* 别名。
func get_shops() -> Dictionary:
	return shops()


## 是否存在指定 id 的shop数据。
func has_shop(id: StringName) -> bool:
	return _shops.has(id)


func dialogues() -> Dictionary:
	return _dialogues.duplicate()


## [method dialogues] 的 get_* 别名。
func get_dialogues() -> Dictionary:
	return dialogues()


## 是否存在指定 id 的dialogue数据。
func has_dialogue(id: StringName) -> bool:
	return _dialogues.has(id)


func festivals() -> Dictionary:
	return _festivals.duplicate()


func commissions() -> Dictionary:
	return _commissions.duplicate()


## 全部矿层，键为 id。
func strata() -> Dictionary:
	return _strata.duplicate()


## 是否存在指定 id 的矿层数据。
func has_stratum(id: StringName) -> bool:
	return _strata.has(id)


## 是否存在指定 id 的 commission 数据。
func has_commission(id: StringName) -> bool:
	return _commissions.has(id)


## 全部委托，按 id 排序（委托板出题要求稳定，不依赖字典迭代顺序）。
func commission_list() -> Array[CommissionData]:
	var result: Array[CommissionData] = []
	for id: StringName in _commissions:
		result.append(_commissions[id])
	result.sort_custom(func(a: CommissionData, b: CommissionData) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## [method festivals] 的 get_* 别名。
func get_festivals() -> Dictionary:
	return festivals()


## 是否存在指定 id 的festival数据。
func has_festival(id: StringName) -> bool:
	return _festivals.has(id)


func events() -> Dictionary:
	return _events.duplicate()


## [method events] 的 get_* 别名。
func get_events() -> Dictionary:
	return events()


## 是否存在指定 id 的event数据。
func has_event(id: StringName) -> bool:
	return _events.has(id)

## 全部节日，按 id 排序（节日日历要求输出稳定，不依赖字典的迭代顺序）。
func festival_list() -> Array[FestivalData]:
	var result: Array[FestivalData] = []
	for id: StringName in _festivals:
		result.append(_festivals[id])
	result.sort_custom(func(a: FestivalData, b: FestivalData) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## 全部事件，按 id 排序。
func event_list() -> Array[EventData]:
	var result: Array[EventData] = []
	for id: StringName in _events:
		result.append(_events[id])
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
		_crops.size() + _animals.size() + _buildings.size() + _floras.size()
		+ _fish.size() + _items.size() + _tools.size() + _npcs.size() + _shops.size()
		+ _dialogues.size() + _festivals.size() + _events.size() + _commissions.size()
		+ _strata.size()
	)


## 对全部资源跑一遍自检；返回形如 ["CropData(turnip): id 不能为空"] 的问题列表。
func validate_all() -> PackedStringArray:
	var problems := PackedStringArray()
	for bucket: Dictionary in [
		_crops, _animals, _buildings, _floras, _fish, _items, _tools, _npcs, _shops,
		_dialogues, _festivals, _events, _commissions, _strata
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


## 收集 [param dir_path] 及其[b]全部子目录[/b]里的 [code].tres[/code]。
##
## 允许按域再分一层目录（例如每个 NPC 一个 [code]data/dialogue/<npc>/[/code]），
## 让一个域的内容增长时不必把几百个文件挤在同一层；索引仍然只认 [code]id[/code]，
## 因此分目录对业务代码完全透明。目录名排序后遍历，保证加载顺序稳定。
func _load_resources(dir_path: String) -> Array[Resource]:
	var found: Array[Resource] = []
	_collect_resources(dir_path, found)
	return found


## [method _load_resources] 的递归实现，结果累加到 [param found]。
func _collect_resources(dir_path: String, found: Array[Resource]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# 目录不存在是合法情况（例如还没添加任何商店）。
		return
	var sub_dirs: PackedStringArray = dir.get_directories()
	sub_dirs.sort()
	for sub_dir: String in sub_dirs:
		_collect_resources(dir_path.path_join(sub_dir), found)
	for file_name: String in dir.get_files():
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var resource: Resource = ResourceLoader.load(dir_path.path_join(clean_name))
		if resource != null:
			found.append(resource)
