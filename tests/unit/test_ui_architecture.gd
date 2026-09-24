extends GdUnitTestSuite
## UI 架构熔断契约。
##
## 这里不测具体玩法，只测“边界被拔掉时 UI 会不会坏死”：
## - UI 不许在场景树里按分组找协作者；
## - provider 缺失时背包必须清空；
## - 模态宿主必须在 close_all 后清空栈，不能把暂停状态交给某个界面自己记得。


func test_ui_scripts_do_not_search_tree_for_collaborators() -> void:
    var offenders := PackedStringArray()
    for path: String in _gd_files("res://src/ui"):
        var source := FileAccess.get_file_as_string(path)
        if source.contains("get_first_node_in_group") or source.contains("get_nodes_in_group"):
            offenders.append(path)
    assert_array(offenders).override_failure_message(
        "UI 不应在场景树里搜索协作者：%s" % ", ".join(offenders)
    ).is_empty()


func test_inventory_ui_clears_when_provider_is_absent() -> void:
    var ui := auto_free(
        load("res://scenes/ui/inventory_ui.tscn").instantiate()
    ) as InventoryUi
    add_child(ui)
    await get_tree().process_frame

    ui.bind_inventory_provider(Callable())
    ui.refresh()

    var grid := ui.find_child("Slots", true, false) as GridContainer
    assert_object(grid).is_not_null()
    if grid == null:
        return
    var first := grid.get_child(0) as ItemSlot
    assert_object(first).is_not_null()
    if first == null:
        return
    assert_object(first.icon.texture).is_null()
    assert_bool(first.icon.visible).is_false()


func test_ui_root_puts_touch_controls_in_a_top_canvas_layer() -> void:
    var ui: UiRoot = auto_free(
        load("res://scenes/ui/ui_root.tscn").instantiate()
    ) as UiRoot
    add_child(ui)
    await get_tree().process_frame

    assert_object(ui.touch_controls).is_not_null()
    if ui.touch_controls == null:
        return
    var touch_layer := ui.touch_controls.get_parent() as CanvasLayer
    assert_object(touch_layer).is_not_null()
    if touch_layer != null:
        # 常规 UI 在 UiRoot(layer=10) / MineElevatorUi(layer=40) 下面。
        assert_int(touch_layer.layer).is_greater(40)
    # 系统菜单不再提供触控开关。
    assert_object(ui.pause_menu.find_child("TouchToggle", true, false)).is_null()


func test_modal_host_close_all_resets_stack_without_a_specific_ui() -> void:
    var host: UiModalHost = auto_free(UiModalHost.new()) as UiModalHost
    var first: UiModal = auto_free(UiModal.new()) as UiModal
    var second: UiModal = auto_free(UiModal.new()) as UiModal

    host.open(first)
    host.open(second)
    assert_bool(host.has_modal()).is_true()

    host.close_all()
    assert_bool(host.has_modal()).is_false()


## 递归收集目录下的 .gd 文件。
func _gd_files(dir_path: String) -> PackedStringArray:
    var paths := PackedStringArray()
    for entry: String in DirAccess.get_files_at(dir_path):
        if entry.ends_with(".gd"):
            paths.append("%s/%s" % [dir_path, entry])
    for sub: String in DirAccess.get_directories_at(dir_path):
        paths.append_array(_gd_files("%s/%s" % [dir_path, sub]))
    return paths
