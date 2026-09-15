extends GdUnitTestSuite
## 存档槽位规则测试：文件名往返、最小空位分配、按时间排序。
##
## 这些规则是纯静态函数，不碰引擎 FS，所以放在 unit 层。

func test_file_name_is_canonical() -> void:
	assert_str(SaveSlots.file_name(0)).is_equal("slot_0.json")
	assert_str(SaveSlots.file_name(12)).is_equal("slot_12.json")


func test_slot_from_file_name_round_trips() -> void:
	for slot: int in [0, 1, 42, 999]:
		assert_int(SaveSlots.slot_from_file_name(SaveSlots.file_name(slot))).is_equal(slot)


## 非规范写法（前导零 / 数字缺失 / 后缀不符）一律不认，避免同一局有两个文件名。
func test_slot_from_file_name_rejects_bad_names() -> void:
	for name: String in [
		"slot_007.json",
		"slot_.json",
		"slot_x.json",
		"slot_-1.json",
		"slot_1.txt",
		"other_1.json",
		"slot_1.json.bak",
	]:
		assert_int(SaveSlots.slot_from_file_name(name)).override_failure_message(
			"不该接受文件名 %s" % name
		).is_equal(-1)


func test_next_free_reuses_the_lowest_gap() -> void:
	var empty: Array[int] = []
	assert_int(SaveSlots.next_free(empty)).is_equal(0)
	assert_int(SaveSlots.next_free([0, 1, 2] as Array[int])).is_equal(3)
	assert_int(SaveSlots.next_free([1, 2] as Array[int])).is_equal(0)
	assert_int(SaveSlots.next_free([0, 2] as Array[int])).is_equal(1)


func test_sort_meta_by_recency_prefers_newest_then_lowest_slot() -> void:
	var metas: Array[Dictionary] = []
	metas.append({"slot": 1, "saved_at": "2024-01-01 10:00:00"})
	metas.append({"slot": 2, "saved_at": "2024-02-01 10:00:00"})
	metas.append({"slot": 0, "saved_at": "2024-02-01 10:00:00"})
	SaveSlots.sort_meta_by_recency(metas)
	assert_int(int(metas[0].get("slot", -1))).is_equal(0)
	assert_int(int(metas[1].get("slot", -1))).is_equal(2)
	assert_int(int(metas[2].get("slot", -1))).is_equal(1)
