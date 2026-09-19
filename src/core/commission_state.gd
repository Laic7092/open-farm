class_name CommissionState
extends Resource
## 委托板的可存档状态（Resource）。
##
## 只记"哪一天上了哪些板、今天完成了哪些"：委托的静态数据在 [CommissionData]，
## 挑选规则在 [CommissionRules]。日期一变，完成记录自动清空，就是委托板的每日刷新；
## 不需要额外注册日结钩子，读档后也按存档里的日期正确重算。

## 当前这批委托对应的日期键（[method day_key] 的结果）。
var day_key: String = ""
## 当天已完成的委托 id。
var completed: Array[StringName] = []


func reset() -> void:
	day_key = ""
	completed.clear()


## 确保状态对应 [param date] 这一天；跨天则清空完成记录。
##
## 返回 true 表示发生了刷新（日期变了），调用方可据此重建列表。
func ensure_for(date: GameDate) -> bool:
	var key := day_key_of(date)
	if key == day_key:
		return false
	day_key = key
	completed.clear()
	return true


## 某个委托今天是否已完成。
func is_completed(commission_id: StringName) -> bool:
	return completed.has(commission_id)


## 标记完成；今天已经完成过则返回 false。
func complete(commission_id: StringName) -> bool:
	if commission_id == &"" or is_completed(commission_id):
		return false
	completed.append(commission_id)
	return true


## 日期键；空日期返回空串。
static func day_key_of(date: GameDate) -> String:
	if date == null:
		return ""
	return "%d-%d-%d" % [date.year, int(date.season), date.day]


func to_dict() -> Dictionary:
	var done: Array = []
	for commission_id: StringName in completed:
		done.append(String(commission_id))
	return {"day_key": day_key, "completed": done}


func from_dict(data: Dictionary) -> void:
	reset()
	day_key = str(data.get("day_key", ""))
	var done: Variant = data.get("completed", [])
	if done is Array:
		for value: Variant in done:
			var commission_id := StringName(str(value))
			if commission_id != &"" and not completed.has(commission_id):
				completed.append(commission_id)
