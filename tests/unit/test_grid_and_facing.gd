extends GdUnitTestSuite
## 网格换算与朝向工具测试。


func test_world_to_cell_floors_negative_coordinates() -> void:
	assert_that(GridUtils.world_to_cell(Vector2(0, 0))).is_equal(Vector2i(0, 0))
	assert_that(GridUtils.world_to_cell(Vector2(15.9, 15.9))).is_equal(Vector2i(0, 0))
	assert_that(GridUtils.world_to_cell(Vector2(16, 16))).is_equal(Vector2i(1, 1))
	assert_that(GridUtils.world_to_cell(Vector2(-1, -1))).is_equal(Vector2i(-1, -1))


func test_cell_to_world_returns_cell_center() -> void:
	assert_that(GridUtils.cell_to_world(Vector2i(0, 0))).is_equal(Vector2(8, 8))
	assert_that(GridUtils.cell_to_world(Vector2i(2, 3))).is_equal(Vector2(40, 56))


func test_world_to_cell_then_back_is_stable() -> void:
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(-3, -7)]:
		var world := GridUtils.cell_to_world(cell)
		assert_that(GridUtils.world_to_cell(world)).is_equal(cell)


func test_cells_in_area_covers_every_cell() -> void:
	var cells := GridUtils.cells_in_area(Vector2i(1, 2), Vector2i(3, 2))
	assert_array(cells).has_size(6)
	assert_bool(cells.has(Vector2i(1, 2))).is_true()
	assert_bool(cells.has(Vector2i(3, 3))).is_true()
	assert_bool(cells.has(Vector2i(4, 3))).is_false()


func test_cells_in_area_treats_zero_size_as_one() -> void:
	assert_array(GridUtils.cells_in_area(Vector2i(0, 0), Vector2i.ZERO)).has_size(1)


func test_cells_in_direction_excludes_origin() -> void:
	var cells := GridUtils.cells_in_direction(Vector2i(0, 0), Vector2i(1, 0), 3)
	assert_array(cells).contains_exactly([Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_cells_in_direction_with_zero_direction_is_empty() -> void:
	assert_array(GridUtils.cells_in_direction(Vector2i(0, 0), Vector2i.ZERO, 3)).is_empty()


func test_area_in_front_shifts_by_facing() -> void:
	assert_that(GridUtils.area_in_front(Vector2i(4, 4), Vector2i(0, 1))).is_equal(
		Vector2i(4, 5)
	)
	assert_that(GridUtils.area_in_front(Vector2i(4, 4), Vector2i(-1, 0))).is_equal(
		Vector2i(3, 4)
	)


func test_area_in_front_centers_larger_areas() -> void:
	# 3x3 的作用范围应当以正前方那一格为中心。
	assert_that(
		GridUtils.area_in_front(Vector2i(5, 5), Vector2i(0, 1), Vector2i(3, 3))
	).is_equal(Vector2i(4, 5))


func test_snap_to_cell_center() -> void:
	assert_that(GridUtils.snap_to_cell_center(Vector2(20, 20))).is_equal(Vector2(24, 24))


func test_cell_distance_is_chebyshev() -> void:
	assert_int(GridUtils.cell_distance(Vector2i(0, 0), Vector2i(1, 1))).is_equal(1)
	assert_int(GridUtils.cell_distance(Vector2i(0, 0), Vector2i(3, 1))).is_equal(3)
	assert_int(GridUtils.cell_distance(Vector2i(2, 2), Vector2i(2, 2))).is_equal(0)


# ---------------------------------------------------------------- Facing

func test_facing_vectors() -> void:
	assert_that(Facing.to_vector(Facing.Direction.DOWN)).is_equal(Vector2i(0, 1))
	assert_that(Facing.to_vector(Facing.Direction.UP)).is_equal(Vector2i(0, -1))
	assert_that(Facing.to_vector(Facing.Direction.LEFT)).is_equal(Vector2i(-1, 0))
	assert_that(Facing.to_vector(Facing.Direction.RIGHT)).is_equal(Vector2i(1, 0))


func test_facing_from_vector_prefers_horizontal_on_ties() -> void:
	assert_int(Facing.from_vector(Vector2(1, 1))).is_equal(Facing.Direction.RIGHT)
	assert_int(Facing.from_vector(Vector2(-1, -1))).is_equal(Facing.Direction.LEFT)
	assert_int(Facing.from_vector(Vector2(0, 1))).is_equal(Facing.Direction.DOWN)
	assert_int(Facing.from_vector(Vector2(0, -1))).is_equal(Facing.Direction.UP)


func test_facing_from_zero_vector_returns_fallback() -> void:
	assert_int(Facing.from_vector(Vector2.ZERO)).is_equal(Facing.Direction.DOWN)
	assert_int(Facing.from_vector(Vector2.ZERO, Facing.Direction.LEFT)).is_equal(
		Facing.Direction.LEFT
	)


func test_facing_opposite_is_an_involution() -> void:
	for direction: Facing.Direction in [0, 1, 2, 3]:
		assert_int(Facing.opposite(Facing.opposite(direction))).is_equal(direction)


func test_side_facing_shares_one_animation() -> void:
	assert_str(String(Facing.animation_suffix(Facing.Direction.LEFT))).is_equal("side")
	assert_str(String(Facing.animation_suffix(Facing.Direction.RIGHT))).is_equal("side")
	assert_bool(Facing.flip_h(Facing.Direction.LEFT)).is_true()
	assert_bool(Facing.flip_h(Facing.Direction.RIGHT)).is_false()


func test_facing_key_roundtrip() -> void:
	for direction: Facing.Direction in [0, 1, 2, 3]:
		assert_int(Facing.from_key(String(Facing.to_key(direction)))).is_equal(direction)
