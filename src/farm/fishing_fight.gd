class_name FishingFight
extends RefCounted
## 拉扯小游戏：收线拉锯的纯状态机。
##
## 一根竖直的「深度轴」（[constant DEPTH_MIN] = 水面，[constant DEPTH_MAX] = 水底）：
## 鱼在轴上按随机目标点游走，钩子松开收线键时受重力下沉、按住时上浮。
## 钩子压在鱼身上（距离不超过 [method zone_half]）→ 上钩进度上涨、鱼线放松；
## 脱开 → 进度回退、张力飙升。进度满 = 上岸，进度归零或张力拉满 = 断线跑鱼。
##
## 与 [FishingRules] 一致：[Node] 一个都不碰、随机源由调用方注入，
## 因此整场拉锯可以脱离场景树复现；[PlayerStateFishing] 只负责喂输入与演出。
##
## 难度来自 [member FishData.difficulty]（鱼更快、判定区更窄），
## 缓解来自 [member ToolData.tier]（判定区更宽、鱼稍慢），
## 于是"升级钓竿"与"挑战稀有鱼"都能在数值上被感觉到。

## 一场拉锯的结果。
enum Status {
	FIGHTING,  ## 还在拉锯
	LANDED,    ## 成功上岸
	ESCAPED,   ## 断线 / 脱钩
}

## 深度轴两端：0 = 水面（上），1 = 水底（下）。
const DEPTH_MIN: float = 0.0
const DEPTH_MAX: float = 1.0

## 钩子运动：按住收线时上浮速度、松开时下沉速度、速度变化率（每秒）。
const HOOK_REEL_SPEED: float = 1.15
const HOOK_SINK_SPEED: float = 0.9
const HOOK_ACCEL: float = 7.0

## 鱼的基础游动速度；难度越高越快，钓竿越好越慢。
const FISH_SPEED_BASE: float = 0.30
const FISH_SPEED_PER_DIFFICULTY: float = 0.075
const FISH_SPEED_PER_TIER: float = 0.02
const FISH_SPEED_MIN: float = 0.08
## 鱼两次换向之间的间隔（秒）。
const TURN_MIN: float = 0.35
const TURN_MAX: float = 1.15

## 判断区半高（深度单位）：钩子离鱼这么近才算压住了。
const ZONE_BASE: float = 0.17
const ZONE_PER_DIFFICULTY: float = 0.022
const ZONE_PER_TIER: float = 0.018
const ZONE_MIN: float = 0.07

## 上钩进度：起始值、压住时的涨幅、脱开时的回退。
const PROGRESS_START: float = 0.35
const PROGRESS_GAIN: float = 0.42
const PROGRESS_LOSS: float = 0.18

## 张力：起始值、脱开时的涨幅、压住时的回落。
const TENSION_START: float = 0.2
const TENSION_GAIN: float = 0.42
const TENSION_RELIEF: float = 0.5

var _fish_pos: float = 0.5
var _hook_pos: float = DEPTH_MIN
var _hook_velocity: float = 0.0
var _fish_target: float = 0.5
var _turn_timer: float = 0.0
var _fish_speed: float = FISH_SPEED_BASE
var _zone_half: float = ZONE_BASE
var _progress: float = PROGRESS_START
var _tension: float = TENSION_START
var _elapsed: float = 0.0
var _status: Status = Status.FIGHTING
var _rng: RandomNumberGenerator


## 为一条鱼开一场拉锯。[param tier] 为钓竿等级，[param rng] 可为 null（测试里可直接摆位）。
func _init(fish: FishData, tier: int = 0, rng: RandomNumberGenerator = null) -> void:
	_rng = rng
	var difficulty: int = clampi(fish.difficulty if fish != null else 1, 1, 5)
	var rod: int = maxi(tier, 0)
	_fish_speed = maxf(
		FISH_SPEED_BASE
			+ FISH_SPEED_PER_DIFFICULTY * float(difficulty - 1)
			- FISH_SPEED_PER_TIER * float(rod),
		FISH_SPEED_MIN
	)
	_zone_half = maxf(
		ZONE_BASE - ZONE_PER_DIFFICULTY * float(difficulty - 1) + ZONE_PER_TIER * float(rod),
		ZONE_MIN
	)
	_fish_pos = clampf(_random(), 0.15, 0.85)
	_hook_pos = DEPTH_MIN
	_pick_target()


## 推进一步；[param reeling] 表示玩家此刻是否按住收线键。
##
## 返回推进之后的状态，调用方据此决定"继续演 / 收杆 / 跑鱼"。
func step(delta: float, reeling: bool) -> Status:
	if _status != Status.FIGHTING:
		return _status
	_elapsed += delta
	_step_hook(delta, reeling)
	_step_fish(delta)

	if in_contact():
		_progress += PROGRESS_GAIN * delta
		_tension -= TENSION_RELIEF * delta
	else:
		_progress -= PROGRESS_LOSS * delta
		_tension += TENSION_GAIN * delta
	_progress = clampf(_progress, 0.0, 1.0)
	_tension = clampf(_tension, 0.0, 1.0)

	if _progress >= 1.0:
		_status = Status.LANDED
	elif _progress <= 0.0 or _tension >= 1.0:
		_status = Status.ESCAPED
	return _status


# ---------------------------------------------------------------- 只读状态

## 鱼在深度轴上的位置（0 = 水面）。
func fish_pos() -> float:
	return _fish_pos


## 钩子在深度轴上的位置（0 = 水面）。
func hook_pos() -> float:
	return _hook_pos


## 判断区半高（深度单位）。
func zone_half() -> float:
	return _zone_half


## 上钩进度（0 = 脱钩，1 = 上岸）。
func progress() -> float:
	return _progress


## 鱼线张力（1 = 断线）。
func tension() -> float:
	return _tension


## 当前状态。
func status() -> Status:
	return _status


## 这场拉锯已经持续了多久（秒）。
func elapsed() -> float:
	return _elapsed


## 钩子此刻是否压在鱼身上。
func in_contact() -> bool:
	return absf(_hook_pos - _fish_pos) <= _zone_half


# ---------------------------------------------------------------- 内部

func _step_hook(delta: float, reeling: bool) -> void:
	var target_speed: float = -HOOK_REEL_SPEED if reeling else HOOK_SINK_SPEED
	_hook_velocity = move_toward(_hook_velocity, target_speed, HOOK_ACCEL * delta)
	_hook_pos = clampf(_hook_pos + _hook_velocity * delta, DEPTH_MIN, DEPTH_MAX)
	if is_equal_approx(_hook_pos, DEPTH_MIN) or is_equal_approx(_hook_pos, DEPTH_MAX):
		# 顶到端点就停住，避免"贴着边界还攒速度"导致松手后猛地弹开。
		_hook_velocity = 0.0


func _step_fish(delta: float) -> void:
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_pick_target()
	_fish_pos = move_toward(_fish_pos, _fish_target, _fish_speed * delta)


func _pick_target() -> void:
	_fish_target = _random()
	_turn_timer = _random_range(TURN_MIN, TURN_MAX)


func _random() -> float:
	return _rng.randf() if _rng != null else 0.5


func _random_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to) if _rng != null else (from + to) * 0.5
