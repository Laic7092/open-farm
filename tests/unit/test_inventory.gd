extends GdUnitTestSuite
## 背包行为测试：堆叠、容量、序列化。


func test_new_inventory_is_empty() -> void:
	var inventory := Inventory.new(6)
	assert_int(inventory.capacity).is_equal(6)
	assert_array(inventory.slots).has_size(6)
	assert_int(inventory.used_slots()).is_equal(0)
	assert_bool(inventory.is_full()).is_false()


func test_capacity_is_at_least_one() -> void:
	assert_int(Inventory.new(0).capacity).is_equal(1)
	assert_int(Inventory.new(-5).capacity).is_equal(1)


func test_add_returns_zero_when_it_fits() -> void:
	var inventory := Inventory.new(4)
	assert_int(inventory.add(&"turnip", 3)).is_equal(0)
	assert_int(inventory.count_of(&"turnip")).is_equal(3)


func test_add_stacks_up_to_the_item_limit() -> void:
	var inventory := Inventory.new(1)
	# 萝卜的 stack_limit 是 99：单格装不下 150，会剩下 51。
	assert_int(inventory.add(&"turnip", 150)).is_equal(51)
	assert_int(inventory.count_of(&"turnip")).is_equal(99)
	assert_int(inventory.used_slots()).is_equal(1)


func test_add_fills_a_single_slot_up_to_its_limit() -> void:
	var inventory := Inventory.new(1)
	assert_int(inventory.add(&"turnip", 99)).is_equal(0)
	assert_int(inventory.slots[0].count).is_equal(99)


func test_add_spills_into_a_second_slot() -> void:
	var inventory := Inventory.new(2)
	inventory.add(&"turnip", 99)
	inventory.add(&"turnip", 5)
	assert_int(inventory.count_of(&"turnip")).is_equal(104)
	assert_int(inventory.used_slots()).is_equal(2)


func test_add_reports_remainder_when_full() -> void:
	var inventory := Inventory.new(1)
	var remainder := inventory.add(&"turnip", 120)
	assert_int(remainder).is_equal(21)
	assert_bool(inventory.is_full()).is_true()


func test_add_ignores_invalid_arguments() -> void:
	var inventory := Inventory.new(2)
	assert_int(inventory.add(&"", 5)).is_equal(5)
	assert_int(inventory.add(&"turnip", 0)).is_equal(0)
	assert_int(inventory.used_slots()).is_equal(0)


func test_remove_requires_enough_items() -> void:
	var inventory := Inventory.new(2)
	inventory.add(&"turnip", 3)
	assert_bool(inventory.remove(&"turnip", 4)).is_false()
	assert_int(inventory.count_of(&"turnip")).is_equal(3)


func test_remove_clears_emptied_slots() -> void:
	var inventory := Inventory.new(2)
	inventory.add(&"turnip", 3)
	assert_bool(inventory.remove(&"turnip", 3)).is_true()
	assert_int(inventory.count_of(&"turnip")).is_equal(0)
	assert_bool(inventory.slots[0].is_empty()).is_true()


func test_has_and_count_of() -> void:
	var inventory := Inventory.new(2)
	inventory.add(&"potato", 2)
	assert_bool(inventory.has(&"potato")).is_true()
	assert_bool(inventory.has(&"potato", 3)).is_false()
	assert_int(inventory.count_of(&"nope")).is_equal(0)


func test_find_slot() -> void:
	var inventory := Inventory.new(3)
	inventory.add(&"turnip", 1)
	inventory.add(&"potato", 1)
	assert_int(inventory.find_slot(&"potato")).is_equal(1)
	assert_int(inventory.find_slot(&"nope")).is_equal(-1)


func test_changed_signal_fires_once_per_add() -> void:
	var inventory := Inventory.new(3)
	var counter := [0]
	inventory.changed.connect(func() -> void: counter[0] += 1)
	inventory.add(&"turnip", 2)
	assert_int(counter[0]).is_equal(1)


func test_dictionary_keys_survive_json_roundtrip() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 7)
	inventory.add(&"wood", 2)

	var json := JSON.stringify(inventory.to_dict())
	var parsed: Variant = JSON.parse_string(json)
	assert_bool(parsed is Dictionary).is_true()

	var restored := Inventory.new(1)
	restored.from_dict(parsed)
	assert_int(restored.capacity).is_equal(4)
	assert_int(restored.count_of(&"turnip")).is_equal(7)
	assert_int(restored.count_of(&"wood")).is_equal(2)


func test_from_dict_tolerates_garbage() -> void:
	var inventory := Inventory.new(2)
	inventory.from_dict({})
	assert_int(inventory.capacity).is_equal(Inventory.DEFAULT_CAPACITY)
	assert_int(inventory.count_of(&"turnip")).is_equal(0)


func test_set_capacity_shrinks_and_grows() -> void:
	var inventory := Inventory.new(6)
	inventory.set_capacity(3)
	assert_array(inventory.slots).has_size(3)
	inventory.set_capacity(8)
	assert_array(inventory.slots).has_size(8)
	assert_bool(inventory.slots[7].is_empty()).is_true()


func test_clear_empties_every_slot() -> void:
	var inventory := Inventory.new(3)
	inventory.add(&"turnip", 5)
	inventory.clear()
	assert_int(inventory.used_slots()).is_equal(0)
