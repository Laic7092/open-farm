class_name ShopUi
extends Control
## 商店界面。
##
## 界面本身[b]不含任何价格 / 库存 / 找零逻辑[/b]——那些都在 [Shop] 里。
## 这里只做三件事：把货架画出来、把按键翻译成 [method Shop.buy] / [method Shop.sell]、
## 把结果刷新到画面上。
##
## [b]操作（纯键盘）[/b]：WASD / 方向键选，[code]A[/code] / [code]D[/code] 换左右两个列表，
## [code]E[/code] / 回车 / 空格成交，[code]Esc[/code] 离开。
##
## 导航不交给 Godot 的焦点系统：左边购买、右边卖出是两块 [ItemList]，
## 而 [ItemList] 会把上下左右方向键全部吃掉（见其 [code]_gui_input[/code]），
## 焦点永远出不去。所以在 [method _input] 里统一翻译方向键与 WASD，
## 再标记事件已处理；只有"当前在哪一侧"这一个状态。

## 当前操作的是哪一侧。
enum ShopSide {
	BUY,   ## 左边的购买列表
	SELL,  ## 右边的卖出列表
}

@onready var title_label: Label = %TitleLabel
@onready var money_label: Label = %MoneyLabel
@onready var buy_list: ItemList = %BuyList
@onready var sell_list: ItemList = %SellList
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

var _shop: Shop
var _entries: Array[ShopStock] = []
var _sellable_ids: Array[StringName] = []
var _side: ShopSide = ShopSide.BUY

## 由 [UiRoot] 在组合根注入；[ShopUi] 不按 Autoload 全局名取依赖。
var _wallet
var _catalog
var _events
var _clock


func _ready() -> void:
	visible = false
	hint_label.text = Text.key(&"SHOP_UI_HINT")
	buy_list.item_selected.connect(func(_index: int) -> void: _refresh_info())
	sell_list.item_selected.connect(func(_index: int) -> void: _refresh_sell_info())


## 注入运行时依赖。必须在 [method open] 之前调用。
func configure(wallet, catalog, events, clock) -> void:
	_wallet = wallet
	_catalog = catalog
	_events = events
	_clock = clock
	if _events != null and not _events.money_changed.is_connected(_on_money_changed):
		_events.money_changed.connect(_on_money_changed)


## 打开某家商店。
func open(shop_data: ShopData) -> void:
	if shop_data == null:
		push_error("ShopUi: 商店数据为空")
		return
	if _wallet == null or _catalog == null or _events == null or _clock == null:
		push_error("ShopUi: 未注入依赖，无法打开商店")
		return
	_shop = Shop.new(shop_data, _wallet, _catalog, _events)
	_shop.purchased.connect(_on_transaction)
	_shop.sold.connect(_on_transaction)
	_shop.rejected.connect(_on_rejected)
	title_label.text = Text.key(shop_data.display_name_key)
	_side = ShopSide.BUY
	refresh()
	visible = true
	_focus_side()


func close() -> void:
	visible = false
	_shop = null


## 重建两个列表。
##
## 重建会清空列表，所以先记下两边的选中行，重建后按（夹紧的）原下标恢复，
## 否则键盘玩家每买一次就要重新选一遍。
func refresh() -> void:
	_refresh_money()
	if _shop == null:
		return
	var buy_index := _selected_index(buy_list)
	var sell_index := _selected_index(sell_list)
	_refresh_buy_list()
	_refresh_sell_list()
	_restore_selection(buy_list, buy_index)
	_restore_selection(sell_list, sell_index)
	_refresh_info_for_side()


func _refresh_money() -> void:
	if _wallet == null:
		return
	money_label.text = Text.format(&"HUD_MONEY", {"value": _wallet.money})


func _refresh_buy_list() -> void:
	_entries = _shop.available_entries(_clock.date.day)
	buy_list.clear()
	for entry: ShopStock in _entries:
		var item: Variant = _catalog.get_item(entry.item_id)
		var price: int = _shop.price_of(entry)
		var left: int = _shop.stock_left(entry)
		var stock_text := (
			Text.key(&"SHOP_UI_UNLIMITED")
			if left < 0
			else Text.format(&"SHOP_UI_STOCK", {"value": left})
		)
		buy_list.add_item(
			"%s   %s   [%s]" % [
				Text.item_name(_catalog.get_item(entry.item_id)),
				Text.format(&"SHOP_UI_PRICE", {"value": price}),
				stock_text,
			]
		)
		var row := buy_list.item_count - 1
		if item != null and item.icon != null:
			buy_list.set_item_icon(row, item.icon)
		buy_list.set_item_disabled(row, item == null)


func _refresh_sell_list() -> void:
	var inventory := _player_inventory()
	sell_list.clear()
	_sellable_ids.clear()
	if inventory == null:
		return
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty() or _sellable_ids.has(slot.item_id):
			continue
		var item: Variant = _catalog.get_item(slot.item_id)
		if item == null or not item.sellable:
			continue
		_sellable_ids.append(slot.item_id)
		var unit: int = _shop.buyback_price(item)
		sell_list.add_item(
			"%s ×%d   %s" % [
				Text.item_name(_catalog.get_item(slot.item_id)),
				slot.count,
				Text.format(&"SHOP_UI_PRICE", {"value": unit}),
			]
		)
		if item.icon != null:
			sell_list.set_item_icon(sell_list.item_count - 1, item.icon)


func _refresh_info() -> void:
	var index := _selected_index(buy_list)
	if index < 0 or index >= _entries.size():
		info_label.text = ""
		return
	var entry: ShopStock = _entries[index]
	info_label.text = "%s  %s" % [
		Text.item_name(_catalog.get_item(entry.item_id)),
		Text.format(&"SHOP_UI_PRICE", {"value": _shop.price_of(entry)}),
	]


func _refresh_sell_info() -> void:
	var index := _selected_index(sell_list)
	if index < 0 or index >= _sellable_ids.size():
		info_label.text = ""
		return
	var item: Variant = _catalog.get_item(_sellable_ids[index])
	if item != null:
		info_label.text = "%s  %s" % [
			Text.item_name(item),
			Text.format(&"SHOP_UI_PRICE", {"value": _shop.buyback_price(item)}),
		]


## 按当前所在的一侧刷新底部说明。
func _refresh_info_for_side() -> void:
	if _side == ShopSide.SELL:
		_refresh_sell_info()
	else:
		_refresh_info()


func _on_money_changed(_money: int, _delta: int) -> void:
	if visible:
		_refresh_money()


# ---------------------------------------------------------------- 键盘导航

## 商店可见时独占方向键与 WASD。
##
## 用 [code]_input()[/code] 而不是 [code]_unhandled_input()[/code]：后者发生在 GUI 之后，
## 方向键那时已经被 [ItemList] 吃掉了。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _navigate(event):
		get_viewport().set_input_as_handled()


## 翻译一次按键；返回 true 表示这次事件属于商店。
func _navigate(event: InputEvent) -> bool:
	# 允许 echo：按住方向键 / WASD 连续移动。
	if event.is_action_pressed(&"ui_up", true):
		_move_cursor(-1)
	elif event.is_action_pressed(&"ui_down", true):
		_move_cursor(1)
	elif event.is_action_pressed(&"ui_left", true):
		_switch_side(ShopSide.BUY)
	elif event.is_action_pressed(&"ui_right", true):
		_switch_side(ShopSide.SELL)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool"):
		_confirm()
	else:
		return false
	return true


## 在当前列表里上下移动光标。
func _move_cursor(step: int) -> void:
	var list := _active_list()
	if list.item_count <= 0:
		return
	var current := _selected_index(list)
	var next: int = clampi(current + step, 0, list.item_count - 1)
	if next == current:
		return
	list.select(next)
	list.ensure_current_is_visible()
	_refresh_info_for_side()
	EventBus.ui_sound_requested.emit(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)


## 左右切换列表；同一侧时什么也不做。
func _switch_side(side: ShopSide) -> void:
	if _side == side:
		return
	_side = side
	var list := _active_list()
	_restore_selection(list, _selected_index(list))
	_focus_side()
	_refresh_info_for_side()
	EventBus.ui_sound_requested.emit(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)


## 把焦点交给当前列表，让金边焦点框落在正确的一侧。
func _focus_side() -> void:
	_active_list().grab_focus()


## 成交：买或卖当前列表中选中的那一件。
func _confirm() -> void:
	if _side == ShopSide.SELL:
		_on_sell_pressed()
	else:
		_on_buy_pressed()


func _active_list() -> ItemList:
	return sell_list if _side == ShopSide.SELL else buy_list


func _selected_index(list: ItemList) -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


## 选中第 [param index] 行；列表为空时什么也不做，越界会夹到最近一行。
func _restore_selection(list: ItemList, index: int) -> void:
	if list.item_count <= 0:
		return
	list.select(clampi(index, 0, list.item_count - 1))


# ---------------------------------------------------------------- 交易

func _on_buy_pressed() -> void:
	if _shop == null:
		return
	var inventory := _player_inventory()
	var index := _selected_index(buy_list)
	if inventory == null or index < 0 or index >= _entries.size():
		return
	_shop.buy(_entries[index], 1, inventory)


func _on_sell_pressed() -> void:
	if _shop == null:
		return
	var inventory := _player_inventory()
	var index := _selected_index(sell_list)
	if inventory == null or index < 0 or index >= _sellable_ids.size():
		return
	_shop.sell(_sellable_ids[index], 1, inventory)


func _on_transaction(_item_id: StringName, _count: int, _total: int) -> void:
	refresh()


func _on_rejected(reason_key: StringName) -> void:
	if _events != null:
		_events.notification_requested.emit(reason_key, {})


func _player_inventory() -> Inventory:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	return player.inventory if player != null else null
