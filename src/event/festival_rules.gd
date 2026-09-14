class_name FestivalRules
extends RefCounted
## 节日的纯静态规则：哪天办、开了没、下次还有几天。
##
## 不引用任何 autoload（自己带常量），只吃 [GameDate] 与 [FestivalData]，
## 因此可以脱离场景树直接单测——和 [CropGrowth] / [AffectionRules] 同一层。

## 每小时的分钟数。
const MINUTES_PER_HOUR: int = 60
## 每天的分钟数。
const MINUTES_PER_DAY: int = 1440


## 某天（[param date]）要办的节日，按 id 排序保证输出稳定。
static func on_date(festivals: Array[FestivalData], date: GameDate) -> Array[FestivalData]:
	var result: Array[FestivalData] = []
	if date == null:
		return result
	for festival: FestivalData in festivals:
		if festival == null:
			continue
		if festival.season == date.season and festival.day == date.day:
			result.append(festival)
	result.sort_custom(func(a: FestivalData, b: FestivalData) -> bool:
		return String(a.id) < String(b.id)
	)
	return result


## 会场在 [param minute_of_day] 时刻是否开放。
##
## [member FestivalData.end_hour] 不大于 [member FestivalData.start_hour] 时表示全天开放，
## 这样"整天的祭典"不需要写 00:00–24:00。
static func is_within(festival: FestivalData, minute_of_day: int) -> bool:
	if festival == null:
		return false
	var start: int = clampi(festival.start_hour, 0, 23) * MINUTES_PER_HOUR
	var end: int = clampi(festival.end_hour, 0, 24) * MINUTES_PER_HOUR
	if end <= start:
		return true
	var now: int = wrapi(minute_of_day, 0, MINUTES_PER_DAY)
	return now >= start and now < end


## 从 [param from_date] 当天算起，下一次该节日还有几天（0 表示就是今天）。
## 一年之内找不到时返回 -1。
static func days_until(festival: FestivalData, from_date: GameDate) -> int:
	if festival == null or from_date == null:
		return -1
	for offset: int in GameDate.DAYS_PER_YEAR:
		var date := GameDate.from_absolute_day(from_date.absolute_day() + offset)
		if date.season == festival.season and date.day == festival.day:
			return offset
	return -1
