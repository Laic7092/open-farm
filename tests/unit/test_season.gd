extends GdUnitTestSuite
## 季节规则测试。


func test_days_per_season_is_positive() -> void:
	assert_int(Season.DAYS_PER_SEASON).is_greater(0)


func test_next_cycles_through_all_seasons() -> void:
	var season := Season.Type.SPRING
	var visited: Array[Season.Type] = []
	for _i: int in Season.COUNT:
		visited.append(season)
		season = Season.next(season)
	assert_array(visited).contains_exactly(Season.all())
	assert_int(season).is_equal(Season.Type.SPRING)


func test_from_index_wraps_out_of_range_values() -> void:
	assert_int(Season.from_index(-1)).is_equal(Season.Type.WINTER)
	assert_int(Season.from_index(Season.COUNT)).is_equal(Season.Type.SPRING)
	assert_int(Season.from_index(Season.COUNT * 3 + 2)).is_equal(Season.Type.FALL)


func test_is_valid_rejects_out_of_range() -> void:
	assert_bool(Season.is_valid(0)).is_true()
	assert_bool(Season.is_valid(Season.COUNT - 1)).is_true()
	assert_bool(Season.is_valid(-1)).is_false()
	assert_bool(Season.is_valid(Season.COUNT)).is_false()


func test_every_season_has_a_translation_key() -> void:
	var keys: Array[StringName] = []
	for season: Season.Type in Season.all():
		var key := Season.name_key(season)
		assert_str(String(key)).is_not_empty()
		keys.append(key)
	assert_array(keys).has_size(Season.COUNT)


func test_key_roundtrip() -> void:
	for season: Season.Type in Season.all():
		assert_int(Season.from_key(String(Season.to_key(season)))).is_equal(season)


func test_from_key_falls_back_to_spring() -> void:
	assert_int(Season.from_key("nonsense")).is_equal(Season.Type.SPRING)
