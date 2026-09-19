class_name CookingRules
extends RefCounted
## 料理的纯规则：缺不缺材料、背包放不放得下。
##
## 与 [CropGrowth] / [CommissionRules] 同一层：只吃"已经查好的事实"
## （材料数量表 / 背包格子 / 静态数据），不依赖 [Database]、场景树或 Autoload，
## 因此 [code]tests/unit/test_cooking.gd[/code] 可以逐条断言。
##
## 运行时状态（做过哪些菜）由 [CookingState] 持有，"扣材料、出成品"由 [Cooking] 编排。


## 还缺哪些材料；材料齐了返回空数组。
##
## [param counts] 是 [code]item_id → 持有数量[/code]（由调用方从背包统计后传入）。
static func missing(
	recipe: RecipeData, counts: Dictionary[StringName, int]
) -> Array[RecipeIngredient]:
	var result: Array[RecipeIngredient] = []
	if recipe == null:
		return result
	for ingredient: RecipeIngredient in recipe.ingredients:
		if ingredient == null or ingredient.item_id == &"":
			continue
		if int(counts.get(ingredient.item_id, 0)) < ingredient.amount:
			result.append(ingredient)
	return result


## 材料是否齐备。
static func can_cook(recipe: RecipeData, counts: Dictionary[StringName, int]) -> bool:
	return recipe != null and missing(recipe, counts).is_empty()


## 背包里还能再放进多少件 [param item]。
##
## 空格按该道具的堆叠上限算，已有的同类堆只补剩余空间；别的道具占着的格子不计。
static func room_for(item: ItemData, slots: Array[InventorySlot]) -> int:
	if item == null or slots.is_empty():
		return 0
	var limit: int = maxi(item.stack_limit, 1)
	var room: int = 0
	for slot: InventorySlot in slots:
		if slot.is_empty():
			room += limit
		elif slot.item_id == item.id:
			room += maxi(limit - slot.count, 0)
	return room


## 扣掉 [param recipe] 的材料后，背包还能放进多少件 [param output]。
##
## 必须先算这一步：[method room_for] 只看当前格子，会漏掉"材料被吃掉后腾出来的格子"，
## 于是背包明明还装得下一盘菜，却因为材料占着地方而做不了。
## 移除顺序与 [method Inventory.remove] 一致（从后往前吃），只有被完全吃空的格子才算释放。
static func room_after_ingredients(
	recipe: RecipeData, output: ItemData, slots: Array[InventorySlot]
) -> int:
	if recipe == null or output == null or slots.is_empty():
		return 0
	var room: int = room_for(output, slots)
	var pending: Dictionary[StringName, int] = {}
	for ingredient: RecipeIngredient in recipe.ingredients:
		if ingredient == null or ingredient.item_id == &"":
			continue
		pending[ingredient.item_id] = int(pending.get(ingredient.item_id, 0)) + ingredient.amount
	for index: int in range(slots.size() - 1, -1, -1):
		var slot: InventorySlot = slots[index]
		if slot.is_empty() or not pending.has(slot.item_id):
			continue
		# 成品与材料同 id 时，这个格子释放的空间已由 room_for 算过，不能重复计。
		if slot.item_id == output.id:
			continue
		var take: int = mini(slot.count, int(pending[slot.item_id]))
		pending[slot.item_id] = int(pending[slot.item_id]) - take
		if take >= slot.count:
			room += maxi(output.stack_limit, 1)
	return room
