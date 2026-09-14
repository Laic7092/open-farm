extends GdUnitTestSuite
## 数据仓库测试：示例数据是否齐全、能否按 id 取到、自检是否通过。


func test_all_expected_crops_are_loaded() -> void:
	assert_bool(Database.crops.has(&"turnip")).is_true()
	assert_bool(Database.crops.has(&"potato")).is_true()
	assert_bool(Database.crops.has(&"tomato")).is_true()


func test_all_expected_tools_are_loaded() -> void:
	for tool_id: StringName in [&"hoe", &"watering_can", &"sickle", &"seed_bag"]:
		assert_object(Database.get_tool(tool_id)).is_not_null()


func test_shops_and_npcs_are_loaded() -> void:
	assert_object(Database.get_shop(&"general_store")).is_not_null()
	assert_object(Database.get_npc(&"merchant")).is_not_null()
	assert_object(Database.get_npc(&"mayor")).is_not_null()


func test_lookup_by_missing_id_returns_null() -> void:
	assert_object(Database.get_crop(&"nope")).is_null()
	assert_object(Database.get_item(&"nope")).is_null()
	assert_object(Database.get_tool(&"nope")).is_null()


func test_validate_all_reports_no_problems() -> void:
	var problems := Database.validate_all()
	assert_array(problems).is_empty()


func test_every_crop_seed_points_at_a_real_item() -> void:
	for crop_id: StringName in Database.crops:
		var crop := Database.get_crop(crop_id)
		assert_object(Database.get_item(crop.seed_item_id)).is_not_null()
		assert_object(Database.get_item(crop.harvest_item_id)).is_not_null()


func test_every_seed_item_points_at_a_real_crop() -> void:
	for item_id: StringName in Database.items:
		var item := Database.get_item(item_id)
		if item.category != ItemData.Category.SEED:
			continue
		assert_object(Database.get_crop(item.crop_id)).is_not_null()


func test_every_tool_item_points_at_a_real_tool() -> void:
	for item_id: StringName in Database.items:
		var item := Database.get_item(item_id)
		if item.category != ItemData.Category.TOOL:
			continue
		assert_object(Database.get_tool(item.tool_id)).is_not_null()


func test_shop_stock_only_sells_known_items() -> void:
	for shop_id: StringName in Database.shops:
		var shop := Database.get_shop(shop_id)
		for entry: ShopStock in shop.stock:
			assert_object(Database.get_item(entry.item_id)).is_not_null()


func test_npc_shop_references_exist() -> void:
	for npc_id: StringName in Database.npcs:
		var npc := Database.get_npc(npc_id)
		if not npc.is_merchant():
			continue
		assert_object(Database.get_shop(npc.shop_id)).is_not_null()


func test_npc_dialogue_is_resolvable_in_every_season() -> void:
	for npc_id: StringName in Database.npcs:
		var npc := Database.get_npc(npc_id)
		for season: Season.Type in Season.all():
			var dialogue := npc.dialogue_for_season(season)
			assert_object(dialogue).is_not_null()
			assert_bool(dialogue.is_empty()).is_false()


func test_reload_is_idempotent() -> void:
	var before: int = Database.total_count()
	Database.reload()
	assert_int(Database.total_count()).is_equal(before)
