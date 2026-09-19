class_name MineFloor
extends FloraField
## 矿洞的一层：按深度确定性地生成矿石与出口。
##
## [b]矿洞单元[/b]：整个矿洞都收在 [code]src/mine/[/code]——本节点负责层生成、
## 矿脉与出口（爬梯 / 电梯），楼层选择界面 [MineElevatorUi] 也由本单元持有；
## 深度规则仍是纯逻辑 [MineRules]，静态数据在 [code]data/mine/[/code]，只按 id 取。
##
## [b]为什么复用 [FloraField][/b]：矿石就是"砸了就掉东西的野生植被"，
## [FarmInteractor] 只认 [code]occupied() / clear()[/code] 这一组鸭子接口，
## 于是同一套镐子逻辑在农场砸石头、在矿洞砸矿石都不需要改。
##
## [b]100 层只有一份场景[/b]：楼层状态不放这里，而是放在 [PlayerProfile]：
## 当前深度、已解锁电梯层、已挖格子。布局由深度做种子确定性生成，
## 换层只是改一个数字再让 [SceneRouter] 重挂同一张缓存场景。
##
## [b]每次进图都会重建[/b]（[method _enter_tree] → [method _catch_up]），
## 因为缓存复用的场景不会重跑 [code]_ready()[/code]。

## 矿洞场景路径（换层时重新切到它）。
const MINE_SCENE: String = "res://scenes/world/mine.tscn"
## 从地面门读不到目标时的兜底：回海滩（矿洞的唯一入口）。
const SURFACE_SCENE: String = "res://scenes/world/beach.tscn"
const SURFACE_SPAWN: StringName = &"from_mine"

var _profile: PlayerProfile
var _depth: int = 1
var _exit_root: Node2D
var _spawn_root: Node
## 地面出口门；类型用 [SceneDoor] 以便坐电梯回地面时复用它的目标场景。
var _surface_door: SceneDoor
var _elevator_ui: MineElevatorUi
## 当前深度所属矿层（由 [method _find_stratum] 解析）；决定画面染色与掉落偏好。
var _stratum: MineStratumData
## 最近一次提示过的矿层 id；只在跨层时弹一次提示。
var _last_stratum_id: StringName = &""
## 场景根上唯一的 [WorldLighting]；按需解析（子节点 _ready 早于父节点）。
var _lighting: WorldLighting


func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_profile = profile
	super.bind_dependencies(profile, clock)


## 不走 [FloraField] 的存档注册：矿石按天重生，没有需要落盘的层内状态。
func _enter_tree() -> void:
	add_to_group(GROUP)
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WORLD)
	if _initialized:
		call_deferred(&"_catch_up")


func _ready() -> void:
	_rng.seed = 1
	_initialized = true
	var world := get_parent()
	var interactables := world.get_node_or_null("Interactables") if world != null else null
	_exit_root = interactables if interactables is Node2D else self
	_spawn_root = world.get_node_or_null("Spawns") if world != null else null
	if _spawn_root == null:
		_spawn_root = self
	_surface_door = world.get_node_or_null("Interactables/ToBeach") as SceneDoor
	_create_spawn_point(&"from_ladder", _ladder_cell())
	_create_spawn_point(&"from_elevator", _elevator_cell())
	_elevator_ui = MineElevatorUi.new()
	_elevator_ui.floor_selected.connect(_on_elevator_floor_selected)
	add_child(_elevator_ui)
	_schedule_initial_generation()


# ---------------------------------------------------------------- 生成

func _generate_initial() -> void:
	_build_floor()


func _catch_up() -> void:
	_build_floor()


func _on_day_rollover(date: GameDate) -> void:
	if _profile != null:
		_profile.mine_refresh_for_day(date.absolute_day())
	_build_floor()


## 按当前深度重建整层：出口 → 矿石。
func _build_floor() -> void:
	if not is_inside_tree():
		return
	_depth = _profile.mine_depth if _profile != null else 1
	# 矿石按天重生：不能只依赖日结转钩子——玩家在农场睡觉过夜时，
	# 矿洞场景并不在场景树里（钩子已注销），重建时补一次刷新。
	if _profile != null and _clock != null:
		_profile.mine_refresh_for_day(_clock.date.absolute_day())
	_clear_floor()
	_build_exits()
	_apply_stratum()

	var candidates: Array[FloraData] = []
	for flora_id: StringName in Database.floras():
		var data := Database.get_flora(flora_id)
		if MineRules.allows(data, _depth):
			candidates.append(data)
	if candidates.is_empty() or flora_scene == null:
		return

	_rng.seed = MineRules.seed_for(_depth)
	var budget: int = MineRules.ore_budget(_depth, _stratum.ore_bonus if _stratum != null else 0)
	var placed: int = 0
	var misses: int = 0
	while placed < budget and misses < budget * 8:
		var loot_bias: float = _stratum.loot_bias if _stratum != null else 1.0
		var data := MineRules.pick_ore(candidates, _depth, _rng, loot_bias)
		if data == null:
			break
		var cell: Vector2i = _random_cell()
		if _profile != null and _profile.mine_is_mined(_depth, cell):
			misses += 1
			continue
		if not _can_place(cell, data.id):
			misses += 1
			continue
		_place(cell, data.id)
		placed += 1
		misses = 0


func _clear_floor() -> void:
	for node: Flora in _nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	flora.clear()
	if _exit_root != null:
		for child: Node in _exit_root.get_children():
			if child is MineLadder or child is MineElevator:
				_exit_root.remove_child(child)
				child.queue_free()
	_update_surface_door()


## 深度 1 才留地面出口；更深只能坐电梯回去。
func _update_surface_door() -> void:
	if _surface_door == null:
		return
	_surface_door.visible = _depth == 1
	_surface_door.enabled = _depth == 1


# ---------------------------------------------------------------- 矿层

## 取当前深度的矿层：给画面染色、定掉落偏好，并在首次进入该矿层时提示。
func _apply_stratum() -> void:
	_stratum = _find_stratum(_depth)
	if _stratum == null:
		return
	if _lighting == null:
		var world := get_parent()
		if world != null:
			_lighting = world.get_node_or_null("WorldLighting") as WorldLighting
	if _lighting != null:
		_lighting.set_world_tint(_blended_tint())
	if _stratum.id == _last_stratum_id:
		return
	_last_stratum_id = _stratum.id
	EventBus.ui.notification_requested.emit(&"NOTIFY_MINE_STRATUM", {
		"name": Text.key(_stratum.display_name_key),
		"depth": _depth,
	})


## 按深度找覆盖它的矿层；区间重叠时取起点最深的一个。
func _find_stratum(depth: int) -> MineStratumData:
	var best: MineStratumData = null
	for stratum_id: StringName in Database.strata():
		var stratum := Database.get_stratum(stratum_id)
		if stratum == null or not stratum.covers(depth):
			continue
		if best == null or stratum.depth_min > best.depth_min:
			best = stratum
	return best


## 当前层的染色：在本层颜色与下一层颜色之间按深度插值，
## 于是同一矿层里每层也有细微变化，不会 100 层一个色。
func _blended_tint() -> Color:
	if _stratum == null:
		return Color.WHITE
	var next := _find_stratum(_stratum.depth_max + 1)
	if next == null:
		return _stratum.tint
	var span: float = maxf(float(_stratum.depth_max - _stratum.depth_min + 1), 1.0)
	var t: float = clampf(float(_depth - _stratum.depth_min) / span, 0.0, 1.0)
	return _stratum.tint.lerp(next.tint, t * 0.6)


# ---------------------------------------------------------------- 出口

func _build_exits() -> void:
	if _exit_root == null:
		return
	var ladder := MineLadder.new()
	ladder.floor = self
	ladder.position = GridUtils.cell_to_world(_ladder_cell())
	_exit_root.add_child(ladder)

	if MineRules.is_elevator_floor(_depth):
		var elevator := MineElevator.new()
		elevator.floor = self
		elevator.position = GridUtils.cell_to_world(_elevator_cell())
		_exit_root.add_child(elevator)


## 爬梯固定放在矿道南端。
func _ladder_cell() -> Vector2i:
	return Vector2i(growth_area.position.x + growth_area.size.x / 2, growth_area.position.y + growth_area.size.y - 4)


## 电梯固定放在矿道北端。
func _elevator_cell() -> Vector2i:
	return Vector2i(growth_area.position.x + growth_area.size.x / 2, growth_area.position.y + 4)


func _create_spawn_point(spawn_id: StringName, cell: Vector2i) -> void:
	var spawn := SpawnPoint.new()
	spawn.name = String(spawn_id).to_pascal_case()
	spawn.spawn_id = spawn_id
	spawn.position = GridUtils.cell_to_world(cell)
	_spawn_root.add_child(spawn)


# ---------------------------------------------------------------- 交互

## 下一层；到底了就提示。
func descend() -> void:
	if _profile == null:
		return
	if _depth >= MineRules.MAX_DEPTH:
		EventBus.ui.notification_requested.emit(&"NOTIFY_MINE_BOTTOM", {})
		return
	_go_to(_depth + 1, &"from_ladder")


## 打开楼层选择。
func open_elevator() -> void:
	if _profile == null or _elevator_ui == null:
		return
	_elevator_ui.open(_depth, _profile.mine_elevator_depth)


func _on_elevator_floor_selected(depth: int) -> void:
	if depth <= MineElevatorUi.SURFACE_DEPTH:
		_leave_mine()
		return
	_go_to(depth, &"from_elevator")


## 坐电梯回地面：优先用地面门声明的场景 / 出生点，避免写死。
func _leave_mine() -> void:
	if _profile == null:
		return
	_profile.mine_leave()
	var host := get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host == null:
		return
	var scene: String = SURFACE_SCENE
	var spawn: StringName = SURFACE_SPAWN
	if _surface_door != null and not _surface_door.target_scene.is_empty():
		scene = _surface_door.target_scene
		spawn = _surface_door.target_spawn_id
	SceneRouter.change_scene_to(host, scene, spawn)


## 记录目标层并让 [SceneRouter] 重挂矿洞场景（缓存复用，原地重建）。
func _go_to(depth: int, spawn_id: StringName) -> void:
	if _profile == null:
		return
	_profile.mine_enter(depth)
	var host := get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host == null:
		return
	SceneRouter.change_scene_to(host, MINE_SCENE, spawn_id)


# ---------------------------------------------------------------- 清除

## 清除一格矿石：先按 [member FloraData.required_tier] 卡工具等级，
## 成功后登记"已挖"并叠加深度品质加成。
func clear(
	cell: Vector2i, tool_kind: ToolData.Kind, by_hand: bool = false, tier: int = 0
) -> Dictionary:
	var state: FloraState = flora.get(cell) as FloraState
	if state == null:
		return {}
	var data := Database.get_flora(state.flora_id)
	if data == null or data.required_tier > tier:
		return {}
	var outcome: Dictionary = super.clear(cell, tool_kind, by_hand, tier)
	if outcome.is_empty():
		return outcome
	if _profile != null:
		_profile.mine_mark_mined(_depth, cell)
	var bonus: float = MineRules.quality_bonus(_depth)
	if _stratum != null:
		bonus += _stratum.quality_bonus
	bonus = minf(bonus, 1.0)
	outcome["quality"] = QualityRules.roll(
		_rng, data.quality_silver_chance + bonus, data.quality_gold_chance + bonus
	)
	return outcome
