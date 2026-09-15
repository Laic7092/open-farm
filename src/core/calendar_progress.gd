class_name CalendarProgress
extends Resource
## 节日 / 事件进度（Resource）。
##
## 只存放"今年参加过哪些节日 / 哪些事件已触发"这类可存档状态；
## 表数据与今日缓存仍在 [Calendar] 服务里。资源不依赖 Autoload，
## 可由 [Main] 持有或测试里单独 new。

## festival_id → 参加时的年份。
var attended: Dictionary[StringName, int] = {}
## event_id → 触发时的绝对天数。
var triggered: Dictionary[StringName, int] = {}


func reset() -> void:
	attended.clear()
	triggered.clear()


func to_dict() -> Dictionary:
	var attended_data := {}
	for festival_id: StringName in attended:
		attended_data[String(festival_id)] = int(attended[festival_id])
	var triggered_data := {}
	for event_id: StringName in triggered:
		triggered_data[String(event_id)] = int(triggered[event_id])
	return {
		"attended": attended_data,
		"triggered": triggered_data,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	var attended_data: Variant = data.get("attended", {})
	if attended_data is Dictionary:
		for key: Variant in attended_data:
			attended[StringName(str(key))] = int(attended_data[key])
	var triggered_data: Variant = data.get("triggered", {})
	if triggered_data is Dictionary:
		for key: Variant in triggered_data:
			triggered[StringName(str(key))] = int(triggered_data[key])
