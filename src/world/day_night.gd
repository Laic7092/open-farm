class_name DayNight
extends RefCounted
## 昼夜光照曲线（纯静态规则）。
##
## [WorldLighting] 把它翻译成画面上的两件事：
## [br]- [method ambient_color]：整张地图的 [CanvasModulate] 染色——白天纯白，
##   清晨偏暖、黄昏偏橙、夜里偏冷变暗；
## [br]- [method lamp_energy]：路灯 / 窗灯的亮度——黄昏渐亮、黎明渐灭。
##
## 与 [Weather] 一样只提供纯静态函数，不碰场景树，可以直接单测；
## 颜色不写在这里，全部来自 [ArtPalette]（"颜色只有一个事实来源"）。

## 一天的分钟数。
const MINUTES_PER_DAY: int = 24 * 60

## 环境光曲线的关键帧（分钟 → 颜色）。
##
## 关键帧之间线性插值；最后一帧跨过午夜与首帧相接，因此整条曲线没有跳变。
## 要调"几点钟看起来像几点"，只需要改这些关键帧。
const KEYS: Array[Dictionary] = [
	{"minute": 0, "color": ArtPalette.AMBIENT_NIGHT},       # 00:00 深夜
	{"minute": 300, "color": ArtPalette.AMBIENT_DAWN},      # 05:00 黎明前
	{"minute": 390, "color": ArtPalette.AMBIENT_MORNING},   # 06:30 日出
	{"minute": 480, "color": ArtPalette.AMBIENT_DAY},       # 08:00 白天
	{"minute": 990, "color": ArtPalette.AMBIENT_DAY},       # 16:30 白天
	{"minute": 1110, "color": ArtPalette.AMBIENT_EVENING},  # 18:30 日落
	{"minute": 1230, "color": ArtPalette.AMBIENT_DUSK},     # 20:30 暮色
	{"minute": 1380, "color": ArtPalette.AMBIENT_NIGHT},    # 23:00 深夜
]

## "夜晚"的边界：18:00 ~ 次日 06:00。夜晚 BGM 与路灯共用它。
const NIGHT_START_MINUTE: int = 18 * 60
const NIGHT_END_MINUTE: int = 6 * 60

## 路灯开始亮 / 全亮 / 开始灭 / 全灭的时刻。
const LAMP_ON_MINUTE: int = 17 * 60
const LAMP_FULL_MINUTE: int = 19 * 60
const LAMP_DIM_MINUTE: int = 5 * 60
const LAMP_OFF_MINUTE: int = 7 * 60


## 当前时刻的环境光颜色（用于 [CanvasModulate]）。
static func ambient_color(minute_of_day: int) -> Color:
	var minute := wrapi(minute_of_day, 0, MINUTES_PER_DAY)
	for index: int in KEYS.size():
		var current: Dictionary = KEYS[index]
		var following: Dictionary = KEYS[(index + 1) % KEYS.size()]
		var start: int = current["minute"]
		var end: int = following["minute"]
		if end <= start:
			# 最后一段跨过午夜，补满 1440 分钟。
			end += MINUTES_PER_DAY
		if minute < start or minute >= end:
			continue
		var weight := float(minute - start) / float(end - start)
		return (current["color"] as Color).lerp(following["color"] as Color, weight)
	return KEYS[0]["color"]


## 路灯 / 窗灯的亮度倍率（0 = 全灭，1 = 全亮）。
static func lamp_energy(minute_of_day: int) -> float:
	var minute := wrapi(minute_of_day, 0, MINUTES_PER_DAY)
	if minute >= LAMP_ON_MINUTE and minute < LAMP_FULL_MINUTE:
		# 17:00 ~ 19:00 渐亮。
		return inverse_lerp(float(LAMP_ON_MINUTE), float(LAMP_FULL_MINUTE), float(minute))
	if minute >= LAMP_OFF_MINUTE and minute < LAMP_ON_MINUTE:
		# 07:00 ~ 17:00 全灭。
		return 0.0
	if minute >= LAMP_DIM_MINUTE and minute < LAMP_OFF_MINUTE:
		# 05:00 ~ 07:00 渐灭。
		return 1.0 - inverse_lerp(float(LAMP_DIM_MINUTE), float(LAMP_OFF_MINUTE), float(minute))
	# 19:00 ~ 次日 05:00 全亮。
	return 1.0


## 是否处于夜晚（18:00 ~ 次日 06:00）。夜晚 BGM 也用它。
static func is_night(minute_of_day: int) -> bool:
	var minute := wrapi(minute_of_day, 0, MINUTES_PER_DAY)
	return minute >= NIGHT_START_MINUTE or minute < NIGHT_END_MINUTE


## 太阳是否应当出现在画面上（晴天右上的那圈阳光）。
static func sun_visible(minute_of_day: int) -> bool:
	return not is_night(minute_of_day)
