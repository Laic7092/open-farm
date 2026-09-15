class_name Shop
extends RefCounted
## 商店交易逻辑（不依赖任何 UI）。
##
## [ShopData] 描述"货架上有什么"，本类负责"能不能买、买了扣多少钱、库存怎么变"。
## 把这些规则从界面里抽出来，就能直接用单元测试覆盖经济系统——
## 这类"数值 + 边界条件"的逻辑最容易出 bug，也最值得测。

## 交易成功 / 失败。
signal purchased(item_id: StringName, count: int, total: int)
signal sold(item_id: StringName, count: int, total: int)
## 交易被拒绝，[param reason_key] 是可直接展示的提示翻译键。
signal rejected(reason_key: StringName)

## 拒绝原因（同时就是提示文案的翻译键）。
const REASON_NO_MONEY: StringName = &"NOTIFY_NOT_ENOUGH_MONEY"
const REASON_NO_STOCK: StringName = &"NOTIFY_OUT_OF_STOCK"
const REASON_NO_ITEM: StringName = &"NOTIFY_NOTHING_HAPPENED"
const REASON_NO_SPACE: StringName = &"NOTIFY_INVENTORY_FULL"

## 静态定义。
var data: ShopData

## 依赖（由拥有者注入，不在方法体内按 Autoload 全局名获取）：
## [param _wallet] 需实现 has_flag / can_afford / spend / earn / record_shipped；
## [param _catalog] 需实现 get_item；
## [param _events] 需带 ui.transaction_completed 信号（通常传 EventBus）。
var _wallet
var _catalog
var _events

## 有限库存的剩余量：item_id → 剩余件数。
var _remaining: Dictionary[StringName, int] = {}


func _init(p_data: ShopData, p_wallet, p_catalog, p_events) -> void:
	data = p_data
	_wallet = p_wallet
	_catalog = p_catalog
	_events = p_events
	restock()


## 重置有限库存到初始值（每天开店时调用）。
func restock() -> void:
	_remaining.clear()
	if data == null:
		return
	for entry: ShopStock in data.stock:
		if entry != null and not entry.unlimited:
			_remaining[entry.item_id] = entry.initial_stock


## 当前季节日可购买的商品（考虑剧情旗标与限定日期）。
func available_entries(day_of_season: int) -> Array[ShopStock]:
	var result: Array[ShopStock] = []
	if data == null:
		return result
	for entry: ShopStock in data.stock:
		if entry == null or entry.item_id == &"":
			continue
		if entry.required_flag != &"" and not _wallet.has_flag(entry.required_flag):
			continue
		if not entry.is_available_on(day_of_season):
			continue
		result.append(entry)
	return result


## 单价。
func price_of(entry: ShopStock) -> int:
	if entry == null:
		return 0
	return entry.effective_price(_catalog.get_item(entry.item_id))


## 剩余库存；-1 表示无限。
func stock_left(entry: ShopStock) -> int:
	if entry == null:
		return 0
	if entry.unlimited:
		return -1
	return _remaining.get(entry.item_id, 0)


## 买下 [param count] 件。
func buy(entry: ShopStock, count: int, inventory: Inventory) -> bool:
	if entry == null or count <= 0 or inventory == null:
		return _reject(REASON_NO_ITEM)

	var total: int = price_of(entry) * count
	if total <= 0:
		return _reject(REASON_NO_ITEM)
	if not _wallet.can_afford(total):
		return _reject(REASON_NO_MONEY)

	var left: int = stock_left(entry)
	if left >= 0 and left < count:
		return _reject(REASON_NO_STOCK)
	if inventory.first_empty_index() < 0 and not inventory.has(entry.item_id):
		return _reject(REASON_NO_SPACE)

	if not _wallet.spend(total):
		return _reject(REASON_NO_MONEY)
	inventory.add(entry.item_id, count)
	if left >= 0:
		_remaining[entry.item_id] = left - count

	purchased.emit(entry.item_id, count, total)
	_events.ui.transaction_completed.emit(entry.item_id, count, total, true)
	return true


## 卖出 [param count] 件。
func sell(item_id: StringName, count: int, inventory: Inventory) -> bool:
	if inventory == null or count <= 0:
		return _reject(REASON_NO_ITEM)
	if not inventory.has(item_id, count):
		return _reject(REASON_NO_ITEM)

	var item: Variant = _catalog.get_item(item_id)
	if item == null or not item.sellable:
		return _reject(REASON_NO_ITEM)

	var total: int = buyback_price(item) * count
	if total <= 0:
		return _reject(REASON_NO_ITEM)
	if not data.buys_from_player:
		return _reject(REASON_NO_ITEM)

	inventory.remove(item_id, count)
	_wallet.earn(total)
	_wallet.record_shipped(count)

	sold.emit(item_id, count, total)
	_events.ui.transaction_completed.emit(item_id, count, total, false)
	return true


## 回收单价。
func buyback_price(item: ItemData) -> int:
	if data == null or item == null:
		return 0
	return data.buyback_price(item)


func _reject(reason_key: StringName) -> bool:
	rejected.emit(reason_key)
	return false
