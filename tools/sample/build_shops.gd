extends "res://tools/sample/sample_base.gd"
## shops：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var shop := ShopData.new()
	shop.id = &"general_store"
	shop.display_name_key = &"SHOP_GENERAL_STORE"
	shop.buys_from_player = true
	shop.sell_multiplier = 1.0
	shop.stock = [
		_stock(&"turnip_seed", 20),
		_stock(&"potato_seed", 35),
		_stock(&"tomato_seed", 50),
		_stock(&"hay", 20),
		_stock(&"chicken", 500),
		_stock(&"cow", 1200),
		_stock(&"blue_feather", 1000),
	] as Array[ShopStock]
	_save(shop, SHOP_DIR.path_join("general_store.tres"))

	# 花店：卖种子与野花，收购价略高，给「种花 / 采花」留出经济出口。
	var flower_shop := ShopData.new()
	flower_shop.id = &"flower_shop"
	flower_shop.display_name_key = &"SHOP_FLOWER_SHOP"
	flower_shop.buys_from_player = true
	flower_shop.sell_multiplier = 1.15
	flower_shop.stock = [
		_stock(&"flower", 30),
		_stock(&"turnip_seed", 25),
		_stock(&"tomato_seed", 55),
	] as Array[ShopStock]
	_save(flower_shop, SHOP_DIR.path_join("flower_shop.tres"))


func _stock(item_id: StringName, price: int) -> ShopStock:
	var entry := ShopStock.new()
	entry.item_id = item_id
	entry.price_override = price
	entry.unlimited = true
	return entry
