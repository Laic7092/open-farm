class_name FestivalGame
extends RefCounted
## 节日小游戏单元：在会场提交一件自家产物，按价值评出名次。
##
## 与 [Commission] / [Cooking] 同一形态：静态配置在 [FestivalGameData]，
## 评分在纯静态的 [FestivalGameRules]，本单元只做编排。
## 依赖（档案 / 时钟 / 日历 / 背包）全部注入，不做全局查找，可脱离界面单测。
##
## [b]参赛品会被收走[/b]——评鉴会当然要留下展品；这也是"好东西卖出高价"
## 之外的另一种变现方式，同时给节日增加一次自愿的取舍。

## 提交结果；界面据此翻译成提示与音效。
enum Result {
	WON,             ## 夺冠：达到门槛，发放全额奖金
	PARTICIPATED,    ## 参赛但没夺冠：发放安慰奖
	ALREADY_PLAYED,  ## 这场今年已经参加过了
	NOT_ACTIVE,      ## 此刻没有这个节日
	NO_GAME,         ## 该节日没有小游戏 / 找不到配置
	NOT_ACCEPTED,    ## 这件东西不能参赛
	MISSING,         ## 背包里没有这件东西
}

## 小游戏进度。
var state: FestivalGameState

var _profile: PlayerProfile
var _clock: GameDateClock
var _calendar: CalendarService
var _inventory_provider: Callable = Callable()


func _init(p_state: FestivalGameState = null) -> void:
	state = p_state if p_state != null else FestivalGameState.new()


## 注入结算所需协作者：玩家档案、时钟、日历服务与"当前背包"的提供者。
func bind(
	profile: PlayerProfile,
	clock: GameDateClock,
	calendar: CalendarService,
	inventory_provider: Callable
) -> void:
	_profile = profile
	_clock = clock
	_calendar = calendar
	_inventory_provider = inventory_provider


## 某个节日的游戏配置；没有则返回 null。
func game_for(festival_id: StringName) -> FestivalGameData:
	if _calendar == null or festival_id == &"":
		return null
	var festival := _calendar.festival(festival_id)
	if festival == null or festival.game_id == &"":
		return null
	return Database.get_festival_game(festival.game_id)


## 此刻正在举办的小游戏配置；没有则返回 null。
func active_game() -> FestivalGameData:
	if _calendar == null:
		return null
	var festival := _calendar.active_festival()
	return game_for(festival.id) if festival != null else null


## 该节日今年还能不能参赛（有游戏、正在进行、今年没玩过）。
func can_play(festival_id: StringName) -> bool:
	if game_for(festival_id) == null or _clock == null or _calendar == null:
		return false
	if not _calendar.is_active(festival_id):
		return false
	return not state.has_played(festival_id, _clock.date.year)


## 背包里可参赛的产物，每项是
## [code]{item_id, quality, count, score}[/code]；同一道具的不同品质各算一项。
func candidates(festival_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var game := game_for(festival_id)
	var inventory := _current_inventory()
	if game == null or inventory == null:
		return result
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty() or not game.item_ids.has(slot.item_id):
			continue
		var item := Database.get_item(slot.item_id)
		if item == null:
			continue
		result.append({
			"item_id": slot.item_id,
			"quality": slot.quality,
			"count": slot.count,
			"score": FestivalGameRules.score(item, slot.quality),
		})
	return result


## 提交一件产物参赛：收走一件、按分评奖、记下成绩。
func play(festival_id: StringName, item_id: StringName, quality: int = -1) -> Result:
	var game := game_for(festival_id)
	if game == null or _calendar == null or _clock == null:
		return Result.NO_GAME
	if not _calendar.is_active(festival_id):
		return Result.NOT_ACTIVE
	if state.has_played(festival_id, _clock.date.year):
		return Result.ALREADY_PLAYED
	if not FestivalGameRules.accepts(game, item_id):
		return Result.NOT_ACCEPTED
	var inventory := _current_inventory()
	if inventory == null or not inventory.has(item_id, 1):
		return Result.MISSING

	# 未指定品质时用背包里该道具的第一格：参赛得分必须与玩家看到的一致。
	var grade: int = quality if quality >= 0 else _first_quality(inventory, item_id)
	var score_value: int = FestivalGameRules.score(Database.get_item(item_id), grade)
	if not inventory.remove(item_id, 1):
		return Result.MISSING

	state.mark_played(festival_id, _clock.date.year)
	state.record_best(festival_id, score_value)
	if FestivalGameRules.is_winner(score_value, game.min_score):
		if _profile != null:
			_profile.earn(game.reward_money)
		return Result.WON
	if _profile != null:
		_profile.earn(game.consolation_money)
	return Result.PARTICIPATED


# ---------------------------------------------------------------- 内部

func _first_quality(inventory: Inventory, item_id: StringName) -> int:
	for slot: InventorySlot in inventory.slots:
		if not slot.is_empty() and slot.item_id == item_id:
			return slot.quality
	return 0


func _current_inventory() -> Inventory:
	if not _inventory_provider.is_valid():
		return null
	return _inventory_provider.call() as Inventory
