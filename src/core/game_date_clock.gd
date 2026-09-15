class_name GameDateClock
extends Resource
## 游戏日期与时间状态（Resource）。
##
## 只存放可序列化的时钟状态：日期、当天分钟、时间倍率、暂停标记。
## 推进规则与 [code]_process[/code] 仍由 [GameClock] 服务执行；本资源不依赖
## 场景树 / Autoload，可以由 [Main] 持有或在测试里单独 new 一份干净实例。

## 每天的小时数。
const HOURS_PER_DAY: int = 24
## 每小时的分钟数。
const MINUTES_PER_HOUR: int = 60
## 每天的分钟数。
const MINUTES_PER_DAY: int = HOURS_PER_DAY * MINUTES_PER_HOUR
## 一天开始的时刻（06:00）。
const DAY_START_HOUR: int = 6

## 当前日期。
var date: GameDate
## 当天已过的分钟数（0..1439，真实时钟语义）。
var minute_of_day: int = DAY_START_HOUR * MINUTES_PER_HOUR
## 时间倍率；>1 加速，<1 减速。
var time_scale: float = 1.0
## 暂停时间推进。
var paused: bool = false


func _init() -> void:
	reset()


## 复位到第 1 年 春 1 日 06:00。
func reset() -> void:
	date = GameDate.new(1, Season.Type.SPRING, 1)
	minute_of_day = DAY_START_HOUR * MINUTES_PER_HOUR


func to_dict() -> Dictionary:
	return {
		"date": date.to_dict() if date != null else {},
		"minute_of_day": minute_of_day,
	}


func from_dict(data: Dictionary) -> void:
	var raw_date: Variant = data.get("date", {})
	date = GameDate.from_dict(raw_date if raw_date is Dictionary else {})
	minute_of_day = clampi(
		int(data.get("minute_of_day", DAY_START_HOUR * MINUTES_PER_HOUR)),
		0,
		MINUTES_PER_DAY - 1
	)
