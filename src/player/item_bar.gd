class_name ItemBar
extends RefCounted
## 物品栏：背包的快捷访问视图。
##
## [b]它不存放任何道具[/b]——每一格都直接映射到 [member backpack] 的前
## [constant SIZE] 格，因此"物品栏里有什么"永远等于"背包前几格里有什么"，
## 不可能出现两份会各自变化的状态。
##
## 工具也不是第二份库存：工具本身就是背包里 [constant ItemData.Category.TOOL]
## 类别的道具，只是不会被消耗。物品栏只额外记住"当前手持背包的哪一格"，
## 供 Q / R 切换。通过 [signal EventBus.hand_changed] 通知 HUD。

## 物品栏显示背包的前多少格。
const SIZE: int = 12

## 当前手持格变化；[param index] 为该格在背包中的下标。
signal changed(item_id: StringName, index: int)

## 被快捷访问的背包。
var backpack: Inventory

var _index: int = -1


func _init(p_backpack: Inventory) -> void:
	backpack = p_backpack


## 物品栏第 [param index] 格对应的背包下标；越界返回 -1。
##
## 目前物品栏就是"背包前 [constant SIZE] 格"，所以两者下标相同；
## 保留这个函数是为了让 HUD 不必知道映射规则。
func slot_index(index: int) -> int:
	if index < 0 or index >= visible_count():
		return -1
	return index


## 物品栏实际显示的格数（背包比 [constant SIZE] 小时按背包算）。
func visible_count() -> int:
	if backpack == null:
		return 0
	return mini(SIZE, backpack.capacity)


## 当前手持格在背包中的下标；没有任何工具时返回 -1。
func hand_index() -> int:
	if _is_tool_index(_index):
		return _index
	return first_tool_index()


## 当前手持的道具 id；没有工具时为空串。
func selected_item_id() -> StringName:
	var index := hand_index()
	return backpack.slots[index].item_id if index >= 0 else &""


## 当前手持道具对应的工具数据；手持的不是工具时返回 null。
func selected_tool() -> ToolData:
	var item := Database.get_item(selected_item_id())
	if item == null or item.tool_id == &"":
		return null
	return Database.get_tool(item.tool_id)


## 第一个装着工具的格子；没有工具时返回 -1。
func first_tool_index() -> int:
	for index: int in visible_count():
		if _is_tool_index(index):
			return index
	return -1


## 切换到下一个工具（循环）。
func next() -> void:
	_step(1)


## 切换到上一个工具（循环）。
func prev() -> void:
	_step(-1)


## 选中背包中某一格；不是工具或越界时返回 false。
func select(index: int) -> bool:
	if not _is_tool_index(index):
		return false
	if index == hand_index():
		return true
	_index = index
	_emit()
	return true


func to_dict() -> Dictionary:
	return {"selected": hand_index()}


func from_dict(data: Dictionary) -> void:
	_index = int(data.get("selected", -1))


# ---------------------------------------------------------------- 内部

func _step(step: int) -> void:
	var tools := _tool_indices()
	if tools.size() <= 1:
		return
	var position := tools.find(hand_index())
	if position < 0:
		position = 0
	_index = tools[wrapi(position + step, 0, tools.size())]
	_emit()


func _tool_indices() -> Array[int]:
	var indices: Array[int] = []
	for index: int in visible_count():
		if _is_tool_index(index):
			indices.append(index)
	return indices


func _is_tool_index(index: int) -> bool:
	if backpack == null or index < 0 or index >= visible_count():
		return false
	var slot: InventorySlot = backpack.slots[index]
	if slot.is_empty():
		return false
	var item := Database.get_item(slot.item_id)
	return item != null and item.category == ItemData.Category.TOOL


func _emit() -> void:
	changed.emit(selected_item_id(), hand_index())
	EventBus.hand_changed.emit(selected_item_id(), hand_index())
