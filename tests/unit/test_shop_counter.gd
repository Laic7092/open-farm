extends GdUnitTestSuite
## 柜台开张规则：上班 + 到岗 + 站在柜台附近，缺一不可。

const MAX_DISTANCE: float = 48.0


func test_open_when_clerk_is_on_shift_and_present() -> void:
	assert_bool(ShopCounter.is_staffed_at(true, false, 12.0, MAX_DISTANCE)).is_true()


func test_closed_when_clerk_is_off_shift() -> void:
	assert_bool(ShopCounter.is_staffed_at(false, false, 12.0, MAX_DISTANCE)).is_false()


## 老板还在路上时柜台应当先关着，避免"人没到东西先能买"。
func test_closed_while_clerk_is_still_walking() -> void:
	assert_bool(ShopCounter.is_staffed_at(true, true, 12.0, MAX_DISTANCE)).is_false()


func test_closed_when_clerk_is_too_far_away() -> void:
	assert_bool(ShopCounter.is_staffed_at(true, false, MAX_DISTANCE + 1.0, MAX_DISTANCE)).is_false()


func test_distance_boundary_counts_as_staffed() -> void:
	assert_bool(ShopCounter.is_staffed_at(true, false, MAX_DISTANCE, MAX_DISTANCE)).is_true()


## 没配 shop_id 的柜台不能交互（场景里忘了填数据时安静失效，而不是报错）。
func test_counter_without_shop_id_cannot_interact() -> void:
	var counter: ShopCounter = auto_free(ShopCounter.new())
	counter.shop_id = &""
	assert_bool(counter.can_interact()).is_false()


## 找不到老板时（换到没有他的地图 / clerk_id 写错）柜台一律打烊。
func test_counter_without_clerk_is_closed() -> void:
	var counter: ShopCounter = auto_free(ShopCounter.new())
	counter.shop_id = &"general_store"
	counter.clerk_id = &"nobody"
	assert_bool(counter.is_staffed()).is_false()
