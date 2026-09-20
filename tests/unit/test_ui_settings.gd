extends GdUnitTestSuite
## [UiSettings] 的可执行规范：挡位吸附、上下界夹取、落盘 / 读回，
## 以及它与 [ViewSettings] / [TouchSettings] 共用同一设置文件时互不覆盖。
##
## 与 [code]test_view_settings.gd[/code] 同一套做法：用例自己的设置文件，
## 绝不碰真实的 [code]user://display_settings.cfg[/code]。

const TEST_PATH: String = "user://test_ui_settings.cfg"

var _original_path: String = UiSettings.DEFAULT_SETTINGS_PATH


func before_test() -> void:
	_original_path = UiSettings.settings_path
	UiSettings.settings_path = TEST_PATH
	_delete_settings_file()
	UiSettings.reset()


func after_test() -> void:
	_delete_settings_file()
	UiSettings.settings_path = _original_path
	UiSettings.reload_from_disk()


func _delete_settings_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## user:// 在受限沙箱 / 只读挂载里写不进；此时跳过磁盘断言，
## 与设置类“写不进就静默降级”的契约一致，不给 CI 添假失败。
func _storage_writable() -> bool:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	return true


func test_default_follows_device() -> void:
	# 触屏给 1.5、桌面给 1.0；不假设跑测试的机器是哪一种。
	assert_float(UiSettings.scale()).is_equal_approx(UiSettings.default_scale(), 0.001)


func test_touch_default_is_1_5() -> void:
	assert_float(UiSettings.default_scale_for(true)).is_equal_approx(1.5, 0.001)


func test_desktop_default_is_1_0() -> void:
	assert_float(UiSettings.default_scale_for(false)).is_equal_approx(1.0, 0.001)


func test_value_snaps_to_step() -> void:
	UiSettings.set_scale(1.30, false)
	assert_float(UiSettings.scale()).is_equal_approx(1.25, 0.001)


func test_value_clamps_below_min() -> void:
	UiSettings.set_scale(0.10, false)
	assert_float(UiSettings.scale()).is_equal_approx(UiSettings.SCALE_MIN, 0.001)


func test_value_clamps_above_max() -> void:
	UiSettings.set_scale(9.0, false)
	assert_float(UiSettings.scale()).is_equal_approx(UiSettings.SCALE_MAX, 0.001)


func test_setting_roundtrips_through_disk() -> void:
	if not _storage_writable():
		return
	UiSettings.set_scale(2.25)
	assert_float(UiSettings.scale()).is_equal_approx(2.25, 0.001)

	UiSettings.reload_from_disk()
	assert_float(UiSettings.scale()).is_equal_approx(2.25, 0.001)


## 三个显示设置共用一个 cfg：后写的必须保住先写的 section。
func test_shares_display_file_without_clobbering_others() -> void:
	if not _storage_writable():
		return
	var view_path: String = ViewSettings.settings_path
	var touch_path: String = TouchSettings.settings_path
	ViewSettings.settings_path = TEST_PATH
	TouchSettings.settings_path = TEST_PATH
	ViewSettings.reset()
	TouchSettings.reset()

	ViewSettings.set_zoom(2.0)
	TouchSettings.set_enabled(true)
	UiSettings.set_scale(1.75)

	ViewSettings.reload_from_disk()
	TouchSettings.reload_from_disk()
	UiSettings.reload_from_disk()
	var zoom: float = ViewSettings.zoom()
	var enabled: bool = TouchSettings.is_enabled()
	var scale: float = UiSettings.scale()

	# 先把别的类的静态路径还回去，断言失败也不会污染后续用例。
	ViewSettings.settings_path = view_path
	TouchSettings.settings_path = touch_path
	ViewSettings.reload_from_disk()
	TouchSettings.reload_from_disk()

	assert_float(zoom).is_equal_approx(2.0, 0.001)
	assert_bool(enabled).is_true()
	assert_float(scale).is_equal_approx(1.75, 0.001)
