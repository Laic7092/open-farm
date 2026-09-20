extends GdUnitTestSuite
## 触控控件的可执行规范：摇杆"位置 → 方向"的翻译、方向到动作名的映射，
## 以及显示设置的落盘 / 读回。
##
## 屏幕上的拖拽本身没法在无头环境里断言，所以这里只覆盖纯函数与设置这两层：
## 真正"点了摇杆人会不会走"由 [code]tools/smoke[/code] 的端到端检查兜底。

## 用例自己的设置文件，绝不碰真实的 [code]user://display_settings.cfg[/code]。
const TEST_PATH: String = "user://test_touch_settings.cfg"

var _original_path: String = TouchSettings.DEFAULT_SETTINGS_PATH


func before_test() -> void:
	_original_path = TouchSettings.settings_path
	TouchSettings.settings_path = TEST_PATH
	_delete_settings_file()
	TouchSettings.reset()


func after_test() -> void:
	_delete_settings_file()
	TouchSettings.settings_path = _original_path
	TouchSettings.reload_from_disk()


# ---------------------------------------------------------------- 摇杆方向

func test_offset_inside_deadzone_is_zero() -> void:
	# 半径 26 px，死区 15% ≈ 3.9 px：站着不动时手指的抖动不应该让角色飘。
	assert_vector(TouchStick.direction_of(Vector2(3.0, 0.0), 26.0)).is_equal(Vector2.ZERO)


func test_partial_push_keeps_its_length() -> void:
	var direction := TouchStick.direction_of(Vector2(13.0, 0.0), 26.0)
	assert_float(direction.length()).is_equal_approx(0.5, 0.001)
	assert_vector(direction.normalized()).is_equal_approx(Vector2.RIGHT, Vector2(0.001, 0.001))


func test_push_inside_control_but_outside_base_is_full_deflection() -> void:
	# 控件比底座大一圈：在角落里蹭一下也应当立刻满偏。
	var direction := TouchStick.direction_of(Vector2(70.0, 0.0), 26.0)
	assert_float(direction.length()).is_equal_approx(1.0, 0.001)
	assert_bool(direction.length() >= TouchStick.RUN_THRESHOLD).is_true()


func test_diagonal_push_is_normalized_with_clamped_length() -> void:
	var direction := TouchStick.direction_of(Vector2(20.0, 20.0), 26.0)
	assert_float(direction.length()).is_equal_approx(1.0, 0.001)
	assert_float(direction.x).is_equal_approx(direction.y, 0.001)


func test_zero_radius_is_safe() -> void:
	assert_vector(TouchStick.direction_of(Vector2(10.0, 0.0), 0.0)).is_equal(Vector2.ZERO)


func test_small_push_does_not_run() -> void:
	var direction := TouchStick.direction_of(Vector2(8.0, 0.0), 26.0)
	assert_bool(direction.length() < TouchStick.RUN_THRESHOLD).is_true()


# ---------------------------------------------------------------- 动作映射

func test_cardinal_direction_maps_to_one_action() -> void:
	var strengths := TouchControls.action_strengths(Vector2.RIGHT)
	assert_dict(strengths).contains_keys([&"move_right"])
	assert_float(strengths[&"move_right"]).is_equal_approx(1.0, 0.001)


func test_diagonal_direction_maps_to_two_actions() -> void:
	var strengths := TouchControls.action_strengths(Vector2(0.6, -0.6))
	assert_dict(strengths).contains_keys([&"move_right", &"move_up"])
	assert_float(strengths[&"move_right"]).is_equal_approx(0.6, 0.001)
	assert_float(strengths[&"move_up"]).is_equal_approx(0.6, 0.001)
	assert_bool(strengths.has(&"move_left")).is_false()
	assert_bool(strengths.has(&"move_down")).is_false()


func test_centered_stick_maps_to_no_action() -> void:
	assert_dict(TouchControls.action_strengths(Vector2.ZERO)).is_empty()


# ---------------------------------------------------------------- 设置

func test_setting_roundtrips_through_disk() -> void:
	TouchSettings.set_enabled(true)
	assert_bool(TouchSettings.is_enabled()).is_true()

	TouchSettings.reload_from_disk()  # 丢掉内存值，强制重新读盘
	assert_bool(TouchSettings.is_enabled()).is_true()

	TouchSettings.set_enabled(false)
	TouchSettings.reload_from_disk()
	assert_bool(TouchSettings.is_enabled()).is_false()


func test_non_persisted_change_is_memory_only() -> void:
	TouchSettings.set_enabled(true, false)
	assert_bool(TouchSettings.is_enabled()).is_true()

	TouchSettings.reload_from_disk()
	assert_bool(TouchSettings.is_enabled()).is_false()


func test_headless_defaults_to_keyboard() -> void:
	# 无头环境没有触摸屏，缺省必须是关——否则 CI 里会凭空多出一层 UI。
	assert_bool(DisplayServer.is_touchscreen_available()).is_false()
	assert_bool(TouchSettings.is_enabled()).is_false()


func test_pointer_is_independent_of_touch_toggle() -> void:
	# 鼠标与触控开关无关：开关只影响屏幕控件，指针始终可用。
	TouchSettings.set_enabled(false, false)
	assert_bool(PointerInput.accepts_mouse()).is_true()
	TouchSettings.set_enabled(true, false)
	assert_bool(PointerInput.accepts_mouse()).is_true()


func test_ui_scale_applies_to_stick_and_pad() -> void:
	# 走公开设置：_ready() 的延迟应用会读到它，和真实流程一致。
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(2.0, false)
	var touch := auto_free(load("res://scenes/ui/touch_controls.tscn").instantiate()) as TouchControls
	add_child(touch)
	# 等布局跑完，pivot 才会依赖到真实的 size。
	await get_tree().process_frame
	await get_tree().process_frame

	assert_float(touch.joystick.scale.x).is_equal_approx(2.0, 0.001)
	# 摇杆钉左下角：pivot 落在控件底边。
	assert_float(touch.joystick.pivot_offset.y).is_equal_approx(touch.joystick.size.y, 0.001)

	var pad := touch.find_child("ActionPad", true, false) as Control
	assert_object(pad).is_not_null()
	if pad == null:
		return
	assert_float(pad.scale.x).is_equal_approx(2.0, 0.001)
	# ABXY 整体钉屏幕右下角：pivot 落在 ActionPad 的右下角。
	assert_vector(pad.pivot_offset).is_equal_approx(pad.size, Vector2(0.001, 0.001))

	UiSettings.set_scale(previous, false)


## 删掉用例自己的设置文件（存在与否都无所谓）。
func _delete_settings_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
