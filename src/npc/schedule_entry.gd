class_name ScheduleEntry
extends Resource
## NPC 日程里的一条：从 [member start_minute] 起前往 [member location_id]。
##
## 时间用"当天 00:00 起的分钟数"表示，和 [member GameDateClock.minute_of_day] 同一语义，
## 因此 06:00 就是 [code]6 * 60[/code]。地点写名字（[member location_id]）而不是坐标，
## 场景重排时只挪 [SchedulePoint]，不用改数据。

## 本段日程开始的时刻（00:00 起的分钟数，0..1439）。
@export_range(0, 1439) var start_minute: int = 0
## 目的地：目标 [SchedulePoint] 的 [member SchedulePoint.point_id]。
@export var location_id: StringName = &""
## 到达后要做的事（自由标签，例如 "shop" / "work" / "stroll"）。
##
## [Npc] 只用它做一个判断：商人是否在"上班"，从而决定要不要开店。
@export var activity: StringName = &"idle"
## 到达后的朝向。
@export var facing: Facing.Direction = Facing.Direction.DOWN


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if start_minute < 0 or start_minute >= 1440:
		problems.append("start_minute 应在 0..1439（实际 %d）" % start_minute)
	if location_id == &"":
		problems.append("location_id 不能为空")
	return problems


func _to_string() -> String:
	# 不引用 GameDateClock：规则层保持"脱离 autoload 也能跑"。
	return "ScheduleEntry(%02d:%02d → %s)" % [
		start_minute / 60,
		start_minute % 60,
		location_id,
	]
