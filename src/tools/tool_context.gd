class_name ToolContext
extends RefCounted
## 一次工具作用所需的世界上下文。
##
## 由"手"（[FarmInteractor]）在玩家所属的世界里解析好后注入给工具；
## 工具只通过本对象读写世界，不做任何全局查找，因此可以脱离场景树单测。

## 使用者玩家（体力 / 背包在它身上）。
var player: Player
## 当前世界的农田；没有农田的场景为空。
var grid: FarmGrid
## 当前世界的野生植被（矿洞是 [code]MineFloor[/code]）；接口为 occupied() / clear()。
var flora: Node
## 当前世界的水面标记。
var water: WaterField
## 组合根注入的时钟；播种读取季节。
var clock: GameDateClock
## 组合根注入的天气服务。
var weather: WeatherService


## 以目标格为中心展开的作用范围（格子列表）。
##
## 奇数边长时严格居中，偶数时偏向右下。
func area_cells(cell: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var width: int = maxi(size.x, 1)
	var height: int = maxi(size.y, 1)
	var offset_x: int = (width - 1) / 2
	var offset_y: int = (height - 1) / 2
	for y: int in height:
		for x: int in width:
			cells.append(cell + Vector2i(x - offset_x, y - offset_y))
	return cells


## 当前季节；没有时钟时按春算。
func current_season() -> Season.Type:
	return clock.date.season if clock != null else Season.Type.SPRING


## 把清除植被的产出放进背包并提示玩家。
func grant(outcome: Dictionary) -> void:
	var item_id: StringName = outcome.get("item_id", &"")
	var amount: int = int(outcome.get("amount", 0))
	if item_id == &"" or amount <= 0:
		return
	if player != null:
		player.inventory.add(item_id, amount, int(outcome.get("quality", 0)))
	notify(
		&"NOTIFY_FLORA_CLEARED",
		{"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)


## 向玩家发一条提示。
func notify(text_key: StringName, args: Dictionary = {}) -> void:
	EventBus.ui.notification_requested.emit(text_key, args)
