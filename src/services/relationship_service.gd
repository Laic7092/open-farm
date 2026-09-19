class_name RelationshipService
extends Node
## 关系服务（由 [Main] 组合根持有，不再是 Autoload）。
##
## 好感度、恋爱与婚姻是[b]跨场景[/b]状态：玩家在小镇和书雅聊天，换到矿洞时
## 书雅并不在场上，但关系必须还在；存档、读档也要一次拿全。状态本体是
## [RelationshipStore]（Resource），服务只负责规则入口、日结转与广播。
##
## 职责边界：
## [br]- 持有 [code]npc_id → RelationshipState[/code]，做增删改查；
## [br]- 在注入时钟的 [DayPipeline] 里清每日标记、推进婚育；
## [br]- 通过 [EventBus] 广播好感 / 关系变化，不直接碰任何 UI 或场景节点。
##
## 数值规则全在纯静态的 [AffectionRules] / [MarriageRules] 里，本脚本只负责
## "持有状态 + 持久化"。

## 关系状态；由组合根持有，可整体替换。
var _store: RelationshipStore = RelationshipStore.new()
## 组合根注入的玩家档案；用于把孩子出生旗标写回同一个 PlayerProfile。
var _profile: PlayerProfile
## 组合根注入的时钟；日转型服务用它注册 / 注销钩子。
var _clock: GameDateClock

## 配偶的 [member NpcData.id]；空串表示未婚。只读。
var spouse_id: StringName:
	get:
		return _store.spouse_id
## 婚后经过的游戏日数。只读。
var days_married: int:
	get:
		return _store.days_married
## 距离孩子出生还剩几天；0 且已婚未育表示尚未进入待产。只读。
var pregnancy_days_left: int:
	get:
		return _store.pregnancy_days_left
## 孩子是否已经出生。只读。
var child_born: bool:
	get:
		return _store.child_born


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


## 注入组合根持有的状态，并重新注册日结转钩子。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)
	_profile = profile
	_clock = clock
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_RELATIONSHIPS)


## 当前关系状态；由组合根持有，可整体替换。
func state() -> RelationshipStore:
	return _store


## 换入关系状态；传 null 会创建一份新的默认状态。
func set_state(value: RelationshipStore) -> void:
	_store = value if value != null else RelationshipStore.new()


# ---------------------------------------------------------------- 查询

## 取某 NPC 的关系状态；没有就懒创建一个。
func state_of(npc_id: StringName) -> RelationshipState:
	return _store.state_of(npc_id)


## 所有已建立关系的 NPC id（按字母序，便于测试与 UI 稳定输出）。
func known_npcs() -> Array[StringName]:
	return _store.known_npcs()


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
		EventBus.player.npc_affection_changed.emit(npc_id, state.affection, delta)
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
	EventBus.player.npc_gift_given.emit(npc_id, item_id, gain)
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
	EventBus.ui.notification_requested.emit(&"NOTIFY_CONFESSED", {"npc": npc_name(npc_id)})
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
	_store.spouse_id = npc_id
	_store.days_married = 0
	_store.pregnancy_days_left = AffectionRules.DAYS_UNTIL_CHILD
	_store.child_born = false
	EventBus.player.player_married.emit(npc_id)
	EventBus.ui.notification_requested.emit(&"NOTIFY_MARRIED", {"npc": npc_name(npc_id)})
	return true


# ---------------------------------------------------------------- 复位 / 序列化

## 复位到新游戏状态。
func reset() -> void:
	_store.reset()


func to_dict() -> Dictionary:
	return _store.to_dict()


func from_dict(data: Dictionary) -> void:
	_store.from_dict(data)
	if child_born and _profile != null:
		_profile.set_flag(&"child_born")


# ---------------------------------------------------------------- 内部

func _max_affection(npc_id: StringName) -> int:
	var data := Database.get_npc(npc_id)
	return data.max_affection if data != null else AffectionRules.HEART_SIZE * AffectionRules.MAX_HEARTS


func _set_status(npc_id: StringName, value: AffectionRules.Status) -> void:
	state_of(npc_id).status = value
	EventBus.player.npc_relationship_changed.emit(npc_id, int(value))


## 日结转：清每日标记，并推进"婚后 → 怀孕 → 生子"。
##
## 数值推进在纯静态的 [MarriageRules.advance_day]；这里只负责把结果写成
## 玩家旗标并广播。
func _on_day_rollover(date: GameDate) -> void:
	if MarriageRules.advance_day(_store, date):
		_birth_child()


func _birth_child() -> void:
	if _profile != null:
		_profile.set_flag(&"child_born")
	EventBus.player.child_born.emit(&"our_child")
	EventBus.ui.notification_requested.emit(&"NOTIFY_CHILD_BORN", {})
