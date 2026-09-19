extends GdUnitTestSuite
## 播种规则：把种子种下去与从背包扣一颗必须绑在一起。
##
## [FarmGrid.plant] 只管地里那一份状态，自己不消耗道具；[ItemUse] 负责"扣一颗"。
## 这里锁住的是二者的边界：失败不扣、成功扣、没种子不动。

func _grid() -> FarmGrid:
	var grid := auto_free(FarmGrid.new()) as FarmGrid
	grid.farmable_area = Rect2i(0, 0, 4, 4)
	return grid


func _till(grid: FarmGrid, cell: Vector2i) -> void:
	var tile := FarmTile.new(cell)
	tile.tilled = true
	grid.tiles[cell] = tile


func test_plant_consumes_exactly_one_seed() -> void:
	var grid := _grid()
	_till(grid, Vector2i(1, 1))
	var inventory := Inventory.new(4)
	inventory.add(&"turnip_seed", 3)

	var planted := ItemUse.plant_seed(
		grid, inventory, &"turnip_seed", Vector2i(1, 1), Season.Type.SPRING
	)
	assert_bool(planted).is_true()
	assert_int(inventory.count_of(&"turnip_seed")).is_equal(2)
	assert_object(grid.get_crop(Vector2i(1, 1))).is_not_null()


func test_failed_plant_does_not_consume() -> void:
	var grid := _grid()
	var inventory := Inventory.new(4)
	inventory.add(&"turnip_seed", 3)

	# 没翻过的地种不下去，就不该扣种子。
	var planted := ItemUse.plant_seed(
		grid, inventory, &"turnip_seed", Vector2i(1, 1), Season.Type.SPRING
	)
	assert_bool(planted).is_false()
	assert_int(inventory.count_of(&"turnip_seed")).is_equal(3)


func test_plant_without_the_seed_in_inventory_is_a_noop() -> void:
	var grid := _grid()
	_till(grid, Vector2i(1, 1))
	var inventory := Inventory.new(4)

	var planted := ItemUse.plant_seed(
		grid, inventory, &"turnip_seed", Vector2i(1, 1), Season.Type.SPRING
	)
	assert_bool(planted).is_false()
	assert_object(grid.get_crop(Vector2i(1, 1))).is_null()


func test_plant_without_grid_or_seed_id_fails() -> void:
	var inventory := Inventory.new(4)
	inventory.add(&"turnip_seed", 1)
	assert_bool(
		ItemUse.plant_seed(null, inventory, &"turnip_seed", Vector2i.ZERO, Season.Type.SPRING)
	).is_false()
	assert_bool(
		ItemUse.plant_seed(null, inventory, &"", Vector2i.ZERO, Season.Type.SPRING)
	).is_false()
	assert_int(inventory.count_of(&"turnip_seed")).is_equal(1)
