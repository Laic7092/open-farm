class_name VillageGoals
extends RefCounted
## 长期村庄目标单元：汇总累计指标、判定达标、发奖。
##
## 与 [Museum] / [Commission] 同一形态：静态定义在 [VillageGoalData]，
## 数值折算在纯静态的 [VillageGoalRules]，本单元只做"查数字 + 发奖 + 记领奖"。
## 依赖（档案 / 图鉴 / 食谱 / 日历）全部注入，因此可脱离界面与场景树单测。
##
## [b]奖励会解锁内容[/b]：领奖时写入 [member VillageGoalData.reward_flag]，
## 例如"推广料理"完成后解锁南瓜派食谱——目标不只是给钱，也推进玩法。

## 领奖结果；界面据此翻译成提示与音效。
enum Result {
	CLAIMED,    ## 领奖成功：已发钱、打旗标、记领奖
	NOT_READY,  ## 还没达标
	ALREADY,    ## 已经领过
	LOCKED,     ## 前置目标还没完成
	UNKNOWN,    ## 没有这条目标的数据
}

## 领奖记录。
var state: VillageGoalState

var _profile: PlayerProfile
var _museum: MuseumState
var _cooking: CookingState
var _calendar: CalendarService


func _init(p_state: VillageGoalState = null) -> void:
	state = p_state if p_state != null else VillageGoalState.new()


## 注入统计所需的协作者：玩家档案、图鉴、食谱与日历。
func bind(
	profile: PlayerProfile,
	museum: MuseumState,
	cooking: CookingState,
	calendar: CalendarService
) -> void:
	_profile = profile
	_museum = museum
	_cooking = cooking
	_calendar = calendar


## 全部目标，按 [member VillageGoalData.order] 与 id 排序。
func goals() -> Array[VillageGoalData]:
	var result: Array[VillageGoalData] = []
	for goal_id: StringName in Database.village_goals():
		result.append(Database.get_village_goal(goal_id))
	result.sort_custom(func(a: VillageGoalData, b: VillageGoalData) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return String(a.id) < String(b.id)
	)
	return result


## 某个目标的当前进度值。
func progress(goal: VillageGoalData) -> int:
	if goal == null:
		return 0
	return VillageGoalRules.value(
		goal.metric,
		_profile.total_shipped if _profile != null else 0,
		_profile.total_earned if _profile != null else 0,
		_museum.discovered_count() if _museum != null else 0,
		_cooking.known_count() if _cooking != null else 0,
		_festival_count()
	)


## 前置目标是否已完成（能看见这条目标）。
func is_unlocked(goal: VillageGoalData) -> bool:
	if goal == null:
		return false
	if goal.required_flag == &"":
		return true
	return _profile != null and _profile.has_flag(goal.required_flag)


## 是否能领奖（已解锁、未领过、已达标）。
func is_claimable(goal: VillageGoalData) -> bool:
	if goal == null or not is_unlocked(goal):
		return false
	if state.is_claimed(goal.id):
		return false
	return VillageGoalRules.met(goal, progress(goal))


## 领奖：发钱、打旗标、记领奖。
func claim(goal_id: StringName) -> Result:
	var goal := Database.get_village_goal(goal_id)
	if goal == null:
		return Result.UNKNOWN
	if not is_unlocked(goal):
		return Result.LOCKED
	if state.is_claimed(goal_id):
		return Result.ALREADY
	if not VillageGoalRules.met(goal, progress(goal)):
		return Result.NOT_READY
	if not state.claim(goal_id):
		return Result.ALREADY
	if _profile != null:
		if goal.reward_money > 0:
			_profile.earn(goal.reward_money)
		if goal.reward_flag != &"":
			_profile.set_flag(goal.reward_flag)
	return Result.CLAIMED


# ---------------------------------------------------------------- 内部

## 参加过的节日种数（跨年去重）。
func _festival_count() -> int:
	if _calendar == null:
		return 0
	return _calendar.state().attended.size()
