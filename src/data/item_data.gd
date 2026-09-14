@tool
class_name ItemData
extends Resource
## 道具 / 物品的静态定义。
##
## 背包、商店、出货箱都以 [member id] 互相引用，避免任何硬编码的字符串常量散落各处。

enum Category {
	SEED,      ## 种子
	CROP,      ## 收获物
	TOOL,      ## 工具
	MATERIAL,  ## 素材（木材、石材……）
	FOOD,      ## 食物
	GIFT,      ## 礼物
	ANIMAL,    ## 牲畜（放入畜舍后成为活体）
}

## 唯一标识。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
## 描述翻译键。
@export var description_key: StringName = &""
@export var category: Category = Category.MATERIAL
## 商店买入价（玩家花钱）。
@export_range(0, 99999) var buy_price: int = 0
## 商店卖出价（玩家赚钱）。
@export_range(0, 99999) var sell_price: int = 0
## 单格堆叠上限。
@export_range(1, 999) var stack_limit: int = 99
## 是否可以在商店卖出。
@export var sellable: bool = true
## 图标。
@export var icon: Texture2D
## 工具类道具指向的 [ToolData] id。
@export var tool_id: StringName = &""
## 种子类道具指向的 [CropData] id。
@export var crop_id: StringName = &""
## 牲畜类道具指向的 [AnimalData] id。
@export var animal_id: StringName = &""


func is_stackable() -> bool:
	return stack_limit > 1


func is_tool() -> bool:
	return category == Category.TOOL


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if category == Category.TOOL and tool_id == &"":
		problems.append("工具类道具必须填写 tool_id")
	if category == Category.SEED and crop_id == &"":
		problems.append("种子类道具必须填写 crop_id")
	if category == Category.ANIMAL and animal_id == &"":
		problems.append("牲畜类道具必须填写 animal_id")
	if sell_price > buy_price and buy_price > 0:
		problems.append("sell_price 高于 buy_price，玩家可以无限刷钱")
	return problems


func _to_string() -> String:
	return "ItemData(%s)" % id
