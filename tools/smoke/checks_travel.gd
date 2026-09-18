extends "res://tools/smoke/smoke_base.gd"
## 跨地图巡游 / NPC / 出口 的冒烟检查；公共断言 / 取用器见 smoke_base.gd。

## 集市：村庄与海滩之间的一站，石板广场 + 水塘，没有常驻 NPC。
func _check_town() -> void:
	var world := _world()
	_check(world != null, "集市场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "town", "切换后应当在集市")
	_check_eq(String(_scene_audio().current_bgm()), "town", "白天进集市应当换成小镇 BGM")
	_check(_player() != null, "集市里应当有玩家")
	_check(_farm_grid() == null, "集市里不应该有农场网格")
	_check(_flora_field() != null, "集市也应当有自己的野生植被")

	var spawn := _find_spawn(&"from_twon")
	_check(spawn != null, "集市应当有 from_twon 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在集市的 from_twon 出生点（实际 %s）" % player.global_position
		)
	_check(get_tree().get_nodes_in_group(Npc.GROUP).is_empty(), "集市不该常驻 NPC")

	# 集市里的池塘：水面标记应当自动挂上，并算作"池塘"。
	var water := get_tree().get_first_node_in_group(WaterField.GROUP) as WaterField
	_check(water != null, "集市也应当有水面标记")
	if water != null:
		_check(water.is_water(Vector2i(6, 20)), "集市 (6,20) 应当是池塘水面")
		_check(
			water.kind_at(Vector2i(6, 20)) == WaterKind.Kind.POND,
			"集市的水应当算作池塘"
		)

	# 池塘有碰撞体：NPC 寻路不会往水里走。
	var navigator := get_tree().get_first_node_in_group(NpcNavigator.GROUP) as NpcNavigator
	_check(navigator != null, "集市应当自动挂载 NPC 导航网格")
	if navigator != null:
		_check(not navigator.is_walkable(Vector2i(6, 20)), "池塘里应当是走不进去的")
	_check_buildings(world, {
		"Granary": "res://assets/sprites/props/barn.png",
		"Cottage": "res://assets/sprites/props/house.png",
	})
	# 集市是"村庄 ↔ 海滩"的中间站，两头都必须是能走出去的出口。
	_check_door_target(world, "ToTwon", "res://scenes/world/twon.tscn", &"from_town")
	_check_door_target(world, "ToBeach", "res://scenes/world/beach.tscn", &"from_town")

	# 在别的地图上过一天：农场不在场景树里，它的日结转钩子是注销的，
	# 所以农场的植被只能靠"重新进图时补算"追上——这正是最后一步要验证的。
	_clock.sleep_until_morning()


func _check_twon() -> void:
	var world := _world()
	_check(world != null, "twon 场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "twon", "切换后应当在大场景 twon")
	_check(_player() != null, "twon 里应当有玩家")
	_check(_farm_grid() == null, "twon 里不应该有农场网格")
	_check(_flora_field() != null, "twon 也应当有自己的野生植被")

	# 村庄里的河沟同样是可垂钓的池塘。
	var water := get_tree().get_first_node_in_group(WaterField.GROUP) as WaterField
	_check(water != null, "twon 也应当有水面标记")
	if water != null:
		_check(
			water.kind_at(Vector2i(24, 43)) == WaterKind.Kind.POND,
			"twon (24,43) 应当是池塘水面"
		)

	var limits: Rect2 = world.get(&"camera_limits")
	_check(
		limits.size.x >= 1280.0 and limits.size.y >= 720.0,
		"twon 应当是一个大地图（实际 %s）" % limits.size
	)
	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(
		ground != null and ground.get_used_cells().size() > 0,
		"twon 地面应当已绘制瓦片"
	)

	var spawn := _find_spawn(&"from_farm")
	_check(spawn != null, "twon 应当有 from_farm 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在 twon 的 from_farm 出生点（实际 %s）" % player.global_position
		)

	var npc_ids: Dictionary = {}
	for npc: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		npc_ids[npc.get(&"npc_id")] = true
	_check(npc_ids.has(&"merchant"), "twon 应当包含商人 NPC")
	_check(npc_ids.has(&"mayor"), "twon 应当包含村长 NPC")
	_check(npc_ids.has(&"blacksmith"), "twon 应当包含铁匠 NPC")
	_check(npc_ids.has(&"florist"), "twon 应当包含花匠 NPC")
	_check(npc_ids.has(&"child"), "twon 应当包含小女孩 NPC")

	_check(_find_schedule_point(&"forge") != null, "twon 应当有 forge 日程地点")
	_check(_find_schedule_point(&"flower_shop") != null, "twon 应当有 flower_shop 日程地点")
	_check(_find_schedule_point(&"garden") != null, "twon 应当有 garden 日程地点")
	_check(_find_schedule_point(&"home") != null, "twon 应当有 home 日程地点")

	# 节日会场：非节日当天应当收摊（不能交互）。
	var plaza := world.find_child("FestivalPlaza", true, false) as FestivalGround
	_check(plaza != null, "twon 广场应当有节日会场")
	if plaza != null:
		_check(plaza.festival_ids.has(&"new_year"), "广场会场应当包含新年祭")
		_check(not plaza.can_interact(), "非节日当天会场不应该能交互")
	_check(world.find_child("FestivalGarden", true, false) != null, "twon 花园应当有节日会场")

	# 村庄是世界的枢纽：西接农场、东接集市，另有一条岔路进图书馆。
	_check_door_target(world, "ToFarm", "res://scenes/world/farm.tscn", &"from_twon")
	_check_door_target(world, "ToTown", "res://scenes/world/town.tscn", &"from_twon")
	_check_door_target(
		world, "ToLibrary", "res://scenes/world/library.tscn", &"from_twon", false
	)

	# 每栋建筑按住的人换造型：杂货铺 / 铁匠铺 / 花店 / 图书馆 / 小女孩家各一张图。
	_check_buildings(world, {
		"GeneralStore": "res://assets/sprites/props/house_merchant.png",
		"TownHall": "res://assets/sprites/props/house_mayor.png",
		"Forge": "res://assets/sprites/props/house_blacksmith.png",
		"FlowerShop": "res://assets/sprites/props/house_florist.png",
		"Library": "res://assets/sprites/props/house_librarian.png",
		"ChildHome": "res://assets/sprites/props/house_child.png",
	})

	# 柜台：杂货店与花店各一个；对话只聊天，开店改由柜台负责。
	var counter_shops: Array[StringName] = []
	for node: Node in world.find_children("*", "ShopCounter", true, false):
		var counter := node as ShopCounter
		if counter != null:
			counter_shops.append(counter.shop_id)
	_check(counter_shops.has(&"general_store"), "twon 的杂货店柜台应当存在")
	_check(counter_shops.has(&"flower_shop"), "twon 的花店柜台应当存在")

	_check_npc_schedule()


## 海滩：出生点、渔夫、栈桥 / 赶海日程点与野生植被。
func _check_beach() -> void:
	var world := _world()
	_check(world != null, "海滩场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "beach", "切换后应当在海滩")
	_check_eq(String(_scene_audio().current_bgm()), "town", "白天进海滩应当换成小镇 BGM")
	_check(_player() != null, "海滩里应当有玩家")
	_check(_farm_grid() == null, "海滩里不应该有农场网格")
	_check(_flora_field() != null, "海滩也应当有自己的野生植被")

	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(ground != null and ground.get_used_cells().size() > 0, "海滩地面应当已绘制瓦片")

	var spawn := _find_spawn(&"from_town")
	_check(spawn != null, "海滩应当有 from_town 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在海滩的 from_town 出生点（实际 %s）" % player.global_position
		)

	_check_door_target(world, "ToTown", "res://scenes/world/town.tscn", &"from_beach")
	_check_door_target(world, "ToMine", "res://scenes/world/mine.tscn", &"from_beach")

	_check(_find_npc(&"fisher") != null, "海滩应当有渔夫 NPC")
	_check_buildings(world, {"Hut": "res://assets/sprites/props/house_fisher.png"})
	_check(_find_schedule_point(&"pier") != null, "海滩应当有 pier 日程地点")
	_check(_find_schedule_point(&"shore") != null, "海滩应当有 shore 日程地点")
	_check_npc_can_reach(&"fisher", &"pier")

	# 水面有碰撞体：海里走不进去，木栈桥那截仍然上得去。
	var navigator := get_tree().get_first_node_in_group(NpcNavigator.GROUP) as NpcNavigator
	_check(navigator != null, "海滩应当自动挂载 NPC 导航网格")
	if navigator != null:
		_check(
			not navigator.is_walkable(Vector2i(6, 24)),
			"海里应当是走不进去的（水面碰撞体）"
		)
		_check(navigator.is_walkable(Vector2i(19, 24)), "木栈桥上应当能走")


## 矿洞：无天气、矿工、矿道 / 营地日程点。
func _check_mine() -> void:
	var world := _world()
	_check(world != null, "矿洞场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "mine", "切换后应当在矿洞")
	_check(_player() != null, "矿洞里应当有玩家")
	_check(_farm_grid() == null, "矿洞里不应该有农场网格")
	var mine_field := _flora_field()
	_check(mine_field != null, "矿洞也应当有自己的野生植被")
	_check(mine_field == null or mine_field.count_of(&"tree_oak") == 0, "矿洞不应该长出阔叶树")
	_check(mine_field == null or mine_field.count_of(&"tree_pine") == 0, "矿洞不应该长出松树")
	_check(world.get(&"weather_effects") == false, "矿洞不应下雨下雪")

	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(ground != null and ground.get_used_cells().size() > 0, "矿洞地面应当已绘制瓦片")

	var spawn := _find_spawn(&"from_beach")
	_check(spawn != null, "矿洞应当有 from_beach 出生点")

	_check_door_target(world, "ToBeach", "res://scenes/world/beach.tscn", &"from_mine")

	_check(_find_npc(&"miner") != null, "矿洞应当有矿工 NPC")
	_check_buildings(world, {"Camp": "res://assets/sprites/props/house_miner.png"})
	_check(_find_schedule_point(&"mine_deep") != null, "矿洞应当有 mine_deep 日程地点")
	_check(_find_schedule_point(&"camp") != null, "矿洞应当有 camp 日程地点")
	_check_npc_can_reach(&"miner", &"mine_entrance")


## 图书馆：室内木地板、没有野生植被、管理员在岗。
func _check_library() -> void:
	var world := _world()
	_check(world != null, "图书馆场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "library", "切换后应当在图书馆")
	_check_eq(String(_scene_audio().current_bgm()), "town", "进图书馆应当播放小镇 BGM")
	_check(_player() != null, "图书馆里应当有玩家")
	_check(_flora_field() == null, "室内图书馆不应该有野生植被")
	_check(world.get(&"weather_effects") == false, "室内不应下雨下雪")

	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(ground != null and ground.get_used_cells().size() > 0, "图书馆地面应当已绘制瓦片")

	var spawn := _find_spawn(&"from_twon")
	_check(spawn != null, "图书馆应当有 from_twon 出生点")

	_check(_find_npc(&"librarian") != null, "图书馆应当有管理员 NPC")
	_check(_find_schedule_point(&"desk") != null, "图书馆应当有 desk 日程地点")
	_check(_find_schedule_point(&"shelves") != null, "图书馆应当有 shelves 日程地点")
	_check_door_target(
		world, "ToTwon", "res://scenes/world/twon.tscn", &"from_library", false
	)
	_check_npc_can_reach(&"librarian", &"desk")
	_check_relationships()


## 关系系统的端到端检查：聊天 / 送礼 / 表白 / 结婚能真实串起来。
##
## 这里直接驱动 [code]RelationshipService[/code]，不调用 [method Npc.interact]——
## 后者会弹出对话框并暂停场景树，把冒烟测试的主循环一起冻住。
func _check_relationships() -> void:
	var npc := _find_npc(&"librarian")
	_check(npc != null, "图书馆应当有可攻略 NPC 书雅")
	if npc == null:
		return
	var before := _relationships.affection(&"librarian")
	_check(_relationships.talk(&"librarian") > 0, "首次聊天应当获得好感")
	_check(_relationships.affection(&"librarian") > before, "聊天后好感应当上升")
	_check(
		_relationships.give_gift(&"librarian", &"flower") > 0,
		"野花应当是书雅喜欢的礼物"
	)
	_relationships.set_affection(&"librarian", 250)
	_check(_relationships.confess(&"librarian"), "好感达标后应当可以表白")
	_check(_relationships.marry(&"librarian"), "交往后应当可以结婚")
	_check(_relationships.is_married(), "结婚后应当记录配偶")
	_check_eq(npc.current_dialogue().id, &"librarian_married", "婚后应当使用婚后对白")
	# 复位，避免影响后续检查。
	_relationships.reset()


## 日程 + 寻路的端到端检查：导航网格可用、两个 NPC 有日程、路径能算出来。
func _check_npc_schedule() -> void:
	var navigator := get_tree().get_first_node_in_group(NpcNavigator.GROUP) as NpcNavigator
	_check(navigator != null, "twon 应当自动挂载 NPC 导航网格")
	_check(_find_schedule_point(&"store") != null, "twon 应当有 store 日程地点")

	if navigator != null:
		var from: Vector2i = navigator.cell_of(Vector2(40, 488))
		var to: Vector2i = navigator.cell_of(Vector2(432, 496))
		_check(navigator.is_walkable(from), "村庄西口应当是可行走格")
		_check(navigator.is_walkable(to), "商店门口应当是可行走格")
		var path := navigator.find_path(from, to)
		_check(not path.is_empty(), "从农场入口到商店应当能找到路径")
		if not path.is_empty():
			_check_eq(path[0], from, "路径应当从起点开始")
			_check_eq(path[path.size() - 1], to, "路径应当以终点结束")

	# 06:00：商人应当在商店、村长应当在镇公所。
	_check_npc_at(&"merchant", &"store")
	_check_npc_at(&"mayor", &"town_hall")


func _check_npc_at(npc_id: StringName, location_id: StringName) -> void:
	var npc := _find_npc(npc_id)
	_check(npc != null, "twon 应当有 NPC %s" % npc_id)
	if npc == null:
		return
	_check(npc.data != null and npc.data.schedule != null, "NPC %s 应当有日程" % npc_id)
	_check_eq(
		String(npc.target_location_id()),
		String(location_id),
		"NPC %s 在 06:00 的目标地点" % npc_id
	)


## 记下 NPC 当前坐标，等几帧后确认它们确实动过。
func _record_npc_positions() -> void:
	_npc_positions.clear()
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null:
			_npc_positions[npc.npc_id] = npc.global_position


func _check_npcs_moved() -> void:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null:
			continue
		var start: Variant = _npc_positions.get(npc.npc_id, null)
		if start is Vector2:
			_check(
				npc.global_position.distance_to(start) > 0.5,
				"NPC %s 应当按日程走起来（起点 %s，现在 %s）"
					% [npc.npc_id, start, npc.global_position]
			)


## 导航可达性：NPC 附近有可走格，并且能算出到目标日程点的路径。
func _check_npc_can_reach(npc_id: StringName, location_id: StringName) -> void:
	var navigator := get_tree().get_first_node_in_group(NpcNavigator.GROUP) as NpcNavigator
	_check(navigator != null, "NPC %s 所在场景应当自动挂载导航网格" % npc_id)
	if navigator == null:
		return
	var npc := _find_npc(npc_id)
	var point := _find_schedule_point(location_id)
	_check(npc != null and point != null, "NPC %s 与地点 %s 应当存在" % [npc_id, location_id])
	if npc == null or point == null:
		return
	var start := navigator.nearest_walkable(navigator.cell_of(npc.global_position))
	var goal := navigator.nearest_walkable(navigator.cell_of(point.global_position))
	_check(start != NpcNavigator.NO_CELL, "NPC %s 附近应当有可走格" % npc_id)
	_check(goal != NpcNavigator.NO_CELL, "日程地点 %s 应当可走" % location_id)
	if start == NpcNavigator.NO_CELL or goal == NpcNavigator.NO_CELL:
		return
	_check(
		not navigator.find_path(start, goal).is_empty(),
		"NPC %s 应当能走到 %s" % [npc_id, location_id]
	)


## 把玩家直接放进农场东口的传送区：这里靠 [code]SceneDoor.auto_enter[/code] 换图，
## 不需要按 E，也不该被"必须先按一下交互键"的实现悄悄破坏。
func _walk_into_exit() -> void:
	var world := _world()
	var player := _player()
	var door: SceneDoor = null
	if world != null:
		door = world.find_child("ToTwon", true, false) as SceneDoor
	_check(door != null and player != null, "农场应当有 ToTwon 出口与玩家")
	if door == null or player == null:
		return
	player.global_position = door.global_position


## 无缝出口的结果：人已经在村庄的 from_farm 出生点上。
func _check_edge_travel() -> void:
	var world := _world()
	_check(world != null, "走过农场东口后应当换到新地图")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "twon", "走进农场东口应当直接到村庄")
	var spawn := _find_spawn(&"from_farm")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"从农场东口走进村庄应当落在 from_farm 出生点（实际 %s）" % player.global_position
		)
