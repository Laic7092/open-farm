class_name HudWeatherView
extends Node
## HUD 上的当前天气与明日预报。
##
## [b]天气自己的小视图[/b]：只订阅天气变化，只读天气服务。跨天时天气服务自己会
## 广播新天气，所以这里不必再去监听日历。
##
## 天气 / 明日预报只保留图标，文字塞进 tooltip，减少屏幕上的常驻文案。

## 天气图标目录：文件名为 [code]weather_<key>.png[/code]。
const WEATHER_ICON_DIR: String = "res://assets/ui"

@onready var weather_label: Label = %WeatherLabel
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var forecast_label: Label = %ForecastLabel
@onready var forecast_icon: TextureRect = %ForecastIcon

var _weather: WeatherService
## 图标缓存：贴着同一张图反复 load 会把刷新变成磁盘 IO。
var _icons: Dictionary[StringName, Texture2D] = {}


func bind_services(
	weather: WeatherService,
	_relationships: RelationshipService,
	_calendar: CalendarService
) -> void:
	_weather = weather
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.world.weather_changed.connect(
		func(_kind: Weather.Type) -> void: refresh()
	)
	refresh()


## 重画当前天气与明日预报；天气服务还没注入时按晴天画。
func refresh() -> void:
	var current: Weather.Type = _weather.current if _weather != null else Weather.Type.SUNNY
	var forecast: Weather.Type = _weather.forecast if _weather != null else Weather.Type.SUNNY
	var current_name := Text.weather_name(current)
	var forecast_name := Text.format(
		&"HUD_FORECAST", {"weather": Text.weather_name(forecast)}
	)

	weather_label.text = current_name
	weather_label.visible = false
	weather_icon.texture = _icon(current)
	weather_icon.tooltip_text = current_name

	forecast_label.text = forecast_name
	forecast_label.visible = false
	forecast_icon.texture = _icon(forecast)
	forecast_icon.tooltip_text = forecast_name


## 取天气图标；找不到时返回 null（只显示文字）。
func _icon(kind: Weather.Type) -> Texture2D:
	var key := Weather.to_key(kind)
	if _icons.has(key):
		return _icons[key]
	var path := "%s/weather_%s.png" % [WEATHER_ICON_DIR, key]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icons[key] = texture
	return texture
