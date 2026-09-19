class_name FishingRules
extends RefCounted
## 钓鱼的纯静态规则：什么鱼在哪里、什么时候咬钩、抛多远、体长多大。
##
## 这里一个 [Node] 都不碰，随机源由调用方注入 [RandomNumberGenerator]，
## 因此可以脱离场景树做单元测试。整条时间轴被拆成三段：
## [br]- [b]抛竿[/b]：本文件的 [method cast_power] / [method cast_distance] 把"按住多久"换算成落点；
## [br]- [b]等鱼[/b]：[method bite_delay] 决定多久后咬钩；
## [br]- [b]拉扯[/b]：真正的搏斗交给 [FishingFight]，本文件只负责按蓄力重新加权鱼群。
##
## [code]player_state_fishing.gd[/code] 只是把这里算出来的数值演出来的驱动器。

## 咬钩等待时间的下 / 上限（秒）。
const BITE_DELAY_MIN: float = 0.8
const BITE_DELAY_MAX: float = 3.6
## 每提升一级钓竿：咬钩更快。
const BITE_DELAY_PER_TIER: float = 0.86

## 抛竿蓄力到满所需时长（秒）。
const CAST_CHARGE_TIME: float = 0.85
## 蓄力下限：轻点一下也算抛出去了，落点不会缩回脚边。
const CAST_POWER_MIN: float = 0.2
## 落点距离（格）：轻抛贴岸、满蓄力甩到远处。
const CAST_DISTANCE_MIN: float = 1.0
const CAST_DISTANCE_MAX: float = 4.0
## 满蓄力时，每级"难度"给权重的额外加成上限（difficulty 5 的鱼最多 ×1.6）。
const CAST_WEIGHT_BONUS: float = 1.6


## 判断小时是否落在 [param min_hour]~[param max_hour] 的窗口内（含端点，可跨午夜）。
static func hour_in_window(hour: int, min_hour: int, max_hour: int) -> bool:
	var h: int = wrapi(hour, 0, 24)
	var lo: int = wrapi(min_hour, 0, 24)
	var hi: int = wrapi(max_hour, 0, 24)
	if lo <= hi:
		return h >= lo and h <= hi
	return h >= lo or h <= hi


## 一条鱼此刻是否可能出现。
static func is_eligible(
	fish: FishData,
	water: int,
	season: Season.Type,
	weather: Weather.Type,
	hour: int
) -> bool:
	if fish == null:
		return false
	if not fish.water.has(water):
		return false
	if not fish.seasons.is_empty() and not fish.seasons.has(season):
		return false
	if not fish.weathers.is_empty() and not fish.weathers.has(weather):
		return false
	return hour_in_window(hour, fish.min_hour, fish.max_hour)


## 从鱼群里筛出此刻可能出现的鱼，保持传入顺序（便于复现与测试）。
static func eligible_fish(
	pool: Array[FishData],
	water: int,
	season: Season.Type,
	weather: Weather.Type,
	hour: int
) -> Array[FishData]:
	var result: Array[FishData] = []
	for fish: FishData in pool:
		if is_eligible(fish, water, season, weather, hour):
			result.append(fish)
	return result


## 按权重抽一条鱼；没有可选鱼时返回 null。
##
## [param power] 为本次抛竿的蓄力（0~1）：蓄得越满，越容易碰上难钓的鱼。
static func pick(
	pool: Array[FishData],
	rng: RandomNumberGenerator,
	water: int,
	season: Season.Type,
	weather: Weather.Type,
	hour: int,
	power: float = 0.0
) -> FishData:
	var candidates := eligible_fish(pool, water, season, weather, hour)
	var total: int = 0
	for fish: FishData in candidates:
		total += weight_at(fish, power)
	if total <= 0:
		return null
	var roll: int = rng.randi_range(1, total)
	var accumulated: int = 0
	for fish: FishData in candidates:
		accumulated += weight_at(fish, power)
		if roll <= accumulated:
			return fish
	if candidates.is_empty():
		return null
	return candidates[candidates.size() - 1]


## 某条鱼在给定蓄力下的抽取权重。
##
## 常见鱼（difficulty 1）权重不受影响；越难钓的鱼被蓄力放大得越多，
## 于是"甩得远"这件事既有手感也有收益，而不只是动画。
static func weight_at(fish: FishData, power: float = 0.0) -> int:
	if fish == null:
		return 0
	var base: int = maxi(fish.weight, 0)
	if base <= 0:
		return 0
	var p: float = clampf(power, 0.0, 1.0)
	var difficulty: int = clampi(fish.difficulty, 1, 5)
	var multiplier: float = 1.0 + CAST_WEIGHT_BONUS * p * float(difficulty - 1) / 4.0
	return maxi(1, int(round(float(base) * multiplier)))


## 按住了 [param held_seconds] 秒之后，这一竿的蓄力（0~1）。
static func cast_power(held_seconds: float) -> float:
	var ratio: float = clampf(held_seconds / CAST_CHARGE_TIME, 0.0, 1.0)
	return clampf(CAST_POWER_MIN + (1.0 - CAST_POWER_MIN) * ratio, CAST_POWER_MIN, 1.0)


## 蓄力对应的落点距离（格）。
static func cast_distance(power: float) -> float:
	return lerpf(CAST_DISTANCE_MIN, CAST_DISTANCE_MAX, clampf(power, 0.0, 1.0))


## 本次抛竿要等多久才咬钩。[param tier] 为钓竿等级。
static func bite_delay(rng: RandomNumberGenerator, tier: int = 0) -> float:
	var base: float = rng.randf_range(BITE_DELAY_MIN, BITE_DELAY_MAX)
	var scaled: float = base * pow(BITE_DELAY_PER_TIER, float(maxi(tier, 0)))
	return maxf(scaled, 0.35)


# ---------------------------------------------------------------- 演出几何

## 抛竿飞行弧线的最高点（像素）：轻抛低、满蓄力高。
const CAST_ARC_MIN_HEIGHT: float = 10.0
const CAST_ARC_MAX_HEIGHT: float = 20.0
## 鱼线从竿尖到浮标之间会分成几段折线（段数越多越平滑，也越贵）。
const LINE_SEGMENTS: int = 8


## 抛竿飞行轨迹上的一点。[param power] 为蓄力，[param t] 为 0~1 的进度。
##
## 二次贝塞尔：控制点在两端中点的正上方，于是浮标先升后落，像真的甩出去。
static func cast_arc(from: Vector2, to: Vector2, power: float, t: float) -> Vector2:
	var control := (from + to) * 0.5
	var lift: float = lerpf(CAST_ARC_MIN_HEIGHT, CAST_ARC_MAX_HEIGHT, clampf(power, 0.0, 1.0))
	control.y -= lift
	var u: float = clampf(t, 0.0, 1.0)
	return from.lerp(control, u).lerp(control.lerp(to, u), u)


## 鱼线的折线顶点（局部坐标）。
##
## [param slack] 是中间最大下垂量（像素），[param shake] 叠一层高频抖动
## （咬钩 / 张力用），[param phase] 是抖动相位（一般传时间）。
## 两端永远精确落在 [param from] / [param to] 上，这样线不会从竿尖或浮标上脱离。
static func line_curve(
	from: Vector2,
	to: Vector2,
	slack: float,
	segments: int = LINE_SEGMENTS,
	shake: float = 0.0,
	phase: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 1)
	for i: int in count + 1:
		var t: float = float(i) / float(count)
		var point := from.lerp(to, t)
		var arch: float = sin(PI * t)
		point.y += arch * slack
		if shake > 0.0:
			point.y += sin(phase * 26.0 + t * 9.0) * shake * arch
		points.append(point)
	return points


## 抽一条鱼的体长（厘米）。
static func roll_size(fish: FishData, rng: RandomNumberGenerator) -> int:
	if fish == null:
		return 0
	return rng.randi_range(fish.size_cm.x, maxi(fish.size_cm.y, fish.size_cm.x))
