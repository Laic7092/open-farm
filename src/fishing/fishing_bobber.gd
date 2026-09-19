class_name FishingBobber
extends Node2D
## 水面浮标与鱼线：抛竿飞行、落水漂浮、咬钩抖动、拉扯绷线、收线飞回。
##
## 它是 [Player] 的子节点但 [member top_level] = true，因此不跟着角色走，
## 而是被钓鱼状态摆到落点格上。所有运动都由 [FishingRules] 的纯函数
## （[method FishingRules.cast_arc] / [method FishingRules.line_curve]）算出来，
## 本节点只负责把结果画到 [Sprite2D] 与 [Line2D] 上——
## 因此不需要 [RigidBody2D] / [PinJoint2D] 那一整套物理，也天然可复现。
##
## 鱼线是一根 8 段的 [Line2D]：中点下垂（[member _slack]）、张力越高越绷直并抖得越厉害，
## 收线时随浮标一起缩回竿尖。颜色取 [constant ArtPalette.FISHING_LINE]，与调色板同源。

const BOBBER_TEXTURE: String = "res://assets/sprites/props/bobber.png"
const RIPPLE_TEXTURE: String = "res://assets/sprites/props/ripple.png"

## 浮标从竿尖飞到落点所需时长（秒）；与钓鱼状态的抛竿动作时长对齐。
const FLIGHT_TIME: float = 0.3
## 收线飞回竿尖的时长（秒）。
const REEL_TIME: float = 0.22
## 等鱼时的上下浮动：振幅（像素）与频率。
const BOB_AMPLITUDE: float = 1.5
const BOB_SPEED: float = 3.2
## 水圈脉动频率。
const PULSE_SPEED: float = 1.7
## 落水水花的扩散时长（秒）。
const SPLASH_TIME: float = 0.45

## 鱼线下垂量：按线长比例下垂（短抛不夸张、长抛看得见），张力越高越绷直。
## [constant SLACK_RATIO] 是下垂量占线长的比例，[constant SLACK_MAX] 是上限像素。
const SLACK_RATIO: float = 0.16
const SLACK_MAX: float = 10.0
const SLACK_MIN: float = 2.0
## 绷紧时的下垂量（像素）。
const SLACK_TAUT: float = 1.5
## 飞行中最多允许的下垂量（像素）。
const SLACK_FLY: float = 3.0
## 张力拉满时把浮标往玩家方向拽多远（像素）。
const FIGHT_PULL: float = 3.0
## 抖动幅度每秒衰减量。
const SHAKE_DECAY: float = 5.0

enum Mode { IDLE, FLYING, FLOATING, FIGHTING, REELING }

var _bobber: Sprite2D
var _ripple: Sprite2D
var _line: Line2D
var _mode: Mode = Mode.IDLE
var _elapsed: float = 0.0

var _rod_tip: Vector2 = Vector2.ZERO
var _cast_from: Vector2 = Vector2.ZERO
var _cast_to: Vector2 = Vector2.ZERO
var _cast_power: float = 0.0
var _flight_t: float = 0.0
var _reel_from: Vector2 = Vector2.ZERO
var _reel_t: float = 0.0

## 抖动幅度（像素）与拉扯张力（0~1）。
var _shake: float = 0.0
var _tension: float = 0.0
## 落水水花进度：1 = 刚落下，0 = 已经完全散开。
var _splash: float = 0.0


func _ready() -> void:
	_ripple = Sprite2D.new()
	_ripple.name = "Ripple"
	_ripple.texture = _load_texture(RIPPLE_TEXTURE)
	add_child(_ripple)

	_line = Line2D.new()
	_line.name = "Line"
	_line.width = 1.0
	_line.default_color = ArtPalette.FISHING_LINE
	_line.antialiased = false
	var gradient := Gradient.new()
	gradient.set_color(0, ArtPalette.FISHING_LINE)
	gradient.set_color(1, Color(ArtPalette.FISHING_LINE, 0.45))
	_line.gradient = gradient
	add_child(_line)

	_bobber = Sprite2D.new()
	_bobber.name = "Bobber"
	_bobber.texture = _load_texture(BOBBER_TEXTURE)
	_bobber.z_index = 1
	add_child(_bobber)

	visible = false
	set_process(false)


## 从竿尖 [param from] 抛到落点 [param to]；[param power] 决定弧线高度。
func cast_to(from: Vector2, to: Vector2, power: float) -> void:
	_mode = Mode.FLYING
	_elapsed = 0.0
	_flight_t = 0.0
	_rod_tip = from
	_cast_from = from
	_cast_to = to
	_cast_power = clampf(power, 0.0, 1.0)
	_shake = 0.0
	_tension = 0.0
	_splash = 0.0
	global_position = from
	_bobber.modulate = Color.WHITE
	_ripple.modulate = Color(1, 1, 1, 0)
	visible = true
	set_process(true)


## 咬钩：浮标猛抖一下。
func bite() -> void:
	if _mode == Mode.IDLE:
		return
	_shake = 3.5


## 进入 / 退出拉扯：进入后浮标会被张力往玩家方向拽。
func set_fight(active: bool) -> void:
	if active:
		_mode = Mode.FIGHTING
	elif _mode == Mode.FIGHTING:
		_mode = Mode.FLOATING


## 更新拉扯张力（0~1）；由钓鱼状态每步喂进来。
func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)


## 收线：浮标（连同鱼线）飞回竿尖后隐藏。
func reel_in() -> void:
	if _mode == Mode.IDLE or _mode == Mode.REELING:
		return
	_mode = Mode.REELING
	_reel_from = global_position
	_reel_t = 0.0
	_tension = 0.0
	_bobber.modulate = Color.WHITE


func _process(delta: float) -> void:
	_elapsed += delta
	_shake = maxf(_shake - delta * SHAKE_DECAY, 0.0)
	_splash = maxf(_splash - delta / SPLASH_TIME, 0.0)

	match _mode:
		Mode.FLYING:
			_step_flying(delta)
		Mode.FLOATING:
			_step_floating()
		Mode.FIGHTING:
			_step_fighting()
		Mode.REELING:
			_step_reeling(delta)

	if _mode != Mode.IDLE:
		_update_line()
	_update_ripple()


# ---------------------------------------------------------------- 各阶段

func _step_flying(delta: float) -> void:
	_flight_t += delta / FLIGHT_TIME
	global_position = FishingRules.cast_arc(_cast_from, _cast_to, _cast_power, _flight_t)
	if _flight_t >= 1.0:
		global_position = _cast_to
		_enter_water()


func _enter_water() -> void:
	_mode = Mode.FLOATING
	_splash = 1.0
	_shake = 2.0


func _step_floating() -> void:
	var bob := Vector2(0.0, sin(_elapsed * BOB_SPEED) * BOB_AMPLITUDE)
	global_position = _cast_to + bob + _jitter()


func _step_fighting() -> void:
	var toward := _rod_tip - _cast_to
	var direction := toward.normalized() if toward.length() > 0.001 else Vector2.ZERO
	global_position = _cast_to + direction * (_tension * FIGHT_PULL) \
		+ Vector2(sin(_elapsed * 43.0), sin(_elapsed * 57.0)) * (0.5 + _tension * 2.5)
	_bobber.modulate = Color.WHITE.lerp(Color(1.0, 0.62, 0.62), _tension)


func _step_reeling(delta: float) -> void:
	_reel_t = minf(_reel_t + delta / REEL_TIME, 1.0)
	global_position = _reel_from.lerp(_rod_tip, _reel_t)
	if _reel_t >= 1.0:
		_hide()


func _jitter() -> Vector2:
	if _shake <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_elapsed * 31.0), sin(_elapsed * 47.0)) * _shake


# ---------------------------------------------------------------- 鱼线 / 水花

func _update_line() -> void:
	var from := _rod_tip - global_position
	_line.points = FishingRules.line_curve(
		from, Vector2.ZERO, _slack(), FishingRules.LINE_SEGMENTS, _line_shake(), _elapsed
	)


## 鱼线下垂量：漂浮时松、张力越高越绷直；短抛少垂、长抛多垂。
func _slack() -> float:
	var length := (_rod_tip - global_position).length()
	var base: float = clampf(length * SLACK_RATIO, SLACK_MIN, SLACK_MAX)
	match _mode:
		Mode.FLOATING, Mode.FIGHTING:
			return lerpf(base, SLACK_TAUT, _tension)
		Mode.FLYING:
			return minf(base, SLACK_FLY)
		Mode.REELING:
			return SLACK_MIN
	return base


## 鱼线抖动：拉扯时随张力抖，咬钩时短促一抖。
func _line_shake() -> float:
	match _mode:
		Mode.FIGHTING:
			return 0.4 + _tension * 1.8
		Mode.FLOATING:
			return _shake * 0.5
		_:
			return 0.0


func _update_ripple() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * PULSE_SPEED)
	var float_scale: float = 0.85 + 0.25 * pulse
	var float_alpha: float = (0.35 + 0.4 * pulse) if _mode == Mode.FLOATING else 0.0
	# 落水水花：从 0.5 倍撑到 1.6 倍并淡出，和漂浮脉动取较大值。
	var splash_scale: float = 0.5 + (1.0 - _splash) * 1.1
	var splash_alpha: float = _splash * 0.8
	var scale: float = maxf(float_scale, splash_scale) if _splash > 0.0 else float_scale
	_ripple.scale = Vector2(scale, scale * 0.7)
	_ripple.modulate.a = maxf(float_alpha, splash_alpha)


func _hide() -> void:
	_mode = Mode.IDLE
	visible = false
	set_process(false)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("FishingBobber: 缺少贴图 %s（跑一次 ./tools/build_assets.sh）" % path)
		return null
	return load(path) as Texture2D
