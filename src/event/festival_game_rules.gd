class_name FestivalGameRules
extends RefCounted
## 节日小游戏的纯规则：评分、胜负与参赛资格。
##
## 只吃 [ItemData] / 品质 / 静态配置，不依赖场景树与 Autoload，
## 因此可以在单元测试里直接断言"好货分更高""门槛卡在正确的位置"。

## 一件参赛品的得分。
##
## 借 [QualityRules.adjusted_price] 复用"售价随品质放大"这条既有规则：
## 银 / 金品质的作物在品评会上本来就该更值钱，不需要为比赛另写一套数值。
static func score(item: ItemData, quality: int) -> int:
	if item == null:
		return 0
	return QualityRules.adjusted_price(item.sell_price, quality)


## 得分是否达到夺冠门槛。
static func is_winner(score_value: int, min_score: int) -> bool:
	return score_value >= maxi(min_score, 0)


## 该道具能不能参加这场比赛。
static func accepts(game: FestivalGameData, item_id: StringName) -> bool:
	return game != null and item_id != &"" and game.item_ids.has(item_id)
