class_name FestivalGameState
extends Resource
## 节日小游戏的可存档状态（Resource）。
##
## 记"今年这场玩过没有"与"历史最好成绩"：节日每年重办，小游戏也每年一次，
## 所以 [member played] 存的是 festival_id → 已参赛的年份。静态配置在
## [FestivalGameData]，评分在 [FestivalGameRules]，本资源不依赖 Autoload。

## festival_id → 已参赛的年份。
var played: Dictionary[StringName, int] = {}
## festival_id → 历史最高分。
var best: Dictionary[StringName, int] = {}


func reset() -> void:
	played.clear()
	best.clear()


## 今年这场是否已经参加过。
func has_played(festival_id: StringName, year: int) -> bool:
	return int(played.get(festival_id, 0)) == year


## 标记今年已参赛。
func mark_played(festival_id: StringName, year: int) -> void:
	if festival_id != &"":
		played[festival_id] = year


## 记录一次成绩；返回 true 表示刷新了历史最好成绩。
func record_best(festival_id: StringName, score_value: int) -> bool:
	if festival_id == &"":
		return false
	if score_value > best_score(festival_id):
		best[festival_id] = score_value
		return true
	return false


## 历史最高分；没参加过返回 0。
func best_score(festival_id: StringName) -> int:
	return int(best.get(festival_id, 0))


func to_dict() -> Dictionary:
	var played_data := {}
	for festival_id: StringName in played:
		played_data[String(festival_id)] = int(played[festival_id])
	var best_data := {}
	for festival_id: StringName in best:
		best_data[String(festival_id)] = int(best[festival_id])
	return {"played": played_data, "best": best_data}


func from_dict(data: Dictionary) -> void:
	reset()
	var played_data: Variant = data.get("played", {})
	if played_data is Dictionary:
		for key: Variant in played_data:
			played[StringName(str(key))] = int(played_data[key])
	var best_data: Variant = data.get("best", {})
	if best_data is Dictionary:
		for key: Variant in best_data:
			best[StringName(str(key))] = int(best_data[key])
