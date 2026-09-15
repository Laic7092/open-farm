class_name PlayerEvents
extends RefCounted
## 玩家域事件（由 [PlayerProfile] 持有）。
##
## 只声明与玩家档案 / 背包 / 关系进度直接相关的事件。节点连接后必须由节点在
## 退出场景树时主动断开；本对象不持有场景引用，也不做任何转发逻辑。

## 体力变化。
signal stamina_changed(current: int, maximum: int)
## 体力归零（需要昏倒 / 强制回家）。
signal stamina_depleted()
## 金钱变化；[param delta] 为本次增量。
signal money_changed(money: int, delta: int)
## 背包内容变化。
signal inventory_changed()
## 背包已满，新物品放不下。
signal inventory_full(item_id: StringName)
## 当前手持道具切换（即物品栏选中的那一格）；[param index] 为背包下标。
signal hand_changed(item_id: StringName, index: int)
## 玩家朝向变化。
signal player_facing_changed(direction: Facing.Direction)
## NPC 好感度变化；[param delta] 为本次增量。
signal npc_affection_changed(npc_id: StringName, affection: int, delta: int)
## NPC 关系阶段变化（单身的 [enum AffectionRules.Status] 数值）。
signal npc_relationship_changed(npc_id: StringName, status: int)
## 向 NPC 送出礼物（[param gain] 为好感度收益，可能为负）。
signal npc_gift_given(npc_id: StringName, item_id: StringName, gain: int)
## 玩家结婚。
signal player_married(spouse_id: StringName)
## 孩子出生。
signal child_born(child_id: StringName)
