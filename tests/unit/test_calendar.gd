extends GdUnitTestSuite
## 节日与事件系统测试：今天的节日 / 参加奖励 / 事件触发 / 存档往返。
##
## CalendarService 不再是 Autoload；测试直接 new 服务并注入状态 / 时钟 / 邻接服务。


var _profile: PlayerProfile
var _clock: GameDateClock
var _weather: WeatherService
var _relationships: RelationshipService
var _calendar: CalendarService


func before_test() -> void:
	_profile = PlayerProfile.new()
	_clock = GameDateClock.new()
	_weather = WeatherService.new()
	_weather.set_state(WeatherState.new())
	_relationships = RelationshipService.new()
	_relationships.set_state(RelationshipStore.new())
	_calendar = CalendarService.new()
	_calendar.set_state(CalendarProgress.new())
	_weather.bind_dependencies(_clock, _weather.state())
	_relationships.bind_dependencies(_profile, _clock)
	_calendar.bind_dependencies(_profile, _clock, _weather, _relationships)
	_weather.set_weather(Weather.Type.SUNNY)


func after_test() -> void:
	_calendar.reset()
	# 服务是 Node，没有挂在场景树上时必须显式释放，避免测试孤儿。
	_calendar.free()
	_relationships.free()
	_weather.free()
	_calendar = null
	_relationships = null
	_weather = null


# ---------------------------------------------------------------- 数据 / 查询

func test_festival_data_is_loaded_from_database() -> void:
	assert_bool(Database.get_festival(&"new_year") != null).is_true()
	assert_int(_calendar.festivals().size()).is_greater_equal(5)
	assert_int(_calendar.events().size()).is_greater_equal(5)


func test_today_festival_is_new_year_on_spring_1() -> void:
	assert_bool(_calendar.has_festival_today()).is_true()
	assert_str(_calendar.today_text()).is_equal(Text.key(&"FESTIVAL_NEW_YEAR"))


func test_today_festival_is_empty_on_a_plain_day() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 3))
	assert_bool(_calendar.has_festival_today()).is_false()
	assert_str(_calendar.today_text()).is_equal("")


func test_is_active_respects_the_opening_window() -> void:
	# 新年祭 08:00–17:00。
	_clock.set_time(7, 59)
	assert_bool(_calendar.is_active(&"new_year")).is_false()
	_clock.set_time(8, 0)
	assert_bool(_calendar.is_active(&"new_year")).is_true()
	_clock.set_time(17, 0)
	assert_bool(_calendar.is_active(&"new_year")).is_false()


func test_gather_point_only_for_participants() -> void:
	_clock.set_time(9, 0)
	assert_str(String(_calendar.gather_point_for(&"mayor"))).is_equal("plaza")
	# 矿工不住在镇上，不参加新年祭。
	assert_str(String(_calendar.gather_point_for(&"miner"))).is_equal("")


func test_required_flag_gates_a_festival() -> void:
	var festival := FestivalData.new()
	festival.id = &"gated"
	festival.required_flag = &"village_unlocked"
	assert_bool(_calendar.is_available(festival)).is_false()
	_profile.set_flag(&"village_unlocked")
	assert_bool(_calendar.is_available(festival)).is_true()
	# 没有前置条件的节日永远可用。
	assert_bool(_calendar.is_available(Database.get_festival(&"new_year"))).is_true()


# ---------------------------------------------------------------- 参加

func test_attend_gives_affection_and_sets_flag() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 14))
	_clock.set_time(10, 0)
	var before := _relationships.affection(&"florist")
	assert_bool(_calendar.attend(&"flower_festival")).is_true()
	assert_int(_relationships.affection(&"florist")).is_equal(before + 4)
	assert_bool(_profile.has_flag(&"flower_festival_joined")).is_true()
	assert_bool(_calendar.has_attended(&"flower_festival")).is_true()


func test_attend_is_once_per_year() -> void:
	_clock.set_time(9, 0)
	assert_bool(_calendar.attend(&"new_year")).is_true()
	assert_bool(_calendar.attend(&"new_year")).is_false()
	# 过完一整年，节日重办，奖励也能再领一次。
	for _day: int in GameDate.DAYS_PER_YEAR:
		_clock.sleep_until_morning()
	assert_int(_clock.date.year).is_equal(2)
	_clock.set_time(9, 0)
	assert_bool(_calendar.can_attend(&"new_year")).is_true()
	assert_bool(_calendar.attend(&"new_year")).is_true()


func test_attend_fails_when_the_ground_is_closed() -> void:
	_clock.set_time(7, 0)
	assert_bool(_calendar.attend(&"new_year")).is_false()
	assert_bool(_calendar.has_attended(&"new_year")).is_false()


func test_attend_fails_on_another_day() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 2))
	_clock.set_time(9, 0)
	assert_bool(_calendar.attend(&"new_year")).is_false()


# ---------------------------------------------------------------- 事件

func test_event_triggers_once_and_grants_money() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	var before: int = _profile.money
	_clock.sleep_until_morning()
	assert_bool(_calendar.has_triggered(&"traveler_visit")).is_true()
	assert_int(_profile.money).is_equal(before + 150)
	# once 事件不会第二次发生。
	_clock.sleep_until_morning()
	assert_int(_profile.money).is_equal(before + 150)


func test_event_waits_for_its_conditions() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	_clock.sleep_until_morning()
	assert_bool(_calendar.has_triggered(&"librarian_visit")).is_false()
	_relationships.set_affection(&"librarian", 120)
	_clock.sleep_until_morning()
	assert_bool(_calendar.has_triggered(&"librarian_visit")).is_true()


func test_event_can_set_a_flag() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.FALL, 28))
	_clock.sleep_until_morning()
	assert_int(_clock.date.season).is_equal(Season.Type.WINTER)
	assert_bool(_profile.has_flag(&"winter_seen")).is_true()


func test_events_for_today_lists_matching_events() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 8))
	var ids := PackedStringArray()
	for entry: EventData in _calendar.events_for_today():
		ids.append(String(entry.id))
	assert_bool(ids.has("traveler_visit")).is_true()


# ---------------------------------------------------------------- 存档

func test_persistence_round_trip() -> void:
	_clock.set_time(9, 0)
	_calendar.attend(&"new_year")
	# 跳到春 8，让 traveler_visit 也发生一次，这样两类状态都被快照覆盖。
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	_clock.sleep_until_morning()
	var snapshot := _calendar.to_dict()

	_calendar.reset()
	assert_bool(_calendar.has_attended(&"new_year")).is_false()
	assert_bool(_calendar.has_triggered(&"traveler_visit")).is_false()

	_calendar.from_dict(snapshot)
	assert_bool(_calendar.has_attended(&"new_year")).is_true()
	assert_bool(_calendar.has_triggered(&"traveler_visit")).is_true()


func test_reset_clears_calendar_state() -> void:
	_clock.set_time(9, 0)
	_calendar.attend(&"new_year")
	_calendar.reset()
	assert_bool(_calendar.has_attended(&"new_year")).is_false()
	assert_bool(_calendar.has_triggered(&"traveler_visit")).is_false()
