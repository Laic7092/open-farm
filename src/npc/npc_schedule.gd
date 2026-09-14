class_name NpcSchedule
extends Resource
## NPC 的一天：一组按时间排列的 [ScheduleEntry]。
##
## [b]日程是循环的[/b]：凌晨没有条目时沿用前一天最后一段（例如 22:00 的"回家"），
## 于是 [method entry_at] 对任意分钟都有确定答案，不需要额外的跨天分支。
## 排序在查询时做，策划可以随便往数组里加条目。

## 时间块；不要求输入时已按开始时间排序。
@export var entries: Array[ScheduleEntry] = []


func is_empty() -> bool:
	return entries.is_empty()


## 按开始时间升序排列的副本。
func sorted_entries() -> Array[ScheduleEntry]:
	var ordered: Array[ScheduleEntry] = []
	ordered.assign(entries)
	ordered.sort_custom(func(a: ScheduleEntry, b: ScheduleEntry) -> bool:
		return a.start_minute < b.start_minute
	)
	return ordered


## [param minute_of_day]（0..1439）时刻生效的那一段日程。
##
## 返回"开始时间不晚于该分钟"的最后一段；若该分钟早于第一段的开始时间，
## 则返回最后一段（日程循环）。空日程返回 [code]null[/code]。
func entry_at(minute_of_day: int) -> ScheduleEntry:
	var ordered := sorted_entries()
	if ordered.is_empty():
		return null
	var minute: int = wrapi(minute_of_day, 0, 1440)
	var picked: ScheduleEntry = ordered[ordered.size() - 1]
	for entry: ScheduleEntry in ordered:
		if entry.start_minute <= minute:
			picked = entry
		else:
			break
	return picked


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if entries.is_empty():
		problems.append("日程至少需要一条")
	for index: int in entries.size():
		var entry: ScheduleEntry = entries[index]
		if entry == null:
			problems.append("第 %d 条日程为空" % (index + 1))
			continue
		for problem: String in entry.validate():
			problems.append("第 %d 条：%s" % [index + 1, problem])
	return problems


func _to_string() -> String:
	return "NpcSchedule(%d entries)" % entries.size()
