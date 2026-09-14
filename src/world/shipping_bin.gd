class_name ShippingBin
extends Interactable
## 出货箱：把背包里所有可出售的东西一次性折算成金钱。
##
## 骨架阶段用"一次性全卖"简化了牧场物语原作的"逐件投放 + 隔天结算"，
## 接口保持不变，后续把它换成 [code]ship(item_id, count)[/code] 即可。

func _ready() -> void:
	prompt_key = &"PROMPT_SHIPPING_BIN"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	var player := actor as Player
	if player == null:
		return

	# 先收集再移除：遍历过程中修改背包容易漏项或重复计数。
	var entries: Array[InventorySlot] = []
	for slot: InventorySlot in player.inventory.slots:
		if slot.is_empty():
			continue
		var item := Database.get_item(slot.item_id)
		if item == null or not item.sellable or item.category == ItemData.Category.TOOL:
			continue
		entries.append(InventorySlot.new(slot.item_id, slot.count))

	if entries.is_empty():
		EventBus.notification_requested.emit(&"NOTIFY_NOTHING_TO_SHIP", {})
		return

	var total: int = 0
	var shipped: int = 0
	for entry: InventorySlot in entries:
		var item := Database.get_item(entry.item_id)
		if not player.inventory.remove(entry.item_id, entry.count):
			continue
		total += item.sell_price * entry.count
		shipped += entry.count

	if total <= 0:
		EventBus.notification_requested.emit(&"NOTIFY_NOTHING_TO_SHIP", {})
		return

	GameState.earn(total)
	GameState.record_shipped(shipped)
	EventBus.notification_requested.emit(
		&"NOTIFY_SHIPPED", {"count": shipped, "total": total}
	)
