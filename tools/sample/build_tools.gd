extends "res://tools/sample/sample_base.gd"
## tools：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 升级链也写在这里：每级工具的 [member ToolData.tier] 决定它能砸开多硬的矿，
## [member ToolData.next_id] / [member ToolData.upgrade_cost] 描述"怎么升上去"。
## 升级台（[UpgradeBench]）只读这些字段，因此加一级不用改脚本。

func build() -> void:
	_tool(&"hoe", &"ITEM_HOE", ToolData.Kind.HOE, 2, 1, Vector2i.ONE, 1, &"hoe_copper")
	_tool(&"hoe_copper", &"ITEM_HOE_COPPER", ToolData.Kind.HOE, 2, 1, Vector2i(3, 3), 2, &"hoe_iron", {
		"copper_ore": 5, "wood": 3,
	}, 500)
	_tool(&"hoe_iron", &"ITEM_HOE_IRON", ToolData.Kind.HOE, 1, 2, Vector2i(3, 3), 3)

	_tool(&"watering_can", &"ITEM_WATERING_CAN", ToolData.Kind.WATERING_CAN, 1, 1, Vector2i.ONE, 1, &"watering_can_copper")
	_tool(&"watering_can_copper", &"ITEM_WATERING_CAN_COPPER", ToolData.Kind.WATERING_CAN, 1, 1, Vector2i(3, 3), 2, &"watering_can_iron", {
		"copper_ore": 5, "stone": 5,
	}, 500)
	_tool(&"watering_can_iron", &"ITEM_WATERING_CAN_IRON", ToolData.Kind.WATERING_CAN, 1, 2, Vector2i(5, 5), 3)

	_tool(&"sickle", &"ITEM_SICKLE", ToolData.Kind.SICKLE, 1, 1, Vector2i.ONE, 1)
	_tool(&"seed_bag", &"ITEM_SEED_BAG", ToolData.Kind.SEED, 1, 1, Vector2i.ONE, 1)

	# 斧头 / 镐子：世界会自己长树长石，必须给玩家清理手段。
	_tool(&"axe", &"ITEM_AXE", ToolData.Kind.AXE, 3, 1, Vector2i.ONE, 1, &"axe_copper")
	_tool(&"axe_copper", &"ITEM_AXE_COPPER", ToolData.Kind.AXE, 2, 1, Vector2i(3, 3), 2, &"axe_iron", {
		"copper_ore": 5, "wood": 5,
	}, 600)
	_tool(&"axe_iron", &"ITEM_AXE_IRON", ToolData.Kind.AXE, 1, 2, Vector2i(3, 3), 3)

	_tool(&"pickaxe", &"ITEM_PICKAXE", ToolData.Kind.PICKAXE, 3, 1, Vector2i.ONE, 1, &"pickaxe_copper")
	_tool(&"pickaxe_copper", &"ITEM_PICKAXE_COPPER", ToolData.Kind.PICKAXE, 2, 1, Vector2i.ONE, 2, &"pickaxe_iron", {
		"copper_ore": 5, "stone": 5,
	}, 600)
	_tool(&"pickaxe_iron", &"ITEM_PICKAXE_IRON", ToolData.Kind.PICKAXE, 2, 2, Vector2i(3, 3), 3)

	# 钓竿：对着水面按空格抛竿，咬钩时再按一次收竿（见 player_state_fishing.gd）。
	_tool(&"fishing_rod", &"ITEM_FISHING_ROD", ToolData.Kind.FISHING, 1, 1, Vector2i.ONE, 1)


func _tool(
	tool_id: StringName,
	name_key: StringName,
	kind: ToolData.Kind,
	stamina_cost: int,
	reach: int,
	area_size: Vector2i,
	tier: int,
	next_id: StringName = &"",
	upgrade_cost: Dictionary = {},
	upgrade_money: int = 0
) -> void:
	var tool := ToolData.new()
	tool.id = tool_id
	tool.display_name_key = name_key
	tool.kind = kind
	tool.stamina_cost = stamina_cost
	tool.reach = reach
	tool.area_size = area_size
	tool.tier = tier
	tool.next_id = next_id
	tool.upgrade_cost = upgrade_cost
	tool.upgrade_money = upgrade_money
	_save(tool, TOOL_DIR.path_join("%s.tres" % tool_id))
