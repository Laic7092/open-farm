extends Node
## 游戏内容 wiki 的数据导出端。
##
## 把 [Database] 里的全部静态数据 + [AtlasLayout] 的切图常量 + 自检问题
## 写成一个 JSON，交给 [code]tools/build_wiki.py[/code] 渲染成静态 HTML。
##
## [b]必须作为场景运行[/b]（[code]res://tools/wiki_dump.tscn[/code]）：
## [code]-s[/code] 在 autoload 注册前编译，拿不到 [Database]。
##
## 用法：[code]godot --headless --path . res://tools/wiki_dump.tscn[/code]

const Serializer := preload("res://tools/wiki/wiki_serialize.gd")
const Layout := preload("res://src/art/atlas_layout.gd")

## 输出目录与文件。
const OUTPUT_DIR: String = "res://.tmp/wiki"
const OUTPUT_PATH: String = "res://.tmp/wiki/data.json"

## [Database] 里的数据桶，顺序 = wiki 侧栏顺序。
const BUCKETS: Array[StringName] = [
	&"items", &"crops", &"fish", &"animals", &"buildings", &"floras", &"tools",
	&"npcs", &"dialogues", &"shops", &"commissions", &"festivals", &"events",
	&"strata",
]


func _ready() -> void:
	var payload: Dictionary = {
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"layout": _layout(),
		"resources": _resources(),
		"validation": Array(Database.validate_all()),
	}
	if _write(JSON.stringify(payload, "\t")):
		print("wiki 数据已导出：%s" % OUTPUT_PATH)
	get_tree().quit()


## 全部数据，按「类名 → {id: 资源}」组织，id 升序保证输出稳定。
func _resources() -> Dictionary:
	var buckets: Dictionary = {}
	for bucket: StringName in BUCKETS:
		var source: Dictionary = Database.call(bucket)
		var ids: Array = source.keys()
		if ids.is_empty():
			continue
		ids.sort()
		var entries: Dictionary = {}
		var kind: String = ""
		for id: Variant in ids:
			var resource: Resource = source[id]
			kind = Serializer.kind_of(resource)
			entries[String(id)] = Serializer.serialize(resource)
		buckets[kind] = entries
	return buckets


## 切图常量：Python 侧据此裁 sprite sheet，避免两处硬编码排版。
func _layout() -> Dictionary:
	return {
		"tile": Layout.TILE,
		"crop_columns": Layout.CROP_COLUMNS,
		"crop_withered": Layout.CROP_WITHERED_COLUMN,
		"animal_columns": Layout.ANIMAL_COLUMNS,
		"animal_cell": Serializer.value(Layout.ANIMAL_CELL),
		"flora_columns": Layout.FLORA_COLUMNS,
		"flora_tree_cell": Serializer.value(Layout.FLORA_TREE_CELL),
		"flora_small_cell": Serializer.value(Layout.FLORA_SMALL_CELL),
		"flora_rock_cell": Serializer.value(Layout.FLORA_ROCK_CELL),
		"item_icon": Serializer.value(Layout.ITEM_ICON_SIZE),
		"npc_columns": Layout.NPC_COLUMNS,
		"npc_rows": Layout.NPC_ROWS,
		"npc_idle_column": Layout.NPC_IDLE_COLUMN,
		"actor_columns": Layout.ACTOR_COLUMNS,
		"actor_rows": Layout.ACTOR_ROWS,
	}


func _write(json: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file == null:
		push_error("wiki_dump: 无法写入 %s" % OUTPUT_PATH)
		return false
	file.store_string(json)
	file.close()
	return true
