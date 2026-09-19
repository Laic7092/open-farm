extends GdUnitTestSuite
## 料理测试：食谱数据、材料判定、背包容量与"扣材料 + 出成品"的绑定。
##
## 这里最要紧的两条：
## [br]- 背包放不下时不能先把材料吞掉（[method Cooking.cook] 先问容量）；
## [br]- 解锁旗标没打上时不能做（长期目标的奖励才有意义）。


func test_database_exposes_recipes_with_real_items() -> void:
	assert_bool(Database.recipes().size() > 0).override_failure_message("应当有食谱数据").is_true()
	for recipe: RecipeData in Database.recipe_list():
		assert_object(Database.get_item(recipe.output_item_id)).override_failure_message(
			"食谱 %s 的成品 %s 不存在" % [recipe.id, recipe.output_item_id]
		).is_not_null()
		for ingredient: RecipeIngredient in recipe.ingredients:
			assert_object(Database.get_item(ingredient.item_id)).override_failure_message(
				"食谱 %s 的材料 %s 不存在" % [recipe.id, ingredient.item_id]
			).is_not_null()


# ---------------------------------------------------------------- 纯规则

func test_missing_reports_short_ingredients() -> void:
	var salad := Database.get_recipe(&"veggie_salad")
	assert_object(salad).is_not_null()
	if salad == null:
		return
	var counts: Dictionary[StringName, int] = {}
	assert_int(CookingRules.missing(salad, counts).size()).is_equal(salad.ingredients.size())

	counts[&"turnip"] = 2
	counts[&"tomato"] = 1
	assert_bool(CookingRules.can_cook(salad, counts)).is_true()


func test_room_after_ingredients_reclaims_consumed_slots() -> void:
	var salad := Database.get_recipe(&"veggie_salad")
	var output := Database.get_item(&"veggie_salad")
	var slots: Array[InventorySlot] = [InventorySlot.new(), InventorySlot.new()]
	slots[0].item_id = &"turnip"
	slots[0].count = 2
	slots[1].item_id = &"tomato"
	slots[1].count = 1

	# 材料占满两格，看起来没地方；但两格都会被吃空，成品其实放得下。
	assert_int(CookingRules.room_for(output, slots)).is_equal(0)
	assert_int(CookingRules.room_after_ingredients(salad, output, slots)).is_greater(0)


func test_room_for_counts_empty_and_stacks() -> void:
	var egg := Database.get_item(&"egg")
	var slots: Array[InventorySlot] = [InventorySlot.new()]
	# 空格按堆叠上限算：99 的上限放 99 个蛋。
	assert_int(CookingRules.room_for(egg, slots)).is_equal(egg.stack_limit)

	slots[0].item_id = &"egg"
	slots[0].count = egg.stack_limit - 1
	assert_int(CookingRules.room_for(egg, slots)).is_equal(1)

	# 别的道具占着格子时不计空间。
	slots[0].item_id = &"wood"
	assert_int(CookingRules.room_for(egg, slots)).is_equal(0)


# ---------------------------------------------------------------- 状态

func test_state_roundtrip() -> void:
	var state := CookingState.new()
	assert_bool(state.record(&"veggie_salad")).is_true()
	assert_bool(state.record(&"veggie_salad")).is_false()
	assert_int(state.times(&"veggie_salad")).is_equal(2)
	assert_int(state.known_count()).is_equal(1)

	var restored := CookingState.new()
	restored.from_dict(state.to_dict())
	assert_int(restored.times(&"veggie_salad")).is_equal(2)
	assert_bool(restored.is_known(&"veggie_salad")).is_true()


# ---------------------------------------------------------------- 单元结算

func _cook_new(profile: PlayerProfile, inventory: Inventory) -> Cooking:
	var cooking := Cooking.new()
	cooking.bind(profile, func() -> Inventory: return inventory)
	return cooking


func test_cook_deducts_ingredients_and_adds_output() -> void:
	var profile := PlayerProfile.new()
	var inventory := Inventory.new(6)
	inventory.add(&"turnip", 2)
	inventory.add(&"tomato", 1)
	var cooking := _cook_new(profile, inventory)

	assert_int(cooking.cook(&"veggie_salad")).is_equal(Cooking.Result.COOKED)
	assert_int(inventory.count_of(&"turnip")).is_equal(0)
	assert_int(inventory.count_of(&"tomato")).is_equal(0)
	assert_int(inventory.count_of(&"veggie_salad")).is_equal(1)
	assert_bool(cooking.state.is_known(&"veggie_salad")).is_true()


func test_cook_without_ingredients_leaves_bag_untouched() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 1)
	var cooking := _cook_new(PlayerProfile.new(), inventory)

	assert_int(cooking.cook(&"veggie_salad")).is_equal(Cooking.Result.MISSING)
	assert_int(inventory.count_of(&"turnip")).is_equal(1)
	assert_int(inventory.count_of(&"veggie_salad")).is_equal(0)


func test_cook_refuses_when_locked() -> void:
	var inventory := Inventory.new(8)
	inventory.add(&"pumpkin", 1)
	inventory.add(&"egg", 1)
	inventory.add(&"milk", 1)
	var cooking := _cook_new(PlayerProfile.new(), inventory)

	assert_int(cooking.cook(&"pumpkin_pie")).is_equal(Cooking.Result.LOCKED)
	assert_int(inventory.count_of(&"egg")).is_equal(1)


func test_unlock_flag_enables_locked_recipe() -> void:
	var profile := PlayerProfile.new()
	var inventory := Inventory.new(8)
	inventory.add(&"pumpkin", 1)
	inventory.add(&"egg", 1)
	inventory.add(&"milk", 1)
	var cooking := _cook_new(profile, inventory)

	profile.set_flag(&"recipe_pumpkin_pie")
	assert_int(cooking.cook(&"pumpkin_pie")).is_equal(Cooking.Result.COOKED)
	assert_int(inventory.count_of(&"pumpkin_pie")).is_equal(1)


func test_cook_reports_full_bag_without_eating_materials() -> void:
	# 两格材料都只被吃掉一部分，没有格子腾空，成品就无处可放。
	var inventory := Inventory.new(2)
	inventory.add(&"turnip", 5)
	inventory.add(&"tomato", 3)
	var cooking := _cook_new(PlayerProfile.new(), inventory)

	assert_int(cooking.cook(&"veggie_salad")).is_equal(Cooking.Result.FULL)
	assert_int(inventory.count_of(&"turnip")).is_equal(5)
	assert_int(inventory.count_of(&"tomato")).is_equal(3)
