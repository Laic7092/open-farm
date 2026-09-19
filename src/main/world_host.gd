class_name WorldHost
extends Node2D
## 世界场景宿主，持有世界实例缓存与显式切换目标。
##
## [SceneRouter] 不再保存任何世界节点；本节点负责“缓存复用世界场景”和
## “在 [method Node.add_child] 前注入组合根依赖”。缓存跨帧保留，因此
## 农田 / 作物 / NPC 进度在换图后仍然存在。

## 宿主所在分组（[SceneRouter] 与 [SaveManager] 只按分组查找，不写节点路径）。
const GROUP: StringName = &"world_host"

## 淡出 / 淡入时长（秒）。
@export var fade_out_duration: float = 0.25
@export var fade_in_duration: float = 0.25
## 遮罩颜色。
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## 世界域事件；与 [code]EventBus.world[/code] 是同一实例。
var events: WorldEvents = EventBus.world

## 世界实例缓存上限；超出后按最近最少使用淘汰。
##
## 淘汰前先把地图内持久化节点的状态快照下来，重新进入时回灌，
## 于是“地图卸载”不会丢进度，也不会让所有地图永久常驻内存。
const MAX_CACHED_WORLDS: int = 4

var _cache: Dictionary[String, Node] = {}
## 每张地图最近一次被挂载的序号，用于 LRU 淘汰。
var _last_used: Dictionary[String, int] = {}
## 被淘汰地图的持久化节点快照；重新实例化时回灌，随后丢弃。
var _evicted_state: Dictionary[String, Dictionary] = {}
var _use_counter: int = 0
var _current_world: Node
var _transitioning: bool = false
## 最近一次落地的出生点，存档时要记下来。
var _last_spawn_id: StringName = &"default"
## 读档时保存“存档所在地图 / 出生点”，等世界重建完再消费。
var _pending_target: WorldTarget = null

## 组合根注入的状态；世界场景挂载前用于注入节点。
var _player_profile: PlayerProfile
var _clock_state: GameDateClock
## 组合根注入的领域服务；世界场景挂载前一并下发。
var _weather_service: WeatherService
var _relationship_service: RelationshipService
var _calendar_service: CalendarService

var _overlay: CanvasLayer
var _fade_rect: ColorRect


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_build_overlay()


func _exit_tree() -> void:
	# 退出时主动释放缓存的世界场景，避免退出期出现一堆“资源仍在使用”的报错。
	clear_world_cache()


## 注入组合根状态；世界场景在进入树前会收到同一份引用。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_player_profile = profile
	_clock_state = clock


## 注入组合根服务；世界场景在进入树前会一并收到。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_weather_service = weather
	_relationship_service = relationships
	_calendar_service = calendar


## 是否正在切换中。
func is_transitioning() -> bool:
	return _transitioning


func begin_transition() -> void:
	_transitioning = true


func finish_transition(spawn_id: StringName) -> void:
	_last_spawn_id = spawn_id
	_transitioning = false


func last_spawn_id() -> StringName:
	return _last_spawn_id


func set_last_spawn(spawn_id: StringName) -> void:
	_last_spawn_id = spawn_id


## 当前挂载中的世界场景；没有则返回 null。
func current_world() -> Node:
	return _current_world if is_instance_valid(_current_world) else null


## 当前挂载世界里的玩家：世界宿主只管自己持有的那张图，不做全树查找。
func current_player() -> Player:
	var world := current_world()
	if world == null:
		return null
	return world.find_child("Player", true, false) as Player


## 当前世界场景的资源路径。
func current_world_path() -> String:
	var world := current_world()
	return world.scene_file_path if world != null else ""


## 挂载（或复用）目标世界；必须在 [method Node.add_child] 前注入依赖。
func install_world(scene_path: String, packed: PackedScene, spawn_id: StringName) -> void:
	_detach_current_world()

	# 被 LRU 淘汰过的地图：先取出快照，等实例 _ready() 跑完再回灌。
	var restored: Dictionary = {}
	if not _cache.has(scene_path):
		_cache[scene_path] = packed.instantiate()
		restored = _evicted_state.get(scene_path, {})
		_evicted_state.erase(scene_path)
	var world: Node = _cache[scene_path]
	_current_world = world
	# 世界子节点的 _enter_tree() 会在 add_child() 时立即执行，因此必须在
	# 挂载前把组合根状态注入场景根；缓存复用也一样。
	_inject_world_dependencies(world)
	add_child(world)

	_use_counter += 1
	_last_used[scene_path] = _use_counter
	_evict_excess()

	# 等两帧，确保新场景的 _ready() 全部跑完、节点进入场景树。
	await get_tree().process_frame
	await get_tree().process_frame

	# 回灌快照：此刻节点引用（crop_scene 等）已齐，from_dict() 才能重建。
	if not restored.is_empty():
		_apply_node_snapshot(world, restored)

	if world.has_method(&"on_world_enter"):
		world.call(&"on_world_enter", spawn_id)


## 把当前世界摘出场景树但保留实例。
func _detach_current_world() -> void:
	var world := current_world()
	if world == null:
		_current_world = null
		return
	if world.has_method(&"on_world_exit"):
		world.call(&"on_world_exit")
	if world.get_parent() == self:
		remove_child(world)
	_current_world = null


## 丢弃单张缓存地图。
func discard_world(scene_path: String) -> void:
	if not _cache.has(scene_path):
		return
	var world: Node = _cache[scene_path]
	_cache.erase(scene_path)
	# 显式丢弃意味着“这局不再要这份状态”，连同淘汰快照一起清掉。
	_evicted_state.erase(scene_path)
	_last_used.erase(scene_path)
	if not is_instance_valid(world):
		return
	if world == _current_world:
		_current_world = null
	var parent := world.get_parent()
	if parent != null:
		parent.remove_child(world)
	world.queue_free()


## 清空世界缓存；新游戏或读档到别的地图时调用，避免复用上一局进度。
func clear_world_cache() -> void:
	for path: String in _cache.keys():
		discard_world(path)
	_cache.clear()
	_evicted_state.clear()
	_last_used.clear()
	_current_world = null


## 缓存超过上限时淘汰最久未使用的地图（当前地图永不淘汰）。
func _evict_excess() -> void:
	while _cache.size() > MAX_CACHED_WORLDS:
		var victim := _least_recently_used()
		if victim.is_empty():
			return
		_evict_world(victim)


## 找一张最久没被切换到的缓存地图；没有可淘汰的（只剩当前地图）时返回空串。
func _least_recently_used() -> String:
	var victim: String = ""
	var oldest: int = 2147483647
	for path: String in _cache.keys():
		if _cache[path] == _current_world:
			continue
		var used: int = _last_used.get(path, 0)
		if used < oldest:
			oldest = used
			victim = path
	return victim


## 淘汰一张地图：先把持久化节点状态快照下来，再释放实例。
func _evict_world(scene_path: String) -> void:
	var world: Node = _cache.get(scene_path) as Node
	if world == null:
		return
	var snapshot := _snapshot_world(world)
	discard_world(scene_path)
	_evicted_state[scene_path] = snapshot


## 收集地图内持久化节点的当前状态（与节点存档同一套 to_dict 契约）。
func _snapshot_world(world: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	for node: Node in world.find_children("*", "", true, false):
		if not node.is_in_group(Persistence.GROUP) or not node.has_method(&"to_dict"):
			continue
		var id := Persistence.id_of(node)
		if id != &"":
			snapshot[String(id)] = node.call(&"to_dict")
	return snapshot


## 把淘汰时保存的节点状态回灌到新实例上（与节点存档同一套 from_dict 契约）。
func _apply_node_snapshot(world: Node, snapshot: Dictionary) -> void:
	for node: Node in world.find_children("*", "", true, false):
		if not node.is_in_group(Persistence.GROUP) or not node.has_method(&"from_dict"):
			continue
		var id := Persistence.id_of(node)
		if id == &"":
			continue
		var data: Variant = snapshot.get(String(id), null)
		if data is Dictionary:
			node.call(&"from_dict", data)


## 把组合根状态注入世界场景；必须发生在 [method Node.add_child] 之前。
func _inject_world_dependencies(world: Node) -> void:
	if world != null and world.has_method(&"bind_dependencies"):
		world.call(&"bind_dependencies", _player_profile, _clock_state)
	if world != null and world.has_method(&"bind_services"):
		world.call(
			&"bind_services", _weather_service, _relationship_service, _calendar_service
		)


## 读档后把世界恢复到显式 [WorldTarget] 记录的地图。
func restore_saved_world() -> void:
	var target := _pending_target
	_pending_target = null
	if target == null or target.is_empty():
		return
	if target.scene_path == current_world_path():
		# 同一张地图：复用现有实例，节点状态会被 SaveManager.apply_node_state() 覆盖。
		SceneRouter.place_player(self, target.spawn_id)
		return
	# 目标地图可能是本局早先缓存的旧实例，先丢掉再按存档重建。
	discard_world(target.scene_path)
	await SceneRouter.change_scene_to(self, target.scene_path, target.spawn_id)


## 存档段；沿用旧键名 "SceneRouter" 的字段格式。
func to_dict() -> Dictionary:
	return {
		"world_path": current_world_path(),
		"spawn_id": String(_last_spawn_id),
	}


func from_dict(data: Dictionary) -> void:
	_pending_target = WorldTarget.new(
		str(data.get("world_path", "")),
		StringName(str(data.get("spawn_id", "default")))
	)


## 世界切换遮罩由宿主持有，[SceneRouter] 只调用无状态过渡方法。
func fade_to(alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	if duration <= 0.0:
		_fade_rect.color.a = alpha
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade_rect, "color:a", alpha, duration)
	await tween.finished


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "ScreenFade"
	_overlay.layer = 128
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_fade_rect.size = viewport_size
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	_overlay.add_child(_fade_rect)
	add_child(_overlay)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	if _fade_rect != null:
		_fade_rect.size = get_viewport().get_visible_rect().size
