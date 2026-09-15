extends GdUnitTestSuite
## 事件条件测试：季节 / 日期 / 天气 / 旗标 / 好感门槛。
##
## [EventRules] 只吃"已经查好的事实"，所以这里连 [PlayerProfile] 都不用碰。


func _event() -> EventData:
	var event := EventData.new()
	event.id = &"test_event"
	event.title_key = &"EVENT_TRAVELER_VISIT"
	return event


func test_any_season_any_day_any_weather_matches() -> void:
	var event := _event()
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.SUMMER, 9), int(Weather.Type.RAINY), false, false, 0)).is_true()


func test_season_and_day_are_exclusive() -> void:
	var event := _event()
	event.season = int(Season.Type.FALL)
	event.day = 15
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.FALL, 15), 0, false, false, 0)).is_true()
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.FALL, 16), 0, false, false, 0)).is_false()
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.SUMMER, 15), 0, false, false, 0)).is_false()


func test_weather_condition() -> void:
	var event := _event()
	event.weather = int(Weather.Type.SNOWY)
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.WINTER, 1), int(Weather.Type.SNOWY), false, false, 0)).is_true()
	assert_bool(EventRules.matches(event, GameDate.new(1, Season.Type.WINTER, 1), int(Weather.Type.SUNNY), false, false, 0)).is_false()


func test_required_and_forbidden_flags() -> void:
	var event := _event()
	event.required_flag = &"met_mayor"
	event.forbidden_flag = &"already_done"
	var date := GameDate.new(1, Season.Type.SPRING, 3)
	assert_bool(EventRules.matches(event, date, 0, false, false, 0)).is_false()
	assert_bool(EventRules.matches(event, date, 0, true, false, 0)).is_true()
	assert_bool(EventRules.matches(event, date, 0, true, true, 0)).is_false()


func test_affection_threshold() -> void:
	var event := _event()
	event.required_npc = &"librarian"
	event.required_affection = 120
	var date := GameDate.new(1, Season.Type.SPRING, 3)
	assert_bool(EventRules.matches(event, date, 0, false, false, 119)).is_false()
	assert_bool(EventRules.matches(event, date, 0, false, false, 120)).is_true()


func test_null_inputs_do_not_match() -> void:
	assert_bool(EventRules.matches(null, GameDate.new(1, Season.Type.SPRING, 1), 0, false, false, 0)).is_false()
	assert_bool(EventRules.matches(_event(), null, 0, false, false, 0)).is_false()
