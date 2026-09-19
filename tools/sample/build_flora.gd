extends "res://tools/sample/sample_base.gd"
## flora：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

## 世界各处会自己长出来的东西。
##
## 数值调法：
## [br]- [code]spawn_weight[/code] 是"每天冒出来的概率权重"，0 = 这个季节不冒
## [br]- [code]initial_weight[/code] 是新地图开局播种的权重（树多、草少）
## [br]- [code]days_per_stage[/code] 为空 = 不生长（石头就是这样"不会变"的）
func build() -> void:
	# 阔叶树：8 天从树苗长到成树；默认从第 0 阶段就挡路。
	_flora(&"tree_oak", &"FLORA_TREE_OAK", FloraData.Kind.TREE, [2, 3, 3], {
		"spawn_weight": [5, 5, 3, 0],
		"rain_bonus": 1,
		"initial_weight": 5,
		"max_per_world": 12,
		"min_spacing": 3,
		"solid_size": Vector2(10, 8),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.AXE,
		"stamina_cost": 3,
		"drop_item_id": &"wood",
		"drop_amount": Vector2i(2, 3),
	})

	# 松树：慢一点、冬季也在长，是冬天唯一会变高变大的东西；默认从第 0 阶段挡路。
	_flora(&"tree_pine", &"FLORA_TREE_PINE", FloraData.Kind.TREE, [3, 3, 3], {
		"spawn_weight": [3, 3, 3, 1],
		"initial_weight": 4,
		"max_per_world": 10,
		"min_spacing": 3,
		"solid_size": Vector2(10, 8),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.AXE,
		"stamina_cost": 3,
		"drop_item_id": &"wood",
		"drop_amount": Vector2i(2, 3),
	})

	# 牧草 / 杂草：一天就长成，会侵占农田空地；低矮地被显式可穿过。
	_flora(&"weed", &"FLORA_WEED", FloraData.Kind.WEED, [1], {
		"passable": true,
		"spawn_weight": [7, 8, 5, 0],
		"rain_bonus": 3,
		"initial_weight": 6,
		"max_per_world": 60,
		"grows_on_farmland": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"fiber",
		"drop_amount": Vector2i(1, 1),
		"drop_chance": 0.7,
	})

	# 石头：不生长、不会变，砸了出石材。
	_flora(&"rock", &"FLORA_ROCK", FloraData.Kind.ROCK, [], {
		"spawn_weight": [3, 3, 3, 1],
		"initial_weight": 4,
		"max_per_world": 14,
		"min_spacing": 2,
		"solid_from_stage": 0,
		"solid_size": Vector2(12, 8),
		"solid_offset": Vector2(0, 4),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"stone",
		"drop_amount": Vector2i(1, 2),
		"mine_weight": 5,
		"mine_min_depth": 1,
		"mine_max_depth": 100,
	})

	# 大石头：稀少，挡路，出的石材更多。
	_flora(&"boulder", &"FLORA_BOULDER", FloraData.Kind.ROCK, [], {
		"spawn_weight": [1, 1, 1, 0],
		"initial_weight": 1,
		"max_per_world": 5,
		"min_spacing": 3,
		"solid_from_stage": 0,
		"solid_size": Vector2(24, 10),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"stone",
		"drop_amount": Vector2i(2, 3),
		"mine_weight": 2,
		"mine_min_depth": 25,
		"mine_max_depth": 100,
	})

	# 矿洞矿石：越深越好的产出；required_tier 用镐子等级卡进度。
	_flora(&"copper_ore", &"FLORA_COPPER_ORE", FloraData.Kind.ROCK, [], {
		"spawn_weight": [0, 0, 0, 0],
		"solid_from_stage": 0,
		"solid_size": Vector2(12, 8),
		"solid_offset": Vector2(0, 4),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"copper_ore",
		"drop_amount": Vector2i(1, 3),
		"quality_silver_chance": 0.1,
		"quality_gold_chance": 0.02,
		"required_tier": 1,
		"mine_weight": 10,
		"mine_min_depth": 1,
		"mine_max_depth": 60,
	})
	_flora(&"iron_ore", &"FLORA_IRON_ORE", FloraData.Kind.ROCK, [], {
		"spawn_weight": [0, 0, 0, 0],
		"solid_from_stage": 0,
		"solid_size": Vector2(12, 8),
		"solid_offset": Vector2(0, 4),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"iron_ore",
		"drop_amount": Vector2i(1, 2),
		"quality_silver_chance": 0.15,
		"quality_gold_chance": 0.04,
		"required_tier": 2,
		"mine_weight": 7,
		"mine_min_depth": 15,
		"mine_max_depth": 100,
	})
	_flora(&"gold_ore", &"FLORA_GOLD_ORE", FloraData.Kind.ROCK, [], {
		"spawn_weight": [0, 0, 0, 0],
		"solid_from_stage": 0,
		"solid_size": Vector2(12, 8),
		"solid_offset": Vector2(0, 4),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"gold_ore",
		"drop_amount": Vector2i(1, 2),
		"quality_silver_chance": 0.2,
		"quality_gold_chance": 0.08,
		"required_tier": 3,
		"mine_weight": 4,
		"mine_min_depth": 40,
		"mine_max_depth": 100,
	})

	# 野花：两天开花，可以徒手采；低矮地被显式可穿过。
	_flora(&"flower", &"FLORA_FLOWER", FloraData.Kind.FLOWER, [1, 1], {
		"passable": true,
		"spawn_weight": [5, 4, 2, 0],
		"rain_bonus": 2,
		"initial_weight": 4,
		"max_per_world": 25,
		"grows_on_farmland": true,
		"pickable_by_hand": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"flower",
		"drop_amount": Vector2i(1, 1),
		"drop_chance": 0.8,
	})

	# 蘑菇：不生长，秋天雨后一夜之间冒出来，徒手采；低矮地被显式可穿过。
	_flora(&"mushroom", &"FLORA_MUSHROOM", FloraData.Kind.MUSHROOM, [], {
		"passable": true,
		"spawn_weight": [0, 1, 4, 0],
		"rain_bonus": 6,
		"max_per_world": 12,
		"min_spacing": 1,
		"pickable_by_hand": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"mushroom",
		"drop_amount": Vector2i(1, 1),
	})


## 建一个野生植被资源并挂上阶段图。
func _flora(
	flora_id: StringName,
	name_key: StringName,
	kind: FloraData.Kind,
	days_per_stage: Array,
	overrides: Dictionary
) -> void:
	var data := FloraData.new()
	data.id = flora_id
	data.display_name_key = name_key
	data.kind = kind
	data.days_per_stage.clear()
	for days: int in days_per_stage:
		data.days_per_stage.append(days)
	# 注意：spawn_weight 是 Array[int]。Object.set() 对"类型化数组"会静默失败
	# （赋进去的是无类型 Array，属性保持默认值），所以这里必须逐项 append。
	if overrides.has("spawn_weight"):
		data.spawn_weight.clear()
		for weight: int in overrides["spawn_weight"]:
			data.spawn_weight.append(weight)
	for key: String in overrides:
		if key == "spawn_weight":
			continue
		data.set(key, overrides[key])
	data.sprite_sheet = _flora_sheet(flora_id)
	_save(data, FLORA_DIR.path_join("%s.tres" % flora_id))


## 取野生植被的阶段表。
func _flora_sheet(flora_id: StringName) -> Texture2D:
	return _texture(FLORA_SHEET_DIR.path_join("%s.png" % flora_id))
