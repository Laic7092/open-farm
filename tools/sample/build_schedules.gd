extends "res://tools/sample/sample_base.gd"
## schedules：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var merchant := NpcSchedule.new()
	merchant.entries = [
		_schedule_entry(360, &"store", &"shop"),
		_schedule_entry(720, &"plaza", &"stroll"),
		_schedule_entry(780, &"store", &"shop"),
		_schedule_entry(1080, &"barn", &"stroll"),
		_schedule_entry(1320, &"store", &"rest"),
	] as Array[ScheduleEntry]
	_save(merchant, SCHEDULE_DIR.path_join("merchant_schedule.tres"))

	var mayor := NpcSchedule.new()
	mayor.entries = [
		_schedule_entry(360, &"town_hall", &"work"),
		_schedule_entry(600, &"plaza", &"stroll"),
		_schedule_entry(720, &"town_hall", &"work"),
		_schedule_entry(1020, &"plaza", &"stroll"),
		_schedule_entry(1200, &"town_hall", &"rest"),
	] as Array[ScheduleEntry]
	_save(mayor, SCHEDULE_DIR.path_join("mayor_schedule.tres"))

	# 小镇常驻：铁匠白天在炉边，花婆婆守花摊，小满在广场和家之间跑。
	_add_schedule(&"blacksmith_schedule", [
		[360, &"forge", &"work"],
		[600, &"plaza", &"stroll"],
		[720, &"forge", &"work"],
		[1080, &"store", &"stroll"],
		[1260, &"forge", &"rest"],
	])
	_add_schedule(&"florist_schedule", [
		[360, &"flower_shop", &"shop"],
		[720, &"garden", &"work"],
		[900, &"flower_shop", &"shop"],
		[1140, &"plaza", &"stroll"],
		[1260, &"flower_shop", &"rest"],
	])
	_add_schedule(&"child_schedule", [
		[360, &"home", &"rest"],
		[540, &"plaza", &"play"],
		[720, &"store", &"stroll"],
		[900, &"plaza", &"play"],
		[1140, &"home", &"rest"],
	])
	# 海滩渔夫：涨潮钓鱼，落潮赶海，其余时间回小屋。
	_add_schedule(&"fisher_schedule", [
		[360, &"pier", &"work"],
		[720, &"hut", &"rest"],
		[900, &"shore", &"work"],
		[1140, &"hut", &"rest"],
	])
	# 矿工：清早下井，午后回洞口歇脚。
	_add_schedule(&"miner_schedule", [
		[360, &"mine_entrance", &"work"],
		[660, &"mine_deep", &"work"],
		[1020, &"mine_entrance", &"rest"],
		[1260, &"camp", &"rest"],
	])
	# 图书管理员：柜台上半天，书架前下半天。
	_add_schedule(&"librarian_schedule", [
		[360, &"desk", &"work"],
		[720, &"shelves", &"work"],
		[1020, &"desk", &"rest"],
	])
	# 孩子：婚后出生就守在家里，不去别处。
	_add_schedule(&"our_child_schedule", [
		[0, &"home", &"rest"],
	])


## 用 [minute, location_id, activity] 三元组批量建一段日程并保存。
func _add_schedule(schedule_id: StringName, entries: Array) -> void:
	var schedule := NpcSchedule.new()
	var built: Array[ScheduleEntry] = []
	for entry: Array in entries:
		built.append(_schedule_entry(entry[0], entry[1], entry[2]))
	schedule.entries = built
	_save(schedule, SCHEDULE_DIR.path_join("%s.tres" % schedule_id))


func _schedule_entry(
	minute: int, location_id: StringName, activity: StringName
) -> ScheduleEntry:
	var entry := ScheduleEntry.new()
	entry.start_minute = minute
	entry.location_id = location_id
	entry.activity = activity
	return entry
