extends GdUnitTestSuite
## UI 布局规范：令牌纯函数 + "场景里不得硬编码尺寸" 门禁 + 模态外壳接线。
##
## 这里锁的是 [UiLayout] 作为尺寸唯一来源、[ModalShell] 作为模态排版唯一实现：
## 场景只声明结构，任何数值都不该再出现在 [code].tscn[/code] 里。

## 所有 UI / 标题场景；逐个检查不得写死配色 / 字号 / 最小尺寸。
const UI_SCENES: Array[String] = [
	"res://scenes/ui/ui_root.tscn",
	"res://scenes/ui/modal_shell.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/dialogue_box.tscn",
	"res://scenes/ui/inventory_ui.tscn",
	"res://scenes/ui/shop_ui.tscn",
	"res://scenes/ui/museum_ui.tscn",
	"res://scenes/ui/commission_ui.tscn",
	"res://scenes/ui/cooking_ui.tscn",
	"res://scenes/ui/festival_game_ui.tscn",
	"res://scenes/ui/village_goal_ui.tscn",
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/fishing_ui.tscn",
	"res://scenes/ui/touch_controls.tscn",
	"res://scenes/ui/item_slot.tscn",
	"res://scenes/ui/hud_slot.tscn",
	"res://scenes/title/title_screen.tscn",
]

## 必须由 [ModalShell] 统一排版的模态界面：不得写任何固定几何或主题覆盖。
const MODAL_SCENES: Array[String] = [
	"res://scenes/ui/commission_ui.tscn",
	"res://scenes/ui/inventory_ui.tscn",
	"res://scenes/ui/shop_ui.tscn",
	"res://scenes/ui/museum_ui.tscn",
	"res://scenes/ui/cooking_ui.tscn",
	"res://scenes/ui/festival_game_ui.tscn",
	"res://scenes/ui/village_goal_ui.tscn",
	"res://scenes/ui/pause_menu.tscn",
]

## 有代表性的分辨率 / 宽高比；下限就是 project.godot 的最小窗口 640×360。
const RESOLUTIONS: Array[Vector2] = [
	Vector2(640, 360),
	Vector2(800, 600),
	Vector2(1024, 768),
	Vector2(1280, 720),
	Vector2(1920, 1080),
	Vector2(2560, 1080),
]

## 触屏设备的典型占位（左摇杆 104、右 ABXY 116）。
const TOUCH_INSETS := Vector2(104, 116)


func test_modal_size_stays_within_viewport() -> void:
	for viewport: Vector2 in RESOLUTIONS:
		for scale: float in [1.0, 1.5, 3.0]:
			var target := UiLayout.modal_size(viewport, Vector2.ZERO, scale)
			assert_bool(target.x > 0.0 and target.y > 0.0).is_true()
			assert_bool(target.x * scale <= viewport.x + 0.01).is_true()
			assert_bool(target.y * scale <= viewport.y + 0.01).is_true()


func test_modal_size_respects_content_minimum() -> void:
	var target := UiLayout.modal_size(Vector2(640, 360), Vector2(300, 200), 1.0)
	assert_bool(target.x >= 300.0).is_true()
	assert_bool(target.y >= 200.0).is_true()


func test_safe_insets_maps_screen_pixels_to_virtual_units() -> void:
	# 窗口 1280×720、虚拟 640×360、安全区左右各 40 屏幕像素 → 虚拟 20。
	var insets := UiLayout.safe_insets(
		Rect2i(40, 0, 1200, 720), Vector2i(1280, 720), Vector2(640, 360)
	)
	assert_float(insets.x).is_equal_approx(20.0, 0.01)
	assert_float(insets.y).is_equal_approx(0.0, 0.01)
	assert_float(insets.z).is_equal_approx(20.0, 0.01)
	assert_float(insets.w).is_equal_approx(0.0, 0.01)


func test_compact_layout_threshold() -> void:
	assert_bool(UiLayout.is_compact(Vector2(640, 360))).is_false()
	assert_bool(UiLayout.is_compact(Vector2(1024, 768))).is_true()
	assert_bool(UiLayout.is_compact(Vector2(0, 0))).is_false()


func test_grow_pivot() -> void:
	assert_vector(UiLayout.grow_pivot(Vector2(0.5, 1.0), Vector2(200, 40))).is_equal(Vector2(100, 40))


func test_ui_scenes_have_no_hardcoded_style() -> void:
	for path: String in UI_SCENES:
		var text := _read(path)
		assert_bool(text.contains("theme_override_colors/")).is_false()
		assert_bool(text.contains("theme_override_font_sizes/")).is_false()
		assert_bool(text.contains("custom_minimum_size")).is_false()


func test_modal_scenes_have_no_fixed_geometry() -> void:
	for path: String in MODAL_SCENES:
		var text := _read(path)
		assert_bool(text.contains("offset_")).is_false()
		assert_bool(text.contains("theme_override_")).is_false()


func test_every_modal_wires_the_shell() -> void:
	for path: String in MODAL_SCENES:
		var modal := (load(path) as PackedScene).instantiate() as Control
		add_child(modal)
		await get_tree().process_frame
		var shell := modal.find_child("Shell", true, false) as ModalShell
		assert_object(shell).is_not_null()
		if shell != null:
			assert_bool(shell.body.get_child_count() > 0).is_true()
		modal.queue_free()
		await get_tree().process_frame


func test_ui_scale_applies_to_modal_shell() -> void:
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(2.0, false)
	var modal := (load("res://scenes/ui/commission_ui.tscn") as PackedScene).instantiate() as Control
	add_child(modal)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell := modal.find_child("Shell", true, false) as ModalShell
	assert_object(shell).is_not_null()
	if shell != null:
		assert_float(shell.panel.scale.x).is_equal_approx(2.0, 0.001)
	UiSettings.set_scale(previous, false)
	modal.queue_free()


func test_modal_panels_fit_viewport() -> void:
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(1.0, false)
	for path: String in MODAL_SCENES:
		for viewport: Vector2 in RESOLUTIONS:
			var host := _host(viewport)
			var modal := (load(path) as PackedScene).instantiate() as Control
			host.add_child(modal)
			await get_tree().process_frame
			await get_tree().process_frame
			var shell := modal.find_child("Shell", true, false) as ModalShell
			if shell != null:
				var rect := _scaled_rect(shell.panel)
				var content := shell.panel.get_combined_minimum_size()
				assert_bool(_inside(rect, viewport)).is_true()
				assert_bool(shell.panel.size.x + 0.5 >= content.x).is_true()
				assert_bool(shell.panel.size.y + 0.5 >= content.y).is_true()
			host.queue_free()
			await get_tree().process_frame
	UiSettings.set_scale(previous, false)


func test_modal_panel_avoids_touch_controls() -> void:
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(1.0, false)
	var viewport := Vector2(640, 360)
	var host := _host(viewport)
	var modal := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as Control
	host.add_child(modal)
	EventBus.ui.touch_insets_changed.emit(TOUCH_INSETS)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell := modal.find_child("Shell", true, false) as ModalShell
	var rect := _scaled_rect(shell.panel)
	assert_bool(rect.position.x >= TOUCH_INSETS.x - 0.5).is_true()
	assert_bool(rect.end.x <= viewport.x - TOUCH_INSETS.y + 0.5).is_true()
	host.queue_free()
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)
	UiSettings.set_scale(previous, false)


func test_hud_regions_do_not_overlap() -> void:
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(1.0, false)
	var viewport := Vector2(640, 360)
	var host := _host(viewport)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Control
	host.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var status := _scaled_rect(hud.find_child("StatusPanel", true, false) as Control)
	var hints := _scaled_rect(hud.find_child("TopHints", true, false) as Control)
	var bar := _scaled_rect(hud.find_child("InventoryBar", true, false) as Control)
	assert_bool(_inside(status, viewport)).is_true()
	assert_bool(_inside(bar, viewport)).is_true()
	assert_bool(status.intersects(hints)).is_false()
	host.queue_free()
	UiSettings.set_scale(previous, false)


func test_fishing_fight_box_avoids_touch_pad() -> void:
	var viewport := Vector2(640, 360)
	var host := _host(viewport)
	var ui := (load("res://scenes/ui/fishing_ui.tscn") as PackedScene).instantiate() as FishingUi
	host.add_child(ui)
	EventBus.ui.touch_insets_changed.emit(TOUCH_INSETS)
	await get_tree().process_frame
	var fight := ui.find_child("FightBox", true, false) as Control
	fight.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var rect := _scaled_rect(fight)
	var pad_left := viewport.x - TOUCH_INSETS.y
	assert_bool(_inside(rect, viewport)).is_true()
	assert_bool(rect.end.x <= pad_left + 0.5).is_true()
	host.queue_free()
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)


func test_modal_panels_fit_at_large_ui_scale() -> void:
	var previous: float = UiSettings.scale()
	var viewport := Vector2(640, 360)
	for scale: float in [1.0, 1.5, 2.0, 3.0]:
		UiSettings.set_scale(scale, false)
		for path: String in MODAL_SCENES:
			var host := _host(viewport)
			var modal := (load(path) as PackedScene).instantiate() as Control
			host.add_child(modal)
			EventBus.ui.touch_insets_changed.emit(_touch_insets(scale))
			EventBus.ui.ui_scale_changed.emit(scale)
			await get_tree().process_frame
			await get_tree().process_frame
			var shell := modal.find_child("Shell", true, false) as ModalShell
			if shell != null:
				var rect := _scaled_rect(shell.panel)
				var content := shell.panel.get_combined_minimum_size()
				assert_bool(_inside(rect, viewport)).is_true()
				assert_bool(shell.panel.size.x + 0.5 >= content.x).is_true()
				assert_bool(shell.panel.size.y + 0.5 >= content.y).is_true()
			host.queue_free()
			await get_tree().process_frame
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)
	UiSettings.set_scale(previous, false)


func test_dialogue_box_avoids_touch_controls() -> void:
	var previous: float = UiSettings.scale()
	var viewport := Vector2(640, 360)
	for scale: float in [1.0, 1.5]:
		UiSettings.set_scale(scale, false)
		var host := _host(viewport)
		var box := (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate() as DialogueBox
		host.add_child(box)
		box.visible = true
		var insets := _touch_insets(scale)
		EventBus.ui.touch_insets_changed.emit(insets)
		EventBus.ui.ui_scale_changed.emit(scale)
		await get_tree().process_frame
		await get_tree().process_frame
		var rect := _scaled_rect(box.panel)
		assert_bool(_inside(rect, viewport)).is_true()
		assert_bool(rect.position.x >= insets.x - 0.5).is_true()
		assert_bool(rect.end.x <= viewport.x - insets.y + 0.5).is_true()
		host.queue_free()
		await get_tree().process_frame
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)
	UiSettings.set_scale(previous, false)


func test_dialogue_box_fits_at_large_ui_scale() -> void:
	var previous: float = UiSettings.scale()
	var viewport := Vector2(640, 360)
	for scale: float in [2.0, 3.0]:
		UiSettings.set_scale(scale, false)
		var host := _host(viewport)
		var box := (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate() as DialogueBox
		host.add_child(box)
		box.visible = true
		EventBus.ui.touch_insets_changed.emit(_touch_insets(scale))
		EventBus.ui.ui_scale_changed.emit(scale)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_bool(_inside(_scaled_rect(box.panel), viewport)).is_true()
		host.queue_free()
		await get_tree().process_frame
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)
	UiSettings.set_scale(previous, false)


func test_hud_item_bar_stays_onscreen_at_large_scale() -> void:
	var previous: float = UiSettings.scale()
	var viewport := Vector2(640, 360)
	var host := _host(viewport)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	host.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	for scale: float in [1.0, 1.5, 2.0, 2.5, 3.0]:
		UiSettings.set_scale(scale, false)
		EventBus.ui.ui_scale_changed.emit(scale)
		EventBus.ui.touch_insets_changed.emit(_touch_insets(scale))
		await get_tree().process_frame
		await get_tree().process_frame
		var rect := _scaled_rect(hud.inventory_bar)
		assert_bool(rect.position.y >= -0.5).is_true()
		assert_bool(rect.end.y <= viewport.y + 0.5).is_true()
	host.queue_free()
	EventBus.ui.ui_scale_changed.emit(previous)
	EventBus.ui.touch_insets_changed.emit(Vector2.ZERO)
	UiSettings.set_scale(previous, false)


func test_pause_menu_hugs_its_content_width() -> void:
	var previous: float = UiSettings.scale()
	var viewport := Vector2(640, 360)
	var host := _host(viewport)
	var modal := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as Control
	host.add_child(modal)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell := modal.find_child("Shell", true, false) as ModalShell
	assert_object(shell).is_not_null()
	if shell != null:
		var content := shell.panel.get_combined_minimum_size()
		var floor_width: float = maxf(content.x, UiLayout.PANEL_MIN.x)
		assert_bool(shell.panel.size.x + 0.5 >= content.x).is_true()
		assert_bool(shell.panel.size.x <= floor_width + 0.5).is_true()
	host.queue_free()
	UiSettings.set_scale(previous, false)


func _host(viewport: Vector2) -> Control:
	var host := Control.new()
	host.size = viewport
	add_child(host)
	return host


## 控件缩放绕 [member Control.pivot_offset]，所以视觉矩形也要按 pivot 换算。
func _scaled_rect(node: Control) -> Rect2:
	var scale := node.scale.x
	return Rect2(node.position + node.pivot_offset * (1.0 - scale), node.size * scale)


## 触控层放大后实际占用的左右宽度（与 [method TouchControls.side_insets] 同式）。
func _touch_insets(scale: float) -> Vector2:
	return Vector2(
		UiLayout.TOUCH_PAD_MARGIN + UiLayout.EDGE_PADDING + UiLayout.TOUCH_STICK_SIZE * scale,
		UiLayout.TOUCH_PAD_MARGIN + UiLayout.EDGE_PADDING + UiLayout.TOUCH_PAD_SIZE * scale
	)


func _inside(rect: Rect2, viewport: Vector2) -> bool:
	return (
		rect.position.x >= -0.5 and rect.position.y >= -0.5
		and rect.end.x <= viewport.x + 0.5 and rect.end.y <= viewport.y + 0.5
	)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""
