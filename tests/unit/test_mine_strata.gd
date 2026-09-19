extends GdUnitTestSuite
## 矿层数据测试：区间恰好覆盖 1–100、按深度解析正确、越深掉落偏好越强。

const DEPTH_ORDER: Array[StringName] = [&"moss", &"iron", &"crystal", &"magma", &"abyss"]


func test_strata_are_loaded() -> void:
	assert_int(Database.strata().size()).is_equal(DEPTH_ORDER.size())
	for id: StringName in DEPTH_ORDER:
		assert_object(Database.get_stratum(id)).override_failure_message(
			"缺少矿层 %s" % id
		).is_not_null()


func test_each_stratum_validates() -> void:
	for id: StringName in Database.strata():
		var stratum := Database.get_stratum(id)
		assert_array(stratum.validate()).override_failure_message(
			"矿层 %s 数据自检未通过" % id
		).is_empty()


func test_every_depth_belongs_to_exactly_one_stratum() -> void:
	var floor := auto_free(MineFloor.new()) as MineFloor
	for depth: int in range(1, MineRules.MAX_DEPTH + 1):
		var owners: int = 0
		for id: StringName in Database.strata():
			var stratum := Database.get_stratum(id)
			if stratum != null and stratum.covers(depth):
				owners += 1
		assert_int(owners).override_failure_message(
			"深度 %d 应当恰好属于 1 个矿层" % depth
		).is_equal(1)
		assert_object(floor._find_stratum(depth)).override_failure_message(
			"深度 %d 解析不到矿层" % depth
		).is_not_null()


func test_depth_resolves_to_expected_stratum() -> void:
	var floor := auto_free(MineFloor.new()) as MineFloor
	var boundaries := {
		1: &"moss", 19: &"moss", 20: &"iron", 39: &"iron",
		40: &"crystal", 59: &"crystal", 60: &"magma", 79: &"magma",
		80: &"abyss", 100: &"abyss",
	}
	for depth: int in boundaries:
		var stratum := floor._find_stratum(depth)
		assert_str(String(stratum.id) if stratum != null else "").override_failure_message(
			"深度 %d 的矿层不对" % depth
		).is_equal(String(boundaries[depth]))


func test_deeper_strata_are_richer() -> void:
	var previous_bias: float = -1.0
	for id: StringName in DEPTH_ORDER:
		var stratum := Database.get_stratum(id)
		assert_bool(stratum.loot_bias >= previous_bias).override_failure_message(
			"矿层 %s 的 loot_bias 不应低于上一层" % id
		).is_true()
		previous_bias = stratum.loot_bias
