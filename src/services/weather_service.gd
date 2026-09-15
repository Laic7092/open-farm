class_name WeatherService
extends Node
## 天气服务（由 [Main] 组合根持有，不再是 Autoload）。
##
## 每天开始时掷出当天天气并预报表日天气；天气决定作物是否自动浇水
## 以及玩家体力消耗倍率。服务持有 [WeatherState]，并向 [GameDateClock]
## 的 [DayPipeline] 注册 [constant DayPipeline.PRIORITY_WEATHER] 钩子，
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
## 组合根注入的时钟；未注入时不会读取日期或注册钩子。
var _clock: GameDateClock


func _ready() -> void:
	# 存档键名继续保持 "WeatherSystem"，兼容旧存档。
	Persistence.register_core(self, &"WeatherSystem", 30)
	_rng.randomize()


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


## 注入组合根持有的时钟与天气状态，并重新注册日结转钩子。
func bind_dependencies(clock: GameDateClock, state: WeatherState) -> void:
	set_state(state)
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)
	_clock = clock
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WEATHER)


## 兼容旧调用：只换时钟、不改状态。
func bind_clock(clock: GameDateClock) -> void:
	bind_dependencies(clock, _state)


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
func reroll(season: Season.Type = Season.Type.SPRING) -> void:
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
