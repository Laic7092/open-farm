class_name VillageGoalState
extends Resource
## 长期村庄目标的领取记录（Resource）。
##
## 进度本身由 [VillageGoalRules] 从档案 / 图鉴 / 食谱 / 日历实时算出，不落盘；
## 需要存活的只有"哪几条已经领过奖"。因此本资源极小，读档后即使指标数值
## 变了也不会出现"重复领奖"或"进度回退"两种坏情况。

## 已领奖的目标 id。
var claimed: Array[StringName] = []


func reset() -> void:
	claimed.clear()


## 是否已领奖。
func is_claimed(goal_id: StringName) -> bool:
	return claimed.has(goal_id)


## 记一次领奖；已经领过则返回 false。
func claim(goal_id: StringName) -> bool:
	if goal_id == &"" or is_claimed(goal_id):
		return false
	claimed.append(goal_id)
	return true


func to_dict() -> Dictionary:
	var done: Array = []
	for goal_id: StringName in claimed:
		done.append(String(goal_id))
	return {"claimed": done}


func from_dict(data: Dictionary) -> void:
	reset()
	var done: Variant = data.get("claimed", [])
	if done is Array:
		for value: Variant in done:
			var goal_id := StringName(str(value))
			if goal_id != &"" and not claimed.has(goal_id):
				claimed.append(goal_id)
