@tool
class_name VillageGoalData
extends Resource
## 长期村庄目标的一条（静态定义）。
##
## 与 [CommissionData] 的每日委托不同，村庄目标是[b]跨年累积[/b]的：
## 它不要求交付某件东西，而是读取玩家档案 / 图鉴 / 食谱的累计数字
## （出货件数、累计收入、图鉴发现数、学会的食谱数、参加过的节日数）。
## 判定在纯静态的 [VillageGoalRules] 里，领取进度在 [VillageGoalState]。
##
## [b]为什么用累计指标而不是"交 10 个萝卜"[/b]：长期目标要能容纳玩家自由选择
## 玩法——种地、钓鱼、挖矿都会出货，都会长图鉴；写成具体交付物反而会逼玩家
## 只做一件事。副作用是"目标本身不产生行为"，只做汇总与奖励。

## 统计口径。
enum Metric {
	SHIPPED,     ## 累计出货件数（[member PlayerProfile.total_shipped]）
	EARNED,      ## 累计赚到的钱（[member PlayerProfile.total_earned]）
	DISCOVERED,  ## 图鉴发现的道具种数（[MuseumState.discovered_count]）
	COOKED,      ## 学会的食谱数量（[CookingState.known_count]）
	FESTIVALS,   ## 参加过的节日种数（[CalendarProgress.attended]）
}

## 唯一标识。
@export var id: StringName = &""
## 标题翻译键。
@export var title_key: StringName = &""
## 说明翻译键（讲清要做什么）。
@export var description_key: StringName = &""
## 统计口径。
@export var metric: Metric = Metric.SHIPPED
## 达标所需数值。
@export_range(1, 999999) var target: int = 1
## 达标后的金钱奖励。
@export_range(0, 999999) var reward_money: int = 0
## 达标后写入的旗标（例如解锁一道食谱）；可空。
@export var reward_flag: StringName = &""
## 需要玩家先拥有该旗标（上一条目标完成后写入）；可空表示开局可见。
@export var required_flag: StringName = &""
## 展示顺序（越小越靠前）。
@export var order: int = 0


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if title_key == &"":
		problems.append("title_key 不能为空")
	if description_key == &"":
		problems.append("description_key 不能为空")
	if target < 1:
		problems.append("target 必须 >= 1")
	if reward_money < 0:
		problems.append("reward_money 不能为负")
	if reward_flag != &"" and reward_flag == required_flag:
		problems.append("reward_flag 与 required_flag 不能相同（目标会自锁）")
	return problems


func _to_string() -> String:
	return "VillageGoalData(%s, %s >= %d)" % [id, Metric.keys()[metric], target]
