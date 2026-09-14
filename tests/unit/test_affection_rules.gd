extends GdUnitTestSuite
## 好感度规则测试：心数换算、档位、礼物收益与门槛判定。
##
## [AffectionRules] 是纯静态类，不依赖 autoload，所以这里可以逐条穷举边界。


func test_hearts_rounds_down_and_caps() -> void:
	assert_int(AffectionRules.hearts(0)).is_equal(0)
	assert_int(AffectionRules.hearts(49)).is_equal(0)
	assert_int(AffectionRules.hearts(50)).is_equal(1)
	assert_int(AffectionRules.hearts(99)).is_equal(1)
	assert_int(AffectionRules.hearts(100)).is_equal(2)
	assert_int(AffectionRules.hearts(249)).is_equal(4)
	assert_int(AffectionRules.hearts(250)).is_equal(5)
	assert_int(AffectionRules.hearts(9999)).is_equal(AffectionRules.MAX_HEARTS)


func test_tier_boundaries() -> void:
	assert_int(AffectionRules.tier(0)).is_equal(AffectionRules.Tier.STRANGER)
	assert_int(AffectionRules.tier(50)).is_equal(AffectionRules.Tier.ACQUAINTANCE)
	assert_int(AffectionRules.tier(100)).is_equal(AffectionRules.Tier.ACQUAINTANCE)
	assert_int(AffectionRules.tier(150)).is_equal(AffectionRules.Tier.FRIEND)
	assert_int(AffectionRules.tier(200)).is_equal(AffectionRules.Tier.CLOSE)
	assert_int(AffectionRules.tier(250)).is_equal(AffectionRules.Tier.LOVER)


func test_every_tier_has_a_translation_key() -> void:
	for tier: AffectionRules.Tier in [
		AffectionRules.Tier.STRANGER,
		AffectionRules.Tier.ACQUAINTANCE,
		AffectionRules.Tier.FRIEND,
		AffectionRules.Tier.CLOSE,
		AffectionRules.Tier.LOVER,
	]:
		assert_str(String(AffectionRules.tier_key(tier))).is_not_empty()


func test_gift_gain_prefers_loved_over_liked_over_disliked() -> void:
	var loved: Array[StringName] = [&"flower"]
	var liked: Array[StringName] = [&"mushroom"]
	var disliked: Array[StringName] = [&"wood"]
	assert_int(AffectionRules.gift_gain(&"flower", loved, liked, disliked)).is_equal(
		AffectionRules.GIFT_LOVED
	)
	assert_int(AffectionRules.gift_gain(&"mushroom", loved, liked, disliked)).is_equal(
		AffectionRules.GIFT_LIKED
	)
	assert_int(AffectionRules.gift_gain(&"wood", loved, liked, disliked)).is_equal(
		AffectionRules.GIFT_DISLIKED
	)
	assert_int(AffectionRules.gift_gain(&"stone", loved, liked, disliked)).is_equal(
		AffectionRules.GIFT_NEUTRAL
	)
	assert_int(AffectionRules.gift_gain(&"", loved, liked, disliked)).is_equal(0)


func test_loved_beats_disliked_when_both_listed() -> void:
	# 规则层用"先看最爱"的优先级兜底；数据自检会阻止这种数据出现。
	var loved: Array[StringName] = [&"flower"]
	var disliked: Array[StringName] = [&"flower"]
	assert_int(AffectionRules.gift_gain(&"flower", loved, [], disliked)).is_equal(
		AffectionRules.GIFT_LOVED
	)


func test_confession_and_marriage_thresholds() -> void:
	assert_bool(AffectionRules.can_confess(199, 200)).is_false()
	assert_bool(AffectionRules.can_confess(200, 200)).is_true()
	assert_bool(AffectionRules.can_marry(249, 250)).is_false()
	assert_bool(AffectionRules.can_marry(250, 250)).is_true()


func test_clamp_affection_keeps_value_in_range() -> void:
	assert_int(AffectionRules.clamp_affection(-5, 255)).is_equal(0)
	assert_int(AffectionRules.clamp_affection(100, 255)).is_equal(100)
	assert_int(AffectionRules.clamp_affection(999, 255)).is_equal(255)
	assert_int(AffectionRules.clamp_affection(10, 0)).is_equal(0)


## 门槛必须落在"能靠日常互动到达"的范围内，否则永远无法触发。
func test_default_thresholds_are_reachable() -> void:
	assert_int(AffectionRules.MAX_HEARTS * AffectionRules.HEART_SIZE).is_equal(250)
	assert_bool(AffectionRules.FRIEND_HEARTS <= AffectionRules.MAX_HEARTS).is_true()
	assert_bool(AffectionRules.TALK_GAIN > 0).is_true()
	assert_bool(AffectionRules.GIFT_LOVED > AffectionRules.GIFT_LIKED).is_true()
	assert_bool(AffectionRules.GIFT_LIKED > AffectionRules.GIFT_NEUTRAL).is_true()
	assert_bool(AffectionRules.DAYS_UNTIL_CHILD > 0).is_true()
