class_name ToolBelt
extends RefCounted
## 工具腰带：管理玩家当前手持的工具。
##
## 工具与背包分开：工具是永久道具，不占背包格、不会用完，
## 这样"按 Q 切换工具"就不会被背包整理逻辑干扰。
## 通过 [signal EventBus.tool_changed] 通知 HUD。

## 当前工具变化时发出。
signal changed(tool_id: StringName, index: int)

## 腰带上的工具 id 列表（按解锁顺序）。
var tool_ids: Array[StringName] = []

var _index: int = 0


func _init(initial_tools: Array[StringName] = []) -> void:
	tool_ids = initial_tools.duplicate()


## 当前下标。
func selected_index() -> int:
	if tool_ids.is_empty():
		return -1
	return clampi(_index, 0, tool_ids.size() - 1)


## 当前工具的数据；腰带为空时返回 null。
func selected_tool() -> ToolData:
	var index := selected_index()
	if index < 0:
		return null
	return Database.get_tool(tool_ids[index])


## 当前工具 id。
func selected_id() -> StringName:
	var index := selected_index()
	return tool_ids[index] if index >= 0 else &""


## 选中指定下标（越界会被夹紧）。
func select(index: int) -> void:
	if tool_ids.is_empty():
		return
	var next_index: int = clampi(index, 0, tool_ids.size() - 1)
	if next_index == selected_index():
		return
	_index = next_index
	_emit()


## 是否装备着某个工具。
func select_by_id(tool_id: StringName) -> bool:
	var index: int = tool_ids.find(tool_id)
	if index < 0:
		return false
	select(index)
	return true


## 切换到下一个工具（循环）。
func next() -> void:
	if tool_ids.size() <= 1:
		return
	_index = (selected_index() + 1) % tool_ids.size()
	_emit()


## 切换到上一个工具（循环）。
func prev() -> void:
	if tool_ids.size() <= 1:
		return
	_index = (selected_index() - 1 + tool_ids.size()) % tool_ids.size()
	_emit()


## 获得新工具。
func add(tool_id: StringName) -> bool:
	if tool_id == &"" or tool_ids.has(tool_id):
		return false
	tool_ids.append(tool_id)
	_emit()
	return true


## 是否拥有某工具。
func has(tool_id: StringName) -> bool:
	return tool_ids.has(tool_id)


func to_dict() -> Dictionary:
	return {"tools": tool_ids.map(func(id: StringName) -> String: return String(id)), "index": selected_index()}


func from_dict(data: Dictionary) -> void:
	tool_ids.clear()
	var raw: Variant = data.get("tools", [])
	if raw is Array:
		for entry: Variant in raw:
			tool_ids.append(StringName(str(entry)))
	_index = clampi(int(data.get("index", 0)), 0, maxi(tool_ids.size() - 1, 0))
	_emit()


func _emit() -> void:
	changed.emit(selected_id(), selected_index())
	EventBus.tool_changed.emit(selected_id(), selected_index())
