extends "res://tools/sample/sample_base.gd"
## fish：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

## 鱼种：出没水域 / 季节 / 天气 / 时段 / 稀有度。
##
## 数值调法：
## [br]- [code]weight[/code] 越大越常见
## [br]- [code]difficulty[/code] 1~5 只影响收竿窗口，不额外掷骰
## [br]- 时段用 24 小时制，[code]min_hour > max_hour[/code] 表示跨午夜
func build() -> void:
	# 海：白天为主，夏夜有鱿鱼，稀有金枪鱼只在盛夏晴天的白天露面。
	_fish(&"sardine", &"sardine", [WaterKind.Kind.OCEAN] as Array[int],
		[] as Array[Season.Type], [] as Array[Weather.Type],
		0, 23, 30, 1, Vector2i(12, 26))
	_fish(&"mackerel", &"mackerel", [WaterKind.Kind.OCEAN] as Array[int],
		[] as Array[Season.Type], [] as Array[Weather.Type],
		0, 23, 22, 2, Vector2i(20, 45))
	_fish(&"sea_bream", &"sea_bream", [WaterKind.Kind.OCEAN] as Array[int],
		[Season.Type.SPRING, Season.Type.SUMMER] as Array[Season.Type],
		[] as Array[Weather.Type],
		5, 18, 10, 3, Vector2i(30, 70))
	_fish(&"squid", &"squid", [WaterKind.Kind.OCEAN] as Array[int],
		[Season.Type.SUMMER, Season.Type.FALL] as Array[Season.Type],
		[] as Array[Weather.Type],
		18, 4, 12, 2, Vector2i(18, 40))
	_fish(&"octopus", &"octopus", [WaterKind.Kind.OCEAN] as Array[int],
		[Season.Type.SUMMER] as Array[Season.Type], [] as Array[Weather.Type],
		10, 20, 5, 4, Vector2i(30, 90))
	_fish(&"tuna", &"tuna", [WaterKind.Kind.OCEAN] as Array[int],
		[Season.Type.SUMMER] as Array[Season.Type],
		[Weather.Type.SUNNY] as Array[Weather.Type],
		6, 16, 2, 5, Vector2i(80, 220))

	# 池塘：鲫鱼 / 鲤鱼常驻；雨天的鲶鱼与极稀有的金鲤是这里的目标。
	_fish(&"crucian", &"crucian", [WaterKind.Kind.POND] as Array[int],
		[] as Array[Season.Type], [] as Array[Weather.Type],
		0, 23, 30, 1, Vector2i(12, 28))
	_fish(&"carp", &"carp", [WaterKind.Kind.POND] as Array[int],
		[] as Array[Season.Type], [] as Array[Weather.Type],
		0, 23, 20, 2, Vector2i(25, 60))
	_fish(&"catfish", &"catfish", [WaterKind.Kind.POND] as Array[int],
		[Season.Type.SPRING, Season.Type.SUMMER, Season.Type.FALL] as Array[Season.Type],
		[Weather.Type.RAINY, Weather.Type.STORMY] as Array[Weather.Type],
		0, 23, 10, 3, Vector2i(40, 90))
	_fish(&"golden_carp", &"golden_carp", [WaterKind.Kind.POND] as Array[int],
		[] as Array[Season.Type], [] as Array[Weather.Type],
		0, 23, 1, 5, Vector2i(40, 100))


## 建一条鱼并保存。
func _fish(
	fish_id: StringName,
	item_id: StringName,
	water: Array[int],
	seasons: Array[Season.Type],
	weathers: Array[Weather.Type],
	min_hour: int,
	max_hour: int,
	weight: int,
	difficulty: int,
	size_cm: Vector2i
) -> void:
	var fish := FishData.new()
	fish.id = fish_id
	fish.item_id = item_id
	fish.water = water
	fish.seasons = seasons
	fish.weathers = weathers
	fish.min_hour = min_hour
	fish.max_hour = max_hour
	fish.weight = weight
	fish.difficulty = difficulty
	fish.size_cm = size_cm
	_save(fish, FISH_DIR.path_join("%s.tres" % fish_id))
