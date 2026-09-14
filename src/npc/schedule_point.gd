class_name SchedulePoint
extends Marker2D
## NPC 日程地点标记。
##
## [NpcSchedule] 里写的是地点名字（[member point_id]）而不是坐标；
## 场景重排时只挪标记、不改数据，和 [SpawnPoint] 是同一套思路。

const GROUP: StringName = &"schedule_point"

## 地点标识；与 [member ScheduleEntry.location_id] 匹配。
@export var point_id: StringName = &""


func _enter_tree() -> void:
	add_to_group(GROUP)
	# 目的地不能被野生树木堵住，否则 NPC 永远走不进去。
	add_to_group(Interactable.FLORA_BLOCKER_GROUP)


func _to_string() -> String:
	return "SchedulePoint(%s)" % point_id
