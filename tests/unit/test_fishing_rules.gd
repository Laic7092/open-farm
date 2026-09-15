extends GdUnitTestSuite
## 钓鱼规则测试：全部是可脱离场景树的纯静态函数。


func _fish(
	fish_id: StringName,
	water: Array[int],
	seasons: Array[Season.Type],
	weathers: Array[Weather.Type],
	min_hour: int,
	max_hour: int,
	weight: int,
	difficulty: int
) -> FishData:
	var fish := FishData.new()
	fish.id = fish_id
	fish.item_id = fish_id
	fish.water = water
	fish.seasons = seasons
	fish.weathers = weathers
	fish.min_hour = min_hour
	fish.max_hour = max_hour
	fish.weight = weight
	fish.difficulty = difficulty
	fish.size_cm = Vector2i(10, 20)
	return fish


# ---------------------------------------------------------------- 时段

func test_hour_window_handles_midnight_wrap() -> void:
	assert_bool(FishingRules.hour_in_window(10, 8, 17)).is_true()
	assert_bool(FishingRules.hour_in_window(7, 8, 17)).is_false()
	assert_bool(FishingRules.hour_in_window(20, 8, 17)).is_false()

	# 18:00 ~ 04:00 是跨午夜的窗口。
	assert_bool(FishingRules.hour_in_window(23, 18, 4)).is_true()
	assert_bool(FishingRules.hour_in_window(2, 18, 4)).is_true()
	assert_bool(FishingRules.hour_in_window(12, 18, 4)).is_false()

	# 全天 = 0~23。
	for hour: int in 24:
		assert_bool(FishingRules.hour_in_window(hour, 0, 23)).is_true()


# ---------------------------------------------------------------- 筛选

func test_eligibility_respects_water_season_weather_and_hour() -> void:
	var tuna := _fish(
		&"tuna",
		[WaterKind.Kind.OCEAN] as Array[int],
		[Season.Type.SUMMER] as Array[Season.Type],
		[Weather.Type.SUNNY] as Array[Weather.Type],
		6, 16, 5, 5
	)
	var summer_noon := [
		WaterKind.Kind.OCEAN, Season.Type.SUMMER, Weather.Type.SUNNY, 12
	]
	assert_bool(FishingRules.is_eligible(
		tuna, summer_noon[0], summer_noon[1], summer_noon[2], summer_noon[3]
	)).is_true()
	assert_bool(FishingRules.is_eligible(
		tuna, WaterKind.Kind.POND, Season.Type.SUMMER, Weather.Type.SUNNY, 12
	)).is_false()
	assert_bool(FishingRules.is_eligible(
		tuna, WaterKind.Kind.OCEAN, Season.Type.WINTER, Weather.Type.SUNNY, 12
	)).is_false()
	assert_bool(FishingRules.is_eligible(
		tuna, WaterKind.Kind.OCEAN, Season.Type.SUMMER, Weather.Type.RAINY, 12
	)).is_false()
	assert_bool(FishingRules.is_eligible(
		tuna, WaterKind.Kind.OCEAN, Season.Type.SUMMER, Weather.Type.SUNNY, 20
	)).is_false()


func test_empty_season_and_weather_lists_mean_any() -> void:
	var crucian := _fish(
		&"crucian",
		[WaterKind.Kind.POND] as Array[int],
		[] as Array[Season.Type],
		[] as Array[Weather.Type],
		0, 23, 30, 1
	)
	for season: Season.Type in [Season.Type.SPRING, Season.Type.WINTER]:
		assert_bool(FishingRules.is_eligible(
			crucian, WaterKind.Kind.POND, season, Weather.Type.SNOWY, 8
		)).is_true()


func test_eligible_fish_keeps_pool_order() -> void:
	var first := _fish(&"first", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 5, 1)
	var second := _fish(&"second", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 5, 1)
	var other_water := _fish(&"other", [WaterKind.Kind.OCEAN] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 5, 1)
	var pool: Array[FishData] = [first, other_water, second]
	var eligible := FishingRules.eligible_fish(
		pool, WaterKind.Kind.POND, Season.Type.SPRING, Weather.Type.SUNNY, 9
	)
	assert_int(eligible.size()).is_equal(2)
	assert_str(String(eligible[0].id)).is_equal("first")
	assert_str(String(eligible[1].id)).is_equal("second")


func test_pick_returns_null_when_nothing_is_eligible() -> void:
	var pool: Array[FishData] = [
		_fish(&"tuna", [WaterKind.Kind.OCEAN] as Array[int],
			[Season.Type.SUMMER] as Array[Season.Type], [] as Array[Weather.Type], 6, 16, 5, 5)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_object(FishingRules.pick(
		pool, rng, WaterKind.Kind.POND, Season.Type.WINTER, Weather.Type.SNOWY, 3
	)).is_null()


# ---------------------------------------------------------------- 抽取

func test_pick_is_reproducible_with_the_same_seed() -> void:
	var pool: Array[FishData] = [
		_fish(&"common", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
			[] as Array[Weather.Type], 0, 23, 90, 1),
		_fish(&"rare", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
			[] as Array[Weather.Type], 0, 23, 10, 5),
	]
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20240601
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20240601
	for _i: int in 50:
		var a := FishingRules.pick(
			pool, rng_a, WaterKind.Kind.POND, Season.Type.SPRING, Weather.Type.SUNNY, 12
		)
		var b := FishingRules.pick(
			pool, rng_b, WaterKind.Kind.POND, Season.Type.SPRING, Weather.Type.SUNNY, 12
		)
		assert_str(String(a.id)).is_equal(String(b.id))


func test_pick_respects_weight() -> void:
	var pool: Array[FishData] = [
		_fish(&"common", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
			[] as Array[Weather.Type], 0, 23, 90, 1),
		_fish(&"rare", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
			[] as Array[Weather.Type], 0, 23, 10, 5),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var commons: int = 0
	for _i: int in 400:
		var picked := FishingRules.pick(
			pool, rng, WaterKind.Kind.POND, Season.Type.SPRING, Weather.Type.SUNNY, 12
		)
		if picked != null and picked.id == &"common":
			commons += 1
	# 权重 9:1，400 次里常见种应当明显过半。
	assert_int(commons).is_greater(240)


# ---------------------------------------------------------------- 时间与体长

func test_better_rod_shortens_wait_and_widens_window() -> void:
	var easy := _fish(&"easy", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 10, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var wait_plain := FishingRules.bite_delay(rng, 0)
	rng.seed = 3
	var wait_upgraded := FishingRules.bite_delay(rng, 3)
	assert_float(wait_upgraded).is_less(wait_plain)
	assert_float(FishingRules.bite_window(easy, 3)).is_greater(
		FishingRules.bite_window(easy, 0)
	)


func test_bite_window_shrinks_with_difficulty_but_has_a_floor() -> void:
	var easy := _fish(&"easy", [WaterKind.Kind.POND] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 10, 1)
	var hard := _fish(&"hard", [WaterKind.Kind.OCEAN] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 10, 5)
	assert_float(FishingRules.bite_window(hard)).is_less(FishingRules.bite_window(easy))
	assert_float(FishingRules.bite_window(hard)).is_greater_equal(FishingRules.BITE_WINDOW_MIN)
	assert_float(FishingRules.bite_delay(RandomNumberGenerator.new(), 0)).is_greater_equal(0.35)


func test_roll_size_stays_within_the_species_range() -> void:
	var fish := _fish(&"bream", [WaterKind.Kind.OCEAN] as Array[int], [] as Array[Season.Type],
		[] as Array[Weather.Type], 0, 23, 10, 1)
	fish.size_cm = Vector2i(30, 70)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for _i: int in 200:
		var size: int = FishingRules.roll_size(fish, rng)
		assert_int(size).is_greater_equal(30)
		assert_int(size).is_less_equal(70)


# ---------------------------------------------------------------- 数据自检

func test_fish_data_validate_catches_bad_input() -> void:
	var fish := FishData.new()
	assert_array(fish.validate()).is_not_empty()

	fish.id = &"ok"
	fish.item_id = &"ok"
	fish.water = [WaterKind.Kind.POND] as Array[int]
	fish.weight = 5
	fish.size_cm = Vector2i(10, 20)
	assert_array(fish.validate()).is_empty()

	fish.water = [99] as Array[int]
	assert_array(fish.validate()).is_not_empty()
