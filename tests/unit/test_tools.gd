extends GdUnitTestSuite
## 工具单元测试：作用范围展开、种类映射、音效归属。
##
## 工具行为本身要真正操作农田 / 植被，属于场景级；这里只锁住可以脱离世界验证的
## 纯逻辑——范围展开的几何、每种 kind 都有对应单元、音效有唯一归属。


func test_area_cells_expand_is_centered() -> void:
	var ctx := ToolContext.new()
	var cells := ctx.area_cells(Vector2i(5, 5), Vector2i(3, 3))
	assert_int(cells.size()).is_equal(9)
	assert_bool(cells.has(Vector2i(4, 4))).is_true()
	assert_bool(cells.has(Vector2i(5, 5))).is_true()
	assert_bool(cells.has(Vector2i(6, 6))).is_true()


func test_area_cells_even_size_bias_to_bottom_right() -> void:
	var ctx := ToolContext.new()
	var cells := ctx.area_cells(Vector2i(0, 0), Vector2i(2, 2))
	assert_int(cells.size()).is_equal(4)
	assert_bool(cells.has(Vector2i(0, 0))).is_true()
	assert_bool(cells.has(Vector2i(1, 1))).is_true()


func test_area_size_is_at_least_one() -> void:
	var ctx := ToolContext.new()
	assert_int(ctx.area_cells(Vector2i(2, 2), Vector2i(0, 0)).size()).is_equal(1)


func _units() -> Array[Tool]:
	return [
		ToolHoe.new(),
		ToolWateringCan.new(),
		ToolAxe.new(),
		ToolPickaxe.new(),
		ToolSickle.new(),
		ToolFishing.new(),
	]


func test_each_kind_has_its_own_unit() -> void:
	var seen: Dictionary = {}
	for unit: Tool in _units():
		var kind: int = unit.kind()
		assert_bool(seen.has(kind)).override_failure_message(
			"工具种类 %d 出现了两个单元" % kind
		).is_false()
		seen[kind] = true
	assert_int(seen.size()).is_equal(6)


func test_tools_own_their_sound() -> void:
	assert_bool(ToolHoe.new().sfx_id() == AudioCatalog.SFX_TILL).is_true()
	assert_bool(ToolWateringCan.new().sfx_id() == AudioCatalog.SFX_WATER).is_true()
	assert_bool(ToolAxe.new().sfx_id() == AudioCatalog.SFX_CHOP).is_true()
	assert_bool(ToolPickaxe.new().sfx_id() == AudioCatalog.SFX_CHOP).is_true()
	# 播种不出自工具系统：种子的音效由 [FarmGrid] 在种成功时播放。
	# 钓竿不在地面上结算，不出声。
	assert_bool(ToolFishing.new().sfx_id() == &"").is_true()


## 挥动曲线：从起手出发、经过蓄力与命中、再回到起手。
func test_swing_curve_visits_windup_and_strike() -> void:
	assert_float(ToolSwing.angle_deg(0.0)).is_equal_approx(ToolSwing.REST_DEG, 0.001)
	assert_float(ToolSwing.angle_deg(1.0)).is_equal_approx(ToolSwing.REST_DEG, 0.001)
	assert_float(ToolSwing.angle_deg(ToolSwing.WINDUP_END)).is_equal_approx(
		ToolSwing.WINDUP_DEG, 0.001
	)
	assert_float(ToolSwing.angle_deg(ToolSwing.STRIKE_END)).is_equal_approx(
		ToolSwing.STRIKE_DEG, 0.001
	)
	# 真的"挥"出去了：命中角大于起手角。
	assert_bool(ToolSwing.STRIKE_DEG > ToolSwing.REST_DEG).is_true()


## 进度越界不能甩出奇怪的角度。
func test_swing_curve_clamps_out_of_range() -> void:
	assert_float(ToolSwing.angle_deg(-3.0)).is_equal_approx(ToolSwing.REST_DEG, 0.001)
	assert_float(ToolSwing.angle_deg(42.0)).is_equal_approx(ToolSwing.REST_DEG, 0.001)
