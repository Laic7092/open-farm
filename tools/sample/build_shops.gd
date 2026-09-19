extends "res://tools/sample/sample_base.gd"
## shops：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## v0.5「商店扩容」：杂货店上架全部 24 种作物的种子 + 建材 + 牲畜 + 信物；
## 花店加卖四种花卉种子。种子价格与 build_crops.gd 的同一张表对齐。

const BuildCrops := preload("res://tools/sample/build_crops.gd")

## 花店专营的观赏作物种子（其余种子归杂货店）。
const FLOWER_SEEDS: Array[StringName] = [
	&"tulip_seed", &"sunflower_seed", &"chrysanthemum_seed", &"wintersweet_seed",
]


func build() -> void:
	var seed_prices := _seed_price_table()

	var general_seeds: Array[ShopStock] = []
	for entry: Dictionary in BuildCrops.CROPS:
		general_seeds.append(_stock(StringName("%s_seed" % entry["id"]), int(entry["seed"])))

	var general_stock: Array[ShopStock] = general_seeds
	for item_id: StringName in [&"wood", &"stone", &"fiber", &"hay"]:
		general_stock.append(_stock(item_id, _material_price(item_id)))
	general_stock.append(_stock(&"chicken", 500))
	general_stock.append(_stock(&"cow", 1200))
	general_stock.append(_stock(&"blue_feather", 1000))

	var shop := ShopData.new()
	shop.id = &"general_store"
	shop.display_name_key = &"SHOP_GENERAL_STORE"
	shop.buys_from_player = true
	shop.sell_multiplier = 1.0
	shop.stock = general_stock
	_save(shop, SHOP_DIR.path_join("general_store.tres"))

	# 花店：卖野花与四种花卉种子，收购价略高，给「种花 / 采花」留出经济出口。
	var flower_shop := ShopData.new()
	flower_shop.id = &"flower_shop"
	flower_shop.display_name_key = &"SHOP_FLOWER_SHOP"
	flower_shop.buys_from_player = true
	flower_shop.sell_multiplier = 1.15
	var flower_stock: Array[ShopStock] = [_stock(&"flower", 30)]
	for seed_id: StringName in FLOWER_SEEDS:
		flower_stock.append(_stock(seed_id, seed_prices.get(seed_id, 30)))
	flower_stock.append(_stock(&"turnip_seed", 25))
	flower_stock.append(_stock(&"tomato_seed", 55))
	flower_shop.stock = flower_stock
	_save(flower_shop, SHOP_DIR.path_join("flower_shop.tres"))


## 建材售价；杂货店上架时用，也是这些素材的一个“保底回收价”。
func _material_price(item_id: StringName) -> int:
	var prices := {&"wood": 25, &"stone": 18, &"fiber": 10, &"hay": 20}
	return int(prices.get(item_id, 10))


## 种子 id → 基础售价，供花店给专属种子定价。
func _seed_price_table() -> Dictionary:
	var table: Dictionary = {}
	for entry: Dictionary in BuildCrops.CROPS:
		table[StringName("%s_seed" % entry["id"])] = int(entry["seed"])
	return table


func _stock(item_id: StringName, price: int) -> ShopStock:
	var entry := ShopStock.new()
	entry.item_id = item_id
	entry.price_override = price
	entry.unlimited = true
	return entry
