extends Node
## 游戏时钟（Autoload：`GameClock`）。
##
## 牧场物语类游戏的"心跳"：一天从 06:00 开始，到次日 02:00 强制结束，
## 时间推进会依次驱动天气抽取、作物生长、体力恢复等系统。
##
## [b]确定性日结转[/b]
## 关键模拟逻辑不用信号驱动（信号回调顺序不作保证），而是注册到有序的
## "日结转钩子"列表中，按注册顺序同步执行：
## [codeblock]
## 1. WeatherSystem  掷出当天天气
## 2. FarmGrid       作物生长 / 枯死 / 浇水标记重置
## 3. Player         恢复体力
## [/codeblock]
## 钩子跑完之后才发出 [signal EventBus.day_changed]，供 UI 等观察者使用。

## 每小时的分钟数。
const MINUTES_PER_HOUR: int = 60
## 每天的小时数。
const HOURS_PER_DAY: int = 24
## 每天的分钟数。
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY
## 一天开始的时刻（06:00）。
const DAY_START_HOUR: int = 6
## 跨天的时刻（次日 02:00）。
const DAY_ROLLOVER_HOUR: int = 2
## 单帧内最多推进的游戏分钟数，避免倍速过高时卡死主线程。
const MAX_STEPS_PER_FRAME: int = 240

## 现实秒 / 游戏分钟（time_scale = 1 时）。
@export_range(0.05, 5.0, 0.05) var seconds_per_game_minute: float = 0.7

## 时间倍率；>1 加速，<1 减速。睡觉等演出可临时调高。
var time_scale: float:
	get:
		return _state.time_scale

## 暂停时间推进（打开菜单 / 对话 / 场景切换时）。
var paused: bool:
	get:
		return _state.paused

## 当前日期。
var date: GameDate:
	get:
		return _state.date

## 当天已过的分钟数（0..1439，真实时钟语义）。
var minute_of_day: int:
	get:
		return _state.minute_of_day

var _state: GameDateClock = GameDateClock.new()
var _accumulator: float = 0.0
var _day_hooks: Array[Callable] = []


func _ready() -> void:
	Persistence.register_core(self, &"GameClock", 10)
	reset()


## 当前时钟状态；由组合根持有，可整体替换。
func state() -> GameDateClock:
	return _state


## 换入时钟状态；传 null 会创建一份新的默认状态。
func set_state(value: GameDateClock) -> void:
	_state = value if value != null else GameDateClock.new()
	_accumulator = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	var step: float = seconds_per_game_minute / maxf(time_scale, 0.01)
	if step <= 0.0:
		return
	_accumulator += delta
	var steps: int = 0
	while _accumulator >= step and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= step
		_advance_one_minute()
		steps += 1
	if steps >= MAX_STEPS_PER_FRAME:
		# 丢帧太多时直接丢弃余量，避免时间越欠越多。
		_accumulator = 0.0


# ---------------------------------------------------------------- 查询

## 当前小时（0..23）。
func hour() -> int:
	return _state.minute_of_day / MINUTES_PER_HOUR


## 当前分钟（0..59）。
func minute() -> int:
	return _state.minute_of_day % MINUTES_PER_HOUR


## 自当天 06:00 起经过的分钟数（0..1199）。用于"今天还剩多久"这类判断。
func minutes_since_day_start() -> int:
	var start: int = DAY_START_HOUR * MINUTES_PER_HOUR
	var now: int = _state.minute_of_day
	if now < start:
		now += MINUTES_PER_DAY
	return now - start


## 是否已过午夜（用于"熬夜"惩罚 / 商店关门判定）。
func is_past_midnight() -> bool:
	return _state.minute_of_day < DAY_ROLLOVER_HOUR * MINUTES_PER_HOUR


## 形如 "06:30" 的时钟文本。
func time_string() -> String:
	return "%02d:%02d" % [hour(), minute()]


## 形如 "第 1 年 春 3 日" 的键值组合由 UI 拼装，这里只给出分量。
func date_string() -> String:
	return "%d年 %s %d日" % [_state.date.year, Season.to_key(_state.date.season), _state.date.day]


# ---------------------------------------------------------------- 控制

## 设置时间倍率（下限 0.01，避免除零）。
func set_time_scale(value: float) -> void:
	_state.time_scale = maxf(value, 0.01)


## 设置暂停状态；外部不得直接写 [member paused]。
func set_paused(value: bool) -> void:
	_state.paused = value


## 设置当前日期（读档 / 测试用）。
func set_date(value: GameDate) -> void:
	_state.date = value if value != null else GameDate.new(1, Season.Type.SPRING, 1)


## 复位到游戏开局：第 1 年 春 1 日 06:00。不会发出任何信号。
func reset() -> void:
	_state.date = GameDate.new(1, Season.Type.SPRING, 1)
	_state.minute_of_day = DAY_START_HOUR * MINUTES_PER_HOUR
	_accumulator = 0.0


## 注册日结转钩子。同一个 [Callable] 只会注册一次。
func register_day_hook(callback: Callable) -> void:
	if not _day_hooks.has(callback):
		_day_hooks.append(callback)


## 注销日结转钩子（节点退出场景树时调用，避免野指针）。
func unregister_day_hook(callback: Callable) -> void:
	_day_hooks.erase(callback)


## 直接设置时间（同一天内）。
func set_time(hour_value: int, minute_value: int) -> void:
	_state.minute_of_day = wrapi(
		clampi(hour_value, 0, HOURS_PER_DAY - 1) * MINUTES_PER_HOUR
			+ clampi(minute_value, 0, MINUTES_PER_HOUR - 1),
		0,
		MINUTES_PER_DAY
	)
	_accumulator = 0.0
	EventBus.minute_changed.emit(hour(), minute())


## 立即推进 [param count] 个游戏分钟，跨天时会走完整的日结转流程。
func advance_minutes(count: int) -> void:
	for _i: int in maxi(count, 0):
		_advance_one_minute()


## 睡到第二天早上 06:00，触发一次日结转。
func sleep_until_morning() -> void:
	_state.minute_of_day = DAY_START_HOUR * MINUTES_PER_HOUR
	_accumulator = 0.0
	_roll_over_day()
	EventBus.minute_changed.emit(hour(), minute())


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"date": _state.date.to_dict(),
		"minute_of_day": _state.minute_of_day,
		"seconds_per_game_minute": seconds_per_game_minute,
	}


func from_dict(data: Dictionary) -> void:
	var raw_date: Variant = data.get("date", {})
	_state.date = GameDate.from_dict(raw_date if raw_date is Dictionary else {})
	_state.minute_of_day = clampi(
		int(data.get("minute_of_day", DAY_START_HOUR * MINUTES_PER_HOUR)),
		0,
		MINUTES_PER_DAY - 1
	)
	seconds_per_game_minute = maxf(
		float(data.get("seconds_per_game_minute", seconds_per_game_minute)), 0.05
	)
	_accumulator = 0.0
	_refresh_observers()


# ---------------------------------------------------------------- 内部

func _advance_one_minute() -> void:
	_state.minute_of_day = (_state.minute_of_day + 1) % MINUTES_PER_DAY
	EventBus.minute_changed.emit(hour(), minute())
	if minute() == 0:
		EventBus.hour_changed.emit(hour())
	if _state.minute_of_day == DAY_ROLLOVER_HOUR * MINUTES_PER_HOUR:
		_roll_over_day()


func _roll_over_day() -> void:
	var crossed: Dictionary = _state.date.advance_day()
	_accumulator = 0.0
	if bool(crossed.get(&"year", false)):
		EventBus.year_changed.emit(_state.date.year)
	if bool(crossed.get(&"season", false)):
		EventBus.season_changed.emit(_state.date.season)

	# 有序执行模拟流水线，顺序即依赖顺序。
	for hook: Callable in _day_hooks.duplicate():
		if hook.is_valid():
			hook.call(_state.date)

	# 钩子跑完后再通知观察者（UI 等）。
	EventBus.day_changed.emit(_state.date)


func _refresh_observers() -> void:
	EventBus.minute_changed.emit(hour(), minute())
	EventBus.hour_changed.emit(hour())
	EventBus.day_changed.emit(_state.date)
	EventBus.season_changed.emit(_state.date.season)
	EventBus.year_changed.emit(_state.date.year)
