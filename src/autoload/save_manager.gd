extends Node
## 存档管理（Autoload：`SaveManager`）。
##
## [b]存储格式[/b]：JSON 而不是 [code]Resource[/code]。
## [code]ResourceSaver[/code] 会把脚本路径写进文件，脚本一改名旧存档就报废；
## JSON 配合显式的 [constant SAVE_VERSION] 与逐字段的 [code]from_dict[/code]
## 兜底默认值，才能做到"旧存档永远读得回来"。
##
## [b]槽位[/b]：槽位号是 0 起的任意非负整数，没有数量上限——磁盘上每个
## [code]slot_<n>.json[/code] 就是"一局游戏"。于是"新增多局"只是分配一个
## 没人占用的槽位号，"继续游戏"则是在标题页的存档列表里挑一个读。
##
## [b]手动存档收敛[/b]：[member current_slot] 记录本局对应哪个槽位；菜单手动存档
## 与日结自动存档都写到它，UI 不再让人手选槽位。选局只发生在标题页。
##
## [b]扩展方式[/b]：任何节点只要加入 [constant Persistence.GROUP] 组
## 并实现 [code]to_dict()[/code] / [code]from_dict()[/code]，就会被自动存档，
## 不需要修改本脚本。核心单例则用 [method Persistence.register_core]
## 声明恢复顺序，[SaveManager] 不硬编码节点名。

## 当前存档结构版本。字段语义发生不兼容变化时才递增。
const SAVE_VERSION: int = 1
## 默认存档目录。单元测试会把它改写到工作区内的临时目录。
const DEFAULT_SAVE_ROOT: String = "user://saves"

## 存档根目录；可写，便于测试注入。
var save_root: String = DEFAULT_SAVE_ROOT

## 本局所在的槽位；-1 表示新游戏还没有落盘。
##
## 手动存档 / 日结自动存档都写到这里，所以 UI 不需要（也不应该）手选槽位。
var current_slot: int = -1

## 最近一次读入的"场景内节点"存档数据。
##
## 世界场景是在核心状态之后才加载的，那时新节点还不存在；
## 因此这里先暂存，等场景挂载完成后再由 [method apply_node_state] 灌进去。
var _pending_node_state: Dictionary = {}

## 读档 / 存档完成后发出（与 EventBus 上的同名信号同步）。
signal save_finished(slot: int, success: bool)
signal load_finished(slot: int, success: bool)

## 由 [Main] 显式注册的核心存档节，按 order 升序恢复。
var _core_sections: Array[SaveSection] = []


## 由组合根注入本局核心存档节；替换而不是追加，避免旧 Main 的资源泄漏。
func set_core_sections(sections: Array[SaveSection]) -> void:
	_core_sections.clear()
	for section: SaveSection in sections:
		if section != null and section.is_valid():
			_core_sections.append(section)


## 当前显式注册的核心存档节副本。
func core_sections() -> Array[SaveSection]:
	var result: Array[SaveSection] = []
	result.assign(_core_sections)
	return result


func _ready() -> void:
	_ensure_root()


# ---------------------------------------------------------------- 槽位

## 槽位对应的文件路径。
func slot_path(slot: int) -> String:
	return "%s/%s" % [save_root, SaveSlots.file_name(slot)]


## 该槽位是否已有存档。槽位号只要求非负。
func has_save(slot: int) -> bool:
	return slot >= 0 and FileAccess.file_exists(slot_path(slot))


## 所有已有存档的槽位号，升序。上限只由磁盘上的文件数量决定。
func existing_slots() -> Array[int]:
	var slots: Array[int] = []
	_ensure_root()
	var dir := DirAccess.open(save_root)
	if dir == null:
		return slots
	for file_name: String in dir.get_files():
		var slot := SaveSlots.slot_from_file_name(file_name)
		if slot >= 0:
			slots.append(slot)
	slots.sort()
	return slots


## 下一个可用槽位：从 0 起找第一个没被占用的整数（复用被删掉的空档）。
func next_slot() -> int:
	return SaveSlots.next_free(existing_slots())


## 最近一次保存的槽位；没有存档时返回 -1。
func latest_slot() -> int:
	var best := -1
	var best_stamp := ""
	for slot: int in existing_slots():
		var stamp := str(read_meta(slot).get("saved_at", ""))
		if best < 0 or stamp > best_stamp:
			best = slot
			best_stamp = stamp
	return best


## 读取槽位的摘要信息，供存档界面显示，避免加载整个存档。
func read_meta(slot: int) -> Dictionary:
	if slot < 0:
		return {}
	var data := _read_json(slot_path(slot))
	if data.is_empty():
		return {}
	var clock: Variant = data.get("GameClock", {})
	var state: Variant = data.get("GameState", {})
	var date_data: Variant = clock.get("date", {}) if clock is Dictionary else {}
	var date := GameDate.from_dict(date_data if date_data is Dictionary else {})
	return {
		"slot": slot,
		"saved_at": str(data.get("saved_at", "")),
		"version": int(data.get("version", 0)),
		"date": date,
		"money": int(state.get("money", 0)) if state is Dictionary else 0,
		"player_name": str(state.get("player_name", "")) if state is Dictionary else "",
		"play_seconds": float(state.get("play_seconds", 0.0)) if state is Dictionary else 0.0,
	}


## 所有存档的摘要，按最近保存时间倒序（同刻按槽位号升序）。
func all_meta() -> Array[Dictionary]:
	var metas: Array[Dictionary] = []
	for slot: int in existing_slots():
		var meta := read_meta(slot)
		if not meta.is_empty():
			metas.append(meta)
	SaveSlots.sort_meta_by_recency(metas)
	return metas


# ---------------------------------------------------------------- 存档 / 读档

## 保存到 [param slot]（槽位号非负即可）。成功后把它记为本局槽位。
func save_game(slot: int) -> bool:
	if slot < 0:
		push_error("SaveManager: 非法槽位 %d" % slot)
		return false
	_ensure_root()
	var success := _write_json(slot_path(slot), collect())
	if success:
		current_slot = slot
	save_finished.emit(slot, success)
	EventBus.save_completed.emit(slot, success)
	return success


## 保存本局：[member current_slot] 还没分配时先取 [method next_slot]。
##
## 这是菜单"保存进度"与日结自动存档共用的唯一入口——手动存档因此收敛成
## "存当前这一局"，不再有手选槽位的机会。
func save_current() -> bool:
	var slot := current_slot
	if slot < 0:
		slot = next_slot()
	return save_game(slot)


## 从 [param slot] 读取核心状态。成功后把它记为本局槽位。
##
## 注意：这个方法是同步的（方便单元测试），只负责恢复核心单例
## 以及[b]当前已挂在场景树上[/b]的持久化节点。
## 如果存档记录的地图和当前地图不同，请用 [method load_game_and_restore_world]。
func load_game(slot: int) -> bool:
	var data := _read_json(slot_path(slot))
	var success: bool = not data.is_empty() and apply(data)
	if success:
		current_slot = slot
	load_finished.emit(slot, success)
	EventBus.load_completed.emit(slot, success)
	return success


## 读档的完整流程（存档按钮 / 快捷读档都走这里）。
##
## 三步：恢复核心状态 → 切到存档记录的地图 → 把节点状态灌进新场景。
## 第二步必须等世界加载完，所以这个方法是异步的。
func load_game_and_restore_world(slot: int) -> bool:
	if not load_game(slot):
		return false
	var host := _world_host()
	if host != null:
		await host.restore_saved_world()
	apply_node_state()
	return true


## 读取本局槽位并重建世界；还没分配槽位时返回 false。
func load_current_and_restore_world() -> bool:
	if current_slot < 0:
		return false
	return await load_game_and_restore_world(current_slot)


## 开始一局新游戏：清空本局槽位，第一次保存时才分配新的槽位号。
func begin_new_game() -> void:
	current_slot = -1


## 删除槽位存档；删掉的正好是本局槽位时，本局回到"未落盘"。
func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	var removed := DirAccess.remove_absolute(
		ProjectSettings.globalize_path(slot_path(slot))
	) == OK
	if removed and current_slot == slot:
		current_slot = -1
	return removed


# ---------------------------------------------------------------- 收集 / 应用

## 收集当前世界的完整存档数据。
func collect() -> Dictionary:
	var nodes := {}
	for section: SaveSection in _scene_sections():
		var problems := section.validate()
		if not problems.is_empty():
			push_error(
				"SaveManager: 节点 '%s' 不满足存档契约：%s"
				% [section.id, ", ".join(problems)]
			)
			continue
		nodes[String(section.id)] = section.to_dict()

	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	for section: SaveSection in _resolved_core_sections():
		var problems := section.validate()
		if not problems.is_empty():
			push_error(
				"SaveManager: 核心存档节 '%s' 不满足契约：%s"
				% [section.id, ", ".join(problems)]
			)
			continue
		payload[String(section.id)] = section.to_dict()
	payload["nodes"] = nodes
	return payload


## 把存档数据应用到当前世界。
func apply(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if version <= 0:
		push_error("SaveManager: 存档缺少版本号，拒绝载入")
		return false
	if version > SAVE_VERSION:
		push_error(
			"SaveManager: 存档版本 %d 高于本程序支持的 %d，拒绝载入" % [version, SAVE_VERSION]
		)
		return false

	# 1) 先恢复核心节：世界节点在 _ready() 时依赖它们。
	for section: SaveSection in _resolved_core_sections():
		var problems := section.validate()
		if not problems.is_empty():
			push_error(
				"SaveManager: 核心存档节 '%s' 不满足契约：%s"
				% [section.id, ", ".join(problems)]
			)
			continue
		var section_data: Variant = data.get(String(section.id), {})
		if section_data is Dictionary and not section_data.is_empty():
			section.from_dict(section_data)

	# 2) 再恢复场景内的持久化节点。
	var nodes: Variant = data.get("nodes", {})
	_pending_node_state = nodes if nodes is Dictionary else {}
	apply_node_state()
	return true


## 把暂存的“场景内节点”存档数据应用到当前场景树。
##
## 读档时调用两次是正常且必要的：一次给已经在树上的旧场景，
## 一次给随后按存档重建出来的新场景。重复应用是幂等的。
func apply_node_state() -> void:
	if _pending_node_state.is_empty() or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(Persistence.GROUP):
		var section := SaveSection.from_object(node, false)
		if not _pending_node_state.has(String(section.id)):
			continue
		var section_data: Variant = _pending_node_state[String(section.id)]
		if section_data is Dictionary:
			section.from_dict(section_data)


# ---------------------------------------------------------------- 内部

## 显式核心节 + 旧接口注册的 Resource / 核心节点，统一去重、排序。
func _resolved_core_sections() -> Array[SaveSection]:
	var result: Array[SaveSection] = []
	var seen: Dictionary = {}
	for section: SaveSection in _core_sections:
		_append_section(result, seen, section)
	for object: Object in Persistence.core_resources():
		_append_section(result, seen, SaveSection.from_object(object, true))
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(Persistence.CORE_GROUP):
			if is_instance_valid(node):
				_append_section(result, seen, SaveSection.from_object(node, true))
	result.sort_custom(_sort_sections)
	return result


## 当前场景树里的持久化节点；读取时包装成 [SaveSection]。
func _scene_sections() -> Array[SaveSection]:
	var result: Array[SaveSection] = []
	if not is_inside_tree():
		return result
	for node: Node in get_tree().get_nodes_in_group(Persistence.GROUP):
		if is_instance_valid(node):
			result.append(SaveSection.from_object(node, false))
	result.sort_custom(_sort_sections)
	return result


func _append_section(
	result: Array[SaveSection], seen: Dictionary, section: SaveSection
) -> void:
	if section == null or not section.is_valid():
		return
	if section.id == &"":
		section.id = Persistence.id_of(section.target)
	if section.id == &"":
		return
	var key := section.target.get_instance_id()
	if seen.has(key):
		return
	seen[key] = true
	result.append(section)


func _sort_sections(a: SaveSection, b: SaveSection) -> bool:
	if a.order == b.order:
		return String(a.id) < String(b.id)
	return a.order < b.order


func _world_host() -> WorldHost:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost


func _ensure_root() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(save_root)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_root))


func _write_json(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error(
			"SaveManager: 无法写入 '%s'（错误码 %d）" % [path, FileAccess.get_open_error()]
		)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: 无法读取 '%s'（错误码 %d）" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_error("SaveManager: '%s' 不是合法的存档 JSON" % path)
		return {}
	return parsed
