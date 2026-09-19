extends "res://tools/sample/sample_base.gd"
## goals：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 长期村庄目标是一条[b]链[/b]：每条用 required_flag 接住上一条的 reward_flag，
## 于是玩家必须按顺序推进（也让后面的目标在界面上显示为"尚未开启"）。
## 指标都是累计数字（出货 / 收入 / 图鉴 / 食谱 / 节日），不强制玩家做某一件事。
##
## 第三条与第五条的 reward_flag 正好是两条料理食谱的解锁旗标，
## 与 build_recipes.gd 的 required_flag 同名——这就是"目标推进玩法"的接口。

## (id, 标题/说明后缀, metric, target, reward_money, reward_flag, required_flag, order)
const GOALS: Array = [
	[&"village_paths", &"SHIPPED", 50, 800, &"goal_paths", &"", 1],
	[&"village_library", &"DISCOVERED", 20, 1000, &"goal_library", &"goal_paths", 2],
	[&"village_kitchen", &"COOKED", 5, 1200, &"recipe_pumpkin_pie", &"goal_library", 3],
	[&"village_market", &"EARNED", 5000, 2000, &"goal_market", &"recipe_pumpkin_pie", 4],
	[&"village_festivals", &"FESTIVALS", 4, 2500, &"recipe_tuna_sashimi", &"goal_market", 5],
]


func build() -> void:
	for entry: Array in GOALS:
		_goal(
			entry[0], entry[1], int(entry[2]), int(entry[3]),
			entry[4], entry[5], int(entry[6])
		)


func _goal(
	goal_id: StringName, metric_key: StringName, target: int, reward: int,
	reward_flag: StringName, required_flag: StringName, order: int
) -> void:
	var goal := VillageGoalData.new()
	goal.id = goal_id
	goal.title_key = StringName("GOAL_%s_TITLE" % String(goal_id).to_upper())
	goal.description_key = StringName("GOAL_%s_DESC" % String(goal_id).to_upper())
	goal.metric = VillageGoalData.Metric[String(metric_key)]
	goal.target = target
	goal.reward_money = reward
	goal.reward_flag = reward_flag
	goal.required_flag = required_flag
	goal.order = order
	_save(goal, GOAL_DIR.path_join("%s.tres" % goal_id))
