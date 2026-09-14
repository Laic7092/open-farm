extends GdUnitTestSuite
## 天气规则测试。


func test_rain_waters_crops() -> void:
	assert_bool(Weather.waters_crops(Weather.Type.RAINY)).is_true()
	assert_bool(Weather.waters_crops(Weather.Type.STORMY)).is_true()
	assert_bool(Weather.waters_crops(Weather.Type.SUNNY)).is_false()
	assert_bool(Weather.waters_crops(Weather.Type.SNOWY)).is_false()


func test_stamina_multiplier_is_at_least_one() -> void:
	for weather: Weather.Type in [0, 1, 2, 3, 4]:
		assert_float(Weather.stamina_multiplier(weather)).is_greater_equal(1.0)


func test_bad_weather_costs_more_stamina() -> void:
	assert_float(Weather.stamina_multiplier(Weather.Type.STORMY)).is_greater(
		Weather.stamina_multiplier(Weather.Type.SUNNY)
	)


func test_every_season_has_weather_candidates() -> void:
	for season: Season.Type in Season.all():
		var candidates := Weather.candidates_for(season)
		assert_dict(candidates).is_not_empty()
		var total: int = 0
		for weight: int in candidates.values():
			assert_int(weight).is_greater(0)
			total += weight
		assert_int(total).is_greater(0)


func test_winter_can_snow() -> void:
	assert_bool(Weather.candidates_for(Season.Type.WINTER).has(Weather.Type.SNOWY)).is_true()


func test_pick_is_deterministic_for_a_seeded_rng() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 12345
	var b := RandomNumberGenerator.new()
	b.seed = 12345
	var weights := Weather.candidates_for(Season.Type.SPRING)
	for _i: int in 20:
		assert_int(Weather.pick(weights, a)).is_equal(Weather.pick(weights, b))


func test_pick_only_returns_candidates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var weights := Weather.candidates_for(Season.Type.SUMMER)
	for _i: int in 200:
		var picked := Weather.pick(weights, rng)
		assert_bool(weights.has(picked)).is_true()


func test_pick_with_empty_weights_falls_back_to_sunny() -> void:
	assert_int(Weather.pick({}, RandomNumberGenerator.new())).is_equal(Weather.Type.SUNNY)


func test_key_roundtrip() -> void:
	for weather: Weather.Type in [0, 1, 2, 3, 4]:
		assert_int(Weather.from_key(String(Weather.to_key(weather)))).is_equal(weather)
