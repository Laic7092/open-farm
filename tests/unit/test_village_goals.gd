extends GdUnitTestSuite
## 长期村庄目标测试：进度换算、前置旗标链与"领奖只发一次"。
##
## 目标不产生行为，只读档案 / 图鉴 / 食谱 / 日历的累计数字，
## 所以这里直接改这些状态，断言进度与领奖结果。


func _make() -> Array:
	var profile := PlayerProfile.new()
	var museum := MuseumState.new()
	var cooking := CookingState.new()
	var calendar := auto_free(CalendarService.new()) as CalendarService
	var goals := VillageGoals.new()
	goals.bind(profile, museum, cooking, calendar)
	return [goals, profile, museum, cooking, calendar]


func test_goals_are_sorted_by_order() -> void:
	var parts := _make()
	var goals: VillageGoals = parts[0]
	var orders: Array[int] = []
	for goal: VillageGoalData in goals.goals():
		orders.append(goal.order)
	assert_int(orders.size()).is_greater(0)
	var sorted_orders: Array[int] = orders.duplicate()
	sorted_orders.sort()
	assert_array(orders).is_equal(sorted_orders)


func test_progress_reads_player_stats() -> void:
	var parts := _make()
	var goals: VillageGoals = parts[0]
	var profile: PlayerProfile = parts[1]
	var goal := Database.get_village_goal(&"village_paths")
	assert_int(goals.progress(goal)).is_equal(0)
	profile.total_shipped = 30
	assert_int(goals.progress(goal)).is_equal(30)


func test_claim_grants_money_and_flag() -> void:
	var parts := _make()
	var goals: VillageGoals = parts[0]
	var profile: PlayerProfile = parts[1]
	profile.set_money(0)
	profile.total_shipped = 50

	assert_bool(goals.is_claimable(Database.get_village_goal(&"village_paths"))).is_true()
	assert_int(goals.claim(&"village_paths")).is_equal(VillageGoals.Result.CLAIMED)
	assert_int(profile.money).is_equal(800)
	assert_bool(profile.has_flag(&"goal_paths")).is_true()
	# 只发一次。
	assert_int(goals.claim(&"village_paths")).is_equal(VillageGoals.Result.ALREADY)


func test_chain_locks_later_goals() -> void:
	var parts := _make()
	var goals: VillageGoals = parts[0]
	var profile: PlayerProfile = parts[1]
	var library := Database.get_village_goal(&"village_library")

	assert_bool(goals.is_unlocked(library)).is_false()
	assert_int(goals.claim(&"village_library")).is_equal(VillageGoals.Result.LOCKED)

	profile.set_flag(&"goal_paths")
	assert_bool(goals.is_unlocked(library)).is_true()
	# 解锁了但还没达标。
	assert_int(goals.claim(&"village_library")).is_equal(VillageGoals.Result.NOT_READY)


func test_museum_and_cooking_feed_progress() -> void:
	var parts := _make()
	var goals: VillageGoals = parts[0]
	var profile: PlayerProfile = parts[1]
	var museum: MuseumState = parts[2]
	var cooking: CookingState = parts[3]

	for index: int in 20:
		museum.discover(StringName("item_%d" % index))
	profile.set_flag(&"goal_paths")
	assert_bool(goals.is_claimable(Database.get_village_goal(&"village_library"))).is_true()

	for index: int in 5:
		cooking.record(StringName("recipe_%d" % index))
	assert_int(goals.progress(Database.get_village_goal(&"village_kitchen"))).is_equal(5)


func test_state_roundtrip() -> void:
	var state := VillageGoalState.new()
	assert_bool(state.claim(&"village_paths")).is_true()
	assert_bool(state.claim(&"village_paths")).is_false()

	var restored := VillageGoalState.new()
	restored.from_dict(state.to_dict())
	assert_bool(restored.is_claimed(&"village_paths")).is_true()


func test_database_exposes_goals() -> void:
	assert_bool(Database.village_goals().size() > 0).override_failure_message(
		"应当有村庄目标数据"
	).is_true()
