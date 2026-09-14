class_name RelationshipState
extends RefCounted
## 单个 NPC 的运行时关系状态（会变、要存档）。
##
## 与静态的 [NpcData] 分离：数据定义"这个人能追吗、最爱什么礼物"，
## 这里只记录"玩家和他现在关系如何"。
## [code]Relationships[/code] 用 [code]npc_id → RelationshipState[/code] 的表统一持有，
## 所以 NPC 节点不在场上时（换地图 / 尚未出生）关系也不会丢。

## 对应的 [member NpcData.id]。
var npc_id: StringName = &""
## 当前好感度。
var affection: int = 0
## 当前关系阶段。
var status: AffectionRules.Status = AffectionRules.Status.SINGLE
## 今天是否已经聊过天（每天只结算一次好感）。
var talked_today: bool = false
## 今天是否已经收过礼物。
var gifted_today: bool = false


func _init(p_npc_id: StringName = &"") -> void:
	npc_id = p_npc_id


## 跨天：清掉"今天做过"的标记。
func reset_daily() -> void:
	talked_today = false
	gifted_today = false


func to_dict() -> Dictionary:
	return {
		"affection": affection,
		"status": int(status),
		"talked_today": talked_today,
		"gifted_today": gifted_today,
	}


func from_dict(data: Dictionary) -> void:
	affection = maxi(int(data.get("affection", 0)), 0)
	status = _status_from(int(data.get("status", 0)))
	talked_today = bool(data.get("talked_today", false))
	gifted_today = bool(data.get("gifted_today", false))


func _status_from(value: int) -> AffectionRules.Status:
	if value < 0 or value > int(AffectionRules.Status.MARRIED):
		return AffectionRules.Status.SINGLE
	return value as AffectionRules.Status


func _to_string() -> String:
	return "RelationshipState(%s, affection=%d, status=%d)" % [npc_id, affection, status]
