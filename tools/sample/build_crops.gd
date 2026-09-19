extends "res://tools/sample/sample_base.gd"
## crops：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 每季 6 种作物（v0.5「内容广度」）。数值只是一张表，形状 / 配色在
## [code]src/art/crop_looks.gd[/code]，道具与图标由
## [code]build_items.gd[/code] / [code]tools/art/generate_items.gd[/code] 按同一份表生成。

const CROPS: Array[Dictionary] = [
	# ------------------------------------------------------------ 春（6）
	{
		"id": &"turnip", "season": Season.Type.SPRING, "days": [1, 1, 1, 1],
		"seed": 20, "sell": 45, "bonus": 0.1,
	},
	{
		"id": &"potato", "season": Season.Type.SPRING, "days": [2, 2, 2],
		"seed": 35, "sell": 90,
	},
	{
		"id": &"strawberry", "season": Season.Type.SPRING, "days": [2, 2, 2, 2],
		"seed": 60, "sell": 110, "regrow": 2,
	},
	{
		"id": &"cabbage", "season": Season.Type.SPRING, "days": [2, 2, 2, 3],
		"seed": 45, "sell": 120,
	},
	{
		"id": &"onion", "season": Season.Type.SPRING, "days": [1, 2, 2],
		"seed": 25, "sell": 60, "bonus": 0.15,
	},
	{
		"id": &"tulip", "season": Season.Type.SPRING, "days": [2, 2, 2],
		"seed": 30, "sell": 70,
	},
	# ------------------------------------------------------------ 夏（6）
	{
		"id": &"tomato", "season": Season.Type.SUMMER, "days": [2, 2, 2, 2],
		"seed": 50, "sell": 70, "regrow": 3,
	},
	{
		"id": &"corn", "season": Season.Type.SUMMER, "days": [2, 2, 2, 2, 2],
		"seed": 80, "sell": 150, "regrow": 4,
	},
	{
		"id": &"melon", "season": Season.Type.SUMMER, "days": [3, 3, 3, 3],
		"seed": 90, "sell": 250,
	},
	{
		"id": &"eggplant", "season": Season.Type.SUMMER, "days": [2, 2, 2],
		"seed": 55, "sell": 95, "regrow": 3,
	},
	{
		"id": &"sunflower", "season": Season.Type.SUMMER, "days": [2, 2, 2, 2],
		"seed": 45, "sell": 105,
	},
	{
		"id": &"pineapple", "season": Season.Type.SUMMER, "days": [3, 3, 3, 3],
		"seed": 120, "sell": 300, "regrow": 5,
	},
	# ------------------------------------------------------------ 秋（6）
	{
		"id": &"pumpkin", "season": Season.Type.FALL, "days": [3, 3, 3, 3],
		"seed": 70, "sell": 220,
	},
	{
		"id": &"carrot", "season": Season.Type.FALL, "days": [1, 2, 2],
		"seed": 30, "sell": 75, "bonus": 0.1,
	},
	{
		"id": &"spinach", "season": Season.Type.FALL, "days": [2, 2, 2],
		"seed": 35, "sell": 85,
	},
	{
		"id": &"sweet_potato", "season": Season.Type.FALL, "days": [2, 2, 3, 2],
		"seed": 55, "sell": 140,
	},
	{
		"id": &"grape", "season": Season.Type.FALL, "days": [2, 2, 2, 3],
		"seed": 85, "sell": 160, "regrow": 4,
	},
	{
		"id": &"chrysanthemum", "season": Season.Type.FALL, "days": [2, 2, 2],
		"seed": 40, "sell": 95,
	},
	# ------------------------------------------------------------ 冬（6）
	{
		"id": &"bok_choy", "season": Season.Type.WINTER, "days": [1, 2, 2],
		"seed": 30, "sell": 80, "bonus": 0.1,
	},
	{
		"id": &"broccoli", "season": Season.Type.WINTER, "days": [2, 2, 3],
		"seed": 50, "sell": 130,
	},
	{
		"id": &"snow_pea", "season": Season.Type.WINTER, "days": [2, 2, 2],
		"seed": 45, "sell": 90, "regrow": 3,
	},
	{
		"id": &"white_radish", "season": Season.Type.WINTER, "days": [2, 2, 2, 2],
		"seed": 40, "sell": 110,
	},
	{
		"id": &"kale", "season": Season.Type.WINTER, "days": [2, 2, 3],
		"seed": 45, "sell": 115,
	},
	{
		"id": &"wintersweet", "season": Season.Type.WINTER, "days": [2, 2, 3],
		"seed": 55, "sell": 130,
	},
]


func build() -> void:
	for entry: Dictionary in CROPS:
		var crop := CropData.new()
		var crop_id: StringName = entry["id"]
		crop.id = crop_id
		crop.display_name_key = _crop_name_key(crop_id)
		crop.seed_item_id = StringName("%s_seed" % crop_id)
		crop.harvest_item_id = crop_id
		crop.harvest_amount = int(entry.get("harvest_amount", 1))
		crop.days_per_stage = _int_array(entry["days"])
		crop.seasons = _season_array([entry["season"]])
		crop.regrow_days = int(entry.get("regrow", 0))
		crop.seed_price = int(entry["seed"])
		crop.base_sell_price = int(entry["sell"])
		crop.bonus_yield_chance = float(entry.get("bonus", 0.0))
		crop.quality_silver_chance = clampf(
			float(entry.get("silver", 0.05 + float(crop.base_sell_price) / 2000.0)), 0.0, 0.9
		)
		crop.quality_gold_chance = clampf(
			float(entry.get("gold", crop.quality_silver_chance * 0.25)), 0.0, 0.9
		)
		crop.sprite_sheet = _crop_sheet(crop_id)
		_save(crop, CROP_DIR.path_join("%s.tres" % crop_id))


## 作物显示名翻译键；与 i18n 的 CROP_<ID> 约定一致。
static func _crop_name_key(crop_id: StringName) -> StringName:
	return StringName("CROP_%s" % String(crop_id).to_upper())


## 取作物生长图；缺图时返回 null（游戏会退回场景里的占位贴图）。
func _crop_sheet(crop_id: StringName) -> Texture2D:
	return _texture(CROP_SHEET_DIR.path_join("%s.png" % crop_id))


func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	result.assign(values)
	return result


func _season_array(values: Array) -> Array[Season.Type]:
	var result: Array[Season.Type] = []
	result.assign(values)
	return result
