extends GdUnitTestSuite
## 品质规则与"按品质分堆"的背包测试。

func test_adjusted_price_scales_by_grade() -> void:
	assert_int(QualityRules.adjusted_price(100, QualityRules.Grade.NORMAL)).is_equal(100)
	assert_int(QualityRules.adjusted_price(100, QualityRules.Grade.SILVER)).is_equal(125)
	assert_int(QualityRules.adjusted_price(100, QualityRules.Grade.GOLD)).is_equal(160)


func test_adjusted_price_never_zero_for_positive_base() -> void:
	assert_int(QualityRules.adjusted_price(1, QualityRules.Grade.SILVER)).is_equal(1)
	assert_int(QualityRules.adjusted_price(0, QualityRules.Grade.GOLD)).is_equal(0)


func test_roll_forced_gold_and_normal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for _i: int in 20:
		assert_int(QualityRules.roll(rng, 1.0, 1.0)).is_equal(QualityRules.Grade.GOLD)
		assert_int(QualityRules.roll(rng, 0.0, 0.0)).is_equal(QualityRules.Grade.NORMAL)


func test_best_picks_higher_grade() -> void:
	assert_int(QualityRules.best(QualityRules.Grade.NORMAL, QualityRules.Grade.GOLD)).is_equal(
		QualityRules.Grade.GOLD
	)
	assert_int(QualityRules.best(QualityRules.Grade.SILVER, QualityRules.Grade.SILVER)).is_equal(
		QualityRules.Grade.SILVER
	)


func test_inventory_keeps_quality_in_separate_stacks() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"turnip", 2, QualityRules.Grade.NORMAL)
	inventory.add(&"turnip", 3, QualityRules.Grade.GOLD)
	assert_int(inventory.count_of(&"turnip")).is_equal(5)
	assert_int(inventory.used_slots()).is_equal(2)
	assert_int(inventory.slots[0].quality).is_equal(QualityRules.Grade.NORMAL)
	assert_int(inventory.slots[1].quality).is_equal(QualityRules.Grade.GOLD)


func test_inventory_roundtrip_preserves_quality() -> void:
	var inventory := Inventory.new(6)
	inventory.add(&"milk", 4, QualityRules.Grade.SILVER)
	var restored := Inventory.new(6)
	restored.from_dict(inventory.to_dict())
	assert_int(restored.slots[0].count).is_equal(4)
	assert_int(restored.slots[0].quality).is_equal(QualityRules.Grade.SILVER)


func test_stars_match_grade() -> void:
	assert_int(QualityRules.stars(QualityRules.Grade.NORMAL)).is_equal(0)
	assert_int(QualityRules.stars(QualityRules.Grade.SILVER)).is_equal(1)
	assert_int(QualityRules.stars(QualityRules.Grade.GOLD)).is_equal(2)
	# 越界的等级要收敛到合法区间，不能越界取 STARS。
	assert_int(QualityRules.stars(99)).is_equal(2)
	assert_int(QualityRules.stars(-1)).is_equal(0)
