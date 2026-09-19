@tool
class_name RecipeData
extends Resource
## 一条料理食谱（静态定义）。
##
## 食谱只描述"用什么、做出什么、什么时候解锁"：能不能做、怎么扣材料、
## 放不放得下都在纯静态的 [CookingRules] 与持有状态的 [Cooking] 单元里结算。
## 与其他域一致，新增一道菜 = 往 [code]res://data/recipes/[/code] 丢一个
## [code].tres[/code]，代码不用动。
##
## [b]解锁[/b]：开局就会做的菜 [member required_flag] 留空；需要村民长期目标 /
## 事件奖励的菜填一个旗标，由 [code]VillageGoals[/code] 在领奖时写进档案。

## 唯一标识（菜名）。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
## 做好后放进背包的道具 id。
@export var output_item_id: StringName = &""
## 一次做出几份。
@export_range(1, 99) var output_amount: int = 1
## 所需材料。
@export var ingredients: Array[RecipeIngredient] = []
## 解锁所需旗标（可空）；留空表示开局就会做。
@export var required_flag: StringName = &""


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if output_item_id == &"":
		problems.append("output_item_id 不能为空")
	if output_amount < 1:
		problems.append("output_amount 必须 >= 1")
	if ingredients.is_empty():
		problems.append("至少要有一味材料")
	for ingredient: RecipeIngredient in ingredients:
		if ingredient == null:
			problems.append("材料为空")
			continue
		for problem: String in ingredient.validate():
			problems.append(problem)
	return problems


func _to_string() -> String:
	return "RecipeData(%s → %s ×%d)" % [id, output_item_id, output_amount]
