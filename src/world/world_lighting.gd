class_name WorldLighting
extends Node2D
## 昼夜光照的"看得见的那一半"：全局环境光 + 夜晚点光源 + 雷暴闪光。
##
## [DayNight] 给出"几点钟该多亮"的曲线，[WeatherService] 给出今天什么天气；
## 本节点把两者相乘后写进唯一的 [CanvasModulate]。
## 之所以必须合并：Godot 每张画布只认一个 [CanvasModulate]，
## 天气与昼夜各挂一个的话只有一个会生效。
##
## 带 [code]light_radius[/code] 的摆件由 [WorldProp] 自己创建 [PointLight2D]，
## 本节点只按 [method DayNight.lamp_energy] 统一调它们的亮度。
##
## 由 [WorldScene] 自动挂载，每张地图一份。

## 天气对画面的染色，与昼夜环境光相乘。
const WEATHER_TINTS := {
	Weather.Type.SUNNY: ArtPalette.WEATHER_SUNNY,
	Weather.Type.CLOUDY: ArtPalette.WEATHER_CLOUDY,
	Weather.Type.RAINY: ArtPalette.WEATHER_RAINY,
	Weather.Type.STORMY: ArtPalette.WEATHER_STORMY,
	Weather.Type.SNOWY: ArtPalette.WEATHER_SNOWY,
}

## 雷暴闪光叠加到环境光上的颜色。
const FLASH_COLOR := Color(1.6, 1.6, 1.7)
## 雷暴两次闪光之间的间隔（秒）。
const FLASH_INTERVAL: float = 4.0

## 0~1 的闪光强度；补间驱动，叠加在最终环境光上。
var flash_strength: float = 0.0:
	set(value):
		flash_strength = value
		_refresh_tint()

var _tint: CanvasModulate
var _flash_timer: Timer
var _flash_tween: Tween
## 组合根注入的时钟；只读分钟数计算环境光。
var _clock: GameDateClock
## 组合根注入的天气服务；只读当前天气。
var _weather: WeatherService


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


## 由 [WorldScene] 在世界进入树前下发领域服务。
func bind_services(
	weather: WeatherService,
	_relationships: RelationshipService,
	_calendar: CalendarService
) -> void:
	_weather = weather
	if is_node_ready():
		_refresh()


func _ready() -> void:
	_tint = CanvasModulate.new()
	_tint.name = "Tint"
	add_child(_tint)

	_flash_timer = Timer.new()
	_flash_timer.name = "Flash"
	_flash_timer.wait_time = FLASH_INTERVAL
	_flash_timer.timeout.connect(_flash)
	add_child(_flash_timer)

	_refresh()


func _enter_tree() -> void:
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	if not EventBus.world.weather_changed.is_connected(_on_weather_changed):
		EventBus.world.weather_changed.connect(_on_weather_changed)
	# 世界场景会被缓存复用，_ready() 一生只跑一次；
	# 从缓存里重新进图时必须在这里补一次刷新。
	if is_node_ready():
		_refresh()


func _exit_tree() -> void:
	if EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.disconnect(_on_minute_changed)
	if EventBus.world.weather_changed.is_connected(_on_weather_changed):
		EventBus.world.weather_changed.disconnect(_on_weather_changed)


## 当前显示的环境光颜色（白天≈纯白）。供 UI / 测试查询。
func tint_color() -> Color:
	return _tint.color if _tint != null else Color.WHITE


# ---------------------------------------------------------------- 内部

func _refresh() -> void:
	_refresh_tint()
	_refresh_storm()


## 当前天气；服务未注入时按晴天处理。
func _current_weather() -> Weather.Type:
	return _weather.current if _weather != null else Weather.Type.SUNNY


func _refresh_tint() -> void:
	if _tint == null:
		return
	var minute := _clock.minute_of_day if _clock != null else GameDateClock.DAY_START_HOUR * 60
	var color := DayNight.ambient_color(minute)
	color *= WEATHER_TINTS.get(_current_weather(), ArtPalette.WEATHER_SUNNY)
	if flash_strength > 0.0:
		color = color.lerp(FLASH_COLOR, flash_strength)
	_tint.color = color
	_refresh_lights()


## 按昼夜曲线统一调节所有发光摆件的亮度。
func _refresh_lights() -> void:
	var minute := _clock.minute_of_day if _clock != null else GameDateClock.DAY_START_HOUR * 60
	var energy := DayNight.lamp_energy(minute)
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(WorldProp.NIGHT_LIGHT_GROUP):
		if node is WorldProp:
			(node as WorldProp).apply_night_energy(energy)


func _refresh_storm() -> void:
	if _flash_timer == null:
		return
	_flash_timer.stop()
	if _current_weather() == Weather.Type.STORMY:
		_flash_timer.start()


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_refresh_tint()


func _on_weather_changed(_weather: Weather.Type) -> void:
	_refresh_tint()
	_refresh_storm()


## 雷暴的瞬间闪光：把环境光推向偏白一瞬，再滑回当前时刻的颜色。
func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_strength = 0.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "flash_strength", 1.0, 0.06)
	_flash_tween.tween_property(self, "flash_strength", 0.0, 0.35)
