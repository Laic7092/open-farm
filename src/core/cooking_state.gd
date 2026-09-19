class_name CookingState
extends Resource
## 料理进度的可存档状态（Resource）。
##
## 只记"每道菜做过几次"：静态食谱在 [RecipeData]，材料判定在 [CookingRules]。
## 做过一次的菜就记进 [b]食谱[/b]（[method is_known]），供图鉴式收集与
## 长期村庄目标统计；资源不依赖 Autoload，可由 [Main] 持有或测试里单独 new。

## recipe_id → 做过的次数。
var cooked: Dictionary[StringName, int] = {}


func reset() -> void:
	cooked.clear()


## 记一次烹饪；返回 true 表示这是第一次做这道菜（新学一道食谱）。
func record(recipe_id: StringName) -> bool:
	if recipe_id == &"":
		return false
	var first_time: bool = not cooked.has(recipe_id)
	cooked[recipe_id] = int(cooked.get(recipe_id, 0)) + 1
	return first_time


## 做过几次。
func times(recipe_id: StringName) -> int:
	return int(cooked.get(recipe_id, 0))


## 是否已经做过（记进食谱）。
func is_known(recipe_id: StringName) -> bool:
	return cooked.has(recipe_id)


## 已学会的食谱数量。
func known_count() -> int:
	return cooked.size()


func to_dict() -> Dictionary:
	var data := {}
	for recipe_id: StringName in cooked:
		data[String(recipe_id)] = int(cooked[recipe_id])
	return {"cooked": data}


func from_dict(data: Dictionary) -> void:
	reset()
	var raw: Variant = data.get("cooked", {})
	if raw is Dictionary:
		for key: Variant in raw:
			var recipe_id := StringName(str(key))
			if recipe_id != &"":
				cooked[recipe_id] = maxi(int(raw[key]), 0)
