class_name AffectionRules
extends RefCounted
## 好感度与恋爱规则的[b]纯静态[/b]实现。
##
## 这里只放"数值怎么算"的纯函数：不碰场景树、不注册 autoload、不读写存档，
## 因此 [code]tests/unit/test_affection_rules.gd[/code] 可以脱离引擎逐条断言。
## 运行时状态（某人现在多少好感、是否在交往）由 [RelationshipState] /
## [code]Relationships[/code] 持有；两者的边界与 [CropData] / [CropGrowth] 一致。
##
## [b]心数[/b]是对玩家暴露的唯一好感度单位：好感度每 [constant HEART_SIZE] 点折一颗心，
## 上限 [constant MAX_HEARTS] 颗。对白 / 礼物 / 表白 / 求婚的门槛都以心数为直觉来定。

## 每颗心需要的好感度。
const HEART_SIZE: int = 50
## 好感度上限（与 [member NpcData.max_affection] 的默认值一致）。
const MAX_HEARTS: int = 5
## 单次聊天提升的好感度（每天只结算一次）。
const TALK_GAIN: int = 2
## 送出"最爱 / 喜欢 / 普通 / 讨厌"礼物时的好感度变化。
const GIFT_LOVED: int = 15
const GIFT_LIKED: int = 8
const GIFT_NEUTRAL: int = 3
const GIFT_DISLIKED: int = -5
## 达到"朋友"档所需心数：从这时起 NPC 改用朋友对白。
const FRIEND_HEARTS: int = 3
## 求婚信物的道具 id。结婚时必须消耗一件。
const PROPOSAL_ITEM: StringName = &"blue_feather"
## 婚后经过多少个游戏日孩子出生。
const DAYS_UNTIL_CHILD: int = 10

## 关系阶段。数值会写进存档，不要随意重排。
enum Status {
	SINGLE,   ## 普通朋友
	DATING,   ## 交往中
	MARRIED,  ## 已婚
}

## 好感度档位（只用于对白选择与文案，不写进存档）。
enum Tier {
	STRANGER,       ## 陌生
	ACQUAINTANCE,   ## 认识
	FRIEND,         ## 朋友
	CLOSE,          ## 亲近
	LOVER,          ## 恋人
}


## 好感度换算成心数（向下取整，封顶 [constant MAX_HEARTS]）。
static func hearts(affection: int) -> int:
	return clampi(affection / HEART_SIZE, 0, MAX_HEARTS)


## 好感度对应的档位。
static func tier(affection: int) -> Tier:
	match hearts(affection):
		0:
			return Tier.STRANGER
		1, 2:
			return Tier.ACQUAINTANCE
		3:
			return Tier.FRIEND
		4:
			return Tier.CLOSE
		_:
			return Tier.LOVER


## 档位对应的翻译键，供 UI / 提示使用。
static func tier_key(value: Tier) -> StringName:
	match value:
		Tier.ACQUAINTANCE:
			return &"REL_TIER_ACQUAINTANCE"
		Tier.FRIEND:
			return &"REL_TIER_FRIEND"
		Tier.CLOSE:
			return &"REL_TIER_CLOSE"
		Tier.LOVER:
			return &"REL_TIER_LOVER"
		_:
			return &"REL_TIER_STRANGER"


## 该道具对某位 NPC 的好感度收益。
##
## 优先级：最爱 > 喜欢 > 讨厌 > 普通。[param loved] / [param liked] / [param disliked]
## 都来自 [member NpcData]；同一个道具同时命中多个列表时以"最爱"为准（由数据自检兜底）。
static func gift_gain(
	item_id: StringName,
	loved: Array[StringName],
	liked: Array[StringName],
	disliked: Array[StringName]
) -> int:
	if item_id == &"":
		return 0
	if loved.has(item_id):
		return GIFT_LOVED
	if liked.has(item_id):
		return GIFT_LIKED
	if disliked.has(item_id):
		return GIFT_DISLIKED
	return GIFT_NEUTRAL


## 好感度是否达到了表白门槛。
static func can_confess(affection: int, threshold: int) -> bool:
	return affection >= maxi(threshold, 0)


## 好感度是否达到了结婚门槛。
static func can_marry(affection: int, threshold: int) -> bool:
	return affection >= maxi(threshold, 0)


## 把好感度夹到合法区间；[param maximum] 来自 [member NpcData.max_affection]。
static func clamp_affection(affection: int, maximum: int) -> int:
	return clampi(affection, 0, maxi(maximum, 0))
