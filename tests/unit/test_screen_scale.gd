extends GdUnitTestSuite
## 整数覆盖的纯函数规范：视口按最大整数倍铺满窗口，且不小于基准分辨率。

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
	for size: Vector2i in [Vector2i(1366, 768), Vector2i(1000, 700), Vector2i(2533, 1170)]:
		var cover := ScreenScale.cover_size(size)
		assert_bool(cover.x >= 640 and cover.y >= 360).override_failure_message(
			"%s 的覆盖视口 %s 小于基准" % [size, cover]
		).is_true()
