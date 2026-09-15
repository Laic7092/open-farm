extends "res://tools/sample/sample_base.gd"
## tools：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var hoe := ToolData.new()
	hoe.id = &"hoe"
	hoe.display_name_key = &"ITEM_HOE"
	hoe.kind = ToolData.Kind.HOE
	hoe.stamina_cost = 2
	_save(hoe, TOOL_DIR.path_join("hoe.tres"))

	var can := ToolData.new()
	can.id = &"watering_can"
	can.display_name_key = &"ITEM_WATERING_CAN"
	can.kind = ToolData.Kind.WATERING_CAN
	can.stamina_cost = 1
	_save(can, TOOL_DIR.path_join("watering_can.tres"))

	var sickle := ToolData.new()
	sickle.id = &"sickle"
	sickle.display_name_key = &"ITEM_SICKLE"
	sickle.kind = ToolData.Kind.SICKLE
	sickle.stamina_cost = 1
	_save(sickle, TOOL_DIR.path_join("sickle.tres"))

	var seed_bag := ToolData.new()
	seed_bag.id = &"seed_bag"
	seed_bag.display_name_key = &"ITEM_SEED_BAG"
	seed_bag.kind = ToolData.Kind.SEED
	seed_bag.stamina_cost = 1
	_save(seed_bag, TOOL_DIR.path_join("seed_bag.tres"))

	# 斧头 / 镐子：世界会自己长树长石，必须给玩家清理手段。
	var axe := ToolData.new()
	axe.id = &"axe"
	axe.display_name_key = &"ITEM_AXE"
	axe.kind = ToolData.Kind.AXE
	axe.stamina_cost = 3
	_save(axe, TOOL_DIR.path_join("axe.tres"))

	var pickaxe := ToolData.new()
	pickaxe.id = &"pickaxe"
	pickaxe.display_name_key = &"ITEM_PICKAXE"
	pickaxe.kind = ToolData.Kind.PICKAXE
	pickaxe.stamina_cost = 3
	_save(pickaxe, TOOL_DIR.path_join("pickaxe.tres"))

	# 钓竿：对着水面按空格抛竿，咬钩时再按一次收竿（见 player_state_fishing.gd）。
	var rod := ToolData.new()
	rod.id = &"fishing_rod"
	rod.display_name_key = &"ITEM_FISHING_ROD"
	rod.kind = ToolData.Kind.FISHING
	rod.stamina_cost = 1
	_save(rod, TOOL_DIR.path_join("fishing_rod.tres"))
