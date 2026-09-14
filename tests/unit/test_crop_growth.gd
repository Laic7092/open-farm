extends GdUnitTestSuite
## 作物生长规则测试。
##
## 这是最"数值化"的一块逻辑，也是玩家最容易感知到 bug 的地方，
## 因此覆盖得细一些：阶段换算、干旱枯死、季节枯死、多次收获。

var _data: CropData


func before_test() -> void:
	_data = CropData.new()
	_data.id = &"test_crop"
	_data.seed_item_id = &"test_seed"
	_data.harvest_item_id = &"test_harvest"
	_data.harvest_amount = 2
	_data.days_per_stage = [1, 2, 3]
	_data.seasons = [Season.Type.SPRING] as Array[Season.Type]
	_data.days_without_water_tolerance = 1
	_data.regrow_days = 0


func _state(days: int = 0) -> CropState:
	var state := CropState.new(_data.id)
	state.days_grown = days
	return state


func test_mature_days_sums_all_stages() -> void:
	assert_int(CropGrowth.mature_days(_data)).is_equal(6)


func test_max_stage_matches_stage_count() -> void:
	assert_int(CropGrowth.max_stage(_data)).is_equal(3)


func test_stage_of_boundaries() -> void:
	assert_int(CropGrowth.stage_of(_data, 0)).is_equal(0)
	assert_int(CropGrowth.stage_of(_data, 1)).is_equal(1)
	assert_int(CropGrowth.stage_of(_data, 2)).is_equal(1)
	assert_int(CropGrowth.stage_of(_data, 3)).is_equal(2)
	assert_int(CropGrowth.stage_of(_data, 5)).is_equal(2)
	assert_int(CropGrowth.stage_of(_data, 6)).is_equal(3)


func test_is_mature() -> void:
	assert_bool(CropGrowth.is_mature(_data, 5)).is_false()
	assert_bool(CropGrowth.is_mature(_data, 6)).is_true()
	assert_bool(CropGrowth.is_mature(_data, 99)).is_true()


func test_advance_grows_when_watered() -> void:
	var state := _state()
	var result := CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(1)
	assert_bool(result[CropGrowth.KEY_STAGE_CHANGED]).is_true()
	assert_bool(result[CropGrowth.KEY_DIED]).is_false()


func test_advance_does_not_grow_without_water() -> void:
	var state := _state()
	CropGrowth.advance(_data, state, false, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(0)
	assert_int(state.days_without_water).is_equal(1)


func test_watering_resets_drought_counter() -> void:
	var state := _state()
	CropGrowth.advance(_data, state, false, Season.Type.SPRING)
	CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_int(state.days_without_water).is_equal(0)


func test_drought_kills_after_tolerance() -> void:
	var state := _state()
	CropGrowth.advance(_data, state, false, Season.Type.SPRING)
	assert_bool(state.dead).is_false()  # 一天没浇水还能撑住
	var result := CropGrowth.advance(_data, state, false, Season.Type.SPRING)
	assert_bool(state.dead).is_true()
	assert_bool(result[CropGrowth.KEY_DIED]).is_true()


func test_zero_tolerance_means_never_withers() -> void:
	_data.days_without_water_tolerance = 0
	var state := _state()
	for _i: int in 30:
		CropGrowth.advance(_data, state, false, Season.Type.SPRING)
	assert_bool(state.dead).is_false()


func test_wrong_season_kills_immediately() -> void:
	var state := _state(3)
	var result := CropGrowth.advance(_data, state, true, Season.Type.WINTER)
	assert_bool(state.dead).is_true()
	assert_bool(result[CropGrowth.KEY_DIED]).is_true()


func test_empty_season_list_means_any_season() -> void:
	_data.seasons = [] as Array[Season.Type]
	var state := _state()
	CropGrowth.advance(_data, state, true, Season.Type.WINTER)
	assert_bool(state.dead).is_false()
	assert_int(state.days_grown).is_equal(1)


func test_matured_flag_only_fires_once() -> void:
	var state := _state(5)
	var result := CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_bool(result[CropGrowth.KEY_MATURED]).is_true()
	var again := CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_bool(again[CropGrowth.KEY_MATURED]).is_false()


func test_advance_on_dead_crop_is_a_no_op() -> void:
	var state := _state(2)
	state.dead = true
	var result := CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(2)
	assert_bool(result[CropGrowth.KEY_DIED]).is_false()


func test_harvest_requires_maturity() -> void:
	var state := _state(2)
	assert_bool(CropGrowth.can_harvest(_data, state)).is_false()
	var outcome := CropGrowth.apply_harvest(_data, state)
	assert_int(int(outcome["amount"])).is_equal(0)
	assert_bool(bool(outcome["removed"])).is_false()


func test_harvest_yields_configured_amount_and_removes_crop() -> void:
	var state := _state(6)
	var outcome := CropGrowth.apply_harvest(_data, state)
	assert_str(String(outcome["item_id"])).is_equal("test_harvest")
	assert_int(int(outcome["amount"])).is_equal(2)
	assert_bool(bool(outcome["removed"])).is_true()
	assert_bool(state.dead).is_true()


func test_regrowable_crop_returns_to_the_field() -> void:
	_data.regrow_days = 2
	var state := _state(6)
	var outcome := CropGrowth.apply_harvest(_data, state)
	assert_bool(bool(outcome["removed"])).is_false()
	assert_bool(state.dead).is_false()
	assert_int(state.days_grown).is_equal(4)  # 6 - 2
	assert_bool(CropGrowth.can_harvest(_data, state)).is_false()


func test_regrow_can_be_harvested_again_after_enough_water() -> void:
	_data.regrow_days = 2
	var state := _state(6)
	CropGrowth.apply_harvest(_data, state)
	CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	CropGrowth.advance(_data, state, true, Season.Type.SPRING)
	assert_bool(CropGrowth.can_harvest(_data, state)).is_true()
	assert_int(state.harvests).is_equal(1)


func test_bonus_yield_is_deterministic_with_a_seeded_rng() -> void:
	_data.bonus_yield_chance = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := _state(6)
	var outcome := CropGrowth.apply_harvest(_data, state, rng)
	assert_int(int(outcome["amount"])).is_equal(3)  # 2 + 必定触发的额外 1


func test_crop_state_serialization_roundtrip() -> void:
	var state := _state(4)
	state.harvests = 2
	var restored := CropState.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_str(String(restored.crop_id)).is_equal("test_crop")
	assert_int(restored.days_grown).is_equal(4)
	assert_int(restored.harvests).is_equal(2)


func test_crop_data_validate_reports_problems() -> void:
	var broken := CropData.new()
	var problems := broken.validate()
	assert_array(problems).is_not_empty()
	assert_bool(problems.size() >= 3).is_true()


func test_shipped_crop_data_is_valid() -> void:
	for crop_id: StringName in Database.crops:
		var crop := Database.get_crop(crop_id)
		assert_array(crop.validate()).is_empty()
