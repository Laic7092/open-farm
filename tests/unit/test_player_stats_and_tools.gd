extends GdUnitTestSuite
## 体力与工具腰带测试。


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


# ---------------------------------------------------------------- ToolBelt

func test_belt_starts_on_first_tool() -> void:
	var belt := ToolBelt.new([&"hoe", &"watering_can"])
	assert_int(belt.selected_index()).is_equal(0)
	assert_that(String(belt.selected_id())).is_equal("hoe")


func test_belt_next_and_prev_wrap_around() -> void:
	var belt := ToolBelt.new([&"hoe", &"watering_can", &"sickle"])
	belt.next()
	assert_str(String(belt.selected_id())).is_equal("watering_can")
	belt.next()
	belt.next()
	assert_str(String(belt.selected_id())).is_equal("hoe")
	belt.prev()
	assert_str(String(belt.selected_id())).is_equal("sickle")


func test_single_tool_belt_does_not_move() -> void:
	var belt := ToolBelt.new([&"hoe"])
	belt.next()
	belt.prev()
	assert_int(belt.selected_index()).is_equal(0)


func test_empty_belt_has_no_selection() -> void:
	var belt := ToolBelt.new()
	assert_int(belt.selected_index()).is_equal(-1)
	assert_that(belt.selected_id()).is_equal(&"")
	assert_object(belt.selected_tool()).is_null()


func test_belt_resolves_tool_data_from_database() -> void:
	var belt := ToolBelt.new([&"watering_can"])
	var tool := belt.selected_tool()
	assert_object(tool).is_not_null()
	if tool != null:
		assert_int(tool.kind).is_equal(ToolData.Kind.WATERING_CAN)


func test_add_is_idempotent() -> void:
	var belt := ToolBelt.new([&"hoe"])
	assert_bool(belt.add(&"hoe")).is_false()
	assert_bool(belt.add(&"sickle")).is_true()
	assert_bool(belt.has(&"sickle")).is_true()
	assert_array(belt.tool_ids).has_size(2)


func test_select_by_id() -> void:
	var belt := ToolBelt.new([&"hoe", &"sickle"])
	assert_bool(belt.select_by_id(&"sickle")).is_true()
	assert_str(String(belt.selected_id())).is_equal("sickle")
	assert_bool(belt.select_by_id(&"nope")).is_false()


func test_tool_belt_serialization_roundtrip() -> void:
	var belt := ToolBelt.new([&"hoe", &"watering_can", &"sickle"])
	belt.select(2)
	var restored := ToolBelt.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(belt.to_dict())))
	assert_array(restored.tool_ids).has_size(3)
	assert_int(restored.selected_index()).is_equal(2)
