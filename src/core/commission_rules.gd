class_name CommissionRules
extends RefCounted
## 委托板的纯规则：每天从委托池里挑出固定数量的一批。
##
## 刻意做成静态函数、只吃 [GameDate]：同一天进来永远是同一批委托
## （不依赖运行时随机数），因此可以脱离场景树单测，也让"今天板子上是什么"
## 在存档 / 读档前后保持一致。

## 每天上板的委托数量。
const DAILY_COUNT: int = 3


## 挑选 [param date] 这一天的委托 id。
##
## [param pool] 是全部可选委托（调用方按 id 排序后传入，保证不同机器的结果一致）；
## 数量不足 [constant DAILY_COUNT] 时就把池子全上。
static func offers_for(
	date: GameDate, pool: Array[StringName], count: int = DAILY_COUNT
) -> Array[StringName]:
	var result: Array[StringName] = []
	if date == null or pool.is_empty():
		return result

	var candidates: Array[StringName] = pool.duplicate()
	candidates.sort()
	var wanted: int = clampi(count, 0, candidates.size())
	if wanted == 0:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(date)
	# 部分 Fisher–Yates：只洗出前 wanted 个，结果与"先整体洗牌再截断"等价。
	for index: int in wanted:
		var swap_with: int = rng.randi_range(index, candidates.size() - 1)
		var held: StringName = candidates[index]
		candidates[index] = candidates[swap_with]
		candidates[swap_with] = held
		result.append(candidates[index])
	return result


## 某一天对应的确定性随机种子。
static func seed_for(date: GameDate) -> int:
	return hash("commission-%d-%d-%d" % [date.year, int(date.season), date.day])


## 委托完成后的报酬；缺数据时返回 0。
static func reward_of(data: CommissionData) -> int:
	return maxi(data.reward_money, 0) if data != null else 0
