class_name FishingRules
extends RefCounted
## 钓鱼的纯静态规则：什么鱼在哪里、什么时候咬钩、窗口多长、体长多大。
##
## 这里一个 [Node] 都不碰，随机源由调用方注入 [RandomNumberGenerator]，
## 因此可以脱离场景树做单元测试；[code]player_state_fishing.gd[/code] 只是
## 把这里算出来的时间轴演出来的驱动器。

## 咬钩等待时间的下 / 上限（秒）。
const BITE_DELAY_MIN: float = 0.8
const BITE_DELAY_MAX: float = 3.6
## 收到咬钩提示后，玩家必须在这么多秒内收竿。
const BITE_WINDOW_BASE: float = 0.85
## 每提升一级钓竿：窗口更长、咬钩更快。
const BITE_WINDOW_PER_TIER: float = 0.08
const BITE_DELAY_PER_TIER: float = 0.86
## 窗口兜底下限，避免高难度把窗口压成 0。
const BITE_WINDOW_MIN: float = 0.28


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
static func pick(
	pool: Array[FishData],
	rng: RandomNumberGenerator,
	water: int,
	season: Season.Type,
	weather: Weather.Type,
	hour: int
) -> FishData:
	var candidates := eligible_fish(pool, water, season, weather, hour)
	var total: int = 0
	for fish: FishData in candidates:
		total += maxi(fish.weight, 0)
	if total <= 0:
		return null
	var roll: int = rng.randi_range(1, total)
	var accumulated: int = 0
	for fish: FishData in candidates:
		accumulated += maxi(fish.weight, 0)
		if roll <= accumulated:
			return fish
	if candidates.is_empty():
		return null
	return candidates[candidates.size() - 1]


## 本次抛竿要等多久才咬钩。[param tier] 为钓竿等级。
static func bite_delay(rng: RandomNumberGenerator, tier: int = 0) -> float:
	var base: float = rng.randf_range(BITE_DELAY_MIN, BITE_DELAY_MAX)
	var scaled: float = base * pow(BITE_DELAY_PER_TIER, float(maxi(tier, 0)))
	return maxf(scaled, 0.35)


## 收竿窗口（秒）。鱼越难窗口越短，钓竿越好窗口越长。
static func bite_window(fish: FishData, tier: int = 0) -> float:
	var difficulty: int = fish.difficulty if fish != null else 1
	var window: float = BITE_WINDOW_BASE + BITE_WINDOW_PER_TIER * float(maxi(tier, 0))
	window -= 0.1 * float(clampi(difficulty, 1, 5) - 1)
	return maxf(window, BITE_WINDOW_MIN)


## 抽一条鱼的体长（厘米）。
static func roll_size(fish: FishData, rng: RandomNumberGenerator) -> int:
	if fish == null:
		return 0
	return rng.randi_range(fish.size_cm.x, maxi(fish.size_cm.y, fish.size_cm.x))
