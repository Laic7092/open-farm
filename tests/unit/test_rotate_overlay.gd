extends GdUnitTestSuite
## 竖屏提示遮罩的纯函数规范：本作只服务横屏，非横屏由 [RotateOverlay] 盖住并提示旋转。
## 视口如何铺满窗口由 project.godot 的 canvas_items + fractional 接管，不再有自定义计算。


func test_rotate_prompt_only_for_non_landscape() -> void:
	# 竖屏 / 方屏提示旋转，横屏（含小于基准的小窗）不提示。
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
