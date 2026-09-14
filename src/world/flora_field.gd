class_name FloraField
extends Node2D
## 一张地图上所有野生植被的[b]唯一权威状态[/b]。
##
## 与 [FarmGrid] 完全同构：格子状态放在 [Dictionary] 里、视图节点按需生成、
## 日结转时推进模拟、存档就是一次 [method to_dict]。
## 区别在于农场是"玩家种、玩家管"，而这里是"自己长、自己扩散"。
##
## [b]生命周期[/b]
## [br]- [method _ready]：播种初始植被（延迟到第一个物理帧，等静态碰撞体就位）
## [br]- 日结转钩子：生长 → 扩散
## [br]- 重新进入场景树（[SceneRouter] 从缓存里挂回来）：把离开的这几天补算掉
##
## [b]和 [FarmGrid] 一样的坑[/b]：[code]_ready()[/code] 一生只跑一次，
## 所以钩子注册放在 [method _enter_tree]，追补也放在那里。

## 加入该分组后，玩家与工具可以找到当前场景的植被。
const GROUP: StringName = &"flora_field"

## 一次追补最多补算多少天（长时间挂机后不要一次算爆主线程）。
const MAX_CATCH_UP_DAYS: int = 60
## 每个新芽最多采样多少个候选格。
const CANDIDATE_TRIES: int = 8
## 判定"这一格有没有被实心东西占住"时探测的方形边长（像素）。
const SOLID_PROBE_SIZE: float = 12.0

## [method _walkable_seed] 找不到起点时的哨兵值。
const NO_SEED: Vector2i = Vector2i(-32768, -32768)

## 四邻域，用于连通性检查。
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

## 允许生长的矩形区域（格子坐标）。
@export var growth_area: Rect2i = Rect2i(0, 0, 48, 30)

## 地面图层；"只能长在自然地表上"这条规则靠读它的瓦片实现。
@export var ground_layer: TileMapLayer

## 植被精灵挂到哪个节点下。
##
## 建议填 [code]..[/code]（世界场景根节点）：这样每株植被与玩家是兄弟节点，
## 会逐株参与 Y 排序，玩家能走到树后面；放进子容器的话整个容器只会参与一次排序。
@export var flora_root: Node2D

## 植被视图场景（[Flora]）。
@export var flora_scene: PackedScene

## 存档标识，每张地图必须不同。
@export var persistence_id: StringName = &"flora_farm"
## 新地图开局撒多少株初始植被。
@export_range(0, 999) var initial_budget: int = 40
## 每天最多扩散几次。
@export_range(0, 99) var daily_budget: int = 3
## 整张地图的数量上限。
@export_range(0, 999) var max_total: int = 150
## 随机种子；不同地图填不同值就能得到不同的植被分布。
@export var world_seed: int = 1
## 出生点 / 门附近的禁生半径（格），避免一夜之间把门口堵死。
@export_range(0, 8) var protect_radius: int = 2

## 格子状态表：只保存"长着东西"的格子，空字典代表一片干净的地。
var flora: Dictionary[Vector2i, FloraState] = {}

var _nodes: Dictionary[Vector2i, Flora] = {}
var _species: Array[FloraData] = []
var _rng := RandomNumberGenerator.new()
var _last_day: int = 0
var _initialized: bool = false
var _loaded: bool = false


## 注册在 [code]_enter_tree()[/code] 而不是 [code]_ready()[/code]：
## 世界场景会被 [SceneRouter] 缓存复用，节点可能多次进出场景树，
## 而 [code]_ready()[/code] 一生只跑一次——放在 _ready 里的话，
## 第一次离开地图后日结转钩子就再也不会被注册回来了。
func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	GameClock.register_day_hook(_on_day_rollover)
	# 重新进入场景树（从缓存挂回来）：把不在的这几天补算掉。
	#
	# 用 call_deferred 而不是直接调用：此刻兄弟节点（出生点、门）还没进场景树，
	# 分组是空的，保护半径会失效，补算时可能把树长到门口。
	# 推迟到本帧末尾，场景树就完整了。
	if _initialized:
		call_deferred(&"_catch_up")


func _exit_tree() -> void:
	GameClock.unregister_day_hook(_on_day_rollover)


func _ready() -> void:
	for flora_id: StringName in Database.floras:
		_species.append(Database.get_flora(flora_id))
	_rng.seed = maxi(world_seed, 1) * 7919 + 104729
	_last_day = GameClock.date.absolute_day()
	_initialized = true
	_schedule_initial_generation()


## 初始植被延迟到第一个物理帧再撒。
##
## 原因：静态道具（房子、水井）的 [StaticBody2D] 是在它们的
## [code]_ready()[/code] 里挂上去的，而 [code]_ready()[/code] 期间
## 物理空间还没刷新，此刻做形状查询可能什么都查不到，树就会长进房子里。
## 等一帧之后，"不许长在实心东西上"这条规则才是可靠的。
func _schedule_initial_generation() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree() or _loaded:
		return
	_generate_initial()


# ---------------------------------------------------------------- 查询

## 这一格上长着东西吗。
func occupied(cell: Vector2i) -> bool:
	return flora.has(cell)


## 取这一格的植被状态；没有则返回 null（只读，不产生副作用）。
func flora_at(cell: Vector2i) -> FloraState:
	return flora.get(cell) as FloraState


## 当前地图上植被的总数。
func total() -> int:
	return flora.size()


## 某个物种当前的数量。
func count_of(flora_id: StringName) -> int:
	var count: int = 0
	for state: FloraState in flora.values():
		if state.flora_id == flora_id:
			count += 1
	return count


# ---------------------------------------------------------------- 操作

## 清除一格上的植被。
##
## [param tool_kind] 必须与 [member FloraData.tool_kind] 一致才会生效
## （斧头砍不动石头）；[param by_hand] 为 true 时改判
## [member FloraData.pickable_by_hand]。
##
## 返回 [code]{ "item_id": StringName, "amount": int, "flora_id": StringName }[/code]，
## 空字典表示这一格没东西 / 工具不对。
func clear(
	cell: Vector2i, tool_kind: ToolData.Kind, by_hand: bool = false
) -> Dictionary:
	var state: FloraState = flora.get(cell) as FloraState
	if state == null:
		return {}
	var data := Database.get_flora(state.flora_id)
	if data == null:
		return {}
	if by_hand:
		if not data.pickable_by_hand:
			return {}
	elif data.tool_kind != tool_kind:
		return {}

	var outcome := FloraGrowth.apply_removal(data, state, _rng)
	var item_id: StringName = outcome.get("item_id", &"")
	var amount: int = int(outcome.get("amount", 0))
	var flora_id: StringName = state.flora_id
	_remove_silently(cell)
	EventBus.flora_cleared.emit(cell, flora_id, item_id, amount)
	return {"item_id": item_id, "amount": amount, "flora_id": flora_id}


# ---------------------------------------------------------------- 日结转

func _on_day_rollover(date: GameDate) -> void:
	_simulate_day(date.season, WeatherSystem.current)
	_last_day = date.absolute_day()


## 把离开这张地图的这几天一次性补算掉。
##
## 未挂载的世界不跑日结转（钩子在 [method _exit_tree] 里注销了），
## 所以"去小镇待了三天，回来树苗长高了"这件事必须在这里补上。
func _catch_up() -> void:
	if not is_inside_tree():
		return
	var now: int = GameClock.date.absolute_day()
	var elapsed: int = now - _last_day
	if elapsed <= 0:
		return
	var steps: int = mini(elapsed, MAX_CATCH_UP_DAYS)
	var start: int = now - steps
	for index: int in steps:
		# 过去这几天的天气无从考据，统一用当前天气近似；季节按天还原。
		_simulate_day(
			GameDate.from_absolute_day(start + index + 1).season, WeatherSystem.current
		)
	_last_day = now


func _simulate_day(season: Season.Type, weather: Weather.Type) -> void:
	_advance_all(season)

	var budget: int = daily_budget
	if Weather.waters_crops(weather):
		budget = int(round(float(budget) * 1.5))
	if weather == Weather.Type.SNOWY:
		budget = 0
	for _i: int in budget:
		if not _try_spawn(_weights_for(season, weather)):
			break


## 所有植被推进一天；跨入"实心"阶段时做一次连通性守卫。
func _advance_all(season: Season.Type) -> void:
	for cell: Vector2i in flora.keys():
		var state: FloraState = flora[cell]
		var data := Database.get_flora(state.flora_id)
		if data == null:
			continue
		var result := FloraGrowth.advance(data, state, season)
		if not bool(result.get(FloraGrowth.KEY_BECAME_SOLID, false)):
			if bool(result.get(FloraGrowth.KEY_STAGE_CHANGED, false)):
				_refresh(cell)
				EventBus.flora_grown.emit(cell, FloraGrowth.stage_of(data, state.days_grown))
			continue

		# 长成实心之前先量一次：假想回到上一阶段，比较可达格数。
		var grown: int = state.days_grown
		state.days_grown = grown - 1
		var before: int = _reachable_count()
		state.days_grown = grown
		if _reachable_count() < before - 1:
			# 这一株会把地图封死：停在原地，明天再试。
			state.days_grown = grown - 1
			_refresh(cell)
			continue
		_refresh(cell)
		EventBus.flora_grown.emit(cell, FloraGrowth.stage_of(data, state.days_grown))


# ---------------------------------------------------------------- 扩散

## 按权重表撒一株新芽；返回是否成功。
func _try_spawn(weights: Dictionary) -> bool:
	if weights.is_empty() or flora.size() >= max_total:
		return false
	var flora_id: StringName = FloraGrowth.pick_spawn(weights, _rng)
	if flora_id == &"":
		return false
	for _attempt: int in CANDIDATE_TRIES:
		var cell: Vector2i = _random_cell()
		if not _can_place(cell, flora_id):
			continue
		return _place_checked(cell, flora_id)
	return false


## 今天可能冒出来的物种及其权重。
func _weights_for(season: Season.Type, weather: Weather.Type) -> Dictionary:
	var weights := {}
	for data: FloraData in _species:
		var weight: int = FloraGrowth.spawn_weight(data, season, weather)
		if weight <= 0 or count_of(data.id) >= data.max_per_world:
			continue
		weights[data.id] = weight
	return weights


## 初始播种用的权重：取四个季节里的峰值，于是"开局是哪一天"不影响新地图的植被。
func _seed_weights() -> Dictionary:
	var weights := {}
	for data: FloraData in _species:
		var weight: int = data.initial_weight
		if weight <= 0 or count_of(data.id) >= data.max_per_world:
			continue
		weights[data.id] = weight
	return weights


func _generate_initial() -> void:
	if initial_budget <= 0 or flora_scene == null:
		return
	for _i: int in initial_budget:
		if not _try_spawn(_seed_weights()):
			break


## 播下一株；如果它一落地就挡路，还要确认没有把地图切成两半。
func _place_checked(cell: Vector2i, flora_id: StringName) -> bool:
	var data := Database.get_flora(flora_id)
	var guard: bool = data != null and data.solid_from_stage == 0
	var before: int = _reachable_count() if guard else 0
	_place(cell, flora_id)
	if guard and _reachable_count() < before - 1:
		_remove_silently(cell)
		return false
	EventBus.flora_spawned.emit(cell, flora_id)
	return true


func _place(cell: Vector2i, flora_id: StringName) -> void:
	var state := FloraState.new(flora_id)
	state.variant = _rng.randi_range(0, 1)
	flora[cell] = state
	_spawn_node(cell)


func _random_cell() -> Vector2i:
	var width: int = maxi(growth_area.size.x, 1)
	var height: int = maxi(growth_area.size.y, 1)
	return Vector2i(
		growth_area.position.x + _rng.randi_range(0, width - 1),
		growth_area.position.y + _rng.randi_range(0, height - 1),
	)


# ---------------------------------------------------------------- 落点判定

func _can_place(cell: Vector2i, flora_id: StringName) -> bool:
	if not growth_area.has_point(cell) or flora.has(cell):
		return false
	var data := Database.get_flora(flora_id)
	if data == null:
		return false
	if not _on_natural_ground(cell):
		return false
	if not _farmland_allows(cell, data):
		return false
	if data.min_spacing > 0 and _too_close_to_same(cell, flora_id, data.min_spacing):
		return false
	if _blocked_by_prop(cell):
		return false
	if _near_protected(cell):
		return false
	if _near_player(cell):
		return false
	return true


## 只有自然地表才长东西：路、石板、水、木地板、栅栏、花圃、干草、木箱
## 这些"人摆过的地方"自动被排除。
func _on_natural_ground(cell: Vector2i) -> bool:
	if ground_layer == null:
		return false
	if ground_layer.get_cell_source_id(cell) == -1:
		return false
	return FloraGrowth.is_natural_ground(ground_layer.get_cell_atlas_coords(cell))


## 农田上的特殊规则：翻过的地、种着作物的地一律不长；
## 没翻耕的空地只有"杂草类"才能长——这就是"田里会长草，得先清掉"。
func _farmland_allows(cell: Vector2i, data: FloraData) -> bool:
	var grid := _farm_grid()
	if grid == null or not grid.is_farmable(cell):
		return true
	if grid.is_tilled(cell) or grid.get_crop(cell) != null:
		return false
	return data.grows_on_farmland


func _too_close_to_same(cell: Vector2i, flora_id: StringName, spacing: int) -> bool:
	for other: Vector2i in flora:
		if flora[other].flora_id != flora_id:
			continue
		if GridUtils.cell_distance(cell, other) <= spacing:
			return true
	return false


## 房子、水井、手摆的实心道具都在 layer 1 上，一次形状查询就能排除。
func _blocked_by_prop(cell: Vector2i) -> bool:
	var world := get_world_2d()
	if world == null:
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SOLID_PROBE_SIZE, SOLID_PROBE_SIZE)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, GridUtils.cell_to_world(cell))
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not world.direct_space_state.intersect_shape(params, 1).is_empty()


## 出生点与门（以及其它 [Interactable]）附近留出空地，免得把门口堵死。
func _near_protected(cell: Vector2i) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for node: Node in tree.get_nodes_in_group(SceneRouter.SPAWN_GROUP):
		if GridUtils.cell_distance(GridUtils.world_to_cell(node.global_position), cell) <= protect_radius:
			return true
	for node: Node in tree.get_nodes_in_group(Interactable.FLORA_BLOCKER_GROUP):
		var interactable := node as Node2D
		if interactable == null:
			continue
		if GridUtils.cell_distance(
			GridUtils.world_to_cell(interactable.global_position), cell
		) <= protect_radius:
			return true
	return false


## 玩家脚边一格之内不许冒东西：睡觉时被树顶住就再也出不来了。
func _near_player(cell: Vector2i) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return false
	return GridUtils.cell_distance(GridUtils.world_to_cell(player.global_position), cell) <= 1


# ---------------------------------------------------------------- 连通性守卫

## 从任意一个可走格出发，能走到多少个格子。
##
## 只看[b]植被[/b]造成的阻挡——房子、边界墙这些是地图设计的一部分，
## 前后不会变，不参与比较。于是"新长出来的东西有没有把地图切成两半"
## 就等价于"可达格数有没有突然变少"。
func _reachable_count() -> int:
	var seed: Vector2i = _walkable_seed()
	if seed == NO_SEED:
		return 0
	var visited := {seed: true}
	var queue: Array[Vector2i] = [seed]
	var count: int = 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		count += 1
		for offset: Vector2i in NEIGHBORS:
			var next: Vector2i = cell + offset
			if visited.has(next) or not growth_area.has_point(next):
				continue
			if _solid_at(next):
				continue
			visited[next] = true
			queue.append(next)
	return count


## 找一个不是实心植被的起点：优先玩家脚下，其次出生点，最后全图扫描。
func _walkable_seed() -> Vector2i:
	var tree := get_tree()
	if tree != null:
		var player := tree.get_first_node_in_group(Player.GROUP) as Player
		if player != null:
			var cell: Vector2i = GridUtils.world_to_cell(player.global_position)
			if growth_area.has_point(cell) and not _solid_at(cell):
				return cell
		for node: Node in tree.get_nodes_in_group(SceneRouter.SPAWN_GROUP):
			var cell: Vector2i = GridUtils.world_to_cell(node.global_position)
			if growth_area.has_point(cell) and not _solid_at(cell):
				return cell
	for y: int in growth_area.size.y:
		for x: int in growth_area.size.x:
			var cell := growth_area.position + Vector2i(x, y)
			if not _solid_at(cell):
				return cell
	return NO_SEED


func _solid_at(cell: Vector2i) -> bool:
	var state: FloraState = flora.get(cell) as FloraState
	if state == null:
		return false
	var data := Database.get_flora(state.flora_id)
	return data != null and FloraGrowth.is_solid(data, state.days_grown)


# ---------------------------------------------------------------- 视图

func _spawn_node(cell: Vector2i) -> void:
	if flora_scene == null:
		return
	var state: FloraState = flora.get(cell) as FloraState
	if state == null:
		return
	var node := flora_scene.instantiate() as Flora
	if node == null:
		push_error("FloraField: flora_scene 的根节点必须是 Flora")
		return
	var parent: Node = flora_root if flora_root != null else self
	parent.add_child(node)
	node.position = GridUtils.cell_to_world(cell)
	node.setup(state, Database.get_flora(state.flora_id))
	_nodes[cell] = node


func _remove_silently(cell: Vector2i) -> void:
	flora.erase(cell)
	var node: Flora = _nodes.get(cell) as Flora
	_nodes.erase(cell)
	if is_instance_valid(node):
		node.queue_free()


func _refresh(cell: Vector2i) -> void:
	var node: Flora = _nodes.get(cell) as Flora
	if is_instance_valid(node):
		node.refresh()


func _rebuild_visuals() -> void:
	for cell: Vector2i in flora:
		_spawn_node(cell)


func _farm_grid() -> FarmGrid:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	var entries: Array = []
	for cell: Vector2i in flora:
		entries.append({"cell": [cell.x, cell.y], "state": flora[cell].to_dict()})
	# 排序保证存档内容稳定，便于 diff 与测试。
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Array = a.get("cell", [0, 0])
		var cb: Array = b.get("cell", [0, 0])
		if int(ca[1]) != int(cb[1]):
			return int(ca[1]) < int(cb[1])
		return int(ca[0]) < int(cb[0])
	)
	return {"flora": entries, "last_day": _last_day, "rng_state": _rng.state}


func from_dict(data: Dictionary) -> void:
	_loaded = true
	for node: Flora in _nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	flora.clear()

	var raw: Variant = data.get("flora", [])
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary:
				continue
			var raw_cell: Variant = (entry as Dictionary).get("cell", [])
			if not raw_cell is Array or (raw_cell as Array).size() < 2:
				continue
			var cell := Vector2i(int((raw_cell as Array)[0]), int((raw_cell as Array)[1]))
			var raw_state: Variant = (entry as Dictionary).get("state", {})
			var state := FloraState.new()
			state.from_dict(raw_state if raw_state is Dictionary else {})
			if state.is_empty():
				continue
			flora[cell] = state

	_last_day = int(data.get("last_day", _last_day))
	var rng_state: int = int(data.get("rng_state", _rng.state))
	if rng_state > 0:
		_rng.state = rng_state
	_rebuild_visuals()
