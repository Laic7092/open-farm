extends GdUnitTestSuite
## NPC 日程表测试：时间块选取、循环、排序与自检。


func _entry(minute: int, location_id: StringName, activity: StringName = &"idle") -> ScheduleEntry:
	var entry := ScheduleEntry.new()
	entry.start_minute = minute
	entry.location_id = location_id
	entry.activity = activity
	return entry


func _schedule(minutes: Array[int]) -> NpcSchedule:
	var schedule := NpcSchedule.new()
	var entries: Array[ScheduleEntry] = []
	for minute: int in minutes:
		entries.append(_entry(minute, StringName("loc_%d" % minute)))
	schedule.entries = entries
	return schedule


func test_entry_at_exact_start_time() -> void:
	var schedule := _schedule([360, 720, 1080])
	assert_int(schedule.entry_at(720).start_minute).is_equal(720)
	assert_int(schedule.entry_at(1080).start_minute).is_equal(1080)


func test_entry_at_uses_latest_passed_entry() -> void:
	var schedule := _schedule([360, 720, 1080])
	assert_int(schedule.entry_at(360).start_minute).is_equal(360)
	assert_int(schedule.entry_at(500).start_minute).is_equal(360)
	assert_int(schedule.entry_at(719).start_minute).is_equal(360)
	assert_int(schedule.entry_at(900).start_minute).is_equal(720)
	assert_int(schedule.entry_at(1439).start_minute).is_equal(1080)


## 凌晨没有条目时沿用前一天最后一段，这就是"日程循环"。
func test_entry_at_before_first_wraps_to_last() -> void:
	var schedule := _schedule([360, 720])
	assert_int(schedule.entry_at(0).start_minute).is_equal(720)
	assert_int(schedule.entry_at(359).start_minute).is_equal(720)


func test_empty_schedule_returns_null() -> void:
	var schedule := NpcSchedule.new()
	assert_bool(schedule.is_empty()).is_true()
	assert_object(schedule.entry_at(600)).is_null()


func test_entry_at_is_independent_of_input_order() -> void:
	var schedule := _schedule([1080, 360, 720])
	assert_int(schedule.entry_at(400).start_minute).is_equal(360)
	assert_int(schedule.entry_at(1000).start_minute).is_equal(720)
	assert_int(schedule.entry_at(1100).start_minute).is_equal(1080)


func test_sorted_entries_does_not_mutate_the_original() -> void:
	var schedule := _schedule([1080, 360])
	var ordered := schedule.sorted_entries()
	assert_int(ordered[0].start_minute).is_equal(360)
	assert_int(ordered[1].start_minute).is_equal(1080)
	assert_int(schedule.entries[0].start_minute).is_equal(1080)


func test_validate_requires_at_least_one_entry() -> void:
	var problems := NpcSchedule.new().validate()
	assert_array(problems).is_not_empty()


func test_validate_reports_bad_location() -> void:
	var schedule := NpcSchedule.new()
	var entries: Array[ScheduleEntry] = [_entry(360, &"")]
	schedule.entries = entries
	assert_array(schedule.validate()).is_not_empty()


func test_validate_reports_out_of_range_minute() -> void:
	var bad := _entry(1500, &"store")
	assert_int(bad.validate().size()).is_equal(1)
	assert_int(_entry(0, &"store").validate().size()).is_equal(0)


func test_entry_activity_is_preserved() -> void:
	var schedule := _schedule([360])
	schedule.entries[0].activity = &"shop"
	assert_str(String(schedule.entry_at(400).activity)).is_equal("shop")
