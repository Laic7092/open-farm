extends GdUnitTestSuite
## 关系系统测试：聊天 / 送礼 / 表白 / 结婚 / 生子 / 存档往返。
##
## [code]Relationships[/code] 是 autoload，用例之间会互相污染，所以每个用例前复位。


func before_test() -> void:
	GameClock.reset()
	GameClock.set_paused(false)
	Relationships.reset()
	GameState.reset()


func after_test() -> void:
	Relationships.reset()


# ---------------------------------------------------------------- 好感度

func test_affection_is_clamped_to_npc_maximum() -> void:
	Relationships.add_affection(&"librarian", 40)
	assert_int(Relationships.affection(&"librarian")).is_equal(40)
	Relationships.add_affection(&"librarian", 9999)
	assert_int(Relationships.affection(&"librarian")).is_equal(255)
	Relationships.add_affection(&"librarian", -9999)
	assert_int(Relationships.affection(&"librarian")).is_equal(0)


func test_hearts_follow_affection() -> void:
	Relationships.set_affection(&"librarian", 150)
	assert_int(Relationships.hearts(&"librarian")).is_equal(3)
	assert_int(Relationships.tier(&"librarian")).is_equal(AffectionRules.Tier.FRIEND)


func test_talk_gives_affection_only_once_a_day() -> void:
	assert_int(Relationships.talk(&"librarian")).is_equal(AffectionRules.TALK_GAIN)
	assert_int(Relationships.talk(&"librarian")).is_equal(0)
	assert_bool(Relationships.can_talk(&"librarian")).is_false()
	GameClock.sleep_until_morning()
	assert_bool(Relationships.can_talk(&"librarian")).is_true()
	assert_int(Relationships.talk(&"librarian")).is_equal(AffectionRules.TALK_GAIN)


# ---------------------------------------------------------------- 送礼

func test_gift_preferences_come_from_npc_data() -> void:
	assert_int(Relationships.gift_gain(&"florist", &"flower")).is_equal(
		AffectionRules.GIFT_LOVED
	)
	assert_int(Relationships.gift_gain(&"florist", &"mushroom")).is_equal(
		AffectionRules.GIFT_LIKED
	)
	assert_int(Relationships.gift_gain(&"florist", &"wood")).is_equal(
		AffectionRules.GIFT_DISLIKED
	)
	assert_int(Relationships.gift_gain(&"florist", &"stone")).is_equal(
		AffectionRules.GIFT_NEUTRAL
	)


func test_gift_only_once_a_day() -> void:
	var gain := Relationships.give_gift(&"florist", &"flower")
	assert_int(gain).is_equal(AffectionRules.GIFT_LOVED)
	assert_int(Relationships.affection(&"florist")).is_equal(AffectionRules.GIFT_LOVED)
	assert_bool(Relationships.can_gift(&"florist")).is_false()
	assert_int(Relationships.give_gift(&"florist", &"flower")).is_equal(0)
	GameClock.sleep_until_morning()
	assert_bool(Relationships.can_gift(&"florist")).is_true()


func test_disliked_gift_lowers_affection_but_never_below_zero() -> void:
	Relationships.add_affection(&"florist", 1)
	Relationships.give_gift(&"florist", &"wood")
	assert_int(Relationships.affection(&"florist")).is_equal(0)


# ---------------------------------------------------------------- 恋爱 / 婚姻

func test_non_romanceable_npc_cannot_confess() -> void:
	Relationships.set_affection(&"child", 255)
	assert_bool(Relationships.can_confess(&"child")).is_false()


func test_confess_requires_threshold_and_sets_dating() -> void:
	Relationships.set_affection(&"librarian", 199)
	assert_bool(Relationships.can_confess(&"librarian")).is_false()
	Relationships.set_affection(&"librarian", 200)
	assert_bool(Relationships.can_confess(&"librarian")).is_true()
	assert_bool(Relationships.confess(&"librarian")).is_true()
	assert_int(Relationships.status(&"librarian")).is_equal(AffectionRules.Status.DATING)
	# 已经在交往就不能重复表白。
	assert_bool(Relationships.can_confess(&"librarian")).is_false()


func test_marry_requires_dating_and_threshold() -> void:
	Relationships.set_affection(&"librarian", 250)
	assert_bool(Relationships.can_marry(&"librarian")).is_false()
	Relationships.confess(&"librarian")
	assert_bool(Relationships.marry(&"librarian")).is_true()
	assert_bool(Relationships.is_married()).is_true()
	assert_str(String(Relationships.spouse_id)).is_equal("librarian")
	assert_int(Relationships.status(&"librarian")).is_equal(AffectionRules.Status.MARRIED)
	assert_int(Relationships.pregnancy_days_left).is_equal(AffectionRules.DAYS_UNTIL_CHILD)


func test_only_one_spouse() -> void:
	Relationships.set_affection(&"librarian", 250)
	Relationships.confess(&"librarian")
	Relationships.marry(&"librarian")
	Relationships.set_affection(&"florist", 250)
	assert_bool(Relationships.can_confess(&"florist")).is_false()
	assert_bool(Relationships.can_marry(&"florist")).is_false()


func test_child_is_born_after_gestation() -> void:
	Relationships.set_affection(&"librarian", 250)
	Relationships.confess(&"librarian")
	Relationships.marry(&"librarian")
	assert_bool(Relationships.has_child()).is_false()
	for _day: int in AffectionRules.DAYS_UNTIL_CHILD:
		GameClock.sleep_until_morning()
	assert_bool(Relationships.has_child()).is_true()
	assert_bool(GameState.has_flag(&"child_born")).is_true()
	assert_int(Relationships.days_married).is_equal(AffectionRules.DAYS_UNTIL_CHILD)


# ---------------------------------------------------------------- 存档

func test_persistence_round_trip() -> void:
	Relationships.set_affection(&"librarian", 120)
	Relationships.give_gift(&"librarian", &"flower")
	Relationships.set_affection(&"librarian", 250)
	Relationships.confess(&"librarian")
	Relationships.marry(&"librarian")
	var snapshot := Relationships.to_dict()

	Relationships.reset()
	assert_int(Relationships.affection(&"librarian")).is_equal(0)
	assert_bool(Relationships.is_married()).is_false()

	Relationships.from_dict(snapshot)
	assert_int(Relationships.affection(&"librarian")).is_equal(250)
	assert_str(String(Relationships.spouse_id)).is_equal("librarian")
	assert_int(Relationships.status(&"librarian")).is_equal(AffectionRules.Status.MARRIED)
	# 每日标记也要一起还原，避免读档后重复送礼。
	assert_bool(Relationships.can_gift(&"librarian")).is_false()


func test_reset_clears_relationships() -> void:
	Relationships.set_affection(&"librarian", 200)
	Relationships.confess(&"librarian")
	Relationships.marry(&"librarian")
	Relationships.reset()
	assert_bool(Relationships.known_npcs().is_empty()).is_true()
	assert_bool(Relationships.is_married()).is_false()
	assert_bool(Relationships.has_child()).is_false()
