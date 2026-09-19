extends GdUnitTestSuite
## 重构契约测试：领域事件入口、只读数据快照、存档节与世界目标。


class _DummyState:
	extends RefCounted
	
	var value: int = 1
	
	func to_dict() -> Dictionary:
		return {"value": value}
	
	func from_dict(data: Dictionary) -> void:
		value = int(data.get("value", 0))


func test_event_bus_keeps_only_cross_domain_signals() -> void:
	# 直接数脚本里声明的 signal，避免把 Node 内建信号算进来。
	var source := FileAccess.get_file_as_string("res://src/autoload/event_bus.gd")
	var signal_count := 0
	for line: String in source.split("\n"):
		if line.begins_with("signal "):
			signal_count += 1
	assert_int(signal_count).is_less_equal(12)
	assert_object(EventBus.player).is_not_null()
	assert_object(EventBus.farm).is_not_null()
	assert_object(EventBus.world).is_not_null()
	assert_object(EventBus.ui).is_not_null()


func test_database_getters_return_snapshots() -> void:
	var before := Database.total_count()
	var snapshot := Database.crops()
	snapshot.clear()
	assert_int(Database.total_count()).is_equal(before)


func test_save_section_roundtrip() -> void:
	var target := _DummyState.new()
	var section := SaveSection.new(target, &"dummy", 7, true)
	assert_array(section.validate()).is_empty()
	target.value = 42
	assert_dict(section.to_dict()).contains_keys(["value"])
	section.from_dict({"value": 3})
	assert_int(target.value).is_equal(3)


func test_world_target_roundtrip() -> void:
	var target := WorldTarget.new("res://scenes/world/farm.tscn", &"start")
	var restored := WorldTarget.from_dict(target.to_dict())
	assert_str(restored.scene_path).is_equal(target.scene_path)
	assert_str(String(restored.spawn_id)).is_equal("start")


func test_domain_events_have_a_single_owner() -> void:
	# 领域事件对象由 EventBus 单点持有；状态 / 宿主上的字段只是同一实例的别名。
	var profile := PlayerProfile.new()
	assert_bool(profile.events == EventBus.player).is_true()


## HUD 只是容器：它自己只碰 UI 域，别的域的状态各有各的小视图。
func test_hud_container_only_owns_the_ui_domain() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/hud.gd")
	assert_bool(source.contains("get_first_node_in_group")).override_failure_message(
		"HUD 容器不该去场景树里找玩家，物品栏由组合根注入"
	).is_false()
	assert_bool(source.contains("EventBus.player.")).override_failure_message(
		"HUD 容器不该订阅玩家域的信号"
	).is_false()
	assert_bool(source.contains("EventBus.world.")).override_failure_message(
		"HUD 容器不该订阅世界域的信号"
	).is_false()


## 覆写了 [code]_enter_tree()[/code] 的 [Interactable] 子类必须显式调 [code]super[/code]。
##
## Godot 的生命周期回调不会自动向父类串。漏掉 [code]super._enter_tree()[/code]，
## 基类那句 [code]add_to_group(FLORA_BLOCKER_GROUP)[/code] 就不会跑，
## 野树会长到它身上（NPC 就这么漏了很久）。
func test_interactable_subclasses_chain_enter_tree() -> void:
	var scripts := _script_bases()
	var offenders := PackedStringArray()
	for class_id: String in scripts:
		if class_id == "Interactable" or not _extends_interactable(class_id, scripts):
			continue
		var path: String = scripts[class_id].get("path", "")
		var source := FileAccess.get_file_as_string(path)
		if source.contains("func _enter_tree") and not source.contains("super._enter_tree()"):
			offenders.append(path)
	assert_array(offenders).override_failure_message(
		"覆写了 _enter_tree() 却没调 super._enter_tree()：%s" % ", ".join(offenders)
	).is_empty()


## 扫描 [code]src/[/code] 下所有脚本，收集[code]class_name[/code] → {基类名, 路径}。
func _script_bases() -> Dictionary:
	var found: Dictionary = {}
	for path: String in _files_under("res://src"):
		var class_id := ""
		var base := ""
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if class_id.is_empty() and line.begins_with("class_name "):
				class_id = line.trim_prefix("class_name ").split(" ")[0].strip_edges()
			elif base.is_empty() and line.begins_with("extends "):
				base = line.trim_prefix("extends ").strip_edges()
		if not class_id.is_empty():
			found[class_id] = {"base": base, "path": path}
	return found


## 沿继承链看 [param class_id] 是不是 [Interactable] 的后代。
func _extends_interactable(class_id: String, scripts: Dictionary) -> bool:
	var cursor := class_id
	for _step: int in 16:
		if cursor == "Interactable":
			return true
		if not scripts.has(cursor):
			return false
		cursor = String(scripts[cursor].get("base", ""))
	return false


func _files_under(dir_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for entry: String in DirAccess.get_files_at(dir_path):
		if entry.ends_with(".gd"):
			paths.append("%s/%s" % [dir_path, entry])
	for sub: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_files_under("%s/%s" % [dir_path, sub]))
	return paths
