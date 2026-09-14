class_name GameDate
extends RefCounted
## 游戏内日期值对象：年 / 季 / 日。
##
## 只负责日期算术与序列化，不知道"现在几点"，那是 [GameClock] 的职责。
## 这样日期推进逻辑可以脱离场景树单独做单元测试。

## 每年包含的天数。
const DAYS_PER_YEAR: int = Season.DAYS_PER_SEASON * Season.COUNT

var year: int
var season: Season.Type
var day: int


func _init(p_year: int = 1, p_season: Season.Type = Season.Type.SPRING, p_day: int = 1) -> void:
	year = maxi(p_year, 1)
	season = p_season
	day = clampi(p_day, 1, Season.DAYS_PER_SEASON)


## 推进一天，自动处理季节与年份进位。
##
## 返回值描述"这一跳跨越了哪些边界"，方便上层决定发出哪些信号。
func advance_day() -> Dictionary:
	var crossed := {
		&"season": false,
		&"year": false,
	}
	day += 1
	if day > Season.DAYS_PER_SEASON:
		day = 1
		season = Season.next(season)
		crossed[&"season"] = true
		if season == Season.Type.SPRING:
			year += 1
			crossed[&"year"] = true
	return crossed


## 本年在当前季节之前的累计天数（0 起算），用于"第几天"这类统计。
func day_of_year() -> int:
	return int(season) * Season.DAYS_PER_SEASON + (day - 1)


## 自游戏开始以来的绝对天数（0 起算）。
func absolute_day() -> int:
	return (year - 1) * DAYS_PER_YEAR + day_of_year()


## 两个日期相隔的天数（[param other] 晚于自身时为正）。
func days_until(other: GameDate) -> int:
	return other.absolute_day() - absolute_day()


## [method absolute_day] 的逆运算：把"自游戏开始以来的第几天"还原成日期。
##
## 用于"世界在你离开的这几天里也在生长"这类补算：只知道过了几天，
## 但需要按天分别拿到当时的季节。
static func from_absolute_day(value: int) -> GameDate:
	var total: int = maxi(value, 0)
	var year: int = total / DAYS_PER_YEAR + 1
	var day_of_year: int = total % DAYS_PER_YEAR
	return GameDate.new(
		year,
		Season.from_index(day_of_year / Season.DAYS_PER_SEASON),
		day_of_year % Season.DAYS_PER_SEASON + 1,
	)


## 值相等比较；[code]==[/code] 对 RefCounted 比较的是引用，这里需要显式方法。
func equals(other: GameDate) -> bool:
	if other == null:
		return false
	return year == other.year and season == other.season and day == other.day


func duplicate_date() -> GameDate:
	return GameDate.new(year, season, day)


func to_dict() -> Dictionary:
	return {
		"year": year,
		"season": Season.to_key(season),
		"day": day,
	}


static func from_dict(data: Dictionary) -> GameDate:
	return GameDate.new(
		int(data.get("year", 1)),
		Season.from_key(str(data.get("season", "spring"))),
		int(data.get("day", 1)),
	)


func _to_string() -> String:
	return "Y%d %s %d" % [year, Season.to_key(season), day]
