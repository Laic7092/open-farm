class_name Weather
extends RefCounted
## 天气规则。
##
## 天气由 [WeatherService] 在每天开始时抽取，会影响：
## [br]- 作物是否需要手动浇水（雨天自动浇水）
## [br]- 玩家体力消耗
## [br]- 可采集物与 NPC 行程

enum Type {
	SUNNY = 0,
	CLOUDY = 1,
	RAINY = 2,
	STORMY = 3,
	SNOWY = 4,
}

const COUNT: int = 5


static func is_valid(value: int) -> bool:
	return value >= 0 and value < COUNT


## 返回该天气的翻译键。
static func name_key(weather: Type) -> StringName:
	match weather:
		Type.SUNNY:
			return &"WEATHER_SUNNY"
		Type.CLOUDY:
			return &"WEATHER_CLOUDY"
		Type.RAINY:
			return &"WEATHER_RAINY"
		Type.STORMY:
			return &"WEATHER_STORMY"
		_:
			return &"WEATHER_SNOWY"


## 该天气是否会为作物自动浇水。
static func waters_crops(weather: Type) -> bool:
	return weather == Type.RAINY or weather == Type.STORMY


## 该天气下玩家体力消耗倍率。
static func stamina_multiplier(weather: Type) -> float:
	match weather:
		Type.RAINY:
			return 1.25
		Type.STORMY:
			return 1.5
		Type.SNOWY:
			return 1.1
		_:
			return 1.0


## 某季节下可能出现的天气及其权重。
static func candidates_for(season: Season.Type) -> Dictionary:
	match season:
		Season.Type.SPRING:
			return {Type.SUNNY: 50, Type.CLOUDY: 25, Type.RAINY: 25}
		Season.Type.SUMMER:
			return {Type.SUNNY: 60, Type.CLOUDY: 15, Type.RAINY: 20, Type.STORMY: 5}
		Season.Type.FALL:
			return {Type.SUNNY: 45, Type.CLOUDY: 25, Type.RAINY: 30}
		_:
			return {Type.SUNNY: 35, Type.CLOUDY: 25, Type.SNOWY: 40}


## 从权重表里按权重抽取一个天气。
## [param rng] 允许注入随机源，便于单元测试复现。
static func pick(weights: Dictionary, rng: RandomNumberGenerator) -> Type:
	var total: int = 0
	for weight: int in weights.values():
		total += weight
	if total <= 0:
		return Type.SUNNY
	var roll: int = rng.randi_range(1, total)
	var accumulated: int = 0
	for weather: Type in weights:
		accumulated += weights[weather]
		if roll <= accumulated:
			return weather
	return Type.SUNNY


static func to_key(weather: Type) -> StringName:
	return StringName(String(Type.keys()[weather]).to_lower())


static func from_key(key: String) -> Type:
	var index: int = Type.keys().find(key.to_upper())
	return (index if index >= 0 else 0) as Type
