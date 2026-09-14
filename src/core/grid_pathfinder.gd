class_name GridPathfinder
extends RefCounted
## 网格 A*：在"哪些格子能走"由调用方决定的前提下找最短路径。
##
## 纯静态函数，[param solid] 是形如 [code]func(cell: Vector2i) -> bool[/code] 的
## [Callable]。这样寻路不碰场景树，单元测试可以直接喂一张内存地图
## （见 [code]tests/unit/test_grid_pathfinder.gd[/code]）。
##
## 支持四方向与八方向；八方向会拒绝"从两个障碍之间斜穿过去"。

## 走一格的代价。
const ORTHOGONAL_COST: float = 1.0
const DIAGONAL_COST: float = 1.41421356237

## 四邻域 / 八邻域步进。
const DIRS_ORTHOGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const DIRS_DIAGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## 从 [param from] 到 [param to] 的格子路径（[b]含首尾[/b]）；找不到返回空数组。
##
## [param bounds] 限定搜索范围；起点或终点在范围外都直接失败。
## 终点是障碍时无路可走；起点是障碍时仍允许出发（不然卡住的人永远出不来）。
static func find_path(
	solid: Callable,
	from: Vector2i,
	to: Vector2i,
	bounds: Rect2i,
	allow_diagonal: bool = true,
	max_expansions: int = 20000
) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not bounds.has_point(from) or not bounds.has_point(to):
		return empty
	if is_solid(solid, to):
		return empty
	if from == to:
		var single: Array[Vector2i] = [from]
		return single

	var dirs: Array[Vector2i] = DIRS_DIAGONAL if allow_diagonal else DIRS_ORTHOGONAL
	var came: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var f_score: Dictionary = {from: heuristic(from, to, allow_diagonal)}
	var open: Array[Vector2i] = [from]
	var closed: Dictionary = {}
	var expansions: int = 0

	while not open.is_empty():
		var current: Vector2i = _heap_pop(open, f_score)
		if closed.has(current):
			continue
		if current == to:
			return _reconstruct(came, from, to)
		closed[current] = true
		expansions += 1
		if expansions > max_expansions:
			break

		for direction: Vector2i in dirs:
			var next: Vector2i = current + direction
			if closed.has(next) or not bounds.has_point(next):
				continue
			if is_solid(solid, next):
				continue
			var diagonal: bool = direction.x != 0 and direction.y != 0
			if diagonal and _cuts_corner(solid, current, direction):
				continue
			var step: float = DIAGONAL_COST if diagonal else ORTHOGONAL_COST
			var tentative: float = float(g_score[current]) + step
			if g_score.has(next) and tentative >= float(g_score[next]):
				continue
			came[next] = current
			g_score[next] = tentative
			f_score[next] = tentative + heuristic(next, to, allow_diagonal)
			_heap_push(open, next, f_score)

	return empty


## 该格是否被判定为障碍（[param solid] 无效时一律当作可走）。
static func is_solid(solid: Callable, cell: Vector2i) -> bool:
	if not solid.is_valid():
		return false
	return bool(solid.call(cell))


## 八方向启发式：无障碍时等于实际步数（可采纳，不会高估）。
static func heuristic(a: Vector2i, b: Vector2i, allow_diagonal: bool) -> float:
	var delta: Vector2i = (a - b).abs()
	if not allow_diagonal:
		return float(delta.x + delta.y)
	var minimum: int = mini(delta.x, delta.y)
	return float(delta.x + delta.y) + (DIAGONAL_COST - 2.0) * float(minimum)


## 把连续同方向的步子合并成一个路径点，减少 NPC 的来回转身。
##
## 只做"共线合并"，不做任意跳跃，因此不会把路径简化到穿过障碍。
static func merge_collinear(path: Array[Vector2i]) -> Array[Vector2i]:
	var merged: Array[Vector2i] = []
	if path.is_empty():
		return merged
	merged.append(path[0])
	if path.size() == 1:
		return merged
	var previous: Vector2i = path[1] - path[0]
	for index: int in range(1, path.size() - 1):
		var step: Vector2i = path[index + 1] - path[index]
		if step != previous:
			merged.append(path[index])
			previous = step
	merged.append(path[path.size() - 1])
	return merged


# ---------------------------------------------------------------- 内部

## 斜穿两个障碍之间的缝：只要有一侧挡住就不许斜着过。
static func _cuts_corner(solid: Callable, current: Vector2i, direction: Vector2i) -> bool:
	return (
		is_solid(solid, current + Vector2i(direction.x, 0))
		or is_solid(solid, current + Vector2i(0, direction.y))
	)


static func _reconstruct(came: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var node: Vector2i = to
	while node != from:
		path.append(node)
		node = came[node]
	path.append(from)
	path.reverse()
	return path


## 以 [param f_score] 为优先级的二叉最小堆。
static func _heap_push(heap: Array[Vector2i], cell: Vector2i, f_score: Dictionary) -> void:
	heap.append(cell)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if float(f_score[heap[parent]]) <= float(f_score[heap[index]]):
			break
		var swap: Vector2i = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


static func _heap_pop(heap: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var top: Vector2i = heap[0]
	var last: Vector2i = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var index: int = 0
	var size: int = heap.size()
	while true:
		var left: int = index * 2 + 1
		var right: int = left + 1
		var smallest: int = index
		if left < size and float(f_score[heap[left]]) < float(f_score[heap[smallest]]):
			smallest = left
		if right < size and float(f_score[heap[right]]) < float(f_score[heap[smallest]]):
			smallest = right
		if smallest == index:
			break
		var swap: Vector2i = heap[smallest]
		heap[smallest] = heap[index]
		heap[index] = swap
		index = smallest
	return top
