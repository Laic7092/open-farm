class_name MineRules
extends RefCounted
## 矿洞深度规则（纯静态函数）。
##
## 和 [CropGrowth] / [AnimalHusbandry] 一样不依赖场景树与 [Database]：
## 给定楼层就能回答"每层几个矿、抽哪些矿、品质加成多少"，
## 因此可以直接单测，也保证同一层每次进入的分布是确定性的。

## 矿洞总层数。
const MAX_DEPTH: int = 100
## 每隔多少层有一个电梯。
const ELEVATOR_EVERY: int = 5

## 该楼层是否设电梯。
static func is_elevator_floor(depth: int) -> bool:
	return depth > 0 and depth % ELEVATOR_EVERY == 0


## 该楼层能坐电梯回到的最深楼层（向下取整到 5 的倍数）。
static func elevator_floor(depth: int) -> int:
	return (clampi(depth, 0, MAX_DEPTH) / ELEVATOR_EVERY) * ELEVATOR_EVERY


## 该楼层要生成多少个矿石节点；越深越挤。
static func ore_budget(depth: int) -> int:
	return mini(10 + clampi(depth, 1, MAX_DEPTH) / 2, 60)


## 该楼层的确定性随机种子；同一层每次生成同样的布局。
static func seed_for(depth: int) -> int:
	return 104729 * maxi(depth, 1) + 7919


## 越深品质越好：按楼层给银 / 金品质加一份额外概率。
static func quality_bonus(depth: int) -> float:
	return minf(0.05 * float(clampi(depth, 1, MAX_DEPTH)) / 10.0, 0.4)


## 某个物种在这一层能不能出现。
static func allows(data: FloraData, depth: int) -> bool:
	if data == null or data.mine_weight <= 0:
		return false
	if data.mine_min_depth > 0 and depth < data.mine_min_depth:
		return false
	if data.mine_max_depth > 0 and depth > data.mine_max_depth:
		return false
	return true


## 抽一次矿洞物种；[param depth] 越深，高价值矿石的权重越高。
static func pick_ore(candidates: Array[FloraData], depth: int, rng: RandomNumberGenerator) -> FloraData:
	if candidates.is_empty():
		return null
	var weights: Array[float] = []
	var total: float = 0.0
	for data: FloraData in candidates:
		var weight: float = maxf(float(data.mine_weight), 0.0)
		# 只在深层的矿石，越接近它的出现深度权重越高。
		if data.mine_min_depth > 1:
			var span: float = maxf(float(MAX_DEPTH - data.mine_min_depth), 1.0)
			var t: float = clampf(float(depth - data.mine_min_depth) / span, 0.0, 1.0)
			weight *= 1.0 + 2.0 * t
		total += weight
		weights.append(total)
	if total <= 0.0:
		return candidates[0]
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for index: int in candidates.size():
		if roll <= weights[index]:
			return candidates[index]
	return candidates[candidates.size() - 1]
