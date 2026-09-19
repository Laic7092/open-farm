class_name Cooking
extends RefCounted
## 料理单元：持有食谱进度，负责"能不能做、做一道菜"。
##
## 与 [Commission] / [Museum] 同一形态：静态数据在 [RecipeData]，
## 材料判定在纯静态的 [CookingRules]，本单元只做编排。
## 结算所需的档案 / 背包都靠注入，不做全局查找，因此可以脱离界面与场景树单测。
##
## [b]为什么"扣材料"和"出成品"绑在一起[/b]：背包放不下时先扣材料会把食材吞掉，
## 所以本单元先问 [method CookingRules.room_for]，放得下才动手。

## 烹饪结果；界面据此翻译成提示与音效。
enum Result {
	COOKED,   ## 成功：已扣材料、放进成品（[member COOKED] 首次做还会记新食谱）
	UNKNOWN,  ## 没有这道菜的数据 / 成品道具缺失
	LOCKED,   ## 还没解锁（缺 [member RecipeData.required_flag]）
	MISSING,  ## 材料不足
	FULL,     ## 背包放不下成品
}

## 食谱进度。
var state: CookingState

var _profile: PlayerProfile
var _inventory_provider: Callable = Callable()


func _init(p_state: CookingState = null) -> void:
	state = p_state if p_state != null else CookingState.new()


## 注入结算所需协作者：玩家档案（解锁旗标）与"当前背包"的提供者。
func bind(profile: PlayerProfile, inventory_provider: Callable) -> void:
	_profile = profile
	_inventory_provider = inventory_provider


## 全部食谱（按 id 排序）。
func recipes() -> Array[RecipeData]:
	return Database.recipe_list()


## 已解锁的食谱。
func available_recipes() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe: RecipeData in recipes():
		if is_unlocked(recipe):
			result.append(recipe)
	return result


## 是否满足解锁条件。
func is_unlocked(recipe: RecipeData) -> bool:
	if recipe == null:
		return false
	if recipe.required_flag == &"":
		return true
	return _profile != null and _profile.has_flag(recipe.required_flag)


## 尚缺的材料；材料齐时返回空数组。
func missing(recipe: RecipeData) -> Array[RecipeIngredient]:
	return CookingRules.missing(recipe, _counts(recipe))


## 背包里某道具的持有量；供界面展示材料够不够。
func count_of(item_id: StringName) -> int:
	var inventory := _current_inventory()
	return inventory.count_of(item_id) if inventory != null else 0


## 做一道菜：扣材料、出成品、记食谱。
func cook(recipe_id: StringName) -> Result:
	var recipe := Database.get_recipe(recipe_id)
	if recipe == null:
		return Result.UNKNOWN
	if not is_unlocked(recipe):
		return Result.LOCKED
	var output := Database.get_item(recipe.output_item_id)
	if output == null:
		return Result.UNKNOWN
	var inventory := _current_inventory()
	if inventory == null:
		return Result.MISSING
	if not CookingRules.can_cook(recipe, _counts(recipe)):
		return Result.MISSING
	if CookingRules.room_after_ingredients(recipe, output, inventory.slots) < recipe.output_amount:
		return Result.FULL
	for ingredient: RecipeIngredient in recipe.ingredients:
		inventory.remove(ingredient.item_id, ingredient.amount)
	inventory.add(recipe.output_item_id, recipe.output_amount)
	state.record(recipe.id)
	return Result.COOKED


# ---------------------------------------------------------------- 内部

## 背包里与这道菜相关的材料数量表。
func _counts(recipe: RecipeData) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	var inventory := _current_inventory()
	if inventory == null or recipe == null:
		return counts
	for ingredient: RecipeIngredient in recipe.ingredients:
		if ingredient == null or ingredient.item_id == &"":
			continue
		if not counts.has(ingredient.item_id):
			counts[ingredient.item_id] = inventory.count_of(ingredient.item_id)
	return counts


func _current_inventory() -> Inventory:
	if not _inventory_provider.is_valid():
		return null
	return _inventory_provider.call() as Inventory
