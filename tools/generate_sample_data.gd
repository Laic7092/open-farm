extends SceneTree
## 示例数据生成器（入口）：按依赖顺序调用 [code]tools/sample/build_*.gd[/code]。
##
## 生成出来的资源就是普通的、可在编辑器里继续编辑的资源——之后策划直接在 Inspector
## 里改数值即可；只有"重置示例数据"时才需要重新运行本脚本。
##
## 它同时负责把 [code]tools/art/*.gd[/code] 生成的贴图挂到数据上
## （[code]icon[/code] / [code]sprite_sheet[/code] / [code]frames[/code]），
## 因此请在跑完 [code]tools/build_assets.sh[/code] 之后再运行本脚本。
##
## 用法：[code]godot --headless --path . -s res://tools/generate_sample_data.gd[/code]

const SampleBase := preload("res://tools/sample/sample_base.gd")
const BuildTools := preload("res://tools/sample/build_tools.gd")
const BuildCrops := preload("res://tools/sample/build_crops.gd")
const BuildAnimals := preload("res://tools/sample/build_animals.gd")
const BuildBuildings := preload("res://tools/sample/build_buildings.gd")
const BuildFlora := preload("res://tools/sample/build_flora.gd")
const BuildItems := preload("res://tools/sample/build_items.gd")
const BuildFish := preload("res://tools/sample/build_fish.gd")
const BuildDialogues := preload("res://tools/sample/build_dialogues.gd")
const BuildSchedules := preload("res://tools/sample/build_schedules.gd")
const BuildNpcs := preload("res://tools/sample/build_npcs.gd")
const BuildShops := preload("res://tools/sample/build_shops.gd")
const BuildCommissions := preload("res://tools/sample/build_commissions.gd")
const BuildFestivals := preload("res://tools/sample/build_festivals.gd")
const BuildEvents := preload("res://tools/sample/build_events.gd")
const BuildMineStrata := preload("res://tools/sample/build_mine_strata.gd")
const BuildRecipes := preload("res://tools/sample/build_recipes.gd")
const BuildFestivalGames := preload("res://tools/sample/build_festival_games.gd")
const BuildGoals := preload("res://tools/sample/build_goals.gd")


func _initialize() -> void:
	SampleBase.ensure_dirs()

	BuildTools.new().build()
	BuildCrops.new().build()
	BuildAnimals.new().build()
	BuildBuildings.new().build()
	BuildFlora.new().build()
	BuildItems.new().build()
	BuildFish.new().build()
	BuildDialogues.new().build()
	BuildSchedules.new().build()
	BuildNpcs.new().build()
	BuildShops.new().build()
	BuildCommissions.new().build()
	# 料理引用道具（成品 / 材料），必须排在 BuildItems 之后。
	BuildRecipes.new().build()
	# 节日引用小游戏 id，小游戏先写。
	BuildFestivalGames.new().build()
	BuildFestivals.new().build()
	BuildEvents.new().build()
	BuildMineStrata.new().build()
	# 长期目标最后写：它的 reward_flag 就是两道锁着的食谱旗标。
	BuildGoals.new().build()

	print("示例数据生成完成")
	quit()
