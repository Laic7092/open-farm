class_name FeedTrough
extends Interactable
## 饲料槽：一次性喂饱同一座畜舍里所有还饿着的牲畜。
##
## 作为 [AnimalPen] 的子节点，building_id 直接取自父节点，
## 避免"槽和舍对不上"这种配置错误。

## 所属畜舍。
func pen() -> AnimalPen:
	return get_parent() as AnimalPen


func manager() -> LivestockManager:
	var owner_pen := pen()
	return owner_pen.manager() if owner_pen != null else null


func interact(actor: Node2D) -> void:
	super.interact(actor)
	var player := actor as Player
	var owner_pen := pen()
	var mgr := manager()
	if player == null or owner_pen == null or mgr == null:
		return

	if mgr.hungry_count(owner_pen.building_id) <= 0:
		EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMALS_CONTENT", {})
		return

	var fed: int = mgr.feed(owner_pen.building_id, player.inventory)
	if fed > 0:
		EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMAL_FED", {"count": fed})
	else:
		EventBus.ui.notification_requested.emit(&"NOTIFY_NO_FEED", {})
