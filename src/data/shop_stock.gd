@tool
class_name ShopStock
extends Resource
## 商店货架上的一件商品。

## 商品对应的 [ItemData.id]。
@export var item_id: StringName = &""
## 覆盖售价；为 0 时使用 [ItemData.buy_price]。
@export_range(0, 99999) var price_override: int = 0
## 是否无限库存。
@export var unlimited: bool = true
## 有限库存的初始数量。
@export_range(0, 999) var initial_stock: int = 0
## 需要哪个剧情旗标才会上架；留空表示无需条件。
@export var required_flag: StringName = &""
## 该商品每季可购买的天数范围（含端点，1 起算）；为空表示全季可买。
@export var available_days: Array[int] = []


## 实际售价。
func effective_price(item: ItemData) -> int:
	if price_override > 0:
		return price_override
	return item.buy_price if item != null else 0


## 在指定的季节日是否上架。
func is_available_on(day: int) -> bool:
	if available_days.is_empty():
		return true
	return available_days.has(day)
