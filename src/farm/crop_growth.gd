class_name CropGrowth
extends RefCounted
## 作物生长规则（纯函数）。
##
## 全部是 [code]static[/code]、无副作用（除显式传入的 [CropState] 之外），
## 因此可以用最朴素的方式做单元测试：给定数据 + 状态，断言输出。

## 日结转结果中可能出现的字段。
const KEY_STAGE_CHANGED: StringName = &"stage_changed"
const KEY_MATURED: StringName = &"matured"
const KEY_DIED: StringName = &"died"


## 成熟所需要的总有效生长天数。
static func mature_days(data: CropData) -> int:
	return data.total_growth_days() if data != null else 0


## 生长阶段总数（含成熟阶段），例如 4 段成长 → 返回值 4，阶段下标 0..4。
static func max_stage(data: CropData) -> int:
	return data.stage_count() if data != null else 0


## 给定已生长天数，返回当前阶段下标（0 = 刚播种，max_stage = 成熟）。
static func stage_of(data: CropData, days_grown: int) -> int:
	if data == null:
		return 0
	var accumulated: int = 0
	for index: int in data.days_per_stage.size():
		accumulated += maxi(data.days_per_stage[index], 0)
		if days_grown < accumulated:
			return index
	return data.days_per_stage.size()


## 是否已经成熟可收获。
static func is_mature(data: CropData, days_grown: int) -> bool:
	if data == null:
		return false
	return days_grown >= mature_days(data)


## 是否可以收获（成熟且没枯死）。
static func can_harvest(data: CropData, state: CropState) -> bool:
	if data == null or state == null or state.dead:
		return false
	return is_mature(data, state.days_grown)


## 推进一天。
##
## [param watered] 为 true 表示今天这株作物获得了水分（玩家浇水或下雨）。
## 返回本次推进产生的变化描述，供 [FarmGrid] 决定发哪些信号 / 刷哪些图。
static func advance(
	data: CropData, state: CropState, watered: bool, season: Season.Type
) -> Dictionary:
	var result := {
		KEY_STAGE_CHANGED: false,
		KEY_MATURED: false,
		KEY_DIED: false,
	}
	if data == null or state == null or state.dead:
		return result

	# 1) 季节不对 → 直接枯死。
	if not data.is_plantable_in(season):
		state.dead = true
		result[KEY_DIED] = true
		return result

	var stage_before: int = stage_of(data, state.days_grown)
	var was_mature: bool = is_mature(data, state.days_grown)

	# 2) 有水分才生长；没水分累计干旱天数，超过容忍度枯死。
	if watered:
		state.days_without_water = 0
		state.days_grown += 1
	else:
		state.days_without_water += 1
		var tolerance: int = data.days_without_water_tolerance
		if tolerance > 0 and state.days_without_water > tolerance:
			state.dead = true
			result[KEY_DIED] = true
			return result

	var stage_after: int = stage_of(data, state.days_grown)
	result[KEY_STAGE_CHANGED] = stage_after != stage_before
	result[KEY_MATURED] = not was_mature and is_mature(data, state.days_grown)
	return result


## 结算一次收获，返回产出描述并就地更新状态。
##
## 返回 [code]{ "item_id": StringName, "amount": int, "removed": bool }[/code]；
## [code]removed[/code] 为 true 表示收获后这株作物应当从地里消失。
static func apply_harvest(
	data: CropData, state: CropState, rng: RandomNumberGenerator = null
) -> Dictionary:
	var outcome := {"item_id": &"", "amount": 0, "removed": false}
	if not can_harvest(data, state):
		return outcome

	var amount: int = maxi(data.harvest_amount, 1)
	if data.bonus_yield_chance > 0.0:
		var roll: float = rng.randf() if rng != null else randf()
		if roll < data.bonus_yield_chance:
			amount += 1

	outcome["item_id"] = data.harvest_item_id
	outcome["amount"] = amount
	state.harvests += 1

	if data.is_regrowable():
		# 回到"距成熟还差 regrow_days 天"的状态，重新结果。
		state.days_grown = maxi(mature_days(data) - data.regrow_days, 0)
		state.days_without_water = 0
	else:
		state.dead = true
		outcome["removed"] = true
	return outcome
