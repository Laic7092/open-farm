class_name Inventory
extends RefCounted
## 背包（格子 + 堆叠）。
##
## 纯数据对象，不依赖场景树；[FarmGrid] 播种、[Shop] 买卖都只跟它打交道。
## 变化通过本地信号广播，由 [Player] 转发到 [EventBus]，本类不认识 Autoload。
## 堆叠上限由外部 [member _stack_limit_provider] 提供，默认 99。

## 默认格数。
const DEFAULT_CAPACITY: int = 24

## 内容发生任何变化时发出。
signal changed()

## 单格内容变化，便于 UI 做局部刷新。
signal slot_changed(index: int)

## 放入失败（还有 [param item_id] 没放下）。
signal full(item_id: StringName)

## 堆叠上限查询器；返回 [ItemData] 或 null。由拥有者在构造时注入。
var _stack_limit_provider: Callable = Callable()

## 格数。
var capacity: int

## 格子数组，长度恒等于 [member capacity]。
var slots: Array[InventorySlot] = []


func _init(p_capacity: int = DEFAULT_CAPACITY) -> void:
	capacity = maxi(p_capacity, 1)
	_resize()


## 放入道具，返回[b]没能放下的数量[/b]（0 表示全部放入）。
##
## 先填已有堆叠，再占用空格，符合玩家直觉。品质不同的同类道具会分成两堆。
func add(item_id: StringName, count: int = 1, quality: int = 0) -> int:
	if item_id == &"" or count <= 0:
		return count
	var grade: int = QualityRules.clamp_grade(quality)
	var remaining: int = count
	var limit: int = _stack_limit(item_id)
	var touched: Array[int] = []

	# 1) 先补已有堆叠。
	for index: int in capacity:
		if remaining <= 0:
			break
		var slot: InventorySlot = slots[index]
		if slot.is_empty() or slot.item_id != item_id or slot.quality != grade:
			continue
		var room: int = limit - slot.count
		if room <= 0:
			continue
		var moved: int = mini(room, remaining)
		slot.count += moved
		remaining -= moved
		touched.append(index)

	# 2) 再占用空格。
	for index: int in capacity:
		if remaining <= 0:
			break
		var slot: InventorySlot = slots[index]
		if not slot.is_empty():
			continue
		var moved: int = mini(limit, remaining)
		slot.item_id = item_id
		slot.count = moved
		slot.quality = grade
		remaining -= moved
		touched.append(index)

	for index: int in touched:
		slot_changed.emit(index)
	if not touched.is_empty():
		changed.emit()
	if remaining > 0:
		full.emit(item_id)
	return remaining


## 取出道具；数量不足时不做任何改动并返回 false。
func remove(item_id: StringName, count: int = 1) -> bool:
	if count <= 0:
		return true
	if count_of(item_id) < count:
		return false
	var remaining: int = count
	for index: int in range(capacity - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: InventorySlot = slots[index]
		if slot.is_empty() or slot.item_id != item_id:
			continue
		var taken: int = mini(slot.count, remaining)
		slot.count -= taken
		remaining -= taken
		if slot.count <= 0:
			slot.clear()
		slot_changed.emit(index)
	if remaining < count:
		changed.emit()
	return remaining == 0


## 背包中某道具的总数。
func count_of(item_id: StringName) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == item_id:
			total += slot.count
	return total


## 是否拥有足够数量。
func has(item_id: StringName, count: int = 1) -> bool:
	return count_of(item_id) >= count


## 是否已经装满（没有任何可再放入的空间）。
func is_full() -> bool:
	return first_empty_index() < 0 and not _has_stack_room()


## 第一个空格下标；没有空格返回 -1。
func first_empty_index() -> int:
	for index: int in capacity:
		if slots[index].is_empty():
			return index
	return -1


## 某道具所在的第一个格子；找不到返回 -1。
func find_slot(item_id: StringName) -> int:
	for index: int in capacity:
		if slots[index].item_id == item_id:
			return index
	return -1


## 已占用的格数。
func used_slots() -> int:
	var used: int = 0
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			used += 1
	return used


## 设置堆叠上限查询器；[param provider] 接受 item_id，返回 [ItemData] 或 null。
func set_stack_limit_provider(provider: Callable) -> void:
	_stack_limit_provider = provider


## 清空背包。
func clear() -> void:
	for index: int in capacity:
		slots[index].clear()
		slot_changed.emit(index)
	changed.emit()


## 扩展格数（升级背包）。
func set_capacity(value: int) -> void:
	capacity = maxi(value, 1)
	_resize()
	changed.emit()


func to_dict() -> Dictionary:
	var data: Array = []
	for slot: InventorySlot in slots:
		data.append(slot.to_dict())
	return {"capacity": capacity, "slots": data}


func from_dict(data: Dictionary) -> void:
	capacity = maxi(int(data.get("capacity", DEFAULT_CAPACITY)), 1)
	_resize()
	var raw: Variant = data.get("slots", [])
	if raw is Array:
		for index: int in mini((raw as Array).size(), capacity):
			var entry: Variant = (raw as Array)[index]
			if entry is Dictionary:
				slots[index].from_dict(entry)
	changed.emit()


func _resize() -> void:
	while slots.size() < capacity:
		slots.append(InventorySlot.new())
	if slots.size() > capacity:
		slots.resize(capacity)


func _has_stack_room() -> bool:
	for slot: InventorySlot in slots:
		if slot.is_empty():
			return true
		if slot.count < _stack_limit(slot.item_id):
			return true
	return false


func _stack_limit(item_id: StringName) -> int:
	if _stack_limit_provider.is_valid():
		var item: Variant = _stack_limit_provider.call(item_id)
		if item is ItemData:
			return maxi((item as ItemData).stack_limit, 1)
	return 99
