class_name SaveSlots
extends RefCounted
## 存档槽位的命名与分配规则（纯静态，可脱离引擎单测）。
##
## 槽位号是 0 起的任意非负整数，磁盘上每个 `slot_<n>.json` 就是一局游戏。
## 这里只做"文件名 ↔ 槽位号""挑最小空位""按时间排序"这类纯计算，
## 真正的读写由 [SaveManager] 负责；规则拆出来，才能不加载场景就测。
##
## [b]规范写法[/b]：文件名必须与 [method file_name] 完全一致。像 `slot_007.json`
## 这种前导零写法虽然能解析成数字，但不承认——否则"槽位 7"会有两个文件名。

## 存档文件名前缀。
const PREFIX: String = "slot_"
## 存档文件名后缀。
const SUFFIX: String = ".json"


## 槽位对应的文件名。
static func file_name(slot: int) -> String:
	return "%s%d%s" % [PREFIX, slot, SUFFIX]


## 最小可用槽位：升序列表里第一个空档（被删掉的号会被复用）。
##
## [param slots] 必须升序；乱序时结果不保证正确。
static func next_free(slots: Array[int]) -> int:
	var slot := 0
	for taken: int in slots:
		if taken == slot:
			slot += 1
		elif taken > slot:
			break
	return slot


## 从文件名还原槽位号；非法或非规范写法返回 -1。
static func slot_from_file_name(value: String) -> int:
	if not value.begins_with(PREFIX) or not value.ends_with(SUFFIX):
		return -1
	var middle := value.trim_prefix(PREFIX).trim_suffix(SUFFIX)
	if not middle.is_valid_int():
		return -1
	var slot := int(middle)
	if slot < 0 or file_name(slot) != value:
		return -1
	return slot


## 把摘要按最近保存时间倒序排列；同一时刻按槽位号升序，保证顺序稳定。
static func sort_meta_by_recency(metas: Array[Dictionary]) -> void:
	metas.sort_custom(_meta_is_more_recent)


static func _meta_is_more_recent(a: Dictionary, b: Dictionary) -> bool:
	var stamp_a := str(a.get("saved_at", ""))
	var stamp_b := str(b.get("saved_at", ""))
	if stamp_a == stamp_b:
		return int(a.get("slot", 0)) < int(b.get("slot", 0))
	return stamp_a > stamp_b
