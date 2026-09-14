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
## 它同时负责把 [code]tools/art/*.gd[/code] 生成的贴图挂到数据上
## （[code]icon[/code] / [code]sprite_sheet[/code] / [code]frames[/code]），
## 因此请在跑完 [code]tools/build_assets.sh[/code] 之后再运行本脚本。
##
## 用法：[code]godot --headless --path . -s res://tools/generate_sample_data.gd[/code]

const CROP_DIR: String = "res://data/crops"
const ANIMAL_DIR: String = "res://data/animals"
const BUILDING_DIR: String = "res://data/buildings"
const FLORA_DIR: String = "res://data/flora"
const ITEM_DIR: String = "res://data/items"
const TOOL_DIR: String = "res://data/tools"
const DIALOGUE_DIR: String = "res://data/dialogue"
const NPC_DIR: String = "res://data/npcs"
const SHOP_DIR: String = "res://data/shops"

## 美术资源目录（由 tools/art/*.gd 生成，这里只负责"把图挂到数据上"）。
const CROP_SHEET_DIR: String = "res://assets/sprites/crops"
const ANIMAL_SHEET_DIR: String = "res://assets/sprites/animals"
const FLORA_SHEET_DIR: String = "res://assets/sprites/flora"
const ITEM_ICON_DIR: String = "res://assets/sprites/items"
const NPC_FRAMES_DIR: String = "res://assets/sprites/actors"


func _initialize() -> void:
	for directory: String in [
		CROP_DIR, ANIMAL_DIR, BUILDING_DIR, FLORA_DIR,
		ITEM_DIR, TOOL_DIR, DIALOGUE_DIR, NPC_DIR, SHOP_DIR
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

	_build_tools()
	_build_crops()
	_build_animals()
	_build_buildings()
	_build_flora()
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

	# 斧头 / 镐子：世界会自己长树长石，必须给玩家清理手段。
	var axe := ToolData.new()
	axe.id = &"axe"
	axe.display_name_key = &"ITEM_AXE"
	axe.kind = ToolData.Kind.AXE
	axe.stamina_cost = 3
	_save(axe, TOOL_DIR.path_join("axe.tres"))

	var pickaxe := ToolData.new()
	pickaxe.id = &"pickaxe"
	pickaxe.display_name_key = &"ITEM_PICKAXE"
	pickaxe.kind = ToolData.Kind.PICKAXE
	pickaxe.stamina_cost = 3
	_save(pickaxe, TOOL_DIR.path_join("pickaxe.tres"))


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
	turnip.sprite_sheet = _crop_sheet(&"turnip")
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
	potato.sprite_sheet = _crop_sheet(&"potato")
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
	tomato.sprite_sheet = _crop_sheet(&"tomato")
	_save(tomato, CROP_DIR.path_join("tomato.tres"))


# ---------------------------------------------------------------- 牲畜

## 可畜养的动物 + 畜舍。
##
## 数值调法：
## [br]- [code]mature_days[/code] = 幼崽到成年需要喂几天
## [br]- [code]produce_days[/code] = 成年后每隔几天产出一次
## [br]- 不喂食不会死，只会掉好感度并停止产出
func _build_animals() -> void:
	# 鸡：3 天成年，之后每天一个鸡蛋，入门牲畜。
	var chicken := AnimalData.new()
	chicken.id = &"chicken"
	chicken.display_name_key = &"ANIMAL_CHICKEN"
	chicken.species = &"chicken"
	chicken.mature_days = 3
	chicken.produce_days = 1
	chicken.product_item_id = &"egg"
	chicken.product_amount = 1
	chicken.feed_item_id = &"hay"
	chicken.sprite_sheet = _animal_sheet(&"chicken")
	_save(chicken, ANIMAL_DIR.path_join("chicken.tres"))

	# 牛：更贵、更慢，但牛奶收益高，且高好感时更容易多产一瓶。
	var cow := AnimalData.new()
	cow.id = &"cow"
	cow.display_name_key = &"ANIMAL_COW"
	cow.species = &"cow"
	cow.mature_days = 5
	cow.produce_days = 2
	cow.product_item_id = &"milk"
	cow.product_amount = 1
	cow.feed_item_id = &"hay"
	cow.affection_per_pet = 3
	cow.bonus_product_chance = 0.35
	cow.sprite_sheet = _animal_sheet(&"cow")
	_save(cow, ANIMAL_DIR.path_join("cow.tres"))


func _build_buildings() -> void:
	var coop := BuildingData.new()
	coop.id = &"coop"
	coop.display_name_key = &"BUILDING_COOP"
	coop.capacity = 4
	coop.allowed_species = [&"chicken"] as Array[StringName]
	_save(coop, BUILDING_DIR.path_join("coop.tres"))

	var barn := BuildingData.new()
	barn.id = &"barn"
	barn.display_name_key = &"BUILDING_BARN"
	barn.capacity = 4
	barn.allowed_species = [&"cow"] as Array[StringName]
	_save(barn, BUILDING_DIR.path_join("barn.tres"))


# ---------------------------------------------------------------- 野生植被

## 世界各处会自己长出来的东西。
##
## 数值调法：
## [br]- [code]spawn_weight[/code] 是"每天冒出来的概率权重"，0 = 这个季节不冒
## [br]- [code]initial_weight[/code] 是新地图开局播种的权重（树多、草少）
## [br]- [code]days_per_stage[/code] 为空 = 不生长（石头就是这样"不会变"的）
func _build_flora() -> void:
	# 阔叶树：8 天从树苗长到成树，成树开始挡路（前两个阶段能穿过去）。
	_flora(&"tree_oak", &"FLORA_TREE_OAK", FloraData.Kind.TREE, [2, 3, 3], {
		"spawn_weight": [5, 5, 3, 0],
		"rain_bonus": 1,
		"initial_weight": 5,
		"max_per_world": 12,
		"min_spacing": 3,
		"solid_from_stage": 2,
		"solid_size": Vector2(10, 8),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.AXE,
		"stamina_cost": 3,
		"drop_item_id": &"wood",
		"drop_amount": Vector2i(2, 3),
	})

	# 松树：慢一点、冬季也在长，是冬天唯一会变高变大的东西。
	_flora(&"tree_pine", &"FLORA_TREE_PINE", FloraData.Kind.TREE, [3, 3, 3], {
		"spawn_weight": [3, 3, 3, 1],
		"initial_weight": 4,
		"max_per_world": 10,
		"min_spacing": 3,
		"solid_from_stage": 2,
		"solid_size": Vector2(10, 8),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.AXE,
		"stamina_cost": 3,
		"drop_item_id": &"wood",
		"drop_amount": Vector2i(2, 3),
	})

	# 杂草：一天就长成，会侵占农田空地——"早上起来田里长草"就是它。
	_flora(&"weed", &"FLORA_WEED", FloraData.Kind.WEED, [1], {
		"spawn_weight": [7, 8, 5, 0],
		"rain_bonus": 3,
		"initial_weight": 6,
		"max_per_world": 60,
		"grows_on_farmland": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"fiber",
		"drop_amount": Vector2i(1, 1),
		"drop_chance": 0.7,
	})

	# 石头：不生长、不会变，砸了出石材。
	_flora(&"rock", &"FLORA_ROCK", FloraData.Kind.ROCK, [], {
		"spawn_weight": [3, 3, 3, 1],
		"initial_weight": 4,
		"max_per_world": 14,
		"min_spacing": 2,
		"solid_from_stage": 0,
		"solid_size": Vector2(12, 8),
		"solid_offset": Vector2(0, 4),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"stone",
		"drop_amount": Vector2i(1, 2),
	})

	# 大石头：稀少，挡路，出的石材更多。
	_flora(&"boulder", &"FLORA_BOULDER", FloraData.Kind.ROCK, [], {
		"spawn_weight": [1, 1, 1, 0],
		"initial_weight": 1,
		"max_per_world": 5,
		"min_spacing": 3,
		"solid_from_stage": 0,
		"solid_size": Vector2(24, 10),
		"solid_offset": Vector2(0, 6),
		"tool_kind": ToolData.Kind.PICKAXE,
		"stamina_cost": 3,
		"drop_item_id": &"stone",
		"drop_amount": Vector2i(2, 3),
	})

	# 野花：两天开花，可以徒手采。
	_flora(&"flower", &"FLORA_FLOWER", FloraData.Kind.FLOWER, [1, 1], {
		"spawn_weight": [5, 4, 2, 0],
		"rain_bonus": 2,
		"initial_weight": 4,
		"max_per_world": 25,
		"grows_on_farmland": true,
		"pickable_by_hand": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"flower",
		"drop_amount": Vector2i(1, 1),
		"drop_chance": 0.8,
	})

	# 蘑菇：不生长，秋天雨后一夜之间冒出来，徒手采。
	_flora(&"mushroom", &"FLORA_MUSHROOM", FloraData.Kind.MUSHROOM, [], {
		"spawn_weight": [0, 1, 4, 0],
		"rain_bonus": 6,
		"max_per_world": 12,
		"min_spacing": 1,
		"pickable_by_hand": true,
		"tool_kind": ToolData.Kind.SICKLE,
		"stamina_cost": 1,
		"drop_item_id": &"mushroom",
		"drop_amount": Vector2i(1, 1),
	})


## 建一个野生植被资源并挂上阶段图。
func _flora(
	flora_id: StringName,
	name_key: StringName,
	kind: FloraData.Kind,
	days_per_stage: Array,
	overrides: Dictionary
) -> void:
	var data := FloraData.new()
	data.id = flora_id
	data.display_name_key = name_key
	data.kind = kind
	data.days_per_stage.clear()
	for days: int in days_per_stage:
		data.days_per_stage.append(days)
	# 注意：spawn_weight 是 Array[int]。Object.set() 对"类型化数组"会静默失败
	# （赋进去的是无类型 Array，属性保持默认值），所以这里必须逐项 append。
	if overrides.has("spawn_weight"):
		data.spawn_weight.clear()
		for weight: int in overrides["spawn_weight"]:
			data.spawn_weight.append(weight)
	for key: String in overrides:
		if key == "spawn_weight":
			continue
		data.set(key, overrides[key])
	data.sprite_sheet = _flora_sheet(flora_id)
	_save(data, FLORA_DIR.path_join("%s.tres" % flora_id))


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

	_tool_item(&"hoe", &"ITEM_HOE", &"TOOL_HOE_DESC", &"hoe")
	_tool_item(&"watering_can", &"ITEM_WATERING_CAN", &"TOOL_WATERING_CAN_DESC", &"watering_can")
	_tool_item(&"sickle", &"ITEM_SICKLE", &"TOOL_SICKLE_DESC", &"sickle")
	_tool_item(&"axe", &"ITEM_AXE", &"TOOL_AXE_DESC", &"axe")
	_tool_item(&"pickaxe", &"ITEM_PICKAXE", &"TOOL_PICKAXE_DESC", &"pickaxe")

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
	merchant.frames = _npc_frames(&"merchant")
	_save(merchant, NPC_DIR.path_join("merchant.tres"))

	var mayor := NpcData.new()
	mayor.id = &"mayor"
	mayor.display_name_key = &"NPC_MAYOR"
	mayor.default_dialogue = _load(DIALOGUE_DIR.path_join("mayor_greeting.tres"))
	mayor.frames = _npc_frames(&"mayor")
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
		_stock(&"hay", 20),
		_stock(&"chicken", 500),
		_stock(&"cow", 1200),
	] as Array[ShopStock]
	_save(shop, SHOP_DIR.path_join("general_store.tres"))


func _stock(item_id: StringName, price: int) -> ShopStock:
	var entry := ShopStock.new()
	entry.item_id = item_id
	entry.price_override = price
	entry.unlimited = true
	return entry


# ---------------------------------------------------------------- 工具方法

## 取作物生长图；缺图时返回 null（游戏会退回场景里的占位贴图）。
func _crop_sheet(crop_id: StringName) -> Texture2D:
	return _texture(CROP_SHEET_DIR.path_join("%s.png" % crop_id))


## 取野生植被的阶段表。
func _flora_sheet(flora_id: StringName) -> Texture2D:
	return _texture(FLORA_SHEET_DIR.path_join("%s.png" % flora_id))


## 取牲畜状态表。
func _animal_sheet(animal_id: StringName) -> Texture2D:
	return _texture(ANIMAL_SHEET_DIR.path_join("%s.png" % animal_id))


## 取道具图标。
func _item_icon(item_id: StringName) -> Texture2D:
	return _texture(ITEM_ICON_DIR.path_join("%s.png" % item_id))


## 取 NPC 动画。
func _npc_frames(npc_id: StringName) -> SpriteFrames:
	var path: String = NPC_FRAMES_DIR.path_join("npc_%s_frames.tres" % npc_id)
	if not ResourceLoader.exists(path):
		push_warning("缺少 NPC 动画 %s（先跑 tools/build_assets.sh）" % path)
		return null
	return ResourceLoader.load(path) as SpriteFrames


func _texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("缺少贴图 %s（先跑 tools/build_assets.sh）" % path)
		return null
	return ResourceLoader.load(path) as Texture2D


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
