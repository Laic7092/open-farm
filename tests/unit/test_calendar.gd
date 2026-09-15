extends GdUnitTestSuite
## 节日与事件系统测试：今天的节日 / 参加奖励 / 事件触发 / 存档往返。
##
## [code]Calendar[/code] 是 autoload，用例之间会互相污染，所以每个用例前复位。


func before_test() -> void:
	GameClock.reset()
	GameClock.set_paused(false)
	GameState.reset()
	Relationships.reset()
	Calendar.reset()
	WeatherSystem.set_weather(Weather.Type.SUNNY)


func after_test() -> void:
	Calendar.reset()


# ---------------------------------------------------------------- 数据 / 查询

func test_festival_data_is_loaded_from_database() -> void:
	assert_bool(Database.get_festival(&"new_year") != null).is_true()
	assert_int(Calendar.festivals().size()).is_greater_equal(5)
	assert_int(Calendar.events().size()).is_greater_equal(5)


func test_today_festival_is_new_year_on_spring_1() -> void:
	assert_bool(Calendar.has_festival_today()).is_true()
	assert_str(Calendar.today_text()).is_equal(Text.key(&"FESTIVAL_NEW_YEAR"))


func test_today_festival_is_empty_on_a_plain_day() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 3))
	assert_bool(Calendar.has_festival_today()).is_false()
	assert_str(Calendar.today_text()).is_equal("")


func test_is_active_respects_the_opening_window() -> void:
	# 新年祭 08:00–17:00。
	GameClock.set_time(7, 59)
	assert_bool(Calendar.is_active(&"new_year")).is_false()
	GameClock.set_time(8, 0)
	assert_bool(Calendar.is_active(&"new_year")).is_true()
	GameClock.set_time(17, 0)
	assert_bool(Calendar.is_active(&"new_year")).is_false()


func test_gather_point_only_for_participants() -> void:
	GameClock.set_time(9, 0)
	assert_str(String(Calendar.gather_point_for(&"mayor"))).is_equal("plaza")
	# 矿工不住在镇上，不参加新年祭。
	assert_str(String(Calendar.gather_point_for(&"miner"))).is_equal("")


func test_required_flag_gates_a_festival() -> void:
	var festival := FestivalData.new()
	festival.id = &"gated"
	festival.required_flag = &"village_unlocked"
	assert_bool(Calendar.is_available(festival)).is_false()
	GameState.set_flag(&"village_unlocked")
	assert_bool(Calendar.is_available(festival)).is_true()
	# 没有前置条件的节日永远可用。
	assert_bool(Calendar.is_available(Database.get_festival(&"new_year"))).is_true()


# ---------------------------------------------------------------- 参加

func test_attend_gives_affection_and_sets_flag() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 14))
	GameClock.set_time(10, 0)
	var before := Relationships.affection(&"florist")
	assert_bool(Calendar.attend(&"flower_festival")).is_true()
	assert_int(Relationships.affection(&"florist")).is_equal(before + 4)
	assert_bool(GameState.has_flag(&"flower_festival_joined")).is_true()
	assert_bool(Calendar.has_attended(&"flower_festival")).is_true()


func test_attend_is_once_per_year() -> void:
	GameClock.set_time(9, 0)
	assert_bool(Calendar.attend(&"new_year")).is_true()
	assert_bool(Calendar.attend(&"new_year")).is_false()
	# 过完一整年，节日重办，奖励也能再领一次。
	for _day: int in GameDate.DAYS_PER_YEAR:
		GameClock.sleep_until_morning()
	assert_int(GameClock.date.year).is_equal(2)
	GameClock.set_time(9, 0)
	assert_bool(Calendar.can_attend(&"new_year")).is_true()
	assert_bool(Calendar.attend(&"new_year")).is_true()


func test_attend_fails_when_the_ground_is_closed() -> void:
	GameClock.set_time(7, 0)
	assert_bool(Calendar.attend(&"new_year")).is_false()
	assert_bool(Calendar.has_attended(&"new_year")).is_false()


func test_attend_fails_on_another_day() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 2))
	GameClock.set_time(9, 0)
	assert_bool(Calendar.attend(&"new_year")).is_false()


# ---------------------------------------------------------------- 事件

func test_event_triggers_once_and_grants_money() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	var before: int = GameState.money
	GameClock.sleep_until_morning()
	assert_bool(Calendar.has_triggered(&"traveler_visit")).is_true()
	assert_int(GameState.money).is_equal(before + 150)
	# once 事件不会第二次发生。
	GameClock.sleep_until_morning()
	assert_int(GameState.money).is_equal(before + 150)


func test_event_waits_for_its_conditions() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	GameClock.sleep_until_morning()
	assert_bool(Calendar.has_triggered(&"librarian_visit")).is_false()
	Relationships.set_affection(&"librarian", 120)
	GameClock.sleep_until_morning()
	assert_bool(Calendar.has_triggered(&"librarian_visit")).is_true()


func test_event_can_set_a_flag() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.FALL, 28))
	GameClock.sleep_until_morning()
	assert_int(GameClock.date.season).is_equal(Season.Type.WINTER)
	assert_bool(GameState.has_flag(&"winter_seen")).is_true()


func test_events_for_today_lists_matching_events() -> void:
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 8))
	var ids := PackedStringArray()
	for entry: EventData in Calendar.events_for_today():
		ids.append(String(entry.id))
	assert_bool(ids.has("traveler_visit")).is_true()


# ---------------------------------------------------------------- 存档

func test_persistence_round_trip() -> void:
	GameClock.set_time(9, 0)
	Calendar.attend(&"new_year")
	# 跳到春 8，让 traveler_visit 也发生一次，这样两类状态都被快照覆盖。
	GameClock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	GameClock.sleep_until_morning()
	var snapshot := Calendar.to_dict()

	Calendar.reset()
	assert_bool(Calendar.has_attended(&"new_year")).is_false()
	assert_bool(Calendar.has_triggered(&"traveler_visit")).is_false()

	Calendar.from_dict(snapshot)
	assert_bool(Calendar.has_attended(&"new_year")).is_true()
	assert_bool(Calendar.has_triggered(&"traveler_visit")).is_true()


func test_reset_clears_calendar_state() -> void:
	GameClock.set_time(9, 0)
	Calendar.attend(&"new_year")
	Calendar.reset()
	assert_bool(Calendar.has_attended(&"new_year")).is_false()
	assert_bool(Calendar.has_triggered(&"traveler_visit")).is_false()
