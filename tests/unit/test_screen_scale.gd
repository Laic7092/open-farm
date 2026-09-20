extends GdUnitTestSuite
## 整数覆盖的纯函数规范：视口按最大整数倍铺满窗口；非横屏 / 窗口小于基准时退回基准视口，
## 由 [method ScreenScale.apply] 等比铺满，并由 [RotateOverlay] 提示旋转。

func test_phone_cover_is_exact_three_times() -> void:
	# iPhone 13 横屏 2532×1170：N=3 → 844×390，正好 3× 铺满、0 黑边。
	assert_that(ScreenScale.cover_size(Vector2i(2532, 1170))).is_equal(Vector2i(844, 390))


func test_desktop_16_9_stays_at_base() -> void:
	# 16:9 桌面正好 2× / 3×，退回 640×360，桌面零变化。
	assert_that(ScreenScale.cover_size(Vector2i(1280, 720))).is_equal(Vector2i(640, 360))
	assert_that(ScreenScale.cover_size(Vector2i(1920, 1080))).is_equal(Vector2i(640, 360))


func test_16_10_desktop_shows_a_little_more() -> void:
	# 16:10 桌面 1920×1200：N=3 → 640×400（多一点纵向世界，仍然 0 黑边）。
	assert_that(ScreenScale.cover_size(Vector2i(1920, 1200))).is_equal(Vector2i(640, 400))


func test_cover_never_shows_less_than_base() -> void:
	for size: Vector2i in [
		Vector2i(1366, 768), Vector2i(1000, 700), Vector2i(2533, 1170)
	]:
		var cover := ScreenScale.cover_size(size)
		assert_bool(cover.x >= 640 and cover.y >= 360).override_failure_message(
			"%s 的覆盖视口 %s 小于基准" % [size, cover]
		).is_true()


func test_landscape_phone_can_use_integer_cover() -> void:
	# 横屏进入时走原有整数覆盖路径，不能因为竖屏回退误伤。
	assert_bool(ScreenScale.can_integer_cover(Vector2i(2532, 1170))).is_true()


func test_portrait_window_falls_back_to_base_viewport() -> void:
	# 浏览器竖屏 390×844 与真机 1170×2532 都会让 floor(宽/基准宽)=0；不当构图，
	# 退回基准视口，由 [RotateOverlay] 盖住并提示旋转。
	for size: Vector2i in [Vector2i(390, 844), Vector2i(1170, 2532)]:
		assert_bool(ScreenScale.can_integer_cover(size)).override_failure_message(
			"%s 不应走整数覆盖" % size
		).is_false()
		assert_that(ScreenScale.cover_size(size)).is_equal(Vector2i(640, 360))


func test_square_window_falls_back_to_base_viewport() -> void:
	assert_bool(ScreenScale.can_integer_cover(Vector2i(800, 800))).is_false()
	assert_that(ScreenScale.cover_size(Vector2i(800, 800))).is_equal(Vector2i(640, 360))


func test_landscape_window_smaller_than_base_falls_back_to_base_viewport() -> void:
	# 窗口宽或高装不下基准时，整数覆盖无解；仍退回基准视口等比铺满。
	for size: Vector2i in [Vector2i(500, 300), Vector2i(1000, 300), Vector2i(700, 350)]:
		assert_bool(ScreenScale.can_integer_cover(size)).override_failure_message(
			"%s 不应走整数覆盖" % size
		).is_false()
		assert_that(ScreenScale.cover_size(size)).is_equal(Vector2i(640, 360))


func test_rotate_prompt_only_for_non_landscape() -> void:
	# 本作只服务横屏：竖屏 / 方屏由 [RotateOverlay] 提示旋转，横屏（含小于基准的小窗）不提示。
	for size: Vector2i in [Vector2i(390, 844), Vector2i(1170, 2532), Vector2i(800, 800)]:
		assert_bool(RotateOverlay.should_show(size)).override_failure_message(
			"%s 应提示旋转" % size
		).is_true()
	for size: Vector2i in [Vector2i(844, 390), Vector2i(1280, 720), Vector2i(500, 300)]:
		assert_bool(RotateOverlay.should_show(size)).override_failure_message(
			"%s 不应提示旋转" % size
		).is_false()
	# 无头 / 窗口未就绪时尺寸为 0，不能当成竖屏弹遮罩（否则吞掉输入）。
	assert_bool(RotateOverlay.should_show(Vector2i(0, 0))).is_false()
