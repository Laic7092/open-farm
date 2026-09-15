extends GdUnitTestSuite
## 重构契约测试：领域事件入口、只读数据快照、存档节与世界目标。


class _DummyState:
	extends RefCounted
	
	var value: int = 1
	
	func to_dict() -> Dictionary:
		return {"value": value}
	
	func from_dict(data: Dictionary) -> void:
		value = int(data.get("value", 0))


func test_event_bus_keeps_only_cross_domain_signals() -> void:
	# 直接数脚本里声明的 signal，避免把 Node 内建信号算进来。
	var source := FileAccess.get_file_as_string("res://src/autoload/event_bus.gd")
	var signal_count := 0
	for line: String in source.split("\n"):
		if line.begins_with("signal "):
			signal_count += 1
	assert_int(signal_count).is_less_equal(12)
	assert_object(EventBus.player).is_not_null()
	assert_object(EventBus.farm).is_not_null()
	assert_object(EventBus.world).is_not_null()
	assert_object(EventBus.ui).is_not_null()


func test_database_getters_return_snapshots() -> void:
	var before := Database.total_count()
	var snapshot := Database.crops()
	snapshot.clear()
	assert_int(Database.total_count()).is_equal(before)


func test_save_section_roundtrip() -> void:
	var target := _DummyState.new()
	var section := SaveSection.new(target, &"dummy", 7, true)
	assert_array(section.validate()).is_empty()
	target.value = 42
	assert_dict(section.to_dict()).contains_keys(["value"])
	section.from_dict({"value": 3})
	assert_int(target.value).is_equal(3)


func test_world_target_roundtrip() -> void:
	var target := WorldTarget.new("res://scenes/world/farm.tscn", &"start")
	var restored := WorldTarget.from_dict(target.to_dict())
	assert_str(restored.scene_path).is_equal(target.scene_path)
	assert_str(String(restored.spawn_id)).is_equal("start")
