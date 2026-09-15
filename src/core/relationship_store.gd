class_name RelationshipStore
extends Resource
## 关系系统状态（Resource）。
##
## 只存放可存档数据：每个 NPC 的 [RelationshipState]、配偶、婚育进度。
## 查询/增减好感/结婚等规则仍在 [Relationships] 服务里；资源不依赖
## Autoload / 场景树，便于由 [Main] 持有或在测试里单独 new。

## 每对关系的运行时状态。
var states: Dictionary[StringName, RelationshipState] = {}

## 配偶的 [member NpcData.id]；空串表示未婚。
var spouse_id: StringName = &""
## 婚后经过的游戏日数。
var days_married: int = 0
## 距离孩子出生还剩几天；0 且已婚未育表示尚未进入待产。
var pregnancy_days_left: int = 0
## 孩子是否已经出生。
var child_born: bool = false


## 取某 NPC 的关系状态；没有就懒创建一个。
func state_of(npc_id: StringName) -> RelationshipState:
	if npc_id == &"":
		return RelationshipState.new(&"")
	if not states.has(npc_id):
		states[npc_id] = RelationshipState.new(npc_id)
	return states[npc_id]


## 所有已建立关系的 NPC id（按字母序）。
func known_npcs() -> Array[StringName]:
	var ids: Array[StringName] = []
	for npc_id: StringName in states:
		ids.append(npc_id)
	ids.sort()
	return ids


## 复位到新游戏状态。
func reset() -> void:
	states.clear()
	spouse_id = &""
	days_married = 0
	pregnancy_days_left = 0
	child_born = false


func to_dict() -> Dictionary:
	var state_data := {}
	for npc_id: StringName in states:
		state_data[String(npc_id)] = states[npc_id].to_dict()
	return {
		"states": state_data,
		"spouse_id": String(spouse_id),
		"days_married": days_married,
		"pregnancy_days_left": pregnancy_days_left,
		"child_born": child_born,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	var state_data: Variant = data.get("states", {})
	if state_data is Dictionary:
		for key: Variant in state_data:
			var entry: Variant = state_data[key]
			if not entry is Dictionary:
				continue
			var npc_id := StringName(str(key))
			var state := RelationshipState.new(npc_id)
			state.from_dict(entry)
			states[npc_id] = state
	spouse_id = StringName(str(data.get("spouse_id", "")))
	days_married = maxi(int(data.get("days_married", 0)), 0)
	pregnancy_days_left = maxi(int(data.get("pregnancy_days_left", 0)), 0)
	child_born = bool(data.get("child_born", false))
