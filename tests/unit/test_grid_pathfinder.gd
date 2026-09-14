extends GdUnitTestSuite
## 网格 A* 测试：直线、绕障、无路、八方向与路径合并。

const BOUNDS := Rect2i(0, 0, 8, 8)


func _open() -> Callable:
	return func(_cell: Vector2i) -> bool: return false


func _walls(cells: Array[Vector2i]) -> Callable:
	var blocked: Dictionary = {}
	for cell: Vector2i in cells:
		blocked[cell] = true
	return func(cell: Vector2i) -> bool: return blocked.has(cell)


func test_straight_path_contains_both_ends() -> void:
	var path := GridPathfinder.find_path(
		_open(), Vector2i(0, 0), Vector2i(3, 0), BOUNDS, false
	)
	assert_array(path).is_equal(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	)


func test_start_equals_goal_returns_single_cell() -> void:
	var path := GridPathfinder.find_path(
		_open(), Vector2i(2, 2), Vector2i(2, 2), BOUNDS, false
	)
	assert_array(path).contains_exactly([Vector2i(2, 2)])


func test_goal_inside_obstacle_has_no_path() -> void:
	var path := GridPathfinder.find_path(
		_walls([Vector2i(3, 0)]), Vector2i(0, 0), Vector2i(3, 0), BOUNDS, false
	)
	assert_array(path).is_empty()


func test_out_of_bounds_endpoints_have_no_path() -> void:
	assert_array(GridPathfinder.find_path(
		_open(), Vector2i(-1, 0), Vector2i(3, 0), BOUNDS, false
	)).is_empty()
	assert_array(GridPathfinder.find_path(
		_open(), Vector2i(0, 0), Vector2i(9, 0), BOUNDS, false
	)).is_empty()


func test_path_routes_around_a_wall() -> void:
	var walls: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var path := GridPathfinder.find_path(
		_walls(walls), Vector2i(1, 1), Vector2i(3, 1), BOUNDS, false
	)
	assert_array(path).has_size(7)
	assert_that(path[0]).is_equal(Vector2i(1, 1))
	assert_that(path[path.size() - 1]).is_equal(Vector2i(3, 1))
	for cell: Vector2i in path:
		assert_bool(walls.has(cell)).is_false()


func test_full_wall_blocks_everything() -> void:
	var walls: Array[Vector2i] = []
	for y: int in 8:
		walls.append(Vector2i(2, y))
	var path := GridPathfinder.find_path(
		_walls(walls), Vector2i(0, 4), Vector2i(7, 4), BOUNDS, false
	)
	assert_array(path).is_empty()


func test_diagonal_path_is_shorter_than_orthogonal() -> void:
	var diagonal := GridPathfinder.find_path(
		_open(), Vector2i(0, 0), Vector2i(4, 4), BOUNDS, true
	)
	var orthogonal := GridPathfinder.find_path(
		_open(), Vector2i(0, 0), Vector2i(4, 4), BOUNDS, false
	)
	assert_array(diagonal).has_size(5)
	assert_array(orthogonal).has_size(9)


func test_diagonal_does_not_squeeze_through_a_corner() -> void:
	var walls: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var path := GridPathfinder.find_path(
		_walls(walls), Vector2i(0, 0), Vector2i(1, 1), Rect2i(0, 0, 3, 3), true
	)
	assert_array(path).is_empty()


func test_merge_collinear_keeps_only_turns() -> void:
	var merged := GridPathfinder.merge_collinear([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
	])
	assert_array(merged).contains_exactly(
		[Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2)]
	)


func test_merge_collinear_handles_short_paths() -> void:
	assert_array(GridPathfinder.merge_collinear([])).is_empty()
	assert_array(GridPathfinder.merge_collinear([Vector2i(1, 1)])).contains_exactly(
		[Vector2i(1, 1)]
	)


func test_heuristic_is_admissible() -> void:
	# 启发式不能高估到目标的实际代价，否则 A* 不再最优。
	var a := Vector2i(0, 0)
	var b := Vector2i(5, 3)
	assert_float(GridPathfinder.heuristic(a, b, false)).is_equal(8.0)
	assert_float(GridPathfinder.heuristic(a, b, true)).is_less_equal(8.0)
