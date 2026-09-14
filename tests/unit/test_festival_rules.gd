extends GdUnitTestSuite
## 节日规则测试：日期筛选 / 开放时间 / 倒数天数。
##
## [FestivalRules] 是纯静态的，测试里直接造 [FestivalData] 即可，不用起场景。


func _festival(
	festival_id: StringName, season: Season.Type, day: int, start_hour: int, end_hour: int
) -> FestivalData:
	var festival := FestivalData.new()
	festival.id = festival_id
	festival.display_name_key = &"FESTIVAL_NEW_YEAR"
	festival.season = season
	festival.day = day
	festival.start_hour = start_hour
	festival.end_hour = end_hour
	festival.world_path = "res://scenes/world/twon.tscn"
	festival.gather_point = &"plaza"
	festival.npc_ids = [&"mayor"] as Array[StringName]
	return festival


func test_on_date_filters_by_season_and_day() -> void:
	var spring := _festival(&"spring_fest", Season.Type.SPRING, 1, 8, 17)
	var fall := _festival(&"fall_fest", Season.Type.FALL, 1, 8, 17)
	var result := FestivalRules.on_date([spring, fall] as Array[FestivalData], GameDate.new(1, Season.Type.SPRING, 1))
	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].id)).is_equal("spring_fest")


func test_on_date_sorts_by_id_for_stable_output() -> void:
	var b := _festival(&"b_fest", Season.Type.SPRING, 3, 8, 17)
	var a := _festival(&"a_fest", Season.Type.SPRING, 3, 8, 17)
	var result := FestivalRules.on_date([b, a] as Array[FestivalData], GameDate.new(1, Season.Type.SPRING, 3))
	assert_int(result.size()).is_equal(2)
	assert_str(String(result[0].id)).is_equal("a_fest")
	assert_str(String(result[1].id)).is_equal("b_fest")


func test_on_date_returns_empty_for_missing_date() -> void:
	var festival := _festival(&"spring_fest", Season.Type.SPRING, 1, 8, 17)
	var result := FestivalRules.on_date(
		[festival] as Array[FestivalData], GameDate.new(1, Season.Type.SUMMER, 1)
	)
	assert_array(result).is_empty()


func test_window_is_half_open() -> void:
	var festival := _festival(&"window", Season.Type.SPRING, 1, 8, 17)
	assert_bool(FestivalRules.is_within(festival, 7 * 60 + 59)).is_false()
	assert_bool(FestivalRules.is_within(festival, 8 * 60)).is_true()
	assert_bool(FestivalRules.is_within(festival, 16 * 60 + 59)).is_true()
	assert_bool(FestivalRules.is_within(festival, 17 * 60)).is_false()


func test_window_spanning_end_means_all_day() -> void:
	var festival := _festival(&"all_day", Season.Type.SPRING, 1, 0, 0)
	assert_bool(FestivalRules.is_within(festival, 0)).is_true()
	assert_bool(FestivalRules.is_within(festival, 23 * 60 + 59)).is_true()


func test_window_ignores_null_festival() -> void:
	assert_bool(FestivalRules.is_within(null, 12 * 60)).is_false()


func test_days_until_counts_within_the_year() -> void:
	var festival := _festival(&"winter_fest", Season.Type.WINTER, 25, 18, 22)
	assert_int(FestivalRules.days_until(festival, GameDate.new(1, Season.Type.WINTER, 20))).is_equal(5)
	# 已经过了就是明年：冬 25 → 次年冬 25 正好一年。
	assert_int(FestivalRules.days_until(festival, GameDate.new(1, Season.Type.WINTER, 26))).is_equal(
		GameDate.DAYS_PER_YEAR - 1
	)
	assert_int(FestivalRules.days_until(festival, GameDate.new(1, Season.Type.WINTER, 25))).is_equal(0)


func test_days_until_returns_minus_one_for_null() -> void:
	assert_int(FestivalRules.days_until(null, GameDate.new(1, Season.Type.SPRING, 1))).is_equal(-1)
