extends GdUnitTestSuite
## 关系系统测试：聊天 / 送礼 / 表白 / 结婚 / 生子 / 存档往返。
##
## RelationshipService 不再是 Autoload；测试直接 new 服务并注入状态 / 时钟，避免互相污染。


var _profile: PlayerProfile
var _clock: GameDateClock
var _service: RelationshipService


func before_test() -> void:
	_profile = PlayerProfile.new()
	_clock = GameDateClock.new()
	_service = RelationshipService.new()
	_service.set_state(RelationshipStore.new())
	_service.bind_dependencies(_profile, _clock)


func after_test() -> void:
	_service.reset()
	_service.free()
	_service = null


# ---------------------------------------------------------------- 好感度

func test_affection_is_clamped_to_npc_maximum() -> void:
	_service.add_affection(&"librarian", 40)
	assert_int(_service.affection(&"librarian")).is_equal(40)
	_service.add_affection(&"librarian", 9999)
	assert_int(_service.affection(&"librarian")).is_equal(255)
	_service.add_affection(&"librarian", -9999)
	assert_int(_service.affection(&"librarian")).is_equal(0)


func test_hearts_follow_affection() -> void:
	_service.set_affection(&"librarian", 150)
	assert_int(_service.hearts(&"librarian")).is_equal(3)
	assert_int(_service.tier(&"librarian")).is_equal(AffectionRules.Tier.FRIEND)


func test_talk_gives_affection_only_once_a_day() -> void:
	assert_int(_service.talk(&"librarian")).is_equal(AffectionRules.TALK_GAIN)
	assert_int(_service.talk(&"librarian")).is_equal(0)
	assert_bool(_service.can_talk(&"librarian")).is_false()
	_clock.sleep_until_morning()
	assert_bool(_service.can_talk(&"librarian")).is_true()
	assert_int(_service.talk(&"librarian")).is_equal(AffectionRules.TALK_GAIN)


# ---------------------------------------------------------------- 送礼

func test_gift_preferences_come_from_npc_data() -> void:
	assert_int(_service.gift_gain(&"florist", &"flower")).is_equal(
		AffectionRules.GIFT_LOVED
	)
	assert_int(_service.gift_gain(&"florist", &"mushroom")).is_equal(
		AffectionRules.GIFT_LIKED
	)
	assert_int(_service.gift_gain(&"florist", &"wood")).is_equal(
		AffectionRules.GIFT_DISLIKED
	)
	assert_int(_service.gift_gain(&"florist", &"stone")).is_equal(
		AffectionRules.GIFT_NEUTRAL
	)


func test_gift_only_once_a_day() -> void:
	var gain := _service.give_gift(&"florist", &"flower")
	assert_int(gain).is_equal(AffectionRules.GIFT_LOVED)
	assert_int(_service.affection(&"florist")).is_equal(AffectionRules.GIFT_LOVED)
	assert_bool(_service.can_gift(&"florist")).is_false()
	assert_int(_service.give_gift(&"florist", &"flower")).is_equal(0)
	_clock.sleep_until_morning()
	assert_bool(_service.can_gift(&"florist")).is_true()


func test_disliked_gift_lowers_affection_but_never_below_zero() -> void:
	_service.add_affection(&"florist", 1)
	_service.give_gift(&"florist", &"wood")
	assert_int(_service.affection(&"florist")).is_equal(0)


# ---------------------------------------------------------------- 恋爱 / 婚姻

func test_non_romanceable_npc_cannot_confess() -> void:
	_service.set_affection(&"child", 255)
	assert_bool(_service.can_confess(&"child")).is_false()


func test_confess_requires_threshold_and_sets_dating() -> void:
	_service.set_affection(&"librarian", 199)
	assert_bool(_service.can_confess(&"librarian")).is_false()
	_service.set_affection(&"librarian", 200)
	assert_bool(_service.can_confess(&"librarian")).is_true()
	assert_bool(_service.confess(&"librarian")).is_true()
	assert_int(_service.status(&"librarian")).is_equal(AffectionRules.Status.DATING)
	# 已经在交往就不能重复表白。
	assert_bool(_service.can_confess(&"librarian")).is_false()


func test_marry_requires_dating_and_threshold() -> void:
	_service.set_affection(&"librarian", 250)
	assert_bool(_service.can_marry(&"librarian")).is_false()
	_service.confess(&"librarian")
	assert_bool(_service.marry(&"librarian")).is_true()
	assert_bool(_service.is_married()).is_true()
	assert_str(String(_service.spouse_id)).is_equal("librarian")
	assert_int(_service.status(&"librarian")).is_equal(AffectionRules.Status.MARRIED)
	assert_int(_service.pregnancy_days_left).is_equal(AffectionRules.DAYS_UNTIL_CHILD)


func test_only_one_spouse() -> void:
	_service.set_affection(&"librarian", 250)
	_service.confess(&"librarian")
	_service.marry(&"librarian")
	_service.set_affection(&"florist", 250)
	assert_bool(_service.can_confess(&"florist")).is_false()
	assert_bool(_service.can_marry(&"florist")).is_false()


func test_child_is_born_after_gestation() -> void:
	_service.set_affection(&"librarian", 250)
	_service.confess(&"librarian")
	_service.marry(&"librarian")
	assert_bool(_service.has_child()).is_false()
	for _day: int in AffectionRules.DAYS_UNTIL_CHILD:
		_clock.sleep_until_morning()
	assert_bool(_service.has_child()).is_true()
	assert_bool(_profile.has_flag(&"child_born")).is_true()
	assert_int(_service.days_married).is_equal(AffectionRules.DAYS_UNTIL_CHILD)


# ---------------------------------------------------------------- 存档

func test_persistence_round_trip() -> void:
	_service.set_affection(&"librarian", 120)
	_service.give_gift(&"librarian", &"flower")
	_service.set_affection(&"librarian", 250)
	_service.confess(&"librarian")
	_service.marry(&"librarian")
	var snapshot := _service.to_dict()

	_service.reset()
	assert_int(_service.affection(&"librarian")).is_equal(0)
	assert_bool(_service.is_married()).is_false()

	_service.from_dict(snapshot)
	assert_int(_service.affection(&"librarian")).is_equal(250)
	assert_str(String(_service.spouse_id)).is_equal("librarian")
	assert_int(_service.status(&"librarian")).is_equal(AffectionRules.Status.MARRIED)
	# 每日标记也要一起还原，避免读档后重复送礼。
	assert_bool(_service.can_gift(&"librarian")).is_false()


func test_reset_clears_relationships() -> void:
	_service.set_affection(&"librarian", 200)
	_service.confess(&"librarian")
	_service.marry(&"librarian")
	_service.reset()
	assert_bool(_service.known_npcs().is_empty()).is_true()
	assert_bool(_service.is_married()).is_false()
	assert_bool(_service.has_child()).is_false()
