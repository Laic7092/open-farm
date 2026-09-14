class_name GridUtils
extends RefCounted
## 网格 / 世界坐标换算与范围计算。
##
## 农场、工具作用范围、寻路提示都基于同一套格子约定：
## 格子中心即 [code]cell * tile_size + tile_size / 2[/code]。

## 默认格子边长（像素）。
const TILE_SIZE: int = 16


## 世界坐标 → 格子坐标。
static func world_to_cell(world: Vector2, tile_size: int = TILE_SIZE) -> Vector2i:
	return Vector2i(floori(world.x / tile_size), floori(world.y / tile_size))


## 格子坐标 → 该格子中心的世界坐标。
static func cell_to_world(cell: Vector2i, tile_size: int = TILE_SIZE) -> Vector2:
	return Vector2(cell) * float(tile_size) + Vector2.ONE * (float(tile_size) * 0.5)


## 以 [param top_left] 为左上角的矩形区域内的所有格子。
static func cells_in_area(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var width: int = maxi(size.x, 1)
	var height: int = maxi(size.y, 1)
	for y: int in height:
		for x: int in width:
			cells.append(top_left + Vector2i(x, y))
	return cells


## 从 [param origin] 沿 [param direction] 延伸 [param reach] 格的直线格子序列（不含起点）。
static func cells_in_direction(
	origin: Vector2i, direction: Vector2i, reach: int = 1
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return cells
	for step: int in range(1, maxi(reach, 0) + 1):
		cells.append(origin + direction * step)
	return cells


## 以 [param origin] 为中心、朝 [param facing] 方向偏移后的作用区域左上角。
##
## 单格工具就是正前方一格；[param size] 大于 1 时以该格为中心铺开。
static func area_in_front(
	origin: Vector2i, facing: Vector2i, size: Vector2i = Vector2i.ONE
) -> Vector2i:
	var anchor: Vector2i = origin + facing
	var offset := Vector2i(
		-((maxi(size.x, 1) - 1) / 2),
		-((maxi(size.y, 1) - 1) / 2),
	)
	return anchor + offset


## 把世界坐标对齐到格子中心。
static func snap_to_cell_center(world: Vector2, tile_size: int = TILE_SIZE) -> Vector2:
	return cell_to_world(world_to_cell(world, tile_size), tile_size)


## 切比雪夫距离，用于判断"是否相邻"这类格子关系。
static func cell_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = (a - b).abs()
	return maxi(delta.x, delta.y)
