@tool
class_name FestivalData
extends Resource
## 节日的静态定义：哪天、在哪张地图、哪些村民来、参加有什么好处。
##
## 与 [NpcData] 一样，这是[b]不变的数据[/b]；"今年参没参加过"属于运行时状态，
## 由 [code]CalendarService[/code] 服务持有并写进存档。
## 判定规则全在纯静态的 [FestivalRules] 里，本类只描述数据。

## 唯一标识。
@export var id: StringName = &""
## 名字翻译键。
@export var display_name_key: StringName = &""
## 节日所在的季节。
@export var season: Season.Type = Season.Type.SPRING
## 节日所在的日（1..Season.DAYS_PER_SEASON）。
@export_range(1, 28) var day: int = 1
## 会场开门钟点。
@export_range(0, 23) var start_hour: int = 9
## 会场关门钟点；不大于 [member start_hour] 时表示全天开放。
@export_range(0, 24) var end_hour: int = 17
## 会场所在地图（世界场景路径）。
@export_file("*.tscn") var world_path: String = ""
## 村民聚集点：场景里 [SchedulePoint] 的 [member SchedulePoint.point_id]。
@export var gather_point: StringName = &""
## 到场的 NPC；节日期间他们会放下日程走到 [member gather_point]。
@export var npc_ids: Array[StringName] = []
## 参加一次给每位到场 NPC 加的好感度。
@export_range(0, 50) var attendance_affection: int = 4
## 参加后打上的剧情旗标（可空）。
@export var attendance_flag: StringName = &""
## 第一次参加时播放的对白（可空）。
@export var intro_dialogue: DialogueData
## 需要玩家已有该旗标节日才出现（可空，例如"村长通知过"之后才办收获祭）。
@export var required_flag: StringName = &""


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if day < 1 or day > Season.DAYS_PER_SEASON:
		problems.append("day 应在 1..%d（实际 %d）" % [Season.DAYS_PER_SEASON, day])
	if world_path.is_empty():
		problems.append("world_path 不能为空")
	if gather_point == &"":
		problems.append("gather_point 不能为空")
	if npc_ids.is_empty():
		problems.append("至少要有一位参加节日的 NPC")
	if attendance_affection < 0:
		problems.append("attendance_affection 不能为负")
	if intro_dialogue != null and intro_dialogue.is_empty():
		problems.append("intro_dialogue 不能是空对白")
	return problems


func _to_string() -> String:
	return "FestivalData(%s)" % id
