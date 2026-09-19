extends GdUnitTestSuite
## 体力与物品栏测试。


func test_stats_start_full() -> void:
	var stats := PlayerStats.new(50)
	assert_int(stats.max_stamina).is_equal(50)
	assert_int(stats.stamina).is_equal(50)
	assert_bool(stats.exhausted).is_false()


func test_max_stamina_is_at_least_one() -> void:
	assert_int(PlayerStats.new(0).max_stamina).is_equal(1)


func test_consume_deducts_stamina() -> void:
	var stats := PlayerStats.new(10)
	assert_bool(stats.consume(4)).is_true()
	assert_int(stats.stamina).is_equal(6)
	assert_bool(stats.exhausted).is_false()


func test_consume_fails_when_insufficient() -> void:
	var stats := PlayerStats.new(3)
	assert_bool(stats.consume(5)).is_false()
	assert_int(stats.stamina).is_equal(3)


func test_consume_to_zero_marks_exhausted() -> void:
	var stats := PlayerStats.new(5)
	assert_bool(stats.consume(5)).is_true()
	assert_bool(stats.exhausted).is_true()
	assert_bool(stats.can_work()).is_false()


func test_consume_zero_is_a_no_op() -> void:
	var stats := PlayerStats.new(5)
	assert_bool(stats.consume(0)).is_true()
	assert_int(stats.stamina).is_equal(5)


func test_restore_clamps_to_max_and_clears_exhaustion() -> void:
	var stats := PlayerStats.new(10)
	stats.consume(10)
	stats.restore(4)
	assert_int(stats.stamina).is_equal(4)
	assert_bool(stats.exhausted).is_false()
	stats.restore(999)
	assert_int(stats.stamina).is_equal(10)


func test_ratio() -> void:
	var stats := PlayerStats.new(10)
	stats.consume(5)
	assert_float(stats.ratio()).is_equal_approx(0.5, 0.001)


func test_deplete_forces_zero() -> void:
	var stats := PlayerStats.new(10)
	stats.deplete()
	assert_int(stats.stamina).is_equal(0)
	assert_bool(stats.exhausted).is_true()


func test_serialization_roundtrip() -> void:
	var stats := PlayerStats.new(80)
	stats.consume(30)
	var restored := PlayerStats.new(1)
	restored.from_dict(stats.to_dict())
	assert_int(restored.max_stamina).is_equal(80)
	assert_int(restored.stamina).is_equal(50)


func test_from_dict_clamps_out_of_range_values() -> void:
	var stats := PlayerStats.new(10)
	stats.from_dict({"max_stamina": 20, "stamina": 999})
	assert_int(stats.stamina).is_equal(20)


# ---------------------------------------------------------------- ItemBar

func test_item_bar_maps_to_the_front_of_the_backpack() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"hoe", 1)
	var bar := ItemBar.new(inventory)
	assert_int(bar.visible_count()).is_equal(4)
	assert_int(bar.slot_index(0)).is_equal(0)
	assert_int(bar.slot_index(3)).is_equal(3)
	assert_int(bar.slot_index(4)).is_equal(-1)
	assert_str(String(bar.selected_item_id())).is_equal("hoe")


func test_item_bar_starts_on_the_first_tool() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"turnip", 3)
	inventory.add(&"hoe", 1)
	inventory.add(&"watering_can", 1)
	var bar := ItemBar.new(inventory)
	assert_int(bar.hand_index()).is_equal(1)
	assert_str(String(bar.selected_item_id())).is_equal("hoe")


func test_item_bar_next_and_prev_skip_non_tools_and_wrap() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"hoe", 1)
	inventory.add(&"turnip", 2)
	inventory.add(&"watering_can", 1)
	inventory.add(&"sickle", 1)
	var bar := ItemBar.new(inventory)
	bar.next()
	assert_str(String(bar.selected_item_id())).is_equal("watering_can")
	bar.next()
	assert_str(String(bar.selected_item_id())).is_equal("sickle")
	bar.next()
	assert_str(String(bar.selected_item_id())).is_equal("hoe")
	bar.prev()
	assert_str(String(bar.selected_item_id())).is_equal("sickle")


func test_item_bar_with_a_single_tool_does_not_move() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"hoe", 1)
	var bar := ItemBar.new(inventory)
	bar.next()
	bar.prev()
	assert_int(bar.hand_index()).is_equal(0)


func test_item_bar_without_tools_has_no_hand() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 1)
	var bar := ItemBar.new(inventory)
	assert_int(bar.hand_index()).is_equal(-1)
	assert_str(String(bar.selected_item_id())).is_equal("")
	assert_object(bar.selected_tool()).is_null()


func test_item_bar_resolves_tool_data_from_database() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"watering_can", 1)
	var tool := ItemBar.new(inventory).selected_tool()
	assert_object(tool).is_not_null()
	if tool != null:
		assert_int(tool.kind).is_equal(ToolData.Kind.WATERING_CAN)


func test_item_bar_refuses_to_select_non_tools() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 2)
	inventory.add(&"hoe", 1)
	var bar := ItemBar.new(inventory)
	assert_bool(bar.select(0)).is_false()
	assert_int(bar.hand_index()).is_equal(1)
	assert_bool(bar.select(1)).is_true()
	assert_str(String(bar.selected_item_id())).is_equal("hoe")


func test_item_bar_treats_seeds_as_usable() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"hoe", 1)
	inventory.add(&"turnip_seed", 5)
	var bar := ItemBar.new(inventory)
	assert_bool(bar.select(1)).is_true()
	assert_int(bar.hand_index()).is_equal(1)
	assert_str(String(bar.selected_item_id())).is_equal("turnip_seed")
	assert_str(String(bar.selected_seed_id())).is_equal("turnip_seed")
	# 换成工具后就不再是种子。
	bar.select(0)
	assert_str(String(bar.selected_seed_id())).is_equal("")
	assert_object(bar.selected_tool()).is_not_null()


func test_item_bar_serialization_roundtrip() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"hoe", 1)
	inventory.add(&"turnip", 1)
	inventory.add(&"watering_can", 1)
	var bar := ItemBar.new(inventory)
	bar.select(2)

	var restored_inventory := Inventory.new(6)
	restored_inventory.add(&"hoe", 1)
	restored_inventory.add(&"turnip", 1)
	restored_inventory.add(&"watering_can", 1)
	var restored := ItemBar.new(restored_inventory)
	restored.from_dict(JSON.parse_string(JSON.stringify(bar.to_dict())))
	assert_int(restored.hand_index()).is_equal(2)
	assert_str(String(restored.selected_item_id())).is_equal("watering_can")
