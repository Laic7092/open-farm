extends GdUnitTestSuite
## 数据仓库测试：示例数据是否齐全、能否按 id 取到、自检是否通过。


func test_all_expected_crops_are_loaded() -> void:
	assert_bool(Database.crops().has(&"turnip")).is_true()
	assert_bool(Database.crops().has(&"potato")).is_true()
	assert_bool(Database.crops().has(&"tomato")).is_true()


## v0.5「内容广度」：每季必须有 6 种可种作物。
func test_every_season_has_six_crops() -> void:
	var per_season: Dictionary[int, int] = {}
	for crop_id: StringName in Database.crops():
		var crop := Database.get_crop(crop_id)
		for season: Season.Type in crop.seasons:
			per_season[int(season)] = per_season.get(int(season), 0) + 1
	for season: Season.Type in Season.all():
		assert_int(per_season.get(int(season), 0)).override_failure_message(
			"%s 只有 %d 种作物（每季应有 6 种）"
				% [Text.season_name(season), per_season.get(int(season), 0)]
		).is_equal(6)


func test_all_expected_flora_are_loaded() -> void:
	for flora_id: StringName in [
		&"tree_oak", &"tree_pine", &"weed", &"rock", &"boulder", &"flower", &"mushroom"
	]:
		assert_object(Database.get_flora(flora_id)).override_failure_message(
			"缺少野生植被 %s" % flora_id
		).is_not_null()


func test_all_expected_tools_are_loaded() -> void:
	for tool_id: StringName in [
		&"hoe", &"watering_can", &"sickle", &"axe", &"pickaxe", &"fishing_rod"
	]:
		assert_object(Database.get_tool(tool_id)).override_failure_message(
			"缺少工具 %s" % tool_id
		).is_not_null()


func test_shops_and_npcs_are_loaded() -> void:
	for shop_id: StringName in [&"general_store", &"flower_shop"]:
		assert_object(Database.get_shop(shop_id)).override_failure_message(
			"缺少商店 %s" % shop_id
		).is_not_null()
	for npc_id: StringName in [
		&"merchant", &"mayor", &"blacksmith", &"florist", &"fisher", &"miner",
		&"child", &"librarian",
	]:
		assert_object(Database.get_npc(npc_id)).override_failure_message(
			"缺少 NPC %s" % npc_id
		).is_not_null()


## 新增内容后，每一个 NPC 都要有可解析的名字、对白与动画。
func test_every_npc_has_name_dialogue_and_frames() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		assert_str(String(npc.display_name_key)).override_failure_message(
			"NPC %s 缺少名字键" % npc_id
		).is_not_empty()
		assert_object(npc.default_dialogue).override_failure_message(
			"NPC %s 缺少默认对白" % npc_id
		).is_not_null()
		assert_object(npc.frames).override_failure_message(
			"NPC %s 缺少动画" % npc_id
		).is_not_null()


## 花店必须有真实在售道具，否则打开界面会是空的。
func test_flower_shop_sells_real_items() -> void:
	var shop := Database.get_shop(&"flower_shop")
	assert_object(shop).is_not_null()
	if shop == null:
		return
	assert_array(shop.stock).is_not_empty()


func test_lookup_by_missing_id_returns_null() -> void:
	assert_object(Database.get_crop(&"nope")).is_null()
	assert_object(Database.get_item(&"nope")).is_null()
	assert_object(Database.get_tool(&"nope")).is_null()


func test_validate_all_reports_no_problems() -> void:
	var problems := Database.validate_all()
	assert_array(problems).is_empty()


func test_every_crop_seed_points_at_a_real_item() -> void:
	for crop_id: StringName in Database.crops():
		var crop := Database.get_crop(crop_id)
		assert_object(Database.get_item(crop.seed_item_id)).is_not_null()
		assert_object(Database.get_item(crop.harvest_item_id)).is_not_null()


func test_every_seed_item_points_at_a_real_crop() -> void:
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		if item.category != ItemData.Category.SEED:
			continue
		assert_object(Database.get_crop(item.crop_id)).is_not_null()


func test_every_tool_item_points_at_a_real_tool() -> void:
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		if item.category != ItemData.Category.TOOL:
			continue
		assert_object(Database.get_tool(item.tool_id)).is_not_null()


func test_shop_stock_only_sells_known_items() -> void:
	for shop_id: StringName in Database.shops():
		var shop := Database.get_shop(shop_id)
		for entry: ShopStock in shop.stock:
			assert_object(Database.get_item(entry.item_id)).is_not_null()


## 野生植被的产出必须指向真实道具，否则砍树时背包会收到一个不存在的 id。
func test_every_flora_drop_points_at_a_real_item() -> void:
	for flora_id: StringName in Database.floras():
		var data := Database.get_flora(flora_id)
		if data.drop_item_id == &"":
			continue
		assert_object(Database.get_item(data.drop_item_id)).override_failure_message(
			"野生植被 %s 的产出 %s 不存在" % [flora_id, data.drop_item_id]
		).is_not_null()


func test_npc_shop_references_exist() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		if not npc.is_merchant():
			continue
		assert_object(Database.get_shop(npc.shop_id)).is_not_null()


func test_npc_dialogue_is_resolvable_in_every_season() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		for season: Season.Type in Season.all():
			var dialogue := npc.dialogue_for_season(season)
			assert_object(dialogue).is_not_null()
			assert_bool(dialogue.is_empty()).is_false()


## 可攻略 NPC 必须配齐表白 / 求婚 / 恋人 / 婚后 / 朋友对白。
func test_romance_candidates_are_fully_configured() -> void:
	var found := 0
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		if not npc.romanceable:
			continue
		found += 1
		assert_object(npc.friend_dialogue).override_failure_message(
			"可攻略 NPC %s 缺少朋友对白" % npc_id
		).is_not_null()
		assert_object(npc.lover_dialogue).override_failure_message(
			"可攻略 NPC %s 缺少恋人好感对白" % npc_id
		).is_not_null()
		assert_object(npc.married_dialogue).override_failure_message(
			"可攻略 NPC %s 缺少婚后对白" % npc_id
		).is_not_null()
		assert_object(npc.confession_dialogue).override_failure_message(
			"可攻略 NPC %s 缺少表白对白" % npc_id
		).is_not_null()
		assert_object(npc.proposal_dialogue).override_failure_message(
			"可攻略 NPC %s 缺少求婚对白" % npc_id
		).is_not_null()
		assert_bool(npc.confession_affection <= npc.marriage_affection).is_true()
		assert_bool(npc.marriage_affection <= npc.max_affection).is_true()
	assert_int(found).override_failure_message("至少要有 1 位可攻略 NPC").is_greater(0)


## 小孩不能成为恋爱对象。
func test_child_npcs_are_not_romanceable() -> void:
	for npc_id: StringName in [&"child", &"our_child"]:
		var npc := Database.get_npc(npc_id)
		assert_object(npc).is_not_null()
		if npc != null:
			assert_bool(npc.romanceable).override_failure_message(
				"NPC %s 不应可攻略" % npc_id
			).is_false()


## 礼物偏好表里出现的道具必须真实存在。
func test_romance_gift_preferences_reference_real_items() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		_assert_items_exist(npc_id, npc.loved_gifts)
		_assert_items_exist(npc_id, npc.liked_gifts)
		_assert_items_exist(npc_id, npc.disliked_gifts)


func _assert_items_exist(npc_id: StringName, item_ids: Array[StringName]) -> void:
	for item_id: StringName in item_ids:
		assert_object(Database.get_item(item_id)).override_failure_message(
			"NPC %s 的礼物 %s 不存在" % [npc_id, item_id]
		).is_not_null()


## 求婚信物必须是 GIFT 分类，且不能被卖掉。
func test_blue_feather_is_the_proposal_gift() -> void:
	var item := Database.get_item(AffectionRules.PROPOSAL_ITEM)
	assert_object(item).is_not_null()
	if item == null:
		return
	assert_int(item.category).is_equal(ItemData.Category.GIFT)
	assert_bool(item.sellable).is_false()


# ---------------------------------------------------------------- 钓鱼

func test_expected_fish_are_loaded() -> void:
	for fish_id: StringName in [
		&"sardine", &"mackerel", &"sea_bream", &"squid", &"octopus", &"tuna",
		&"crucian", &"carp", &"catfish", &"golden_carp",
	]:
		assert_object(Database.get_fish(fish_id)).override_failure_message(
			"缺少鱼种 %s" % fish_id
		).is_not_null()


## 每条鱼都要能变成背包里一件真实且可出货的道具，否则钓上来会凭空消失。
func test_every_fish_points_at_a_real_sellable_item() -> void:
	for fish_id: StringName in Database.fish():
		var fish := Database.get_fish(fish_id)
		var item := Database.get_item(fish.item_id)
		assert_object(item).override_failure_message(
			"鱼 %s 的产出 %s 不存在" % [fish_id, fish.item_id]
		).is_not_null()
		if item != null:
			assert_bool(item.sellable).override_failure_message(
				"鱼 %s 应当可以出货" % fish_id
			).is_true()


## 钓竿必须同时接上工具与道具，否则物品栏里选不到它。
func test_fishing_rod_wires_tool_and_item() -> void:
	var tool := Database.get_tool(&"fishing_rod")
	assert_object(tool).is_not_null()
	if tool == null:
		return
	assert_int(tool.kind).is_equal(ToolData.Kind.FISHING)
	assert_bool(tool.targets_water()).is_true()
	assert_bool(tool.targets_ground()).is_false()
	var item := Database.get_item(&"fishing_rod")
	assert_object(item).is_not_null()
	if item != null:
		assert_str(String(item.tool_id)).is_equal("fishing_rod")


## 每个 NPC 都要有能覆盖全天 24 小时的日程（凌晨靠循环回退到最后一段）。
func test_every_npc_has_a_full_day_schedule() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		assert_object(npc.schedule).override_failure_message(
			"NPC %s 没有日程" % npc_id
		).is_not_null()
		if npc.schedule == null:
			continue
		assert_bool(npc.schedule.is_empty()).is_false()
		for hour: int in 24:
			assert_object(npc.schedule.entry_at(hour * 60)).override_failure_message(
				"NPC %s 在 %02d:00 没有生效的日程" % [npc_id, hour]
			).is_not_null()


## 商人得在白天待在店里，不然玩家永远打不开商店。
func test_merchant_is_on_shift_during_the_day() -> void:
	var merchant := Database.get_npc(&"merchant")
	assert_object(merchant).is_not_null()
	if merchant == null or merchant.schedule == null:
		return
	assert_str(String(merchant.schedule.entry_at(10 * 60).activity)).is_equal("shop")


func test_reload_is_idempotent() -> void:
	var before: int = Database.total_count()
	Database.reload()
	assert_int(Database.total_count()).is_equal(before)


# ---------------------------------------------------------------- 畜牧

func test_expected_animals_and_buildings_are_loaded() -> void:
	for animal_id: StringName in [&"chicken", &"cow"]:
		assert_object(Database.get_animal(animal_id)).override_failure_message(
			"缺少动物 %s" % animal_id
		).is_not_null()
	for building_id: StringName in [&"coop", &"barn"]:
		assert_object(Database.get_building(building_id)).override_failure_message(
			"缺少畜舍 %s" % building_id
		).is_not_null()


func test_every_animal_product_and_feed_points_at_real_items() -> void:
	for animal_id: StringName in Database.animals():
		var animal := Database.get_animal(animal_id)
		assert_object(Database.get_item(animal.product_item_id)).override_failure_message(
			"动物 %s 的产出 %s 不存在" % [animal_id, animal.product_item_id]
		).is_not_null()
		assert_object(Database.get_item(animal.feed_item_id)).override_failure_message(
			"动物 %s 的饲料 %s 不存在" % [animal_id, animal.feed_item_id]
		).is_not_null()


func test_every_animal_item_points_at_a_real_animal() -> void:
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		if item.category != ItemData.Category.ANIMAL:
			continue
		assert_object(Database.get_animal(item.animal_id)).override_failure_message(
			"牲畜道具 %s 指向不存在的动物 %s" % [item_id, item.animal_id]
		).is_not_null()


func test_every_building_accepts_a_known_species() -> void:
	var species: Dictionary[StringName, bool] = {}
	for animal_id: StringName in Database.animals():
		species[Database.get_animal(animal_id).species] = true
	for building_id: StringName in Database.buildings():
		var building := Database.get_building(building_id)
		for value: StringName in building.allowed_species:
			assert_bool(species.has(value)).override_failure_message(
				"畜舍 %s 允许未知物种 %s" % [building_id, value]
			).is_true()
