extends GdUnitTestSuite
## 拉扯小游戏测试：整场搏斗都是纯逻辑，不加载场景、不模拟输入。


func _fish(difficulty: int) -> FishData:
	var fish := FishData.new()
	fish.id = &"test_fish"
	fish.item_id = &"test_fish"
	fish.water = [WaterKind.Kind.POND] as Array[int]
	fish.weight = 10
	fish.difficulty = clampi(difficulty, 1, 5)
	fish.size_cm = Vector2i(20, 40)
	return fish


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 跟着鱼上下收线（鱼比钩子浅就上浮），应当能把进度拉满。
func test_tracking_the_fish_lands_it() -> void:
	var fight := FishingFight.new(_fish(1), 0, _seeded(7))
	for _i: int in 1200:
		var reeling := fight.fish_pos() < fight.hook_pos()
		if fight.step(1.0 / 60.0, reeling) == FishingFight.Status.LANDED:
			assert_float(fight.progress()).is_equal_approx(1.0, 0.001)
			return
	assert_bool(false).override_failure_message("稳住钩子 20 秒内应当把这条鱼拉上来").is_true()


## 完全不按收线键，钩子沉底、张力飙升，鱼一定会跑掉。
func test_ignoring_the_fight_lets_it_escape() -> void:
	var fight := FishingFight.new(_fish(3), 0, _seeded(11))
	for _i: int in 900:
		if fight.step(1.0 / 60.0, false) == FishingFight.Status.ESCAPED:
			return
	assert_bool(false).override_failure_message("不操作应当以跑鱼收场").is_true()


## 越难的鱼判定区越窄、游得越快。
func test_harder_fish_is_harder_to_pin() -> void:
	var easy := FishingFight.new(_fish(1), 0, _seeded(3))
	var hard := FishingFight.new(_fish(5), 0, _seeded(3))
	assert_float(hard.zone_half()).is_less(easy.zone_half())
	# 同一个种子下，困难鱼的起手位置一样，但判定区确实更窄。
	assert_float(hard.zone_half()).is_greater_equal(FishingFight.ZONE_MIN)


## 更好的钓竿放宽判定区。
func test_better_rod_widens_the_zone() -> void:
	var plain := FishingFight.new(_fish(4), 0, _seeded(5))
	var upgraded := FishingFight.new(_fish(4), 3, _seeded(5))
	assert_float(upgraded.zone_half()).is_greater(plain.zone_half())


## 同一个随机种子 + 同一串输入 = 同一场拉锯。
func test_same_seed_and_input_replays_identically() -> void:
	var a := FishingFight.new(_fish(3), 1, _seeded(2024))
	var b := FishingFight.new(_fish(3), 1, _seeded(2024))
	for i: int in 240:
		var reeling := (i % 90) < 45
		a.step(1.0 / 60.0, reeling)
		b.step(1.0 / 60.0, reeling)
	assert_float(a.progress()).is_equal_approx(b.progress(), 0.0001)
	assert_float(a.tension()).is_equal_approx(b.tension(), 0.0001)
	assert_float(a.fish_pos()).is_equal_approx(b.fish_pos(), 0.0001)
	assert_float(a.hook_pos()).is_equal_approx(b.hook_pos(), 0.0001)


## 出结果之后再 step 不会翻盘，也不会继续改数值。
func test_result_is_sticky() -> void:
	var fight := FishingFight.new(_fish(1), 0, _seeded(9))
	var status := FishingFight.Status.FIGHTING
	for _i: int in 1200:
		status = fight.step(1.0 / 60.0, false)
		if status != FishingFight.Status.FIGHTING:
			break
	var progress := fight.progress()
	assert_int(status).is_equal(FishingFight.Status.ESCAPED)
	assert_int(fight.step(1.0 / 60.0, false)).is_equal(FishingFight.Status.ESCAPED)
	assert_float(fight.progress()).is_equal_approx(progress, 0.0001)


## 进度与张力永远被夹在 0~1，位置也被夹在深度轴内。
func test_values_stay_in_range() -> void:
	var fight := FishingFight.new(_fish(5), 0, _seeded(13))
	for i: int in 600:
		var reeling := (i % 40) < 20
		fight.step(1.0 / 60.0, reeling)
		assert_float(fight.progress()).is_greater_equal(0.0)
		assert_float(fight.progress()).is_less_equal(1.0)
		assert_float(fight.tension()).is_greater_equal(0.0)
		assert_float(fight.tension()).is_less_equal(1.0)
		assert_float(fight.fish_pos()).is_greater_equal(FishingFight.DEPTH_MIN)
		assert_float(fight.fish_pos()).is_less_equal(FishingFight.DEPTH_MAX)
		assert_float(fight.hook_pos()).is_greater_equal(FishingFight.DEPTH_MIN)
		assert_float(fight.hook_pos()).is_less_equal(FishingFight.DEPTH_MAX)
