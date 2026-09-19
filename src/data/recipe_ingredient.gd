@tool
class_name RecipeIngredient
extends Resource
## 食谱里的一味材料：道具 id + 数量。
##
## 拆成独立资源而不是两条平行数组（[code]item_ids[/code] / [code]amounts[/code]），
## 是为了让"数量"跟着"道具"走，增删材料时不会错位。
## 与 [ItemData] 一样，这是[b]不变的数据[/b]，运行时只读。

## 材料道具 id。
@export var item_id: StringName = &""
## 需要几件。
@export_range(1, 99) var amount: int = 1


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if item_id == &"":
		problems.append("item_id 不能为空")
	if amount < 1:
		problems.append("amount 必须 >= 1")
	return problems


func _to_string() -> String:
	return "RecipeIngredient(%s ×%d)" % [item_id, amount]
