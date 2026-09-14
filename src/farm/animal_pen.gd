class_name AnimalPen
extends Interactable
## 畜舍：既是"建筑的门口"（玩家在这里放养买来的牲畜），
## 也是牲畜游荡的范围定义。
##
## 节点本身是一个小 [Area2D]（门口），不是把整片围栏做成触发区——
## 否则玩家一走近，牲畜和畜舍会同时进入交互候选，选择会变得难以预料。

## 加入该分组后，[LivestockManager] 之外的 UI 也能枚举畜舍。
const GROUP: StringName = &"animal_pen"

## 对应的 [BuildingData.id]。
@export var building_id: StringName = &"coop"

## 牲畜游荡的矩形（相对本节点），只用于视图，不影响规则。
@export var wander_area: Rect2 = Rect2(-24, -18, 48, 28)


## 所属的养殖系统。
func manager() -> LivestockManager:
	return get_parent() as LivestockManager


func building_data() -> BuildingData:
	return Database.get_building(building_id)


func capacity() -> int:
	var data := building_data()
	return data.capacity if data != null else 0


## 游荡范围的全局矩形，供 [Animal] 定位。
func world_wander_area() -> Rect2:
	return Rect2(to_global(wander_area.position), wander_area.size)


func interact(actor: Node2D) -> void:
	super.interact(actor)
	var player := actor as Player
	var mgr := manager()
	if player == null or mgr == null:
		return

	# 拿着牲畜就放养；否则报一下入住情况。
	if mgr.introduce(building_id, player):
		return
	EventBus.notification_requested.emit(&"NOTIFY_PEN_STATUS", {
		"building": Text.building_name(building_id),
		"count": mgr.animal_count(building_id),
		"capacity": capacity(),
	})
