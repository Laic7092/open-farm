extends GdUnitTestSuite
## 昼夜光照曲线测试（纯逻辑，不加载场景）。


func test_noon_is_bright_white() -> void:
	var noon := DayNight.ambient_color(12 * 60)
	assert_bool(noon.is_equal_approx(Color(1.0, 1.0, 1.0))).is_true()


func test_midnight_is_darker_than_noon() -> void:
	var noon := DayNight.ambient_color(12 * 60)
	var night := DayNight.ambient_color(0)
	assert_float(night.get_luminance()).is_less(noon.get_luminance())


func test_night_is_cooler() -> void:
	var night := DayNight.ambient_color(0)
	assert_float(night.b).is_greater(night.r)


func test_evening_is_warmer() -> void:
	var evening := DayNight.ambient_color(18 * 60 + 30)
	assert_float(evening.r).is_greater(evening.b)


func test_curve_has_no_jumps() -> void:
	var previous := DayNight.ambient_color(-1)
	for minute: int in DayNight.MINUTES_PER_DAY:
		var current := DayNight.ambient_color(minute)
		var delta: float = (
			absf(current.r - previous.r)
			+ absf(current.g - previous.g)
			+ absf(current.b - previous.b)
		)
		var message := "第 %d 分钟的光照曲线出现跳变（%.3f）" % [minute, delta]
		assert_bool(delta < 0.1).override_failure_message(message).is_true()
		previous = current


func test_curve_wraps_around_midnight() -> void:
	assert_bool(DayNight.ambient_color(-1).is_equal_approx(DayNight.ambient_color(1439))).is_true()
	assert_bool(DayNight.ambient_color(1440).is_equal_approx(DayNight.ambient_color(0))).is_true()


func test_lamp_energy_is_off_during_the_day() -> void:
	assert_float(DayNight.lamp_energy(12 * 60)).is_equal(0.0)
	assert_float(DayNight.lamp_energy(8 * 60)).is_equal(0.0)


func test_lamp_energy_is_full_at_night() -> void:
	assert_float(DayNight.lamp_energy(23 * 60)).is_equal(1.0)
	assert_float(DayNight.lamp_energy(0)).is_equal(1.0)


func test_lamp_energy_fades_in_and_out() -> void:
	var dusk := DayNight.lamp_energy(17 * 60 + 30)
	var dawn := DayNight.lamp_energy(6 * 60)
	assert_float(dusk).is_greater(0.0)
	assert_float(dusk).is_less(1.0)
	assert_float(dawn).is_greater(0.0)
	assert_float(dawn).is_less(1.0)


func test_night_boundaries() -> void:
	assert_bool(DayNight.is_night(17 * 60 + 59)).is_false()
	assert_bool(DayNight.is_night(18 * 60)).is_true()
	assert_bool(DayNight.is_night(23 * 60 + 59)).is_true()
	assert_bool(DayNight.is_night(0)).is_true()
	assert_bool(DayNight.is_night(5 * 60 + 59)).is_true()
	assert_bool(DayNight.is_night(6 * 60)).is_false()
	assert_bool(DayNight.is_night(12 * 60)).is_false()


func test_sun_is_hidden_at_night() -> void:
	assert_bool(DayNight.sun_visible(12 * 60)).is_true()
	assert_bool(DayNight.sun_visible(23 * 60)).is_false()

func test_sun_energy_peaks_at_noon_and_dies_at_night() -> void:
	assert_float(DayNight.sun_energy(12 * 60)).is_equal_approx(1.0, 0.001)
	assert_float(DayNight.sun_energy(0)).is_equal(0.0)
	assert_float(DayNight.sun_energy(23 * 60)).is_equal(0.0)
	var morning := DayNight.sun_energy(8 * 60)
	var evening := DayNight.sun_energy(16 * 60)
	assert_float(morning).is_greater(0.0)
	assert_float(morning).is_less(1.0)
	assert_float(evening).is_greater(0.0)
	assert_float(evening).is_less(1.0)


func test_sun_rotation_sweeps_from_east_to_west() -> void:
	assert_float(DayNight.sun_rotation_degrees(6 * 60)).is_equal_approx(-25.0, 0.001)
	assert_float(DayNight.sun_rotation_degrees(12 * 60)).is_equal_approx(0.0, 0.001)
	assert_float(DayNight.sun_rotation_degrees(18 * 60)).is_equal_approx(25.0, 0.001)
	# 夜晚没有太阳，但返回值必须连续地停在日落那一侧。
	assert_float(DayNight.sun_rotation_degrees(0)).is_equal_approx(25.0, 0.001)
	assert_float(DayNight.sun_rotation_degrees(23 * 60)).is_equal_approx(25.0, 0.001)
