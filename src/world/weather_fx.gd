class_name WeatherFx
extends Node2D
## 天气的"看得见的那一半"：粒子 + 画面色调。
##
## [WeatherSystem] 只负责"今天是雨天"这个事实，不碰任何渲染；
## 本节点订阅天气变化，把它翻译成雨丝 / 雪花 / 整体偏冷的色调。
## 两者互不认识，取消天气特效也不会影响任何模拟逻辑。
##
## 由 [WorldScene] 在每个世界场景里自动挂载，因此农场与小镇都有天气。
## 节点每帧跟随相机（粒子发射盒只覆盖一屏，不跟随就会出现"走到地图右边就没雨了"）。

## 每种天气的画面色调（用 [CanvasModulate] 整体染色，不会影响 CanvasLayer 上的 UI）。
const TINTS := {
	Weather.Type.SUNNY: Color(1.0, 1.0, 1.0),
	Weather.Type.CLOUDY: Color(0.88, 0.9, 0.95),
	Weather.Type.RAINY: Color(0.7, 0.76, 0.88),
	Weather.Type.STORMY: Color(0.54, 0.6, 0.76),
	Weather.Type.SNOWY: Color(0.93, 0.95, 1.0),
}

const RAIN_TEXTURE: Texture2D = preload("res://assets/sprites/weather/rain_drop.png")
const SNOW_TEXTURE: Texture2D = preload("res://assets/sprites/weather/snow_flake.png")
const LEAF_TEXTURE: Texture2D = preload("res://assets/sprites/weather/leaf.png")
const SUN_TEXTURE: Texture2D = preload("res://assets/sprites/weather/sunburst.png")

## 粒子发射盒的半宽 / 半高：比 640×360 的视口大一圈，转身时不会有空缺。
const EMIT_EXTENTS := Vector3(380.0, 220.0, 0.0)

## 色调过渡时长（秒）。
const TINT_FADE: float = 1.2

var _tint: CanvasModulate
var _rain: GPUParticles2D
var _snow: GPUParticles2D
var _leaves: GPUParticles2D
var _sunburst: Sprite2D
var _tint_tween: Tween
var _flash_timer: Timer


func _ready() -> void:
	z_index = 90
	_build()
	EventBus.weather_changed.connect(_on_weather_changed)
	_apply(WeatherSystem.current, true)


func _exit_tree() -> void:
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)


func _process(_delta: float) -> void:
	# 跟随相机中心：粒子盒只需要覆盖一屏。
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		global_position = camera.get_screen_center_position()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	_tint = CanvasModulate.new()
	_tint.name = "Tint"
	_tint.color = TINTS[Weather.Type.SUNNY]
	add_child(_tint)

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

	# 雷暴的闪光：定时把色调推到白，再滑回来。
	_flash_timer = Timer.new()
	_flash_timer.name = "Flash"
	_flash_timer.wait_time = 4.0
	_flash_timer.one_shot = false
	_flash_timer.timeout.connect(_flash)
	add_child(_flash_timer)


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
	_apply(weather, false)


func _apply(weather: Weather.Type, immediate: bool) -> void:
	var tint: Color = TINTS.get(weather, TINTS[Weather.Type.SUNNY])

	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()
	if immediate:
		_tint.color = tint
	else:
		_tint_tween = create_tween()
		_tint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tint_tween.tween_property(_tint, "color", tint, TINT_FADE)

	_rain.emitting = weather == Weather.Type.RAINY or weather == Weather.Type.STORMY
	_rain.amount = 360 if weather == Weather.Type.STORMY else 260
	_snow.emitting = weather == Weather.Type.SNOWY
	_leaves.emitting = weather == Weather.Type.STORMY
	_sunburst.visible = weather == Weather.Type.SUNNY

	_flash_timer.stop()
	if weather == Weather.Type.STORMY:
		_flash_timer.start(2.5)


## 雷暴的瞬间闪光：把整体色调推白一帧再收回。
func _flash() -> void:
	if _tint == null:
		return
	var tween := create_tween()
	tween.tween_property(_tint, "color", Color(1.6, 1.6, 1.7), 0.06)
	tween.tween_property(_tint, "color", TINTS[Weather.Type.STORMY], 0.35)
