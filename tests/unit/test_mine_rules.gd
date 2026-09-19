extends GdUnitTestSuite
## 矿洞深度规则测试：电梯层、每层矿量、深度确定性、品质加成。

func _flora(flora_id: StringName, weight: int, min_depth: int, max_depth: int) -> FloraData:
	var data := FloraData.new()
	data.id = flora_id
	data.display_name_key = &"FLORA_ROCK"
	data.mine_weight = weight
	data.mine_min_depth = min_depth
	data.mine_max_depth = max_depth
	return data


func test_elevator_floors_are_multiples_of_five() -> void:
	assert_bool(MineRules.is_elevator_floor(4)).is_false()
	assert_bool(MineRules.is_elevator_floor(5)).is_true()
	assert_bool(MineRules.is_elevator_floor(100)).is_true()
	assert_int(MineRules.elevator_floor(37)).is_equal(35)
	assert_int(MineRules.elevator_floor(5)).is_equal(5)
	assert_int(MineRules.elevator_floor(1)).is_equal(0)


func test_ore_budget_grows_then_caps() -> void:
	assert_int(MineRules.ore_budget(1)).is_equal(10)
	assert_bool(MineRules.ore_budget(50) > MineRules.ore_budget(1)).is_true()
	assert_int(MineRules.ore_budget(100)).is_equal(MineRules.ore_budget(200))


func test_seed_is_stable_per_depth() -> void:
	assert_int(MineRules.seed_for(7)).is_equal(MineRules.seed_for(7))
	assert_bool(MineRules.seed_for(7) != MineRules.seed_for(8)).is_true()


func test_allows_respects_depth_window() -> void:
	var copper := _flora(&"copper_ore", 10, 1, 60)
	var gold := _flora(&"gold_ore", 4, 40, 100)
	assert_bool(MineRules.allows(copper, 1)).is_true()
	assert_bool(MineRules.allows(copper, 61)).is_false()
	assert_bool(MineRules.allows(gold, 39)).is_false()
	assert_bool(MineRules.allows(gold, 40)).is_true()
	var none := _flora(&"rock", 0, 1, 100)
	assert_bool(MineRules.allows(none, 10)).is_false()


func test_pick_ore_is_deterministic() -> void:
	var candidates: Array[FloraData] = [
		_flora(&"copper_ore", 10, 1, 100),
		_flora(&"iron_ore", 5, 1, 100),
	]
	var first := RandomNumberGenerator.new()
	first.seed = 123
	var second := RandomNumberGenerator.new()
	second.seed = 123
	assert_str(String(MineRules.pick_ore(candidates, 20, first).id)).is_equal(
		String(MineRules.pick_ore(candidates, 20, second).id)
	)


func test_quality_bonus_increases_with_depth() -> void:
	assert_bool(MineRules.quality_bonus(1) < MineRules.quality_bonus(50)).is_true()
	assert_float(MineRules.quality_bonus(100)).is_less_equal(0.4)
