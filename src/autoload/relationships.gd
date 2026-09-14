extends Node
## 全局关系系统（Autoload：`Relationships`）。
##
## [b]为什么是独立单例[/b]：好感度、恋爱与婚姻是[b]跨场景[/b]状态——
## 玩家在小镇和书雅聊天，换到矿洞时书雅并不在场上，但关系必须还在；
## 存档、读档也要一次拿全。把这些塞进 [GameState] 会让"全局状态"无限膨胀，
## 也违反 [code]docs/architecture.md[/code] 的分层约定，所以单独一个单例。
##
## 职责边界：
## [br]- 持有 [code]npc_id → RelationshipState[/code]，做增删改查；
## [br]- 在 [method GameClock.register_day_hook] 的日结转里清每日标记、推进婚育；
## [br]- 通过 [EventBus] 广播好感 / 关系变化，不直接碰任何 UI 或场景节点。
##
## 数值规则全在纯静态的 [AffectionRules] 里，本脚本只负责"持有状态 + 持久化"。

## 每对关系的运行时状态。
var _states: Dictionary[StringName, RelationshipState] = {}

## 配偶的 [member NpcData.id]；空串表示未婚。
var spouse_id: StringName = &""
## 婚后经过的游戏日数。
var days_married: int = 0
## 距离孩子出生还剩几天；0 且已婚未育表示尚未进入待产。
var pregnancy_days_left: int = 0
## 孩子是否已经出生。
var child_born: bool = false


func _ready() -> void:
	GameClock.register_day_hook(_on_day_rollover)


# ---------------------------------------------------------------- 查询

## 取某 NPC 的关系状态；没有就懒创建一个。
func state_of(npc_id: StringName) -> RelationshipState:
	if npc_id == &"":
		return RelationshipState.new(&"")
	if not _states.has(npc_id):
		_states[npc_id] = RelationshipState.new(npc_id)
	return _states[npc_id]


## 所有已建立关系的 NPC id（按字母序，便于测试与 UI 稳定输出）。
func known_npcs() -> Array[StringName]:
	var ids: Array[StringName] = []
	for npc_id: StringName in _states:
		ids.append(npc_id)
	ids.sort()
	return ids


func affection(npc_id: StringName) -> int:
	return state_of(npc_id).affection


func hearts(npc_id: StringName) -> int:
	return AffectionRules.hearts(affection(npc_id))


func tier(npc_id: StringName) -> AffectionRules.Tier:
	return AffectionRules.tier(affection(npc_id))


func status(npc_id: StringName) -> AffectionRules.Status:
	return state_of(npc_id).status


func is_dating(npc_id: StringName) -> bool:
	return status(npc_id) == AffectionRules.Status.DATING


func is_married_to(npc_id: StringName) -> bool:
	return status(npc_id) == AffectionRules.Status.MARRIED


func is_married() -> bool:
	return spouse_id != &""


func has_child() -> bool:
	return child_born


## 今天还能不能收礼物。
func can_gift(npc_id: StringName) -> bool:
	return not state_of(npc_id).gifted_today


## 今天还能不能拿聊天好感。
func can_talk(npc_id: StringName) -> bool:
	return not state_of(npc_id).talked_today


## NPC 的显示名（找不到数据时退回 id）。
func npc_name(npc_id: StringName) -> String:
	var data := Database.get_npc(npc_id)
	if data == null:
		return String(npc_id)
	return Text.key(data.display_name_key)


# ---------------------------------------------------------------- 好感度

## 直接增减好感度；返回实际变化量（可能被上下限截断）。
func add_affection(npc_id: StringName, amount: int) -> int:
	if npc_id == &"" or amount == 0:
		return 0
	var state := state_of(npc_id)
	var maximum := _max_affection(npc_id)
	var before := state.affection
	state.affection = AffectionRules.clamp_affection(state.affection + amount, maximum)
	var delta := state.affection - before
	if delta != 0:
		EventBus.npc_affection_changed.emit(npc_id, state.affection, delta)
	return delta


## 直接设定好感度（读旧档 / 调试用）。
func set_affection(npc_id: StringName, value: int) -> void:
	add_affection(npc_id, AffectionRules.clamp_affection(value, _max_affection(npc_id)) - affection(npc_id))


## 聊天：每天第一次会加好感，之后不再重复结算；返回本次收益。
func talk(npc_id: StringName) -> int:
	if npc_id == &"":
		return 0
	var state := state_of(npc_id)
	if state.talked_today:
		return 0
	state.talked_today = true
	return add_affection(npc_id, AffectionRules.TALK_GAIN)


## 某件礼物对某 NPC 的好感度收益（不修改状态）。
func gift_gain(npc_id: StringName, item_id: StringName) -> int:
	var data := Database.get_npc(npc_id)
	if data == null:
		return AffectionRules.GIFT_NEUTRAL
	return AffectionRules.gift_gain(
		item_id, data.loved_gifts, data.liked_gifts, data.disliked_gifts
	)


## 送礼：每天只收一次；返回本次收益。
func give_gift(npc_id: StringName, item_id: StringName) -> int:
	if npc_id == &"" or item_id == &"" or not can_gift(npc_id):
		return 0
	var state := state_of(npc_id)
	state.gifted_today = true
	var gain := add_affection(npc_id, gift_gain(npc_id, item_id))
	EventBus.npc_gift_given.emit(npc_id, item_id, gain)
	return gain


# ---------------------------------------------------------------- 恋爱 / 婚姻

## 是否满足表白条件（好感达标、单身、可攻略）。
func can_confess(npc_id: StringName) -> bool:
	if is_married():
		return false
	var data := Database.get_npc(npc_id)
	if data == null or not data.romanceable:
		return false
	if state_of(npc_id).status != AffectionRules.Status.SINGLE:
		return false
	return AffectionRules.can_confess(affection(npc_id), data.confession_affection)


## 表白成功：进入交往阶段。
func confess(npc_id: StringName) -> bool:
	if not can_confess(npc_id):
		return false
	_set_status(npc_id, AffectionRules.Status.DATING)
	EventBus.notification_requested.emit(&"NOTIFY_CONFESSED", {"npc": npc_name(npc_id)})
	return true


## 是否满足结婚条件（交往中、好感达标、尚未婚配）。
func can_marry(npc_id: StringName) -> bool:
	var data := Database.get_npc(npc_id)
	if data == null or not data.romanceable:
		return false
	if is_married():
		return false
	if state_of(npc_id).status != AffectionRules.Status.DATING:
		return false
	return AffectionRules.can_marry(affection(npc_id), data.marriage_affection)


## 结婚：进入婚姻并开始计算孩子的日子。
##
## 信物的消耗由 [Npc] 在确认持有 [constant AffectionRules.PROPOSAL_ITEM] 后完成，
## 本方法只认"条件是否满足"，不碰背包。
func marry(npc_id: StringName) -> bool:
	if not can_marry(npc_id):
		return false
	_set_status(npc_id, AffectionRules.Status.MARRIED)
	spouse_id = npc_id
	days_married = 0
	pregnancy_days_left = AffectionRules.DAYS_UNTIL_CHILD
	child_born = false
	EventBus.player_married.emit(npc_id)
	EventBus.notification_requested.emit(&"NOTIFY_MARRIED", {"npc": npc_name(npc_id)})
	return true


# ---------------------------------------------------------------- 复位 / 序列化

## 复位到新游戏状态。
func reset() -> void:
	_states.clear()
	spouse_id = &""
	days_married = 0
	pregnancy_days_left = 0
	child_born = false


func to_dict() -> Dictionary:
	var state_data := {}
	for npc_id: StringName in _states:
		state_data[String(npc_id)] = _states[npc_id].to_dict()
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
			_states[npc_id] = state
	spouse_id = StringName(str(data.get("spouse_id", "")))
	days_married = maxi(int(data.get("days_married", 0)), 0)
	pregnancy_days_left = maxi(int(data.get("pregnancy_days_left", 0)), 0)
	child_born = bool(data.get("child_born", false))
	if child_born:
		GameState.set_flag(&"child_born")


# ---------------------------------------------------------------- 内部

func _max_affection(npc_id: StringName) -> int:
	var data := Database.get_npc(npc_id)
	return data.max_affection if data != null else AffectionRules.HEART_SIZE * AffectionRules.MAX_HEARTS


func _set_status(npc_id: StringName, value: AffectionRules.Status) -> void:
	state_of(npc_id).status = value
	EventBus.npc_relationship_changed.emit(npc_id, int(value))


## 日结转：清每日标记，并推进"婚后 → 怀孕 → 生子"。
func _on_day_rollover(_date: GameDate) -> void:
	for npc_id: StringName in _states:
		_states[npc_id].reset_daily()
	if not is_married():
		return
	days_married += 1
	if child_born or pregnancy_days_left <= 0:
		return
	pregnancy_days_left -= 1
	if pregnancy_days_left <= 0:
		_birth_child()


func _birth_child() -> void:
	child_born = true
	pregnancy_days_left = 0
	GameState.set_flag(&"child_born")
	EventBus.child_born.emit(&"our_child")
	EventBus.notification_requested.emit(&"NOTIFY_CHILD_BORN", {})
