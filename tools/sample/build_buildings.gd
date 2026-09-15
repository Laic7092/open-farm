extends "res://tools/sample/sample_base.gd"
## buildings：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var coop := BuildingData.new()
	coop.id = &"coop"
	coop.display_name_key = &"BUILDING_COOP"
	coop.capacity = 4
	coop.allowed_species = [&"chicken"] as Array[StringName]
	_save(coop, BUILDING_DIR.path_join("coop.tres"))

	var barn := BuildingData.new()
	barn.id = &"barn"
	barn.display_name_key = &"BUILDING_BARN"
	barn.capacity = 4
	barn.allowed_species = [&"cow"] as Array[StringName]
	_save(barn, BUILDING_DIR.path_join("barn.tres"))
