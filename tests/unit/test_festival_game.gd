extends GdUnitTestSuite
## 节日小游戏测试：评分规则、参赛资格与"一场一年一次"的结算。
##
## 用真实 [CalendarService] + [GameDateClock] 把日期拨到收获祭当天，
## 因此测的是"会场真的开着"这条链路，而不是打桩出来的假状态。


func test_rules_score_prefers_better_quality() -> void:
	var pumpkin := Database.get_item(&"pumpkin")
	assert_object(pumpkin).is_not_null()
	if pumpkin == null:
		return
	var normal := FestivalGameRules.score(pumpkin, QualityRules.Grade.NORMAL)
	var gold := FestivalGameRules.score(pumpkin, QualityRules.Grade.GOLD)
	assert_int(gold).is_greater(normal)


func test_rules_accepts_only_listed_items() -> void:
	var game := Database.get_festival_game(&"harvest_contest")
	assert_object(game).is_not_null()
	if game == null:
		return
	assert_bool(FestivalGameRules.accepts(game, &"pumpkin")).is_true()
	assert_bool(FestivalGameRules.accepts(game, &"tuna")).is_false()


func test_state_roundtrip() -> void:
	var state := FestivalGameState.new()
	state.mark_played(&"harvest_festival", 2)
	state.record_best(&"harvest_festival", 300)
	state.record_best(&"harvest_festival", 200)

	var restored := FestivalGameState.new()
	restored.from_dict(state.to_dict())
	assert_bool(restored.has_played(&"harvest_festival", 2)).is_true()
	assert_bool(restored.has_played(&"harvest_festival", 3)).is_false()
	assert_int(restored.best_score(&"harvest_festival")).is_equal(300)


# ---------------------------------------------------------------- 单元结算

## 造一份"收获祭正在进行"的日历：秋天 15 日中午。
func _harvest_calendar(profile: PlayerProfile) -> Array:
	var clock := GameDateClock.new()
	clock.set_date(GameDate.new(1, Season.Type.FALL, 15))
	clock.set_time(12, 0)
	var calendar := auto_free(CalendarService.new()) as CalendarService
	calendar.set_state(CalendarProgress.new())
	calendar.bind_dependencies(profile, clock, null, null)
	return [calendar, clock]


func _game_with(
	profile: PlayerProfile, calendar: CalendarService, clock: GameDateClock, inventory: Inventory
) -> FestivalGame:
	var game := FestivalGame.new()
	game.bind(profile, clock, calendar, func() -> Inventory: return inventory)
	return game


func test_play_consumes_item_and_pays_out() -> void:
	var profile := PlayerProfile.new()
	profile.set_money(0)
	var parts := _harvest_calendar(profile)
	var calendar: CalendarService = parts[0]
	var clock: GameDateClock = parts[1]
	assert_bool(calendar.is_active(&"harvest_festival")).is_true()

	var inventory := Inventory.new(4)
	inventory.add(&"pumpkin", 1)
	var game := _game_with(profile, calendar, clock, inventory)

	var before := profile.money
	assert_int(game.play(&"harvest_festival", &"pumpkin")).is_equal(FestivalGame.Result.WON)
	assert_int(inventory.count_of(&"pumpkin")).is_equal(0)
	assert_int(profile.money).is_greater(before)
	assert_bool(game.state.has_played(&"harvest_festival", 1)).is_true()

	# 一年一次：同一年再交不再结算。
	inventory.add(&"pumpkin", 1)
	assert_int(game.play(&"harvest_festival", &"pumpkin")).is_equal(
		FestivalGame.Result.ALREADY_PLAYED
	)


func test_play_rejects_unlisted_item() -> void:
	var profile := PlayerProfile.new()
	var parts := _harvest_calendar(profile)
	var calendar: CalendarService = parts[0]
	var clock: GameDateClock = parts[1]
	var inventory := Inventory.new(4)
	inventory.add(&"tuna", 1)
	var game := _game_with(profile, calendar, clock, inventory)

	assert_int(game.play(&"harvest_festival", &"tuna")).is_equal(
		FestivalGame.Result.NOT_ACCEPTED
	)
	assert_int(inventory.count_of(&"tuna")).is_equal(1)


func test_festival_without_game_has_no_contest() -> void:
	var profile := PlayerProfile.new()
	var clock := GameDateClock.new()
	clock.set_date(GameDate.new(1, Season.Type.SPRING, 1))
	clock.set_time(12, 0)
	var calendar := auto_free(CalendarService.new()) as CalendarService
	calendar.bind_dependencies(profile, clock, null, null)
	var game := FestivalGame.new()
	game.bind(profile, clock, calendar, func() -> Inventory: return null)

	assert_object(game.game_for(&"new_year")).is_null()


func test_database_exposes_games_with_real_items() -> void:
	assert_bool(Database.festival_games().size() > 0).override_failure_message(
		"应当有节日小游戏数据"
	).is_true()
	for game_id: StringName in Database.festival_games():
		var game := Database.get_festival_game(game_id)
		for item_id: StringName in game.item_ids:
			assert_object(Database.get_item(item_id)).override_failure_message(
				"小游戏 %s 的参赛品 %s 不存在" % [game_id, item_id]
			).is_not_null()
