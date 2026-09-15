extends GdUnitTestSuite
## 商店经济系统测试（含金钱与背包的联动）。

const SHOP_ID: StringName = &"general_store"

var _shop: Shop
var _profile: PlayerProfile


func before_test() -> void:
	_profile = PlayerProfile.new()
	_profile.set_money(1000)
	_shop = Shop.new(Database.get_shop(SHOP_ID), _profile, Database, EventBus)
	_shop.restock()


func test_shop_data_exists() -> void:
	assert_object(_shop.data).is_not_null()
	if _shop.data != null:
		assert_array(_shop.data.validate()).is_empty()


func test_available_entries_lists_the_stock() -> void:
	var entries := _shop.available_entries(1)
	assert_array(entries).has_size(_shop.data.stock.size())


func test_price_of_prefers_override_over_item_price() -> void:
	var entry := ShopStock.new()
	entry.item_id = &"turnip_seed"
	entry.price_override = 7
	assert_int(_shop.price_of(entry)).is_equal(7)


func test_price_of_falls_back_to_item_buy_price() -> void:
	var entry := ShopStock.new()
	entry.item_id = &"turnip_seed"
	var item := Database.get_item(&"turnip_seed")
	assert_int(_shop.price_of(entry)).is_equal(item.buy_price)


func test_unlimited_stock_reports_minus_one() -> void:
	var entry := _shop.available_entries(1)[0]
	assert_int(_shop.stock_left(entry)).is_equal(-1)


func test_limited_stock_decreases_after_purchase() -> void:
	var entry := ShopStock.new()
	entry.item_id = &"turnip_seed"
	entry.unlimited = false
	entry.initial_stock = 3
	var limited := ShopData.new()
	limited.id = &"limited"
	limited.display_name_key = &"SHOP_GENERAL_STORE"
	limited.stock = [entry] as Array[ShopStock]
	var shop := Shop.new(limited, _profile, Database, EventBus)

	assert_int(shop.stock_left(entry)).is_equal(3)
	assert_bool(shop.buy(entry, 2, Inventory.new(4))).is_true()
	assert_int(shop.stock_left(entry)).is_equal(1)
	assert_bool(shop.buy(entry, 2, Inventory.new(4))).is_false()
	shop.restock()
	assert_int(shop.stock_left(entry)).is_equal(3)


func test_buy_deducts_money_and_fills_inventory() -> void:
	var inventory := Inventory.new(4)
	var entry := _shop.available_entries(1)[0]
	var price := _shop.price_of(entry)

	assert_bool(_shop.buy(entry, 2, inventory)).is_true()
	assert_int(_profile.money).is_equal(1000 - price * 2)
	assert_int(inventory.count_of(entry.item_id)).is_equal(2)


func test_buy_fails_without_enough_money() -> void:
	_profile.set_money(1)
	var inventory := Inventory.new(4)
	var entry := _shop.available_entries(1)[0]

	assert_bool(_shop.buy(entry, 1, inventory)).is_false()
	assert_int(_profile.money).is_equal(1)
	assert_int(inventory.count_of(entry.item_id)).is_equal(0)


func test_buy_fails_when_inventory_is_full() -> void:
	var inventory := Inventory.new(1)
	inventory.add(&"wood", 99)
	var entry := _shop.available_entries(1)[0]

	assert_bool(_shop.buy(entry, 1, inventory)).is_false()
	assert_int(_profile.money).is_equal(1000)


func test_buy_rejects_invalid_arguments() -> void:
	assert_bool(_shop.buy(null, 1, Inventory.new(1))).is_false()
	assert_bool(_shop.buy(_shop.available_entries(1)[0], 0, Inventory.new(1))).is_false()
	assert_bool(_shop.buy(_shop.available_entries(1)[0], 1, null)).is_false()


func test_sell_pays_money_and_removes_items() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip", 3)
	var item := Database.get_item(&"turnip")
	var unit := _shop.buyback_price(item)

	assert_bool(_shop.sell(&"turnip", 2, inventory)).is_true()
	assert_int(inventory.count_of(&"turnip")).is_equal(1)
	assert_int(_profile.money).is_equal(1000 + unit * 2)
	assert_int(_profile.total_shipped).is_equal(2)


func test_sell_fails_without_the_item() -> void:
	var inventory := Inventory.new(4)
	assert_bool(_shop.sell(&"turnip", 1, inventory)).is_false()
	assert_int(_profile.money).is_equal(1000)


func test_sell_ignores_unsellable_items() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"hoe", 1)
	assert_bool(_shop.sell(&"hoe", 1, inventory)).is_false()
	assert_int(inventory.count_of(&"hoe")).is_equal(1)


func test_buyback_price_respects_multiplier() -> void:
	var data := ShopData.new()
	data.id = &"test"
	data.display_name_key = &"SHOP_GENERAL_STORE"
	data.sell_multiplier = 0.5
	var shop := Shop.new(data, _profile, Database, EventBus)
	var item := Database.get_item(&"turnip")
	assert_int(shop.buyback_price(item)).is_equal(int(floorf(item.sell_price * 0.5)))


func test_rejected_signal_carries_a_reason_key() -> void:
	var reasons: Array[StringName] = []
	_shop.rejected.connect(func(key: StringName) -> void: reasons.append(key))
	_profile.set_money(0)
	_shop.buy(_shop.available_entries(1)[0], 1, Inventory.new(4))
	assert_array(reasons).contains_exactly([Shop.REASON_NO_MONEY])


func test_limited_day_stock_is_hidden_on_other_days() -> void:
	var entry := ShopStock.new()
	entry.item_id = &"turnip_seed"
	entry.available_days = [1, 2, 3] as Array[int]
	var data := ShopData.new()
	data.id = &"day_limited"
	data.display_name_key = &"SHOP_GENERAL_STORE"
	data.stock = [entry] as Array[ShopStock]
	var shop := Shop.new(data, _profile, Database, EventBus)

	assert_array(shop.available_entries(2)).has_size(1)
	assert_array(shop.available_entries(9)).is_empty()


func test_flag_locked_stock_needs_the_flag() -> void:
	var entry := ShopStock.new()
	entry.item_id = &"potato_seed"
	entry.required_flag = &"met_mayor"
	var data := ShopData.new()
	data.id = &"flag_locked"
	data.display_name_key = &"SHOP_GENERAL_STORE"
	data.stock = [entry] as Array[ShopStock]
	var shop := Shop.new(data, _profile, Database, EventBus)

	assert_array(shop.available_entries(1)).is_empty()
	_profile.set_flag(&"met_mayor")
	assert_array(shop.available_entries(1)).has_size(1)
