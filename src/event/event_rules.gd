class_name EventRules
extends RefCounted
## 一次性事件的条件判定（纯静态）。
##
## 传入的都是"已经查好的事实"（日期 / 天气 / 旗标有无 / 好感度），
## 而不是 [GameState] 或 [WeatherSystem] 本体：这样规则层不依赖 autoload，
## 单元测试只要拼几个参数就能覆盖全部分支。


## [param event] 的条件是否全部命中。
##
## [param has_required_flag] / [param has_forbidden_flag] 由调用方用
## [GameState] 查好后传入；[param affection] 是 [member EventData.required_npc] 的好感度。
static func matches(
	event: EventData,
	date: GameDate,
	weather: int,
	has_required_flag: bool,
	has_forbidden_flag: bool,
	affection: int
) -> bool:
	if event == null or date == null:
		return false
	if event.season >= 0 and event.season != int(date.season):
		return false
	if event.day > 0 and event.day != date.day:
		return false
	if event.weather >= 0 and event.weather != weather:
		return false
	if event.required_flag != &"" and not has_required_flag:
		return false
	if event.forbidden_flag != &"" and has_forbidden_flag:
		return false
	if event.required_affection > 0 and affection < event.required_affection:
		return false
	return true
