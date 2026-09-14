extends SceneTree
## 示例数据生成器：一次性产出 [code]res://data/**/*.tres[/code]。
##
## [b]为什么用脚本生成而不是手写 .tres[/b]
## [code].tres[/code] 里嵌套枚举数组、子资源（[DialogueLine] / [ShopStock]）的
## 序列化格式很容易写错且难以排查；交给 [ResourceSaver] 生成的格式永远和引擎版本一致。
##
## 生成出来的资源就是[b]普通的、可在编辑器里继续编辑的资源[/b]——
## 之后策划直接在 Inspector 里改数值即可，不需要再碰这个脚本。
## 只有"重置示例数据"时才需要重新运行它。
##
## 用法：[code]godot --headless --path . -s res://tools/generate_sample_data.gd[/code]

const CROP_DIR: String = "res://data/crops"
const ITEM_DIR: String = "res://data/items"
const TOOL_DIR: String = "res://data/tools"
const DIALOGUE_DIR: String = "res://data/dialogue"
const NPC_DIR: String = "res://data/npcs"
const SHOP_DIR: String = "res://data/shops"


func _initialize() -> void:
	for directory: String in [CROP_DIR, ITEM_DIR, TOOL_DIR, DIALOGUE_DIR, NPC_DIR, SHOP_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

	_build_tools()
	_build_crops()
	_build_items()
	_build_dialogues()
	_build_npcs()
	_build_shops()

	print("示例数据生成完成")
	quit()


# ---------------------------------------------------------------- 工具

func _build_tools() -> void:
	var hoe := ToolData.new()
	hoe.id = &"hoe"
	hoe.display_name_key = &"ITEM_HOE"
	hoe.kind = ToolData.Kind.HOE
	hoe.stamina_cost = 2
	_save(hoe, TOOL_DIR.path_join("hoe.tres"))

	var can := ToolData.new()
	can.id = &"watering_can"
	can.display_name_key = &"ITEM_WATERING_CAN"
	can.kind = ToolData.Kind.WATERING_CAN
	can.stamina_cost = 1
	_save(can, TOOL_DIR.path_join("watering_can.tres"))

	var sickle := ToolData.new()
	sickle.id = &"sickle"
	sickle.display_name_key = &"ITEM_SICKLE"
	sickle.kind = ToolData.Kind.SICKLE
	sickle.stamina_cost = 1
	_save(sickle, TOOL_DIR.path_join("sickle.tres"))

	var seed_bag := ToolData.new()
	seed_bag.id = &"seed_bag"
	seed_bag.display_name_key = &"ITEM_SEED_BAG"
	seed_bag.kind = ToolData.Kind.SEED
	seed_bag.stamina_cost = 1
	_save(seed_bag, TOOL_DIR.path_join("seed_bag.tres"))


# ---------------------------------------------------------------- 作物

func _build_crops() -> void:
	# 萝卜：春季入门作物，4 天成熟，一次性收获，回本快。
	var turnip := CropData.new()
	turnip.id = &"turnip"
	turnip.display_name_key = &"CROP_TURNIP"
	turnip.seed_item_id = &"turnip_seed"
	turnip.harvest_item_id = &"turnip"
	turnip.harvest_amount = 1
	turnip.days_per_stage = [1, 1, 1, 1]
	turnip.seasons = [Season.Type.SPRING] as Array[Season.Type]
	turnip.seed_price = 20
	turnip.base_sell_price = 45
	turnip.bonus_yield_chance = 0.1
	_save(turnip, CROP_DIR.path_join("turnip.tres"))

	# 土豆：春季主力，6 天成熟，收益更高。
	var potato := CropData.new()
	potato.id = &"potato"
	potato.display_name_key = &"CROP_POTATO"
	potato.seed_item_id = &"potato_seed"
	potato.harvest_item_id = &"potato"
	potato.harvest_amount = 1
	potato.days_per_stage = [2, 2, 2]
	potato.seasons = [Season.Type.SPRING] as Array[Season.Type]
	potato.seed_price = 35
	potato.base_sell_price = 90
	_save(potato, CROP_DIR.path_join("potato.tres"))

	# 番茄：夏季多次收获作物，收获后 3 天重新结果。
	var tomato := CropData.new()
	tomato.id = &"tomato"
	tomato.display_name_key = &"CROP_TOMATO"
	tomato.seed_item_id = &"tomato_seed"
	tomato.harvest_item_id = &"tomato"
	tomato.harvest_amount = 1
	tomato.days_per_stage = [2, 2, 2, 2]
	tomato.seasons = [Season.Type.SUMMER] as Array[Season.Type]
	tomato.regrow_days = 3
	tomato.seed_price = 50
	tomato.base_sell_price = 70
	_save(tomato, CROP_DIR.path_join("tomato.tres"))


# ---------------------------------------------------------------- 道具

func _build_items() -> void:
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
	_save(wood, ITEM_DIR.path_join("wood.tres"))

	_tool_item(&"hoe", &"ITEM_HOE", &"TOOL_HOE_DESC", &"hoe")
	_tool_item(&"watering_can", &"ITEM_WATERING_CAN", &"TOOL_WATERING_CAN_DESC", &"watering_can")
	_tool_item(&"sickle", &"ITEM_SICKLE", &"TOOL_SICKLE_DESC", &"sickle")

	var seed_bag := ItemData.new()
	seed_bag.id = &"seed_bag"
	seed_bag.display_name_key = &"ITEM_SEED_BAG"
	seed_bag.category = ItemData.Category.TOOL
	seed_bag.tool_id = &"seed_bag"
	seed_bag.sellable = false
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
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


func _crop_item(item_id: StringName, name_key: StringName, sell_price: int) -> void:
	var item := ItemData.new()
	item.id = item_id
	item.display_name_key = name_key
	item.category = ItemData.Category.CROP
	item.sell_price = sell_price
	item.stack_limit = 99
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
	_save(item, ITEM_DIR.path_join("%s.tres" % item_id))


# ---------------------------------------------------------------- 对话

func _build_dialogues() -> void:
	var merchant := DialogueData.new()
	merchant.id = &"merchant_greeting"
	merchant.speaker_key = &"NPC_MERCHANT"
	merchant.lines = [
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_GREETING"),
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_WEATHER"),
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_CLOSING"),
	] as Array[DialogueLine]
	_save(merchant, DIALOGUE_DIR.path_join("merchant_greeting.tres"))

	var mayor := DialogueData.new()
	mayor.id = &"mayor_greeting"
	mayor.speaker_key = &"NPC_MAYOR"
	mayor.lines = [
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_GREETING"),
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_TIP"),
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_SEASON"),
	] as Array[DialogueLine]
	_save(mayor, DIALOGUE_DIR.path_join("mayor_greeting.tres"))


func _line(speaker_key: StringName, text_key: StringName) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_key = speaker_key
	line.text_key = text_key
	return line


# ---------------------------------------------------------------- NPC

func _build_npcs() -> void:
	var merchant := NpcData.new()
	merchant.id = &"merchant"
	merchant.display_name_key = &"NPC_MERCHANT"
	merchant.default_dialogue = _load(DIALOGUE_DIR.path_join("merchant_greeting.tres"))
	merchant.shop_id = &"general_store"
	_save(merchant, NPC_DIR.path_join("merchant.tres"))

	var mayor := NpcData.new()
	mayor.id = &"mayor"
	mayor.display_name_key = &"NPC_MAYOR"
	mayor.default_dialogue = _load(DIALOGUE_DIR.path_join("mayor_greeting.tres"))
	_save(mayor, NPC_DIR.path_join("mayor.tres"))


# ---------------------------------------------------------------- 商店

func _build_shops() -> void:
	var shop := ShopData.new()
	shop.id = &"general_store"
	shop.display_name_key = &"SHOP_GENERAL_STORE"
	shop.buys_from_player = true
	shop.sell_multiplier = 1.0
	shop.stock = [
		_stock(&"turnip_seed", 20),
		_stock(&"potato_seed", 35),
		_stock(&"tomato_seed", 50),
	] as Array[ShopStock]
	_save(shop, SHOP_DIR.path_join("general_store.tres"))


func _stock(item_id: StringName, price: int) -> ShopStock:
	var entry := ShopStock.new()
	entry.item_id = item_id
	entry.price_override = price
	entry.unlimited = true
	return entry


# ---------------------------------------------------------------- 工具方法

func _load(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_error("找不到资源：%s" % path)
		return null
	return ResourceLoader.load(path)


func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("  → ", path)
