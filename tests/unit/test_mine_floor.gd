extends GdUnitTestSuite
## 矿洞分层测试：按深度生成、清除登记、工具等级门槛。
##
## [MineFloor] 继承 [FloraField] 但需要地面图层才能判定落点；测试里用
## 一个只放开落点判定的子类，专注验证"分层数据"这一层逻辑。

class TestFloor:
	extends MineFloor

	func _can_place(_cell: Vector2i, _flora_id: StringName) -> bool:
		return true


func _make(profile: PlayerProfile) -> TestFloor:
	var floor := auto_free(TestFloor.new()) as TestFloor
	floor.growth_area = Rect2i(1, 1, 24, 24)
	floor.flora_scene = load("res://scenes/world/flora.tscn")
	floor.bind_dependencies(profile, null)
	add_child(floor)
	return floor


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_first_floor_only_uses_shallow_ores() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(1)
	var floor := _make(profile)
	await _settle()
	assert_int(floor.total()).is_greater(0)
	for state: FloraState in floor.flora.values():
		var data := Database.get_flora(state.flora_id)
		assert_bool(data != null and MineRules.allows(data, 1)).override_failure_message(
			"第 1 层不该出现 %s" % state.flora_id
		).is_true()


func test_depth_comes_from_profile() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(50)
	var floor := _make(profile)
	await _settle()
	assert_int(floor._depth).is_equal(50)


func test_clear_marks_cell_and_yields_item() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(1)
	var floor := _make(profile)
	await _settle()
	assert_bool(floor.flora.is_empty()).is_false()
	var cell: Vector2i = floor.flora.keys()[0]
	var data := Database.get_flora(floor.flora[cell].flora_id)
	var outcome: Dictionary = floor.clear(cell, ToolData.Kind.PICKAXE, false, data.required_tier)
	assert_bool(outcome.is_empty()).is_false()
	assert_bool(floor.occupied(cell)).is_false()
	assert_bool(profile.mine_is_mined(1, cell)).is_true()


func test_descend_increments_depth() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(1)
	var floor := _make(profile)
	await _settle()
	floor.descend()
	assert_int(profile.mine_depth).is_equal(2)


func test_mine_enter_unlocks_elevator_floors() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(37)
	assert_int(profile.mine_elevator_depth).is_equal(35)
	profile.mine_enter(40)
	assert_int(profile.mine_elevator_depth).is_equal(40)


func test_mine_mined_resets_on_new_day() -> void:
	var profile := PlayerProfile.new()
	profile.mine_refresh_for_day(3)
	profile.mine_mark_mined(5, Vector2i(2, 2))
	assert_bool(profile.mine_is_mined(5, Vector2i(2, 2))).is_true()
	profile.mine_refresh_for_day(4)
	assert_bool(profile.mine_is_mined(5, Vector2i(2, 2))).is_false()


func test_tier_gate_blocks_low_tools() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(1)
	var floor := _make(profile)
	await _settle()
	var copper_cell := Vector2i(-1, -1)
	for cell: Vector2i in floor.flora:
		if floor.flora[cell].flora_id == &"copper_ore":
			copper_cell = cell
			break
	if copper_cell.x < 0:
		return
	assert_bool(floor.clear(copper_cell, ToolData.Kind.PICKAXE, false, 0).is_empty()).is_true()
	assert_bool(floor.occupied(copper_cell)).is_true()
	assert_bool(floor.clear(copper_cell, ToolData.Kind.PICKAXE, false, 1).is_empty()).is_false()


func test_elevator_starts_locked_until_five() -> void:
	var profile := PlayerProfile.new()
	assert_int(profile.mine_elevator_depth).is_equal(0)
	profile.mine_enter(4)
	assert_int(profile.mine_elevator_depth).is_equal(0)
	profile.mine_enter(5)
	assert_int(profile.mine_elevator_depth).is_equal(5)


## 回归：玩家在农场睡觉过夜（矿洞不在场景树里）时，重建楼层也要刷新已挖记录。
func test_rebuild_refreshes_ores_on_new_day() -> void:
	var profile := PlayerProfile.new()
	profile.mine_enter(1)
	var floor := _make(profile)
	var clock := GameDateClock.new()
	clock.set_date(GameDate.new(1, Season.Type.SPRING, 1))
	floor.bind_dependencies(profile, clock)
	await _settle()
	assert_bool(floor.flora.is_empty()).is_false()
	var cell: Vector2i = floor.flora.keys()[0]
	profile.mine_mark_mined(1, cell)
	assert_bool(profile.mine_is_mined(1, cell)).is_true()

	clock.set_date(GameDate.new(1, Season.Type.SPRING, 2))
	floor._build_floor()
	assert_bool(profile.mine_is_mined(1, cell)).is_false()
