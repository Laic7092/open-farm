class_name Npc
extends Interactable
## NPC：可以对话、按日程在场景里走动，商人还会在上班时开店。
##
## 行为数据来自 [NpcData] 与 [NpcSchedule]：
## [br]- 到点后走 [NpcNavigator] 算出的格子路径前往 [SchedulePoint]；
## [br]- 路上播放行走动画，到达后按 [member ScheduleEntry.facing] 站定；
## [br]- 商人只在日程的 [code]activity == "shop"[/code] 时才开店。
##
## 本脚本只负责"把数据变成移动与一次交互"，寻路算法本身在 [GridPathfinder] 里。

const GROUP: StringName = &"npc"
## 距目标格中心多近算"到了"（像素）。
const ARRIVE_EPSILON: float = 1.0
## 路径失效后隔多久再重算一次（秒），避免每帧都跑 A*。
const REPATH_INTERVAL: float = 0.5

## 好感度变化。
signal affection_changed(value: int)
## 日程切换到了新地点。
signal schedule_location_changed(location_id: StringName)

## 对应的 [NpcData.id]。
@export var npc_id: StringName = &""
## 存档标识（同一场景里多个 NPC 必须各不相同）。
@export var persistence_id: StringName = &""
## 是否在站立时播放轻微起伏动画。
@export var idle_bob: bool = true
## 关闭后不按日程走动（调试或特殊 NPC 用）。
@export var schedule_enabled: bool = true

## 静态数据。
var data: NpcData
## 好感度。
var affection: int = 0
## 当前朝向。
var facing: Facing.Direction = Facing.Direction.DOWN

var _pending_shop_id: StringName = &""
var _schedule: NpcSchedule
var _current_entry: ScheduleEntry
var _target_cell: Vector2i = NpcNavigator.NO_CELL
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _moving: bool = false
var _repath_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = %Sprite


func _enter_tree() -> void:
	add_to_group(GROUP)
	# 世界场景会被缓存复用，所以"每次进树都要接上"的信号放在这里，
	# 不能放在一生只跑一次的 _ready() 里。
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	if not EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.dialogue_finished.connect(_on_dialogue_finished)


func _exit_tree() -> void:
	if EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.disconnect(_on_minute_changed)
	if EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.dialogue_finished.disconnect(_on_dialogue_finished)


func _ready() -> void:
	data = Database.get_npc(npc_id)
	if data != null:
		prompt_key = &"PROMPT_TALK"
		if data.is_merchant():
			prompt_key = &"PROMPT_SHOP"
		if persistence_id == &"":
			persistence_id = StringName("npc_%s" % npc_id)
	else:
		push_warning("Npc: 找不到 NpcData '%s'" % npc_id)

	if persistence_id != &"":
		Persistence.register(self, persistence_id)

	# 动画来自 NpcData：同一个 npc.tscn 换个 npc_id 就换一张脸。
	if data != null:
		_schedule = data.schedule
		if data.frames != null:
			sprite.sprite_frames = data.frames

	if idle_bob:
		_play(&"idle")

	_refresh_schedule()


func _physics_process(delta: float) -> void:
	if _repath_timer > 0.0:
		_repath_timer = maxf(_repath_timer - delta, 0.0)
	if schedule_enabled:
		_refresh_schedule()
	_advance(delta)


# ---------------------------------------------------------------- 日程

## 当前生效的日程段；没有日程时为 null。
func current_entry() -> ScheduleEntry:
	return _current_entry


## 当前要前往的地点 id；没有目标时为空。
func target_location_id() -> StringName:
	return _current_entry.location_id if _current_entry != null else &""


## 当前是否在路上。
func is_moving() -> bool:
	return _moving


## 剩余路径点数量（调试与测试用）。
func path_size() -> int:
	return _path.size()


## 商人是否"在上班"（可以开店）；没有日程数据时一律为 true，保持旧行为。
func is_working() -> bool:
	if _current_entry == null or _schedule == null:
		return true
	return _current_entry.activity == &"shop"


func _on_minute_changed(_hour: int, _minute: int) -> void:
	if schedule_enabled:
		_refresh_schedule()


func _refresh_schedule() -> void:
	if _schedule == null or _schedule.is_empty():
		return
	var entry := _schedule.entry_at(GameClock.minute_of_day)
	if entry == null or entry == _current_entry:
		return
	_current_entry = entry
	schedule_location_changed.emit(entry.location_id)
	_navigate_to(entry.location_id)


func _navigate_to(location_id: StringName) -> void:
	var point := _find_schedule_point(location_id)
	if point == null:
		push_warning("Npc '%s': 找不到日程地点 '%s'" % [npc_id, location_id])
		_target_cell = NpcNavigator.NO_CELL
		_clear_path()
		return
	var navigator := _navigator()
	if navigator != null:
		_target_cell = navigator.cell_of(point.global_position)
	else:
		_target_cell = GridUtils.world_to_cell(point.global_position)
	_recompute_path(true)


func _recompute_path(force: bool) -> void:
	if _target_cell == NpcNavigator.NO_CELL:
		return
	if not force and _repath_timer > 0.0:
		return
	var navigator := _navigator()
	if navigator == null:
		# 导航网格是父节点在 _ready() 里挂的，比 NPC 的 _ready() 晚，
		# 这里不设冷却，下一帧就会再试。
		_clear_path()
		return
	_repath_timer = REPATH_INTERVAL

	var goal := navigator.nearest_walkable(_target_cell)
	if goal == NpcNavigator.NO_CELL:
		_clear_path()
		return
	var from := navigator.cell_of(global_position)
	if from == goal:
		_finish_path()
		return
	_path = navigator.find_path(from, goal)
	_path_index = 0


func _advance(delta: float) -> void:
	if _path.is_empty():
		_set_moving(false)
		if _target_cell != NpcNavigator.NO_CELL:
			_recompute_path(false)
		return

	var next: Vector2i = _path[_path_index]
	var navigator := _navigator()
	var target_world: Vector2 = (
		navigator.world_of(next) if navigator != null else GridUtils.cell_to_world(next)
	)
	if navigator != null and next != _target_cell and not navigator.is_walkable(next):
		# 路上冒出了新障碍（例如今天长成的树），重算一次。
		_recompute_path(true)
		return

	var offset: Vector2 = target_world - global_position
	var step: float = _move_speed() * delta
	if offset.length() <= maxf(step, ARRIVE_EPSILON):
		global_position = target_world
		_path_index += 1
		if _path_index >= _path.size():
			_finish_path()
		return

	_set_moving(true)
	face(Facing.from_vector(offset, facing))
	global_position += offset.normalized() * step


func _finish_path() -> void:
	_path.clear()
	_path_index = 0
	_set_moving(false)
	if _current_entry != null:
		face(_current_entry.facing)


func _clear_path() -> void:
	_path.clear()
	_path_index = 0
	_set_moving(false)


# ---------------------------------------------------------------- 能力

## 转身；站立时会同步切换到对应朝向的待机动画。
func face(direction: Facing.Direction) -> void:
	if facing == direction:
		return
	facing = direction
	if sprite != null:
		sprite.flip_h = Facing.flip_h(facing)
	if not _moving:
		_play(&"idle")


func _set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_play(&"walk" if moving else &"idle")


## 播放 [code]prefix_方向[/code] 形式的动画；旧帧表只有 idle_down 时退回它。
func _play(prefix: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var animation := StringName("%s_%s" % [prefix, Facing.animation_suffix(facing)])
	if not sprite.sprite_frames.has_animation(animation):
		if not sprite.sprite_frames.has_animation(&"idle_down"):
			return
		animation = &"idle_down"
	if sprite.animation == animation and sprite.is_playing():
		return
	sprite.play(animation)


func _move_speed() -> float:
	return maxf(data.move_speed, 1.0) if data != null else 24.0


func _navigator() -> NpcNavigator:
	var tree := get_tree()
	if tree == null:
		return null
	var root := _world_root()
	for node: Node in tree.get_nodes_in_group(NpcNavigator.GROUP):
		var navigator := node as NpcNavigator
		if navigator == null:
			continue
		if root == null or root == navigator or root.is_ancestor_of(navigator):
			return navigator
	return null


func _world_root() -> Node:
	var node: Node = self
	while node != null:
		if node is WorldScene:
			return node
		node = node.get_parent()
	return owner


func _find_schedule_point(location_id: StringName) -> SchedulePoint:
	var tree := get_tree()
	if tree == null:
		return null
	var root := _world_root()
	for node: Node in tree.get_nodes_in_group(SchedulePoint.GROUP):
		var point := node as SchedulePoint
		if point == null or point.point_id != location_id:
			continue
		if root == null or root == point or root.is_ancestor_of(point):
			return point
	return null


# ---------------------------------------------------------------- 对白 / 交互

## 当前季节应该说的话。
func current_dialogue() -> DialogueData:
	if data == null:
		return null
	return data.dialogue_for_season(GameClock.date.season)


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	super.interact(actor)

	var dialogue := current_dialogue()
	if dialogue == null or dialogue.is_empty():
		EventBus.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
		return

	# 停下来面向说话的人，观感更像"被叫住"。
	if actor != null:
		face(Facing.from_vector(actor.global_position - global_position, facing))
	# 商人：先把招呼打完，再打开商店（由 dialogue_finished 触发）。
	_pending_shop_id = data.shop_id if data.is_merchant() and is_working() else &""
	EventBus.dialogue_requested.emit(dialogue)


## 增加好感度。
func add_affection(amount: int) -> void:
	if data == null or amount == 0:
		return
	affection = clampi(affection + amount, 0, data.max_affection)
	affection_changed.emit(affection)


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"affection": affection,
		"position": [global_position.x, global_position.y],
	}


func from_dict(data_dict: Dictionary) -> void:
	affection = maxi(int(data_dict.get("affection", 0)), 0)
	var raw_position: Variant = data_dict.get("position", null)
	if raw_position is Array and (raw_position as Array).size() >= 2:
		global_position = Vector2(
			float((raw_position as Array)[0]), float((raw_position as Array)[1])
		)
	# 位置被存档改写后，强制下一帧按当前时间重新寻路。
	_current_entry = null
	_repath_timer = 0.0
	_clear_path()
	affection_changed.emit(affection)


func _on_dialogue_finished(_dialogue: DialogueData) -> void:
	if _pending_shop_id == &"":
		return
	var shop_id: StringName = _pending_shop_id
	_pending_shop_id = &""
	EventBus.shop_requested.emit(shop_id)
