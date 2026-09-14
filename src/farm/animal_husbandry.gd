class_name AnimalHusbandry
extends RefCounted
## 牲畜养殖规则（纯静态函数）。
##
## 与 [CropGrowth] 对称：给定 [AnimalData] + [AnimalState] 断言输出，
## 不依赖场景树、时间或数据库，因此可以直接单测。
##
## [b]核心循环[/b]：每天喂食 → 累计成长天数 → 成年后按 [member AnimalData.produce_days]
## 产出；不喂食则好感度下降且停止产出。抚摸只能提升好感度，不能替代喂食。

## 日结转结果中可能出现的字段。
const KEY_MATURED: StringName = &"matured"


## 是否已成年。
static func is_mature(data: AnimalData, state: AnimalState) -> bool:
	if data == null or state == null:
		return false
	return state.days_grown >= data.mature_days


## 成年且产出间隔已到，是否有产出可收。
static func can_collect(data: AnimalData, state: AnimalState) -> bool:
	if not is_mature(data, state):
		return false
	return state.days_since_product >= data.produce_days


## 今天是否还饿着（需要一份饲料）。
static func needs_feed(_data: AnimalData, state: AnimalState) -> bool:
	if state == null:
		return false
	return not state.fed_today


## 喂食；今天已喂过返回 false。
static func feed(_data: AnimalData, state: AnimalState) -> bool:
	if state == null or state.fed_today:
		return false
	state.fed_today = true
	return true


## 抚摸；返回实际增加的好感度（今天已摸过或已满则 0）。
static func pet(data: AnimalData, state: AnimalState) -> int:
	if data == null or state == null or state.petted_today:
		return 0
	var before: int = state.affection
	state.affection = mini(state.affection + data.affection_per_pet, data.max_affection)
	state.petted_today = true
	return state.affection - before


## 推进一天。
##
## [param fed] 为 true 表示今天喂过：好感度维持、成年后产出计时 +1；
## 否则好感度下降且产出计时停摆（牲畜不会因为没有产出而死亡）。
## 返回本次推进产生的变化描述。
static func advance(data: AnimalData, state: AnimalState, fed: bool) -> Dictionary:
	var result := {KEY_MATURED: false}
	if data == null or state == null:
		return result

	var was_mature: bool = is_mature(data, state)
	state.days_grown += 1
	if not was_mature and is_mature(data, state):
		result[KEY_MATURED] = true

	if fed:
		if is_mature(data, state):
			state.days_since_product += 1
	else:
		state.affection = maxi(state.affection - data.affection_decay_per_day, 0)

	# 日结转后重置当天的"照顾"标记。
	state.fed_today = false
	state.petted_today = false
	return result


## 结算一次产出，返回产出描述并就地更新状态。
##
## 返回 [code]{ "item_id": StringName, "amount": int, "bonus": bool }[/code]；
## [code]amount[/code] 为 0 表示现在没有可收的东西。
static func apply_collect(
	data: AnimalData, state: AnimalState, rng: RandomNumberGenerator = null
) -> Dictionary:
	var outcome := {"item_id": &"", "amount": 0, "bonus": false}
	if not can_collect(data, state):
		return outcome

	var amount: int = maxi(data.product_amount, 1)
	if (
		data.bonus_product_chance > 0.0
		and state.affection >= data.bonus_affection_threshold
	):
		var roll: float = rng.randf() if rng != null else randf()
		if roll < data.bonus_product_chance:
			amount += 1
			outcome["bonus"] = true

	state.days_since_product = 0
	outcome["item_id"] = data.product_item_id
	outcome["amount"] = amount
	return outcome


## 动物贴图应显示的列：0 = 幼崽、1 = 成年、2 = 有产出。
static func sprite_column(data: AnimalData, state: AnimalState) -> int:
	if not is_mature(data, state):
		return 0
	return 2 if can_collect(data, state) else 1
