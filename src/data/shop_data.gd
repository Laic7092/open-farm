@tool
class_name ShopData
extends Resource
## 商店定义。
##
## 商店只描述"卖什么、按什么价格买卖"，具体买卖逻辑在 [Shop] 中，
## 这样经济规则可以脱离 UI 与场景单独做单元测试。

## 唯一标识。
@export var id: StringName = &""
## 店名翻译键。
@export var display_name_key: StringName = &""
## 出售给玩家的商品列表。
@export var stock: Array[ShopStock] = []
## 是否回收玩家的物品。
@export var buys_from_player: bool = true
## 回收价倍率（1.0 = 按 [ItemData.sell_price]）。
@export_range(0.0, 5.0, 0.05) var sell_multiplier: float = 1.0


## 某件商品的回收价。
func buyback_price(item: ItemData) -> int:
	if item == null or not item.sellable:
		return 0
	return maxi(int(floorf(float(item.sell_price) * sell_multiplier)), 0)


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	for entry: ShopStock in stock:
		if entry == null or entry.item_id == &"":
			problems.append("stock 中存在空的或缺少 item_id 的商品")
	return problems


func _to_string() -> String:
	return "ShopData(%s, %d items)" % [id, stock.size()]
