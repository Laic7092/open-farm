@tool
class_name EventData
extends Resource
## 一次性事件（镇上发生的事）的静态定义。
##
## 事件在日结转时判定：条件全部命中且本局还没发生过，就执行一次效果
## （打旗标 / 给钱 / 弹提示 / 播一段对白）。
## 条件判定放在纯静态的 [EventRules] 里，本类只描述数据。

## 唯一标识。
@export var id: StringName = &""
## 标题翻译键。
@export var title_key: StringName = &""
## 触发时的提示文案键；留空则退回 [member title_key]。
@export var message_key: StringName = &""
## 限定季节（[enum Season.Type] 数值）；-1 表示任意季节。
@export_range(-1, 3) var season: int = -1
## 限定日期（1..28）；-1 表示任意日期。
@export_range(-1, 28) var day: int = -1
## 限定天气（[enum Weather.Type] 数值）；-1 表示任意天气。
@export_range(-1, 4) var weather: int = -1
## 需要玩家已有该旗标（可空）。
@export var required_flag: StringName = &""
## 玩家已有该旗标时不再触发（可空）。
@export var forbidden_flag: StringName = &""
## 好感度条件：对 [member required_npc] 的好感至少达到该值；0 表示不要求。
@export_range(0, 255) var required_affection: int = 0
## 好感度条件对应的 NPC（可空）。
@export var required_npc: StringName = &""
## 触发后给玩家的钱。
@export var grant_money: int = 0
## 触发后打上的旗标（可空）。
@export var set_flag: StringName = &""
## 触发时播放的对白（可空）。
@export var dialogue: DialogueData
## true 表示本局只发生一次；false 表示每个游戏年都能再发生一次。
@export var once: bool = true


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if title_key == &"":
		problems.append("title_key 不能为空")
	if season < -1 or season > Season.COUNT - 1:
		problems.append("season 应在 -1..%d（实际 %d）" % [Season.COUNT - 1, season])
	if day < -1 or day > Season.DAYS_PER_SEASON:
		problems.append("day 应在 -1..%d（实际 %d）" % [Season.DAYS_PER_SEASON, day])
	if weather < -1 or weather > Weather.COUNT - 1:
		problems.append("weather 应在 -1..%d（实际 %d）" % [Weather.COUNT - 1, weather])
	if required_affection > 0 and required_npc == &"":
		problems.append("设置了好感门槛就必须指定 required_npc")
	if grant_money < 0:
		problems.append("grant_money 不能为负")
	if dialogue != null and dialogue.is_empty():
		problems.append("dialogue 不能是空对白")
	return problems


func _to_string() -> String:
	return "EventData(%s)" % id
