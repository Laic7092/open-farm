extends GdUnitTestSuite
## 日期值对象测试：进位、绝对天数、序列化。


func test_new_clamps_input() -> void:
	var date := GameDate.new(0, Season.Type.SPRING, 99)
	assert_int(date.year).is_equal(1)
	assert_int(date.day).is_equal(Season.DAYS_PER_SEASON)


func test_advance_day_within_season() -> void:
	var date := GameDate.new(1, Season.Type.SPRING, 5)
	var crossed := date.advance_day()
	assert_int(date.day).is_equal(6)
	assert_bool(crossed[&"season"]).is_false()
	assert_bool(crossed[&"year"]).is_false()


func test_advance_day_crosses_season() -> void:
	var date := GameDate.new(1, Season.Type.SPRING, Season.DAYS_PER_SEASON)
	var crossed := date.advance_day()
	assert_int(date.season).is_equal(Season.Type.SUMMER)
	assert_int(date.day).is_equal(1)
	assert_bool(crossed[&"season"]).is_true()
	assert_bool(crossed[&"year"]).is_false()


func test_advance_day_crosses_year_after_winter() -> void:
	var date := GameDate.new(1, Season.Type.WINTER, Season.DAYS_PER_SEASON)
	var crossed := date.advance_day()
	assert_int(date.year).is_equal(2)
	assert_int(date.season).is_equal(Season.Type.SPRING)
	assert_int(date.day).is_equal(1)
	assert_bool(crossed[&"year"]).is_true()


func test_absolute_day_is_monotonic() -> void:
	var previous := -1
	var date := GameDate.new(1, Season.Type.SPRING, 1)
	for _i: int in GameDate.DAYS_PER_YEAR + 2:
		var current: int = date.absolute_day()
		assert_int(current).is_greater(previous)
		previous = current
		date.advance_day()


func test_days_until() -> void:
	var first := GameDate.new(1, Season.Type.SPRING, 1)
	var last := GameDate.new(1, Season.Type.SPRING, Season.DAYS_PER_SEASON)
	assert_int(first.days_until(last)).is_equal(Season.DAYS_PER_SEASON - 1)
	assert_int(last.days_until(first)).is_equal(-(Season.DAYS_PER_SEASON - 1))


func test_day_of_year_maps_every_day_uniquely() -> void:
	var seen := {}
	var date := GameDate.new(1, Season.Type.SPRING, 1)
	for _i: int in GameDate.DAYS_PER_YEAR:
		var index: int = date.day_of_year()
		assert_bool(seen.has(index)).is_false()
		seen[index] = true
		date.advance_day()
	assert_int(seen.size()).is_equal(GameDate.DAYS_PER_YEAR)


func test_equals_compares_by_value_not_reference() -> void:
	var a := GameDate.new(2, Season.Type.FALL, 7)
	var b := GameDate.new(2, Season.Type.FALL, 7)
	assert_bool(a == b).is_false()  # RefCounted 的 == 是引用比较
	assert_bool(a.equals(b)).is_true()
	b.advance_day()
	assert_bool(a.equals(b)).is_false()


func test_serialization_roundtrip() -> void:
	var date := GameDate.new(3, Season.Type.WINTER, 14)
	var restored := GameDate.from_dict(date.to_dict())
	assert_bool(restored.equals(date)).is_true()


func test_from_dict_uses_safe_defaults() -> void:
	var restored := GameDate.from_dict({})
	assert_int(restored.year).is_equal(1)
	assert_int(restored.season).is_equal(Season.Type.SPRING)
	assert_int(restored.day).is_equal(1)


func test_from_absolute_day_is_the_inverse_of_absolute_day() -> void:
	var date := GameDate.new(1, Season.Type.SPRING, 1)
	for _i: int in GameDate.DAYS_PER_YEAR * 2 + 3:
		var restored := GameDate.from_absolute_day(date.absolute_day())
		assert_bool(restored.equals(date)).override_failure_message(
			"第 %d 天还原成了 %s，期望 %s" % [date.absolute_day(), restored, date]
		).is_true()
		date.advance_day()


func test_from_absolute_day_clamps_negative_input() -> void:
	var restored := GameDate.from_absolute_day(-99)
	assert_int(restored.absolute_day()).is_equal(0)
	assert_int(restored.year).is_equal(1)
	assert_int(restored.season).is_equal(Season.Type.SPRING)
	assert_int(restored.day).is_equal(1)
