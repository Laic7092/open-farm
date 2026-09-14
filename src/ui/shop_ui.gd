class_name ShopUi
extends Control
## 商店界面。
##
## 界面本身[b]不含任何价格 / 库存 / 找零逻辑[/b]——那些都在 [Shop] 里。
## 这里只做三件事：把货架画出来、把按钮点击翻译成 [method Shop.buy] / [method Shop.sell]、
## 把结果刷新到画面上。

@onready var title_label: Label = %TitleLabel
@onready var money_label: Label = %MoneyLabel
@onready var buy_list: ItemList = %BuyList
@onready var sell_list: ItemList = %SellList
@onready var buy_button: Button = %BuyButton
@onready var sell_button: Button = %SellButton
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

var _shop: Shop
var _entries: Array[ShopStock] = []
var _sellable_ids: Array[StringName] = []


func _ready() -> void:
	visible = false
	buy_button.text = Text.key(&"SHOP_UI_BUY")
	sell_button.text = Text.key(&"SHOP_UI_SELL")
	hint_label.text = Text.key(&"SHOP_UI_HINT")
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	buy_list.item_selected.connect(func(_index: int) -> void: _refresh_info())
	sell_list.item_selected.connect(func(_index: int) -> void: _refresh_sell_info())
	EventBus.money_changed.connect(func(_money: int, _delta: int) -> void: _refresh_money())


## 打开某家商店。
func open(shop_data: ShopData) -> void:
	if shop_data == null:
		push_error("ShopUi: 商店数据为空")
		return
	_shop = Shop.new(shop_data)
	_shop.purchased.connect(_on_transaction)
	_shop.sold.connect(_on_transaction)
	_shop.rejected.connect(_on_rejected)
	title_label.text = Text.key(shop_data.display_name_key)
	refresh()
	visible = true


func close() -> void:
	visible = false
	_shop = null


## 重建两个列表。
func refresh() -> void:
	_refresh_money()
	if _shop == null:
		return
	_refresh_buy_list()
	_refresh_sell_list()
	_refresh_info()


func _refresh_money() -> void:
	money_label.text = Text.format(&"HUD_MONEY", {"value": GameState.money})


func _refresh_buy_list() -> void:
	_entries = _shop.available_entries(GameClock.date.day)
	buy_list.clear()
	for entry: ShopStock in _entries:
		var item := Database.get_item(entry.item_id)
		var price: int = _shop.price_of(entry)
		var left: int = _shop.stock_left(entry)
		var stock_text := (
			Text.key(&"SHOP_UI_UNLIMITED")
			if left < 0
			else Text.format(&"SHOP_UI_STOCK", {"value": left})
		)
		buy_list.add_item(
			"%s   %s   [%s]" % [
				Text.item_name(entry.item_id),
				Text.format(&"SHOP_UI_PRICE", {"value": price}),
				stock_text,
			]
		)
		buy_list.set_item_disabled(buy_list.item_count - 1, item == null)


func _refresh_sell_list() -> void:
	var inventory := _player_inventory()
	sell_list.clear()
	_sellable_ids.clear()
	if inventory == null:
		return
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty() or _sellable_ids.has(slot.item_id):
			continue
		var item := Database.get_item(slot.item_id)
		if item == null or not item.sellable:
			continue
		_sellable_ids.append(slot.item_id)
		var unit: int = _shop.buyback_price(item)
		sell_list.add_item(
			"%s ×%d   %s" % [
				Text.item_name(slot.item_id),
				slot.count,
				Text.format(&"SHOP_UI_PRICE", {"value": unit}),
			]
		)


func _refresh_info() -> void:
	var index := buy_list.get_selected_items()
	if index.is_empty():
		info_label.text = ""
		return
	var entry: ShopStock = _entries[index[0]]
	info_label.text = "%s  %s" % [
		Text.item_name(entry.item_id),
		Text.format(&"SHOP_UI_PRICE", {"value": _shop.price_of(entry)}),
	]


func _refresh_sell_info() -> void:
	var index := sell_list.get_selected_items()
	if index.is_empty():
		info_label.text = ""
		return
	var item := Database.get_item(_sellable_ids[index[0]])
	if item != null:
		info_label.text = "%s  %s" % [
			Text.item_name(item.id),
			Text.format(&"SHOP_UI_PRICE", {"value": _shop.buyback_price(item)}),
		]


# ---------------------------------------------------------------- 交互

func _on_buy_pressed() -> void:
	if _shop == null:
		return
	var inventory := _player_inventory()
	var index := buy_list.get_selected_items()
	if inventory == null or index.is_empty() or index[0] >= _entries.size():
		return
	_shop.buy(_entries[index[0]], 1, inventory)


func _on_sell_pressed() -> void:
	if _shop == null:
		return
	var inventory := _player_inventory()
	var index := sell_list.get_selected_items()
	if inventory == null or index.is_empty() or index[0] >= _sellable_ids.size():
		return
	_shop.sell(_sellable_ids[index[0]], 1, inventory)


func _on_transaction(_item_id: StringName, _count: int, _total: int) -> void:
	refresh()


func _on_rejected(reason_key: StringName) -> void:
	EventBus.notification_requested.emit(reason_key, {})


func _player_inventory() -> Inventory:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	return player.inventory if player != null else null
