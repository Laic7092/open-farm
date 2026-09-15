class_name WeatherFx
extends Node2D
## 天气的"看得见的那一半"：粒子 + 晴天的阳光。
##
## [WeatherService] 只负责"今天是雨天"这个事实，不碰任何渲染；
## 本节点订阅天气变化，把它翻译成雨丝 / 雪花 / 落叶 / 阳光。
##
## 全局染色（天气 × 昼夜）不在这里，而在 [WorldLighting]：
## Godot 每张画布只认一个 [CanvasModulate]，天气与昼夜必须合并到同一个节点。
##
## 由 [WorldScene] 在每个世界场景里自动挂载，因此农场与小镇都有天气。
## 节点每帧跟随相机（粒子发射盒只覆盖一屏，不跟随就会出现"走到地图右边就没雨了"）。

const RAIN_TEXTURE: Texture2D = preload("res://assets/sprites/weather/rain_drop.png")
const SNOW_TEXTURE: Texture2D = preload("res://assets/sprites/weather/snow_flake.png")
const LEAF_TEXTURE: Texture2D = preload("res://assets/sprites/weather/leaf.png")
const SUN_TEXTURE: Texture2D = preload("res://assets/sprites/weather/sunburst.png")

## 粒子发射盒的半宽 / 半高：比 640×360 的视口大一圈，转身时不会有空缺。
const EMIT_EXTENTS := Vector3(380.0, 220.0, 0.0)

var _rain: GPUParticles2D
var _snow: GPUParticles2D
var _leaves: GPUParticles2D
var _sunburst: Sprite2D
## 组合根注入的时钟；只读分钟数判断白天。
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
		_apply(_current_weather())


func _ready() -> void:
	z_index = 90
	_build()
	_apply(_current_weather())


func _enter_tree() -> void:
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	# 世界场景会缓存复用：_ready() 一生只跑一次，
	# 从缓存里重新进图时要在这里补一次状态。
	if is_node_ready():
		_apply(_current_weather())


func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)
	if EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.disconnect(_on_minute_changed)


func _process(_delta: float) -> void:
	# 跟随相机中心：粒子盒只需要覆盖一屏。
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		global_position = camera.get_screen_center_position()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	# 晴天：右上角一圈很淡的阳光。
	_sunburst = Sprite2D.new()
	_sunburst.name = "Sunburst"
	_sunburst.texture = SUN_TEXTURE
	_sunburst.position = Vector2(250, -130)
	_sunburst.modulate.a = 0.55
	_sunburst.visible = false
	add_child(_sunburst)

	_rain = _make_particles("Rain", RAIN_TEXTURE, 260, 0.9, Vector2(0.16, 1.0), 320.0, 520.0, Vector2(0.8, 0.4))
	_snow = _make_particles("Snow", SNOW_TEXTURE, 120, 3.4, Vector2(0.1, 1.0), 22.0, 46.0, Vector2(1.0, 1.0))
	_leaves = _make_particles("Leaves", LEAF_TEXTURE, 40, 3.0, Vector2(0.7, 1.0), 30.0, 70.0, Vector2(1.0, 1.0))


func _make_particles(
	name_: String,
	texture: Texture2D,
	amount: int,
	lifetime: float,
	direction: Vector2,
	speed_min: float,
	speed_max: float,
	scale_range: Vector2
) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = name_
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	# 已经在下雨的状态，而不是"进入场景后从头开始下"。
	particles.emitting = false
	particles.local_coords = false
	particles.z_index = 1

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = EMIT_EXTENTS
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 4.0
	material.initial_velocity_min = speed_min
	material.initial_velocity_max = speed_max
	material.gravity = Vector3(0.0, 40.0, 0.0)
	material.scale_min = scale_range.x
	material.scale_max = scale_range.y
	particles.process_material = material
	add_child(particles)
	return particles


# ---------------------------------------------------------------- 天气切换

func _on_weather_changed(weather: Weather.Type) -> void:
	_apply(weather)


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_update_sunburst(_current_weather())


## 当前天气；服务未注入时按晴天处理。
func _current_weather() -> Weather.Type:
	return _weather.current if _weather != null else Weather.Type.SUNNY


func _apply(weather: Weather.Type) -> void:
	_rain.emitting = weather == Weather.Type.RAINY or weather == Weather.Type.STORMY
	_rain.amount = 360 if weather == Weather.Type.STORMY else 260
	_snow.emitting = weather == Weather.Type.SNOWY
	_leaves.emitting = weather == Weather.Type.STORMY
	_update_sunburst(weather)


## 阳光只在晴天且白天出现；天黑之后由 [WorldLighting] 负责把画面压暗。
func _update_sunburst(weather: Weather.Type) -> void:
	_sunburst.visible = (
		weather == Weather.Type.SUNNY
		and _clock != null
		and DayNight.sun_visible(_clock.minute_of_day)
	)
