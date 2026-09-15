extends GdUnitTestSuite
## 游戏时钟测试：跨天、季节/年份进位、有序日结转钩子。
##
## GameDateClock 是纯 Resource，每个用例 new 一份，不依赖 Autoload。

var _clock: GameDateClock
var _hooks: Array[Callable] = []


func before_test() -> void:
	_clock = GameDateClock.new()
	_clock.set_paused(false)
	_clock.set_time_scale(1.0)
	_hooks.clear()


func after_test() -> void:
	for hook: Callable in _hooks:
		_clock.unregister_day_hook(hook)
	_hooks.clear()


func _register(hook: Callable, priority: int = DayPipeline.PRIORITY_DEFAULT) -> Callable:
	_clock.register_day_hook(hook, priority)
	_hooks.append(hook)
	return hook


# ---------------------------------------------------------------- 复位与查询

func test_reset_starts_at_spring_day_one_0600() -> void:
	_clock.reset()
	assert_int(_clock.date.year).is_equal(1)
	assert_int(_clock.date.season).is_equal(Season.Type.SPRING)
	assert_int(_clock.date.day).is_equal(1)
	assert_int(_clock.hour()).is_equal(GameDateClock.DAY_START_HOUR)
	assert_int(_clock.minute()).is_equal(0)


func test_time_string_is_zero_padded() -> void:
	_clock.set_time(7, 5)
	assert_str(_clock.time_string()).is_equal("07:05")


func test_minutes_since_day_start_handles_midnight() -> void:
	_clock.set_time(6, 0)
	assert_int(_clock.minutes_since_day_start()).is_equal(0)
	_clock.set_time(23, 59)
	assert_int(_clock.minutes_since_day_start()).is_equal(17 * 60 + 59)
	_clock.set_time(1, 0)
	assert_int(_clock.minutes_since_day_start()).is_equal(19 * 60)


func test_is_past_midnight() -> void:
	_clock.set_time(23, 0)
	assert_bool(_clock.is_past_midnight()).is_false()
	_clock.set_time(1, 0)
	assert_bool(_clock.is_past_midnight()).is_true()


func test_set_time_clamps_invalid_input() -> void:
	_clock.set_time(99, 99)
	assert_int(_clock.hour()).is_equal(23)
	assert_int(_clock.minute()).is_equal(59)


# ---------------------------------------------------------------- 跨天

func test_advance_minutes_moves_the_clock() -> void:
	_clock.set_time(10, 0)
	_clock.advance_minutes(90)
	assert_int(_clock.hour()).is_equal(11)
	assert_int(_clock.minute()).is_equal(30)


func test_rollover_happens_at_0200() -> void:
	var day_before: int = _clock.date.day
	_clock.set_time(GameDateClock.DAY_ROLLOVER_HOUR - 1, 59)
	_clock.advance_minutes(1)
	assert_int(_clock.date.day).is_equal(day_before + 1)
	assert_int(_clock.hour()).is_equal(GameDateClock.DAY_ROLLOVER_HOUR)


func test_time_does_not_roll_over_before_0200() -> void:
	var day_before: int = _clock.date.day
	_clock.set_time(1, 58)
	_clock.advance_minutes(1)
	assert_int(_clock.date.day).is_equal(day_before)


func test_season_advances_after_the_last_day() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.SPRING, Season.DAYS_PER_SEASON))
	_clock.sleep_until_morning()
	assert_int(_clock.date.season).is_equal(Season.Type.SUMMER)
	assert_int(_clock.date.day).is_equal(1)


func test_year_advances_after_winter() -> void:
	_clock.set_date(GameDate.new(1, Season.Type.WINTER, Season.DAYS_PER_SEASON))
	_clock.sleep_until_morning()
	assert_int(_clock.date.year).is_equal(2)
	assert_int(_clock.date.season).is_equal(Season.Type.SPRING)


func test_sleep_returns_to_morning_and_advances_a_day() -> void:
	_clock.set_time(23, 30)
	var day_before: int = _clock.date.day
	_clock.sleep_until_morning()
	assert_int(_clock.hour()).is_equal(GameDateClock.DAY_START_HOUR)
	assert_int(_clock.date.day).is_equal(day_before + 1)


# ---------------------------------------------------------------- 日结转钩子

func test_day_hooks_run_in_explicit_priority_order() -> void:
	var order: Array[String] = []
	# 故意按与期望相反的注册顺序注册，优先级的权威性才不会被注册顺序掩盖。
	_register(func(_date: GameDate) -> void: order.append("world"), DayPipeline.PRIORITY_WORLD)
	_register(func(_date: GameDate) -> void: order.append("calendar"), DayPipeline.PRIORITY_CALENDAR)
	_register(func(_date: GameDate) -> void: order.append("weather"), DayPipeline.PRIORITY_WEATHER)

	_clock.sleep_until_morning()
	assert_array(order).contains_exactly(["weather", "calendar", "world"])


func test_day_hooks_with_same_priority_keep_registration_order() -> void:
	var order: Array[String] = []
	_register(func(_date: GameDate) -> void: order.append("first"))
	_register(func(_date: GameDate) -> void: order.append("second"))
	_register(func(_date: GameDate) -> void: order.append("third"))

	_clock.sleep_until_morning()
	assert_array(order).contains_exactly(["first", "second", "third"])


func test_day_hook_receives_the_new_date() -> void:
	var received: Array[GameDate] = []
	_register(func(date: GameDate) -> void: received.append(date))

	_clock.set_date(GameDate.new(1, Season.Type.SPRING, 7))
	_clock.sleep_until_morning()

	assert_array(received).has_size(1)
	if not received.is_empty():
		assert_int(received[0].day).is_equal(8)


func test_registering_the_same_hook_twice_is_idempotent() -> void:
	var count := [0]
	var hook := func(_date: GameDate) -> void: count[0] += 1
	_register(hook)
	_clock.register_day_hook(hook)
	_clock.sleep_until_morning()
	assert_int(count[0]).is_equal(1)


func test_unregistered_hook_is_not_called() -> void:
	var count := [0]
	var hook := func(_date: GameDate) -> void: count[0] += 1
	_clock.register_day_hook(hook)
	_clock.unregister_day_hook(hook)
	_clock.sleep_until_morning()
	assert_int(count[0]).is_equal(0)


func test_day_hooks_only_run_on_rollover() -> void:
	var count := [0]
	_register(func(_date: GameDate) -> void: count[0] += 1)

	_clock.set_time(10, 0)
	_clock.advance_minutes(120)
	assert_int(count[0]).is_equal(0)

	_clock.set_time(GameDateClock.DAY_ROLLOVER_HOUR - 1, 59)
	_clock.advance_minutes(1)
	assert_int(count[0]).is_equal(1)


# ---------------------------------------------------------------- 暂停

func test_paused_clock_does_not_advance() -> void:
	_clock.set_time(10, 0)
	_clock.set_paused(true)
	_clock.tick(10.0)
	assert_int(_clock.hour()).is_equal(10)
	assert_int(_clock.minute()).is_equal(0)


func test_unpaused_clock_advances_with_process() -> void:
	_clock.set_time(10, 0)
	_clock.seconds_per_game_minute = 1.0
	_clock.tick(3.5)
	assert_int(_clock.hour()).is_equal(10)
	assert_int(_clock.minute()).is_equal(3)


func test_time_scale_speeds_up_the_clock() -> void:
	_clock.set_time(10, 0)
	_clock.seconds_per_game_minute = 1.0
	_clock.set_time_scale(4.0)
	_clock.tick(3.0)
	assert_int(_clock.minute()).is_equal(12)


# ---------------------------------------------------------------- 序列化

func test_serialization_roundtrip() -> void:
	_clock.set_date(GameDate.new(2, Season.Type.FALL, 13))
	_clock.set_time(15, 42)
	var snapshot := _clock.to_dict()

	_clock.reset()
	_clock.from_dict(snapshot)

	assert_int(_clock.date.year).is_equal(2)
	assert_int(_clock.date.season).is_equal(Season.Type.FALL)
	assert_int(_clock.date.day).is_equal(13)
	assert_int(_clock.hour()).is_equal(15)
	assert_int(_clock.minute()).is_equal(42)


func test_from_dict_survives_a_json_roundtrip() -> void:
	_clock.set_date(GameDate.new(3, Season.Type.SUMMER, 4))
	_clock.set_time(9, 5)
	var parsed: Variant = JSON.parse_string(JSON.stringify(_clock.to_dict()))

	_clock.reset()
	_clock.from_dict(parsed)
	assert_int(_clock.date.year).is_equal(3)
	assert_int(_clock.date.day).is_equal(4)
	assert_int(_clock.hour()).is_equal(9)


func test_from_dict_tolerates_missing_fields() -> void:
	_clock.from_dict({})
	assert_int(_clock.date.year).is_equal(1)
	assert_int(_clock.hour()).is_equal(GameDateClock.DAY_START_HOUR)
