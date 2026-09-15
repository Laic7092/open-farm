extends "res://tools/sample/sample_base.gd"
## items：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	_seed_item(&"turnip_seed", &"ITEM_TURNIP_SEED", &"turnip", 20, 8)
	_crop_item(&"turnip", &"ITEM_TURNIP", 45)
	_seed_item(&"potato_seed", &"ITEM_POTATO_SEED", &"potato", 35, 12)
	_crop_item(&"potato", &"ITEM_POTATO", 90)
	_seed_item(&"tomato_seed", &"ITEM_TOMATO_SEED", &"tomato", 50, 20)
	_crop_item(&"tomato", &"ITEM_TOMATO", 70)

	var wood := ItemData.new()
	wood.id = &"wood"
	wood.display_name_key = &"ITEM_WOOD"
	wood.category = ItemData.Category.MATERIAL
	wood.buy_price = 0
	wood.sell_price = 5
	wood.stack_limit = 99
	wood.icon = _item_icon(&"wood")
	_save(wood, ITEM_DIR.path_join("wood.tres"))

	# 野生植被的三种产出：砍树出木材（上面已经有了），砸石出石材，割草出纤维。
	_material_item(&"stone", &"ITEM_STONE", 8)
	_material_item(&"fiber", &"ITEM_FIBER", 3)
	# 野外采集物。
	_material_item(&"flower", &"ITEM_FLOWER", 12)
	_material_item(&"mushroom", &"ITEM_MUSHROOM", 25)

	# 畜产品与饲料。
	_food_item(&"egg", &"ITEM_EGG", 80)
	_food_item(&"milk", &"ITEM_MILK", 160)
	_material_item(&"hay", &"ITEM_HAY", 4)
	# 牲畜：杂货店买来后放进畜舍。
	_animal_item(&"chicken", &"ITEM_CHICKEN", &"chicken", 500)
	_animal_item(&"cow", &"ITEM_COW", &"cow", 1200)

	# 求婚信物：杂货店有售，结婚时消耗一件，不能卖出。
	var blue_feather := ItemData.new()
	blue_feather.id = &"blue_feather"
	blue_feather.display_name_key = &"ITEM_BLUE_FEATHER"
	blue_feather.description_key = &"ITEM_BLUE_FEATHER_DESC"
	blue_feather.category = ItemData.Category.GIFT
	blue_feather.buy_price = 1000
	blue_feather.sell_price = 100
	blue_feather.sellable = false
	blue_feather.stack_limit = 1
	blue_feather.icon = _item_icon(&"blue_feather")
	_save(blue_feather, ITEM_DIR.path_join("blue_feather.tres"))

	_tool_item(&"hoe", &"ITEM_HOE", &"TOOL_HOE_DESC", &"hoe")
	_tool_item(&"watering_can", &"ITEM_WATERING_CAN", &"TOOL_WATERING_CAN_DESC", &"watering_can")
	_tool_item(&"sickle", &"ITEM_SICKLE", &"TOOL_SICKLE_DESC", &"sickle")
	_tool_item(&"axe", &"ITEM_AXE", &"TOOL_AXE_DESC", &"axe")
	_tool_item(&"pickaxe", &"ITEM_PICKAXE", &"TOOL_PICKAXE_DESC", &"pickaxe")

	# 钓鱼产出：和畜产品一样属于"能吃能卖"的食物，海边与池塘各有一批。
	_food_item(&"sardine", &"ITEM_SARDINE", 40)
	_food_item(&"mackerel", &"ITEM_MACKEREL", 60)
	_food_item(&"sea_bream", &"ITEM_SEA_BREAM", 130)
	_food_item(&"squid", &"ITEM_SQUID", 90)
	_food_item(&"octopus", &"ITEM_OCTOPUS", 160)
	_food_item(&"tuna", &"ITEM_TUNA", 320)
	_food_item(&"crucian", &"ITEM_CRUCIAN", 35)
	_food_item(&"carp", &"ITEM_CARP", 55)
	_food_item(&"catfish", &"ITEM_CATFISH", 120)
	_food_item(&"golden_carp", &"ITEM_GOLDEN_CARP", 420)

	_tool_item(&"fishing_rod", &"ITEM_FISHING_ROD", &"TOOL_FISHING_ROD_DESC", &"fishing_rod")

	var seed_bag := ItemData.new()
	seed_bag.id = &"seed_bag"
	seed_bag.display_name_key = &"ITEM_SEED_BAG"
	seed_bag.category = ItemData.Category.TOOL
	seed_bag.tool_id = &"seed_bag"
	seed_bag.sellable = false
	seed_bag.icon = _item_icon(&"seed_bag")
	_save(seed_bag, ITEM_DIR.path_join("seed_bag.tres"))


func _seed_item(
	item_id: StringName,
	name_key: StringName,
	crop_id: StringName,
	price: int,
	sell_price: int
) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.SEED
	item.crop_id = crop_id
	item.buy_price = price
	item.sell_price = sell_price
	item.stack_limit = 99
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


func _crop_item(item_id: StringName, name_key: StringName, sell_price: int) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.CROP
	item.sell_price = sell_price
	item.stack_limit = 99
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


## 畜产品：能吃能卖。
func _food_item(item_id: StringName, name_key: StringName, sell_price: int) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.FOOD
	item.buy_price = 0
	item.sell_price = sell_price
	item.stack_limit = 99
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


## 牲畜道具：购买后放进畜舍变成活体，不能当普通商品卖掉。
func _animal_item(
	item_id: StringName,
	name_key: StringName,
	animal_id: StringName,
	buy_price: int
) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.ANIMAL
	item.animal_id = animal_id
	item.buy_price = buy_price
	item.sell_price = 0
	item.sellable = false
	item.stack_limit = 1
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


## 野外素材 / 采集物：只能卖、不能买（buy_price 保持 0，也就不会破坏经济）。
func _material_item(item_id: StringName, name_key: StringName, sell_price: int) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.MATERIAL
	item.buy_price = 0
	item.sell_price = sell_price
	item.stack_limit = 99
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


func _tool_item(
	item_id: StringName,
	name_key: StringName,
	description_key: StringName,
	tool_id: StringName
) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.description_key = description_key
	item.category = ItemData.Category.TOOL
	item.tool_id = tool_id
	item.stack_limit = 1
	item.sellable = false
	item.icon = _item_icon(item_id)
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


## 取道具图标。
func _item_icon(item_id: StringName) -> Texture2D:
	return _texture(ITEM_ICON_DIR.path_join("%s.png" % item_id))
