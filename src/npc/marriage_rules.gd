class_name MarriageRules
extends RefCounted
## 婚育推进的纯静态规则。
##
## 日结转时由 [RelationshipService] 调用；只读写 [RelationshipStore]，
## 不碰 Autoload / EventBus / 场景树，因此可以单独用干净 Resource 覆盖全部分支。

## 推进一天：重置所有 NPC 的每日标记，并按状态推进"婚后 → 怀孕 → 生子"。
##
## 返回 [code]true[/code] 表示 [b]本日孩子出生[/b]，服务层据此发信号与写玩家旗标。
static func advance_day(store: RelationshipStore, _date: GameDate) -> bool:
	if store == null:
		return false

	for npc_id: StringName in store.states:
		var state: RelationshipState = store.states[npc_id]
		if state != null:
			state.reset_daily()

	if store.spouse_id == &"":
		return false

	store.days_married += 1
	if store.child_born or store.pregnancy_days_left <= 0:
		return false

	store.pregnancy_days_left -= 1
	if store.pregnancy_days_left > 0:
		return false

	store.child_born = true
	store.pregnancy_days_left = 0
	return true
