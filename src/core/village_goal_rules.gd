class_name VillageGoalRules
extends RefCounted
## 长期村庄目标的纯规则：把几项累计数字折算成某个目标的进度。
##
## 只吃裸数值（不碰 [PlayerProfile] / [Database] / 场景树），因此可以逐条单测。
## 调用方（[VillageGoals]）负责把档案 / 图鉴 / 食谱 / 日历的数字查好后传进来。

## 某个统计口径的当前值。
static func value(
	metric: VillageGoalData.Metric,
	shipped: int,
	earned: int,
	discovered: int,
	cooked: int,
	festivals: int
) -> int:
	match metric:
		VillageGoalData.Metric.EARNED:
			return maxi(earned, 0)
		VillageGoalData.Metric.DISCOVERED:
			return maxi(discovered, 0)
		VillageGoalData.Metric.COOKED:
			return maxi(cooked, 0)
		VillageGoalData.Metric.FESTIVALS:
			return maxi(festivals, 0)
		_:
			return maxi(shipped, 0)


## 进度是否达标。
static func met(goal: VillageGoalData, current: int) -> bool:
	return goal != null and current >= goal.target


## 进度比例（0..1），供进度条使用。
static func ratio(goal: VillageGoalData, current: int) -> float:
	if goal == null or goal.target <= 0:
		return 0.0
	return clampf(float(current) / float(goal.target), 0.0, 1.0)
