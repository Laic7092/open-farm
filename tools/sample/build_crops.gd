extends "res://tools/sample/sample_base.gd"
## crops：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
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


## 取作物生长图；缺图时返回 null（游戏会退回场景里的占位贴图）。
func _crop_sheet(crop_id: StringName) -> Texture2D:
	return _texture(CROP_SHEET_DIR.path_join("%s.png" % crop_id))
