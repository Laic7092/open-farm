extends Node
## 天气系统（Autoload：`WeatherSystem`）。
##
## 每天开始时掷出当天天气并预报表日天气；天气决定作物是否自动浇水
## 以及玩家体力消耗倍率。
##
## 通过 [method GameClock.register_day_hook] 注册为[b]第一个[/b]日结转钩子，
## 保证其它系统在响应日结转时读到的 [member current] 已经是当天的天气。

## 天气变化时发出（与 [signal EventBus.weather_changed] 同步）。
signal changed(weather: Weather.Type)

var _rng := RandomNumberGenerator.new()

## 今天的天气。只读；通过 [method set_weather] / 日结转修改。
var current: Weather.Type:
	get:
		return _state.current

## 明天的天气预报（电视 / 告示牌会展示）。只读。
var forecast: Weather.Type:
	get:
		return _state.forecast

var _state: WeatherState = WeatherState.new()


func _ready() -> void:
	Persistence.register_core(self, &"WeatherSystem", 30)
	_rng.randomize()
	GameClock.register_day_hook(_on_day_rollover)
	# 开局那一天也要有天气。
	_state.current = roll_for(GameClock.date.season)
	_state.forecast = roll_for(GameClock.date.season)


## 当前天气状态；由组合根持有，可整体替换。
func state() -> WeatherState:
	return _state


## 换入天气状态；传 null 会创建一份新的默认状态。
func set_state(value: WeatherState) -> void:
	_state = value if value != null else WeatherState.new()


## 为某个季节掷一次天气。可注入 [param rng] 以便测试复现。
func roll_for(season: Season.Type, rng: RandomNumberGenerator = null) -> Weather.Type:
	var source: RandomNumberGenerator = rng if rng != null else _rng
	return Weather.pick(Weather.candidates_for(season), source)


## 直接设置天气（读档 / 剧情演出）。
func set_weather(weather: Weather.Type) -> void:
	if _state.current == weather:
		return
	_state.current = weather
	changed.emit(current)
	EventBus.weather_changed.emit(current)


## 强制重掷今天的天气。
func reroll(season: Season.Type = GameClock.date.season) -> void:
	set_weather(roll_for(season))


## 今天是否会为作物自动浇水。
func waters_crops() -> bool:
	return Weather.waters_crops(current)


## 今天的体力消耗倍率。
func stamina_multiplier() -> float:
	return Weather.stamina_multiplier(current)


## 今天的天气翻译键。
func name_key() -> StringName:
	return Weather.name_key(current)


func to_dict() -> Dictionary:
	return {
		"current": Weather.to_key(current),
		"forecast": Weather.to_key(forecast),
	}


func from_dict(data: Dictionary) -> void:
	_state.current = Weather.from_key(str(data.get("current", "sunny")))
	_state.forecast = Weather.from_key(str(data.get("forecast", "sunny")))
	changed.emit(current)
	EventBus.weather_changed.emit(current)


func _on_day_rollover(date: GameDate) -> void:
	_state.current = _state.forecast
	_state.forecast = roll_for(date.season)
	changed.emit(current)
	EventBus.weather_changed.emit(current)
