extends GdUnitTestSuite
## 委托板规则测试：出题确定性、每日刷新与存档往返。
##
## 委托板最容易出的 bug 是"同一天读档后委托换了"或"跨天没有刷新"，
## 所以这里全部围绕 [GameDate] 的可复现性来断言。


func _pool() -> Array[StringName]:
	return [&"a", &"b", &"c", &"d", &"e", &"f", &"g", &"h"]


func test_offers_are_deterministic_for_the_same_day() -> void:
	var date := GameDate.new(1, Season.Type.SPRING, 4)
	var first := CommissionRules.offers_for(date, _pool())
	var second := CommissionRules.offers_for(date, _pool())
	assert_array(first).is_equal(second)


func test_offers_are_distinct_and_within_pool() -> void:
	var date := GameDate.new(2, Season.Type.FALL, 9)
	var offers := CommissionRules.offers_for(date, _pool())
	assert_int(offers.size()).is_equal(CommissionRules.DAILY_COUNT)
	var seen: Dictionary = {}
	for offer_id: StringName in offers:
		assert_bool(_pool().has(offer_id)).is_true()
		assert_bool(seen.has(offer_id)).override_failure_message("委托重复：%s" % offer_id).is_false()
		seen[offer_id] = true


func test_offers_change_across_days() -> void:
	var pool := _pool()
	var runs := 0
	for day: int in range(1, 12):
		var a := CommissionRules.offers_for(GameDate.new(1, Season.Type.SUMMER, day), pool)
		var b := CommissionRules.offers_for(GameDate.new(1, Season.Type.SUMMER, day + 1), pool)
		if a != b:
			runs += 1
	assert_int(runs).override_failure_message("连续两天出题完全一样，随机性失效").is_greater(0)


func test_empty_pool_yields_nothing() -> void:
	var empty: Array[StringName] = []
	assert_array(CommissionRules.offers_for(GameDate.new(1, Season.Type.SPRING, 1), empty)).is_empty()


# ---------------------------------------------------------------- 状态

func test_state_resets_on_new_day() -> void:
	var state := CommissionState.new()
	var day_one := GameDate.new(1, Season.Type.SPRING, 1)
	assert_bool(state.ensure_for(day_one)).is_true()
	state.complete(&"a")
	assert_bool(state.is_completed(&"a")).is_true()

	# 同一天重复 ensure 不刷新。
	assert_bool(state.ensure_for(day_one)).is_false()
	assert_bool(state.is_completed(&"a")).is_true()

	# 换一天就清空。
	assert_bool(state.ensure_for(GameDate.new(1, Season.Type.SPRING, 2))).is_true()
	assert_bool(state.is_completed(&"a")).is_false()


func test_complete_is_idempotent() -> void:
	var state := CommissionState.new()
	state.ensure_for(GameDate.new(1, Season.Type.SPRING, 1))
	assert_bool(state.complete(&"a")).is_true()
	assert_bool(state.complete(&"a")).is_false()


func test_state_roundtrip() -> void:
	var state := CommissionState.new()
	state.ensure_for(GameDate.new(3, Season.Type.WINTER, 12))
	state.complete(&"ship_egg")

	var restored := CommissionState.new()
	restored.from_dict(state.to_dict())
	assert_str(restored.day_key).is_equal(state.day_key)
	assert_bool(restored.is_completed(&"ship_egg")).is_true()

	# 读档后回到同一天，不应清空；换一天才清空。
	assert_bool(restored.ensure_for(GameDate.new(3, Season.Type.WINTER, 12))).is_false()
	assert_bool(restored.is_completed(&"ship_egg")).is_true()


func test_database_exposes_commissions() -> void:
	assert_bool(Database.commissions().size() > 0).override_failure_message("应当有委托数据").is_true()
	assert_int(Database.commission_list().size()).is_equal(Database.commissions().size())
	for data: CommissionData in Database.commission_list():
		assert_object(Database.get_item(data.item_id)).override_failure_message(
			"委托 %s 要求的 %s 不存在" % [data.id, data.item_id]
		).is_not_null()
