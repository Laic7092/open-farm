extends GdUnitTestSuite
## 野生植被运行时状态的序列化测试。
##
## 存档走 JSON，往返会把 [StringName] 变成 [String]，所以"存了再读回来还一样"
## 必须真的跑一遍，而不是假设。


func test_default_state_is_empty() -> void:
	var state := FloraState.new()
	assert_bool(state.is_empty()).is_true()
	assert_int(state.days_grown).is_equal(0)


func test_round_trip_keeps_every_field() -> void:
	var state := FloraState.new(&"tree_oak")
	state.days_grown = 7
	state.variant = 1
	state.dead = true

	# 模拟一次 JSON 往返：StringName 键与值都会变成 String。
	var payload: Variant = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_bool(payload is Dictionary).is_true()
	if not payload is Dictionary:
		return

	var restored := FloraState.new()
	restored.from_dict(payload)
	assert_str(String(restored.flora_id)).is_equal("tree_oak")
	assert_int(restored.days_grown).is_equal(7)
	assert_int(restored.variant).is_equal(1)
	assert_bool(restored.dead).is_true()


func test_from_dict_tolerates_garbage() -> void:
	var state := FloraState.new(&"weed")
	state.from_dict({})
	assert_bool(state.is_empty()).is_true()
	state.from_dict({"flora_id": "weed", "days_grown": -5, "variant": -1})
	assert_str(String(state.flora_id)).is_equal("weed")
	assert_int(state.days_grown).is_equal(0)
	assert_int(state.variant).is_equal(0)


func test_duplicate_state_is_independent() -> void:
	var state := FloraState.new(&"rock")
	state.days_grown = 3
	var copy := state.duplicate_state()
	copy.days_grown = 9
	assert_int(state.days_grown).is_equal(3)
	assert_int(copy.days_grown).is_equal(9)
