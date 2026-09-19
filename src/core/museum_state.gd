class_name MuseumState
extends Resource
## 博物馆图鉴的可存档状态（Resource）。
##
## 只记"见过哪些道具"：id → 首次发现时的游戏日（绝对天数，用于将来做排序 / 统计）。
## 记录由 [Main] 在背包变化时补充，因此钓鱼 / 收获 / 购买 / 采集都会自动入册。
## 已发现的道具即使被卖掉也不会从图鉴里消失。

## item_id → 首次发现时的绝对天数。
var discovered: Dictionary[StringName, int] = {}


func reset() -> void:
	discovered.clear()


## 记录发现；返回 true 表示这是第一次见到。
func discover(item_id: StringName, day: int = 0) -> bool:
	if item_id == &"" or discovered.has(item_id):
		return false
	discovered[item_id] = maxi(day, 0)
	return true


## 是否已经记录过。
func is_discovered(item_id: StringName) -> bool:
	return discovered.has(item_id)


## 首次发现的绝对天数；没记录过返回 -1。
func first_seen_day(item_id: StringName) -> int:
	return int(discovered.get(item_id, -1))


## 已记录的道具总数。
func discovered_count() -> int:
	return discovered.size()


## 只读快照（键为 id，值为首次发现天数）。
func entries() -> Dictionary:
	return discovered.duplicate()


## 扫描一个背包，把所有道具记进图鉴；返回本次新增的数量。
func discover_inventory(inventory: Inventory, day: int = 0) -> int:
	if inventory == null:
		return 0
	var added: int = 0
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty():
			continue
		if discover(slot.item_id, day):
			added += 1
	return added


func to_dict() -> Dictionary:
	var data := {}
	for item_id: StringName in discovered:
		data[String(item_id)] = int(discovered[item_id])
	return {"discovered": data}


func from_dict(data: Dictionary) -> void:
	reset()
	var raw: Variant = data.get("discovered", {})
	if raw is Dictionary:
		for key: Variant in raw:
			var item_id := StringName(str(key))
			if item_id != &"":
				discovered[item_id] = int(raw[key])
