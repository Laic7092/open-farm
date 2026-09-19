extends RefCounted
## 示例数据生成器的公共基座（由 tools/sample/build_*.gd 继承）。
##
## 只放两类东西：① 数据 / 美术目录常量；② 所有域都要用的写盘与加载工具。
## 各域只写自己的 _build 内容，公共部分不重复。

const CROP_DIR: String = "res://data/crops"
const ANIMAL_DIR: String = "res://data/animals"
const BUILDING_DIR: String = "res://data/buildings"
const FLORA_DIR: String = "res://data/flora"
const FISH_DIR: String = "res://data/fish"
const ITEM_DIR: String = "res://data/items"
const TOOL_DIR: String = "res://data/tools"
const DIALOGUE_DIR: String = "res://data/dialogue"
const NPC_DIR: String = "res://data/npcs"
const SCHEDULE_DIR: String = "res://data/schedules"
const SHOP_DIR: String = "res://data/shops"
const COMMISSION_DIR: String = "res://data/commissions"
const FESTIVAL_DIR: String = "res://data/festivals"
const EVENT_DIR: String = "res://data/events"

## 美术资源目录（由 tools/art/*.gd 生成，这里只负责"把图挂到数据上"）。
const CROP_SHEET_DIR: String = "res://assets/sprites/crops"
const ANIMAL_SHEET_DIR: String = "res://assets/sprites/animals"
const FLORA_SHEET_DIR: String = "res://assets/sprites/flora"
const ITEM_ICON_DIR: String = "res://assets/sprites/items"
const NPC_FRAMES_DIR: String = "res://assets/sprites/actors"

## 节日都在小镇广场办，这里只写一次，免得每份节日数据各写一遍路径。
const TWON_SCENE: String = "res://scenes/world/twon.tscn"


## 建好所有数据目录；入口脚本启动时调用一次。
static func ensure_dirs() -> void:
	for directory: String in [
		CROP_DIR, ANIMAL_DIR, BUILDING_DIR, FLORA_DIR, FISH_DIR,
		ITEM_DIR, TOOL_DIR, DIALOGUE_DIR, NPC_DIR, SCHEDULE_DIR, SHOP_DIR,
		FESTIVAL_DIR, EVENT_DIR, COMMISSION_DIR
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))


func _str_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(str(value)))
	return result


func _texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("缺少贴图 %s（先跑 tools/build_assets.sh）" % path)
		return null
	return ResourceLoader.load(path) as Texture2D


func _load(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_error("找不到资源：%s" % path)
		return null
	return ResourceLoader.load(path)


func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("  → ", path)
