extends GdUnitTestSuite
## [ViewSettings] 的可执行规范：挡位吸附、上下界夹取、落盘 / 读回。
##
## 与 [code]test_touch_controls.gd[/code] 同一套做法：用例自己的设置文件，
## 绝不碰真实的 [code]user://display_settings.cfg[/code]。

const TEST_PATH: String = "user://test_view_settings.cfg"

var _original_path: String = ViewSettings.DEFAULT_SETTINGS_PATH


func before_test() -> void:
	_original_path = ViewSettings.settings_path
	ViewSettings.settings_path = TEST_PATH
	_delete_settings_file()
	ViewSettings.reset()


func after_test() -> void:
	_delete_settings_file()
	ViewSettings.settings_path = _original_path
	ViewSettings.reload_from_disk()


func _delete_settings_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_default_follows_device() -> void:
	# 触屏给 1.5、桌面给 1.0；不假设跑测试的机器是哪一种。
	assert_float(ViewSettings.zoom()).is_equal_approx(ViewSettings.default_zoom(), 0.001)


func test_touch_default_is_1_5() -> void:
	assert_float(ViewSettings.default_zoom_for(true)).is_equal_approx(1.5, 0.001)


func test_desktop_default_is_1_0() -> void:
	assert_float(ViewSettings.default_zoom_for(false)).is_equal_approx(1.0, 0.001)


func test_value_snaps_to_step() -> void:
	ViewSettings.set_zoom(1.30, false)
	assert_float(ViewSettings.zoom()).is_equal_approx(1.25, 0.001)


func test_value_clamps_below_min() -> void:
	ViewSettings.set_zoom(0.10, false)
	assert_float(ViewSettings.zoom()).is_equal_approx(ViewSettings.ZOOM_MIN, 0.001)


func test_value_clamps_above_max() -> void:
	ViewSettings.set_zoom(9.0, false)
	assert_float(ViewSettings.zoom()).is_equal_approx(ViewSettings.ZOOM_MAX, 0.001)


func test_setting_roundtrips_through_disk() -> void:
	ViewSettings.set_zoom(2.25)
	assert_float(ViewSettings.zoom()).is_equal_approx(2.25, 0.001)

	ViewSettings.reload_from_disk()
	assert_float(ViewSettings.zoom()).is_equal_approx(2.25, 0.001)
