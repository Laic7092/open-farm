class_name NpcNavigator
extends Node2D
## 一张地图的 NPC 行走网格。
##
## 由 [WorldScene] 自动挂载（见 [method WorldScene._ensure_navigator]），
## NPC 通过它把"从 A 到 B"翻译成格子路径。可通行性来自物理查询
## （layer 1 = world），因此房子、水井、长成的大树都会自动成为障碍，
## 不需要在场景里额外标注。
##
## 查询结果会缓存：世界本身基本不变，只有野生植被会随时间生长，
## 所以日结转过会 [method invalidate] 一次。

## 挂在当前地图上的导航节点所属分组。
const GROUP: StringName = &"npc_navigator"
## 找不到可走格时的哨兵值。
const NO_CELL: Vector2i = Vector2i(-32768, -32768)

## 网格覆盖的世界矩形。
@export var area: Rect2 = Rect2(0, 0, 640, 360)
## 格子边长（像素）。
@export var cell_size: int = GridUtils.TILE_SIZE
## 判定"格子被挡住"时探测的方形边长（像素）。
@export var probe_size: float = 12.0
## A* 最多扩展多少个格子，防止病态地图卡死主线程。
@export var max_expansions: int = 20000

var _region: Rect2i = Rect2i()
var _walkable: Dictionary[Vector2i, bool] = {}
## 组合根注入的时钟；日结转钩子注册在它上面。
var _clock: GameDateClock


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


func _enter_tree() -> void:
	add_to_group(GROUP)
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WORLD)
	_rebuild_region()


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


## 丢弃可通行性缓存（植被长出来后调用）。
func invalidate() -> void:
	_walkable.clear()


## 网格范围（格子坐标）。
func region() -> Rect2i:
	return _region


## 世界坐标 → 格子。
func cell_of(world: Vector2) -> Vector2i:
	return GridUtils.world_to_cell(world, cell_size)


## 格子 → 格子中心的世界坐标。
func world_of(cell: Vector2i) -> Vector2:
	return GridUtils.cell_to_world(cell, cell_size)


## 该格子能不能走。
func is_walkable(cell: Vector2i) -> bool:
	if not _region.has_point(cell):
		return false
	if _walkable.has(cell):
		return _walkable[cell]
	var walkable: bool = not _probe_blocked(cell)
	_walkable[cell] = walkable
	return walkable


## 从 [param from] 到 [param to] 的格子路径（含首尾）；找不到返回空数组。
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var raw := GridPathfinder.find_path(
		func(cell: Vector2i) -> bool: return not is_walkable(cell),
		from,
		to,
		_region,
		true,
		max_expansions
	)
	return GridPathfinder.merge_collinear(raw)


## 距 [param cell] 最近的可走格；[param radius] 格内都没有则返回 [constant NO_CELL]。
func nearest_walkable(cell: Vector2i, radius: int = 4) -> Vector2i:
	if is_walkable(cell):
		return cell
	for ring: int in range(1, radius + 1):
		for y: int in range(-ring, ring + 1):
			for x: int in range(-ring, ring + 1):
				if absi(x) != ring and absi(y) != ring:
					continue
				var candidate: Vector2i = cell + Vector2i(x, y)
				if is_walkable(candidate):
					return candidate
	return NO_CELL


# ---------------------------------------------------------------- 内部

func _rebuild_region() -> void:
	var top_left := GridUtils.world_to_cell(area.position, cell_size)
	var bottom_right := GridUtils.world_to_cell(area.end, cell_size)
	_region = Rect2i(top_left, bottom_right - top_left)


func _probe_blocked(cell: Vector2i) -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(probe_size, probe_size)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, GridUtils.cell_to_world(cell, cell_size))
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not world.direct_space_state.intersect_shape(params, 1).is_empty()


func _on_day_rollover(_date: GameDate) -> void:
	invalidate()
