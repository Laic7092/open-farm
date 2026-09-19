class_name FloraGrowth
extends RefCounted
## 野生植被的生长与扩散规则（纯函数）。
##
## 和 [CropGrowth] 一样全是 [code]static[/code]、无副作用（除显式传入的
## [FloraState] 之外），所以可以用最朴素的方式单测：
## 给定数据 + 状态 + 季节 + 天气，断言输出。
##
## [b]野生植被和作物最大的区别[/b]：作物靠玩家浇水，植被靠自己扩散；
## 因此除了"长大"之外，这里还负责回答"今天冒不冒新芽、冒哪一种"。

## 日推进 / 清除结果里可能出现的字段。
const KEY_STAGE_CHANGED: StringName = &"stage_changed"
const KEY_MATURED: StringName = &"matured"
const KEY_BECAME_SOLID: StringName = &"became_solid"

## 允许野生长东西的地表瓦片。
##
## 用"白名单"而不是"黑名单"：路、石板、木地板这些被人铺过的地方
## 自动不在列表里，于是"东西不会长在路上"这条规则不需要在代码里逐个枚举。
## 装饰（花 / 栅栏 / 碎石）已不占图集格子，它们占住的格子由
## [FloraField] 按 [code]decor_props[/code] 分组判掉。
const NATURAL_GROUND: Array[Vector2i] = [
	FarmAtlas.GRASS,
	FarmAtlas.GRASS_ALT,
	FarmAtlas.GRASS_LUSH,
	FarmAtlas.GRASS_DRY,
	FarmAtlas.GRASS_DAPPLED,
	FarmAtlas.GRASS_MEADOW,
	FarmAtlas.DIRT,
	FarmAtlas.GRAVEL,
	FarmAtlas.SAND,
]


## 这块地表是不是"自然的"（能长东西）。
static func is_natural_ground(atlas: Vector2i) -> bool:
	if NATURAL_GROUND.has(atlas):
		return true
	return (
		FarmAtlas.is_transition_of(FarmAtlas.Surface.SAND, atlas)
		or FarmAtlas.is_transition_of(FarmAtlas.Surface.DIRT, atlas)
	)


## 成熟所需要的总有效生长天数。
static func mature_days(data: FloraData) -> int:
	return data.total_growth_days() if data != null else 0


## 给定已生长天数，返回当前阶段下标（0 = 刚冒芽，[method FloraData.stage_count] = 成熟）。
static func stage_of(data: FloraData, days_grown: int) -> int:
	if data == null:
		return 0
	var accumulated: int = 0
	for index: int in data.days_per_stage.size():
		accumulated += maxi(data.days_per_stage[index], 0)
		if days_grown < accumulated:
			return index
	return data.days_per_stage.size()


## 是否已经成熟。
static func is_mature(data: FloraData, days_grown: int) -> bool:
	if data == null:
		return false
	return days_grown >= mature_days(data)


## 当前阶段是否已经挡住去路。
##
## [member FloraData.passable] 是唯一显式可穿过标记：牧草这类低矮地被
## 即使配置了阶段也不会生成碰撞体。
static func is_solid(data: FloraData, days_grown: int) -> bool:
	if data == null or data.passable or data.solid_from_stage < 0:
		return false
	return stage_of(data, days_grown) >= data.solid_from_stage


## 这种东西在这个季节还会不会继续长。
static func can_grow(data: FloraData, season: Season.Type) -> bool:
	if data == null or not data.can_grow():
		return false
	return data.grow_seasons.is_empty() or data.grow_seasons.has(season)


## 今天的扩散权重：季节权重 + 雨天加成。
##
## 返回 0 表示这个物种今天不会冒新芽。霜雪天不下种子（冬季本来也大多为 0）。
static func spawn_weight(data: FloraData, season: Season.Type, weather: Weather.Type) -> int:
	if data == null:
		return 0
	if weather == Weather.Type.SNOWY:
		return 0
	var weight: int = data.spawn_weight_for_season(season)
	if weight <= 0:
		return 0
	if Weather.waters_crops(weather):
		weight += maxi(data.rain_bonus, 0)
	return weight


## 从权重表里抽一个物种；[param rng] 可注入，便于测试复现。
static func pick_spawn(weights: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total: int = 0
	for weight: int in weights.values():
		total += maxi(weight, 0)
	if total <= 0:
		return &""
	var roll: int = rng.randi_range(1, total)
	var accumulated: int = 0
	for flora_id: StringName in weights:
		accumulated += maxi(int(weights[flora_id]), 0)
		if roll <= accumulated:
			return flora_id
	return &""


## 推进一天；返回本次推进产生的变化描述。
static func advance(
	data: FloraData, state: FloraState, season: Season.Type
) -> Dictionary:
	var result := {
		KEY_STAGE_CHANGED: false,
		KEY_MATURED: false,
		KEY_BECAME_SOLID: false,
	}
	if data == null or state == null or state.dead:
		return result
	# 季节不对 / 本来就不生长：原地不动，但也不会死。
	if not can_grow(data, season):
		return result

	var stage_before: int = stage_of(data, state.days_grown)
	var was_mature: bool = is_mature(data, state.days_grown)
	var was_solid: bool = is_solid(data, state.days_grown)

	state.days_grown += 1

	var stage_after: int = stage_of(data, state.days_grown)
	result[KEY_STAGE_CHANGED] = stage_after != stage_before
	result[KEY_MATURED] = not was_mature and is_mature(data, state.days_grown)
	result[KEY_BECAME_SOLID] = not was_solid and is_solid(data, state.days_grown)
	return result


## 结算一次清除，返回产出描述。
##
## 返回 [code]{ "item_id": StringName, "amount": int }[/code]；
## 数量为 0 表示这次什么也没掉（杂草不一定有纤维）。
static func apply_removal(
	data: FloraData, state: FloraState, rng: RandomNumberGenerator = null
) -> Dictionary:
	var outcome := {"item_id": &"", "amount": 0}
	if data == null or state == null or data.drop_item_id == &"":
		return outcome
	var roll: float = rng.randf() if rng != null else randf()
	if roll > data.drop_chance:
		return outcome
	var low: int = maxi(mini(data.drop_amount.x, data.drop_amount.y), 0)
	var high: int = maxi(data.drop_amount.x, data.drop_amount.y)
	var amount: int = rng.randi_range(low, high) if rng != null else low
	if amount <= 0:
		return outcome
	outcome["item_id"] = data.drop_item_id
	outcome["amount"] = amount
	return outcome
