class_name GameDateClock
extends Resource
## 游戏日期与时间状态（Resource），同时接管原 [GameDateClock] 的推进规则。
##
## 这个 Resource 既是可存档状态，也是本局时钟的唯一权威对象：日期、当天
## 分钟、倍率、暂停标记与推进累积器都在这里。日结转钩子拆到 [DayPipeline]，
## 由 [Main] 在 [method bind_dependencies] 阶段显式注册；场景节点注入同一份实例，
## 不再通过 Autoload 全局名访问。
##
## 资源本身不进入场景树，[Main] 每帧调用 [method tick] 驱动时间；所有观察者
## 通过资源信号或由 [Main] 转发后的 [EventBus] 信号收到变化通知。

## 一天已过的分钟数变化。
signal minute_changed(hour: int, minute: int)
## 整点变化。
signal hour_changed(hour: int)
## 跨天（含季节 / 年份进位）完成，[member day_pipeline] 已执行完毕。
signal day_changed(date: GameDate)
## 季节变化。
signal season_changed(season: Season.Type)
## 年份变化。
signal year_changed(year: int)

## 每小时的分钟数。
const MINUTES_PER_HOUR: int = 60
## 每天的小时数。
const HOURS_PER_DAY: int = 24
## 每天的分钟数。
const MINUTES_PER_DAY: int = HOURS_PER_DAY * MINUTES_PER_HOUR
## 一天开始的时刻（06:00）。
const DAY_START_HOUR: int = 6
## 跨天的时刻（次日 02:00）。
const DAY_ROLLOVER_HOUR: int = 2
## 单帧内最多推进的游戏分钟数，避免倍速过高时卡死主线程。
const MAX_STEPS_PER_FRAME: int = 240

## 现实秒 / 游戏分钟（time_scale = 1 时）。
@export_range(0.05, 5.0, 0.05) var seconds_per_game_minute: float = 0.7

## 当前日期。
var date: GameDate
## 当天已过的分钟数（0..1439，真实时钟语义）。
var minute_of_day: int = DAY_START_HOUR * MINUTES_PER_HOUR
## 时间倍率；>1 加速，<1 减速。
var time_scale: float = 1.0
## 暂停时间推进。
var paused: bool = false

var _accumulator: float = 0.0
## 日结转流水线：按显式优先级执行跨天钩子。
var day_pipeline: DayPipeline = DayPipeline.new()


func _init() -> void:
	reset()


# ---------------------------------------------------------------- 生命周期

## 每帧推进时间；由 [Main] 在组合根中调用。
func tick(delta: float) -> void:
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


## 复位到第 1 年 春 1 日 06:00。不会发出任何信号。
func reset() -> void:
	date = GameDate.new(1, Season.Type.SPRING, 1)
	minute_of_day = DAY_START_HOUR * MINUTES_PER_HOUR
	_accumulator = 0.0


# ---------------------------------------------------------------- 查询

## 当前小时（0..23）。
func hour() -> int:
	return minute_of_day / MINUTES_PER_HOUR


## 当前分钟（0..59）。
func minute() -> int:
	return minute_of_day % MINUTES_PER_HOUR


## 自当天 06:00 起经过的分钟数（0..1199）。
func minutes_since_day_start() -> int:
	var start: int = DAY_START_HOUR * MINUTES_PER_HOUR
	var now: int = minute_of_day
	if now < start:
		now += MINUTES_PER_DAY
	return now - start


## 是否已过午夜（用于"熬夜"惩罚 / 商店关门判定）。
func is_past_midnight() -> bool:
	return minute_of_day < DAY_ROLLOVER_HOUR * MINUTES_PER_HOUR


## 形如 "06:30" 的时钟文本。
func time_string() -> String:
	return "%02d:%02d" % [hour(), minute()]


## 形如 "第 1 年 春 3 日" 的键值组合由 UI 拼装，这里只给出分量。
func date_string() -> String:
	return "%d年 %s %d日" % [date.year, Season.to_key(date.season), date.day]


# ---------------------------------------------------------------- 控制

## 设置时间倍率（下限 0.01，避免除零）。
func set_time_scale(value: float) -> void:
	time_scale = maxf(value, 0.01)


## 设置暂停状态；外部不得直接写 [member paused]。
func set_paused(value: bool) -> void:
	paused = value


## 设置当前日期（读档 / 测试用）。
func set_date(value: GameDate) -> void:
	date = value if value != null else GameDate.new(1, Season.Type.SPRING, 1)


## 直接设置时间（同一天内）。
func set_time(hour_value: int, minute_value: int) -> void:
	minute_of_day = wrapi(
		clampi(hour_value, 0, HOURS_PER_DAY - 1) * MINUTES_PER_HOUR
			+ clampi(minute_value, 0, MINUTES_PER_HOUR - 1),
		0,
		MINUTES_PER_DAY
	)
	_accumulator = 0.0
	minute_changed.emit(hour(), minute())


## 立即推进 [param count] 个游戏分钟，跨天时会走完整的日结转流程。
func advance_minutes(count: int) -> void:
	for _i: int in maxi(count, 0):
		_advance_one_minute()


## 睡到第二天早上 06:00，触发一次日结转。
func sleep_until_morning() -> void:
	minute_of_day = DAY_START_HOUR * MINUTES_PER_HOUR
	_accumulator = 0.0
	_roll_over_day()
	minute_changed.emit(hour(), minute())


# ---------------------------------------------------------------- 日结转钩子

## 注册日结转钩子。同一个 [Callable] 只会注册一次；[param priority]
## 见 [DayPipeline] 的常量，数值越小越先执行。
func register_day_hook(callback: Callable, priority: int = DayPipeline.PRIORITY_DEFAULT) -> void:
	day_pipeline.register(callback, priority)


## 注销日结转钩子（节点退出场景树时调用，避免野指针）。
func unregister_day_hook(callback: Callable) -> void:
	day_pipeline.unregister(callback)


## 清空全部日结转钩子（测试 / 重建组合根时使用）。
func clear_day_hooks() -> void:
	day_pipeline.clear()


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"date": date.to_dict() if date != null else {},
		"minute_of_day": minute_of_day,
		"seconds_per_game_minute": seconds_per_game_minute,
	}


func from_dict(data: Dictionary) -> void:
	var raw_date: Variant = data.get("date", {})
	date = GameDate.from_dict(raw_date if raw_date is Dictionary else {})
	minute_of_day = clampi(
		int(data.get("minute_of_day", DAY_START_HOUR * MINUTES_PER_HOUR)),
		0,
		MINUTES_PER_DAY - 1
	)
	seconds_per_game_minute = maxf(
		float(data.get("seconds_per_game_minute", seconds_per_game_minute)), 0.05
	)
	_accumulator = 0.0
	refresh_observers()


## 广播一次完整状态；读档后由 [Main] 调用以刷新 UI / Audio。
func refresh_observers() -> void:
	minute_changed.emit(hour(), minute())
	hour_changed.emit(hour())
	day_changed.emit(date)
	season_changed.emit(date.season)
	year_changed.emit(date.year)


# ---------------------------------------------------------------- 内部

func _advance_one_minute() -> void:
	minute_of_day = (minute_of_day + 1) % MINUTES_PER_DAY
	minute_changed.emit(hour(), minute())
	if minute() == 0:
		hour_changed.emit(hour())
	if minute_of_day == DAY_ROLLOVER_HOUR * MINUTES_PER_HOUR:
		_roll_over_day()


func _roll_over_day() -> void:
	var crossed: Dictionary = date.advance_day()
	_accumulator = 0.0
	if bool(crossed.get(&"year", false)):
		year_changed.emit(date.year)
	if bool(crossed.get(&"season", false)):
		season_changed.emit(date.season)

	# 显式优先级的模拟流水线；依赖顺序不再由注册先后碰运气。
	day_pipeline.run(date)

	# 钩子跑完后再通知观察者（UI 等）。
	day_changed.emit(date)
