extends GdUnitTestSuite
## 博物馆图鉴状态测试：首次记录、背包扫描与存档往返。


func test_discover_records_only_once() -> void:
	var state := MuseumState.new()
	assert_bool(state.discover(&"turnip", 3)).is_true()
	assert_bool(state.discover(&"turnip", 9)).is_false()
	assert_bool(state.is_discovered(&"turnip")).is_true()
	assert_int(state.first_seen_day(&"turnip")).is_equal(3)
	assert_int(state.discovered_count()).is_equal(1)


func test_discover_inventory_scans_slots() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 2)
	inventory.add(&"stone", 5)
	var state := MuseumState.new()
	assert_int(state.discover_inventory(inventory, 7)).is_equal(2)
	assert_bool(state.is_discovered(&"turnip")).is_true()
	assert_bool(state.is_discovered(&"stone")).is_true()

	# 再扫一遍不应重复计数。
	assert_int(state.discover_inventory(inventory, 8)).is_equal(0)


## 单元订阅被注入的玩家事件即可复现发现逻辑，不需要场景树或全局查找。
func test_unit_records_on_injected_item_event() -> void:
	var events := PlayerEvents.new()
	var museum := Museum.new()
	museum.bind(events, null)
	events.item_obtained.emit(&"turnip")
	events.item_obtained.emit(&"stone")
	events.item_obtained.emit(&"turnip")
	assert_int(museum.state.discovered_count()).is_equal(2)
	assert_bool(museum.state.is_discovered(&"turnip")).is_true()


func test_state_roundtrip() -> void:
	var state := MuseumState.new()
	state.discover(&"turnip", 1)
	state.discover(&"milk", 4)

	var restored := MuseumState.new()
	restored.from_dict(state.to_dict())
	assert_int(restored.discovered_count()).is_equal(2)
	assert_bool(restored.is_discovered(&"milk")).is_true()
	assert_int(restored.first_seen_day(&"milk")).is_equal(4)


func test_inventory_survives_selling() -> void:
	# 图鉴记录独立于背包：卖掉后仍然"见过"。
	var inventory := Inventory.new(2)
	inventory.add(&"turnip", 1)
	var state := MuseumState.new()
	state.discover_inventory(inventory)
	inventory.remove(&"turnip", 1)
	assert_bool(state.is_discovered(&"turnip")).is_true()
