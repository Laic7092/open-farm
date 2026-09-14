extends GdUnitTestSuite
## 游戏时钟测试：跨天、季节/年份进位、有序日结转钩子。
##
## GameClock 是 autoload（全局单例），每个用例前必须复位，否则用例之间会互相污染。

var _hooks: Array[Callable] = []


func before_test() -> void:
	GameClock.reset()
	GameClock.paused = false
	GameClock.time_scale = 1.0
	_hooks.clear()


func after_test() -> void:
	for hook: Callable in _hooks:
		GameClock.unregister_day_hook(hook)
	_hooks.clear()


func _register(hook: Callable) -> Callable:
	GameClock.register_day_hook(hook)
	_hooks.append(hook)
	return hook


# ---------------------------------------------------------------- 复位与查询

func test_reset_starts_at_spring_day_one_0600() -> void:
	GameClock.reset()
	assert_int(GameClock.date.year).is_equal(1)
	assert_int(GameClock.date.season).is_equal(Season.Type.SPRING)
	assert_int(GameClock.date.day).is_equal(1)
	assert_int(GameClock.hour()).is_equal(GameClock.DAY_START_HOUR)
	assert_int(GameClock.minute()).is_equal(0)


func test_time_string_is_zero_padded() -> void:
	GameClock.set_time(7, 5)
	assert_str(GameClock.time_string()).is_equal("07:05")


func test_minutes_since_day_start_handles_midnight() -> void:
	GameClock.set_time(6, 0)
	assert_int(GameClock.minutes_since_day_start()).is_equal(0)
	GameClock.set_time(23, 59)
	assert_int(GameClock.minutes_since_day_start()).is_equal(17 * 60 + 59)
	GameClock.set_time(1, 0)
	assert_int(GameClock.minutes_since_day_start()).is_equal(19 * 60)


func test_is_past_midnight() -> void:
	GameClock.set_time(23, 0)
	assert_bool(GameClock.is_past_midnight()).is_false()
	GameClock.set_time(1, 0)
	assert_bool(GameClock.is_past_midnight()).is_true()


func test_set_time_clamps_invalid_input() -> void:
	GameClock.set_time(99, 99)
	assert_int(GameClock.hour()).is_equal(23)
	assert_int(GameClock.minute()).is_equal(59)


# ---------------------------------------------------------------- 跨天

func test_advance_minutes_moves_the_clock() -> void:
	GameClock.set_time(10, 0)
	GameClock.advance_minutes(90)
	assert_int(GameClock.hour()).is_equal(11)
	assert_int(GameClock.minute()).is_equal(30)


func test_rollover_happens_at_0200() -> void:
	var day_before: int = GameClock.date.day
	GameClock.set_time(GameClock.DAY_ROLLOVER_HOUR - 1, 59)
	GameClock.advance_minutes(1)
	assert_int(GameClock.date.day).is_equal(day_before + 1)
	assert_int(GameClock.hour()).is_equal(GameClock.DAY_ROLLOVER_HOUR)


func test_time_does_not_roll_over_before_0200() -> void:
	var day_before: int = GameClock.date.day
	GameClock.set_time(1, 58)
	GameClock.advance_minutes(1)
	assert_int(GameClock.date.day).is_equal(day_before)


func test_season_advances_after_the_last_day() -> void:
	GameClock.date = GameDate.new(1, Season.Type.SPRING, Season.DAYS_PER_SEASON)
	GameClock.sleep_until_morning()
	assert_int(GameClock.date.season).is_equal(Season.Type.SUMMER)
	assert_int(GameClock.date.day).is_equal(1)


func test_year_advances_after_winter() -> void:
	GameClock.date = GameDate.new(1, Season.Type.WINTER, Season.DAYS_PER_SEASON)
	GameClock.sleep_until_morning()
	assert_int(GameClock.date.year).is_equal(2)
	assert_int(GameClock.date.season).is_equal(Season.Type.SPRING)


func test_sleep_returns_to_morning_and_advances_a_day() -> void:
	GameClock.set_time(23, 30)
	var day_before: int = GameClock.date.day
	GameClock.sleep_until_morning()
	assert_int(GameClock.hour()).is_equal(GameClock.DAY_START_HOUR)
	assert_int(GameClock.date.day).is_equal(day_before + 1)


# ---------------------------------------------------------------- 日结转钩子

func test_day_hooks_run_in_registration_order() -> void:
	var order: Array[String] = []
	_register(func(_date: GameDate) -> void: order.append("first"))
	_register(func(_date: GameDate) -> void: order.append("second"))
	_register(func(_date: GameDate) -> void: order.append("third"))

	GameClock.sleep_until_morning()
	assert_array(order).contains_exactly(["first", "second", "third"])


func test_day_hook_receives_the_new_date() -> void:
	var received: Array[GameDate] = []
	_register(func(date: GameDate) -> void: received.append(date))

	GameClock.date = GameDate.new(1, Season.Type.SPRING, 7)
	GameClock.sleep_until_morning()

	assert_array(received).has_size(1)
	if not received.is_empty():
		assert_int(received[0].day).is_equal(8)


func test_registering_the_same_hook_twice_is_idempotent() -> void:
	var count := [0]
	var hook := func(_date: GameDate) -> void: count[0] += 1
	_register(hook)
	GameClock.register_day_hook(hook)
	GameClock.sleep_until_morning()
	assert_int(count[0]).is_equal(1)


func test_unregistered_hook_is_not_called() -> void:
	var count := [0]
	var hook := func(_date: GameDate) -> void: count[0] += 1
	GameClock.register_day_hook(hook)
	GameClock.unregister_day_hook(hook)
	GameClock.sleep_until_morning()
	assert_int(count[0]).is_equal(0)


func test_day_hooks_only_run_on_rollover() -> void:
	var count := [0]
	_register(func(_date: GameDate) -> void: count[0] += 1)

	GameClock.set_time(10, 0)
	GameClock.advance_minutes(120)
	assert_int(count[0]).is_equal(0)

	GameClock.set_time(GameClock.DAY_ROLLOVER_HOUR - 1, 59)
	GameClock.advance_minutes(1)
	assert_int(count[0]).is_equal(1)


# ---------------------------------------------------------------- 暂停

func test_paused_clock_does_not_advance() -> void:
	GameClock.set_time(10, 0)
	GameClock.paused = true
	GameClock._process(10.0)
	assert_int(GameClock.hour()).is_equal(10)
	assert_int(GameClock.minute()).is_equal(0)


func test_unpaused_clock_advances_with_process() -> void:
	GameClock.set_time(10, 0)
	GameClock.seconds_per_game_minute = 1.0
	GameClock._process(3.5)
	assert_int(GameClock.hour()).is_equal(10)
	assert_int(GameClock.minute()).is_equal(3)


func test_time_scale_speeds_up_the_clock() -> void:
	GameClock.set_time(10, 0)
	GameClock.seconds_per_game_minute = 1.0
	GameClock.time_scale = 4.0
	GameClock._process(3.0)
	assert_int(GameClock.minute()).is_equal(12)


# ---------------------------------------------------------------- 序列化

func test_serialization_roundtrip() -> void:
	GameClock.date = GameDate.new(2, Season.Type.FALL, 13)
	GameClock.set_time(15, 42)
	var snapshot := GameClock.to_dict()

	GameClock.reset()
	GameClock.from_dict(snapshot)

	assert_int(GameClock.date.year).is_equal(2)
	assert_int(GameClock.date.season).is_equal(Season.Type.FALL)
	assert_int(GameClock.date.day).is_equal(13)
	assert_int(GameClock.hour()).is_equal(15)
	assert_int(GameClock.minute()).is_equal(42)


func test_from_dict_survives_a_json_roundtrip() -> void:
	GameClock.date = GameDate.new(3, Season.Type.SUMMER, 4)
	GameClock.set_time(9, 5)
	var parsed: Variant = JSON.parse_string(JSON.stringify(GameClock.to_dict()))

	GameClock.reset()
	GameClock.from_dict(parsed)
	assert_int(GameClock.date.year).is_equal(3)
	assert_int(GameClock.date.day).is_equal(4)
	assert_int(GameClock.hour()).is_equal(9)


func test_from_dict_tolerates_missing_fields() -> void:
	GameClock.from_dict({})
	assert_int(GameClock.date.year).is_equal(1)
	assert_int(GameClock.hour()).is_equal(GameClock.DAY_START_HOUR)
