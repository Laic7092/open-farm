extends GdUnitTestSuite
## HUD：容器只组装，各域的小视图自己认领状态。
##
## 这里锁的是新接缝——[HudItemBarView] 通过组合根注入的提供者拿到物品栏，
## 而不是像以前那样去场景树里找玩家。

func _hud() -> Hud:
	var hud := auto_free(load("res://scenes/ui/hud.tscn").instantiate()) as Hud
	add_child(hud)
	return hud


func _slot(hud: Hud, index: int) -> HudSlot:
	var bar := hud.find_child("InventoryBar", true, false) as HBoxContainer
	assert_object(bar).is_not_null()
	if bar == null:
		return null
	return bar.get_child(index) as HudSlot


func test_item_bar_view_renders_the_injected_bar() -> void:
	var hud := _hud()
	var backpack := Inventory.new(6)
	backpack.add(&"turnip_seed", 5)
	backpack.add(&"hoe", 1)

	hud.bind_item_bar(func() -> ItemBar: return ItemBar.new(backpack))

	assert_str(_slot(hud, 0).count_label.text).is_equal("5")
	assert_object(_slot(hud, 0).icon.texture).is_not_null()
	# 背包只有 6 格，物品栏后面几格应当留空。
	assert_str(_slot(hud, 8).count_label.text).is_equal("")


func test_item_bar_view_goes_empty_without_a_player() -> void:
	var hud := _hud()
	var backpack := Inventory.new(6)
	backpack.add(&"turnip_seed", 5)
	hud.bind_item_bar(func() -> ItemBar: return ItemBar.new(backpack))
	assert_str(_slot(hud, 0).count_label.text).is_equal("5")

	# 玩家离开世界（换图 / 读档）时提供者会给 null，视图应当清空而不是留住旧内容。
	hud.bind_item_bar(func() -> ItemBar: return null)
	assert_str(_slot(hud, 0).count_label.text).is_equal("")
	assert_bool(_slot(hud, 0).icon.visible).is_false()


func test_ui_scale_applies_to_regions() -> void:
	# 走公开设置：_ready() 的延迟应用会读到它，和真实流程一致。
	var previous: float = UiSettings.scale()
	UiSettings.set_scale(2.0, false)
	var hud := _hud()
	# 等布局跑完，pivot 才会依赖到真实的 size。
	await get_tree().process_frame
	await get_tree().process_frame

	var status := hud.find_child("StatusPanel", true, false) as Control
	assert_float(status.scale.x).is_equal_approx(2.0, 0.001)
	# 左上状态卡钉左上角，放大不改变 pivot。
	assert_vector(status.pivot_offset).is_equal(Vector2.ZERO)

	var bar := hud.find_child("InventoryBar", true, false) as Control
	assert_float(bar.scale.x).is_equal_approx(2.0, 0.001)
	# 底部物品栏钉底边中点，放大只朝屏幕内侧长。
	assert_float(bar.pivot_offset.x).is_equal_approx(bar.size.x * 0.5, 0.001)
	assert_float(bar.pivot_offset.y).is_equal_approx(bar.size.y, 0.001)

	var hints := hud.find_child("TopHints", true, false) as Control
	assert_float(hints.scale.x).is_equal_approx(2.0, 0.001)
	# 交互 / 浮动提示整体钉顶边中点，放大只朝下长，行距一起缩放。
	assert_float(hints.pivot_offset.x).is_equal_approx(hints.size.x * 0.5, 0.001)
	assert_float(hints.pivot_offset.y).is_equal_approx(0.0, 0.001)

	UiSettings.set_scale(previous, false)
