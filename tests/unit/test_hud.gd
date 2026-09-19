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
