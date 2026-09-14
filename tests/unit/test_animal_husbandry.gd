extends GdUnitTestSuite
## 牲畜养殖规则测试。
##
## 与作物测试对称：覆盖成年判定、产出周期、喂食 / 抚摸、
## 不喂食的惩罚，以及状态与畜舍的序列化往返。

var _data: AnimalData
var _state: AnimalState


func before_test() -> void:
	_data = AnimalData.new()
	_data.id = &"test_animal"
	_data.display_name_key = &"ANIMAL_CHICKEN"
	_data.species = &"chicken"
	_data.mature_days = 3
	_data.produce_days = 2
	_data.product_item_id = &"egg"
	_data.product_amount = 2
	_data.feed_item_id = &"hay"
	_data.max_affection = 100
	_data.affection_per_pet = 5
	_data.affection_decay_per_day = 3
	_data.bonus_affection_threshold = 80
	_data.bonus_product_chance = 0.0
	_state = AnimalState.new(_data.id)


func _adult(fed: bool = true) -> AnimalState:
	_state.days_grown = _data.mature_days
	_state.fed_today = fed
	return _state


# ---------------------------------------------------------------- 成长

func test_is_mature_at_threshold() -> void:
	assert_bool(AnimalHusbandry.is_mature(_data, _state)).is_false()
	_state.days_grown = 2
	assert_bool(AnimalHusbandry.is_mature(_data, _state)).is_false()
	_state.days_grown = 3
	assert_bool(AnimalHusbandry.is_mature(_data, _state)).is_true()
	_state.days_grown = 99
	assert_bool(AnimalHusbandry.is_mature(_data, _state)).is_true()


func test_advance_grows_regardless_of_feed() -> void:
	AnimalHusbandry.advance(_data, _state, false)
	assert_int(_state.days_grown).is_equal(1)


func test_advance_reports_maturity_once() -> void:
	_state.days_grown = 2
	var result := AnimalHusbandry.advance(_data, _state, true)
	assert_bool(bool(result[AnimalHusbandry.KEY_MATURED])).is_true()
	var again := AnimalHusbandry.advance(_data, _state, true)
	assert_bool(bool(again[AnimalHusbandry.KEY_MATURED])).is_false()


func test_advance_resets_daily_flags() -> void:
	_state.fed_today = true
	_state.petted_today = true
	AnimalHusbandry.advance(_data, _state, true)
	assert_bool(_state.fed_today).is_false()
	assert_bool(_state.petted_today).is_false()


# ---------------------------------------------------------------- 喂食 / 抚摸

func test_feed_only_once_per_day() -> void:
	assert_bool(AnimalHusbandry.feed(_data, _state)).is_true()
	assert_bool(AnimalHusbandry.feed(_data, _state)).is_false()


func test_pet_raises_affection_once_per_day() -> void:
	var gained := AnimalHusbandry.pet(_data, _state)
	assert_int(gained).is_equal(5)
	assert_int(_state.affection).is_equal(5)
	assert_int(AnimalHusbandry.pet(_data, _state)).is_equal(0)
	assert_int(_state.affection).is_equal(5)


func test_pet_caps_at_max_affection() -> void:
	_state.affection = 98
	var gained := AnimalHusbandry.pet(_data, _state)
	assert_int(gained).is_equal(2)
	assert_int(_state.affection).is_equal(100)


func test_not_fed_decays_affection() -> void:
	_state.affection = 10
	AnimalHusbandry.advance(_data, _state, false)
	assert_int(_state.affection).is_equal(7)


func test_affection_never_goes_negative() -> void:
	_state.affection = 1
	AnimalHusbandry.advance(_data, _state, false)
	assert_int(_state.affection).is_equal(0)


# ---------------------------------------------------------------- 产出

func test_can_collect_requires_adult_and_interval() -> void:
	assert_bool(AnimalHusbandry.can_collect(_data, _state)).is_false()
	_adult()
	_state.days_since_product = 1
	assert_bool(AnimalHusbandry.can_collect(_data, _state)).is_false()
	_state.days_since_product = 2
	assert_bool(AnimalHusbandry.can_collect(_data, _state)).is_true()


func test_fed_adult_advances_product_timer() -> void:
	_adult()
	AnimalHusbandry.advance(_data, _state, true)
	assert_int(_state.days_since_product).is_equal(1)


func test_unfed_adult_pauses_product_timer() -> void:
	_adult(false)
	AnimalHusbandry.advance(_data, _state, false)
	assert_int(_state.days_since_product).is_equal(0)


func test_collect_yields_amount_and_resets_timer() -> void:
	_adult()
	_state.days_since_product = 5
	var outcome := AnimalHusbandry.apply_collect(_data, _state)
	assert_str(String(outcome["item_id"])).is_equal("egg")
	assert_int(int(outcome["amount"])).is_equal(2)
	assert_int(_state.days_since_product).is_equal(0)


func test_collect_when_not_ready_is_empty() -> void:
	var outcome := AnimalHusbandry.apply_collect(_data, _state)
	assert_int(int(outcome["amount"])).is_equal(0)
	assert_str(String(outcome["item_id"])).is_empty()


func test_high_affection_can_bonus_yield() -> void:
	_adult()
	_state.days_since_product = 2
	_state.affection = 100
	_data.bonus_product_chance = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var outcome := AnimalHusbandry.apply_collect(_data, _state, rng)
	assert_int(int(outcome["amount"])).is_equal(3)
	assert_bool(bool(outcome["bonus"])).is_true()


func test_low_affection_never_bonuses() -> void:
	_adult()
	_state.days_since_product = 2
	_state.affection = 10
	_data.bonus_product_chance = 1.0
	var outcome := AnimalHusbandry.apply_collect(_data, _state)
	assert_int(int(outcome["amount"])).is_equal(2)
	assert_bool(bool(outcome["bonus"])).is_false()


func test_sprite_column_reflects_state() -> void:
	assert_int(AnimalHusbandry.sprite_column(_data, _state)).is_equal(0)
	_adult()
	assert_int(AnimalHusbandry.sprite_column(_data, _state)).is_equal(1)
	_state.days_since_product = 2
	assert_int(AnimalHusbandry.sprite_column(_data, _state)).is_equal(2)


# ---------------------------------------------------------------- 序列化

func test_animal_state_roundtrip() -> void:
	_state.days_grown = 4
	_state.affection = 33
	_state.days_since_product = 1
	_state.fed_today = true
	_state.petted_today = true

	var restored := AnimalState.new()
	restored.from_dict(_state.to_dict())
	assert_str(String(restored.animal_id)).is_equal("test_animal")
	assert_int(restored.days_grown).is_equal(4)
	assert_int(restored.affection).is_equal(33)
	assert_int(restored.days_since_product).is_equal(1)
	assert_bool(restored.fed_today).is_true()
	assert_bool(restored.petted_today).is_true()


func test_building_state_capacity() -> void:
	var building := BuildingData.new()
	building.id = &"test_building"
	building.capacity = 2
	var state := BuildingState.new(building.id)
	assert_bool(state.is_full(building)).is_false()
	state.add(AnimalState.new(&"chicken"))
	state.add(AnimalState.new(&"cow"))
	assert_bool(state.is_full(building)).is_true()
	assert_int(state.size()).is_equal(2)


func test_building_state_roundtrip() -> void:
	var state := BuildingState.new(&"coop")
	state.add(AnimalState.new(&"chicken"))
	state.add(AnimalState.new(&"chicken"))

	var restored := BuildingState.new()
	restored.from_dict(state.to_dict())
	assert_str(String(restored.building_id)).is_equal("coop")
	assert_int(restored.size()).is_equal(2)
	assert_str(String(restored.animals[0].animal_id)).is_equal("chicken")
