extends "res://tools/sample/sample_base.gd"
## recipes：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 一条食谱 = 一组 (道具, 数量) 与一个成品。产物道具与显示名统一走
## [code]ITEM_<ID>[/code] / [code]RECIPE_<ID>[/code] 约定（见 assets/i18n/content.csv）。
## 材料都取自既有内容（作物 / 畜产 / 鱼 / 蘑菇），于是料理把已有循环串成经济闭环。
##
## 升级奖励的菜（南瓜派 / 金枪鱼刺身）用 [code]required_flag[/code] 锁着，
## 旗标由 tools/sample/build_goals.gd 的长期村庄目标发放——两处同名即是接口。

## (id, [(item_id, amount), ...], required_flag)
const RECIPES: Array = [
	[&"veggie_salad", [[&"turnip", 2], [&"tomato", 1]], &""],
	[&"omelette", [[&"egg", 2], [&"milk", 1]], &""],
	[&"mushroom_soup", [[&"mushroom", 2], [&"milk", 1]], &""],
	[&"grilled_fish", [[&"crucian", 1]], &""],
	[&"fish_stew", [[&"sardine", 1], [&"mackerel", 1], [&"mushroom", 1]], &""],
	[&"strawberry_jam", [[&"strawberry", 2]], &""],
	[&"pumpkin_pie", [[&"pumpkin", 1], [&"egg", 1], [&"milk", 1]], &"recipe_pumpkin_pie"],
	[&"tuna_sashimi", [[&"tuna", 1]], &"recipe_tuna_sashimi"],
]


func build() -> void:
	for entry: Array in RECIPES:
		_recipe(entry[0], entry[1], entry[2])


func _recipe(recipe_id: StringName, ingredients: Array, required_flag: StringName) -> void:
	var recipe := RecipeData.new()
	recipe.id = recipe_id
	recipe.display_name_key = StringName("RECIPE_%s" % String(recipe_id).to_upper())
	recipe.output_item_id = recipe_id
	recipe.output_amount = 1
	recipe.required_flag = required_flag
	var list: Array[RecipeIngredient] = []
	for pair: Array in ingredients:
		var ingredient := RecipeIngredient.new()
		ingredient.item_id = pair[0]
		ingredient.amount = int(pair[1])
		list.append(ingredient)
	recipe.ingredients = list
	_save(recipe, RECIPE_DIR.path_join("%s.tres" % recipe_id))
