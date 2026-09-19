@tool
class_name FestivalGameData
extends Resource
## 节日小游戏的静态定义（目前是"带上自家最好的东西来评一评"）。
##
## 只描述"收什么、多少分算赢、奖多少"，评分与判定在纯静态的
## [FestivalGameRules] 里，运行时进度在 [FestivalGameState]。
## [FestivalData.game_id] 指向这里的一条记录：节日当天在会场按 E 参加后，
## 再次交互就会打开小游戏。
##
## [b]为什么用显式 [member item_ids] 而不是类别过滤[/b]：花祭比花、收获祭比作物、
## 钓鱼大赛比鱼，"哪些算数"本身就是要审的内容；显式列出来后
## [code]build_festival_games.gd[/code] 能在生成时校验每个 id 都存在。

## 唯一标识。
@export var id: StringName = &""
## 游戏名翻译键。
@export var display_name_key: StringName = &""
## 可以参赛的道具 id。
@export var item_ids: Array[StringName] = []
## 达到该分数才算夺冠；低于它只拿安慰奖。
@export_range(0, 99999) var min_score: int = 200
## 夺冠奖金。
@export_range(0, 99999) var reward_money: int = 0
## 未夺冠的安慰奖。
@export_range(0, 99999) var consolation_money: int = 0


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if item_ids.is_empty():
		problems.append("至少要有一件可参赛的道具")
	if min_score < 0:
		problems.append("min_score 不能为负")
	if reward_money < 0 or consolation_money < 0:
		problems.append("奖金不能为负")
	return problems


func _to_string() -> String:
	return "FestivalGameData(%s, %d 件参赛品)" % [id, item_ids.size()]
