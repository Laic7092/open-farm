extends Node
## 场景路由（Autoload：`SceneRouter`）。
##
## 负责带淡入淡出的场景切换，并把玩家落到目标场景正确的 [SpawnPoint] 上。
##
## [b]为什么出生点用标记节点而不是坐标[/b]：
## 让逻辑引用"名字"（[code]spawn_id[/code]）而不是"数字"，
## 这样重排场景布局、调整房间大小都不需要改任何传送代码。
##
## [b]为什么世界场景要缓存[/b]：
## 农田的翻耕 / 作物状态就存在世界场景的节点里。每次传送都重建场景，
## 会让"种好菜去趟小镇，回来地全荒了"。所以切过的地图保留实例、只是移出场景树，
## 再回去时直接挂回来，进度自然还在。
## 代价是常驻内存——地图数量真的多起来时，需要改成
## "卸载地图 + 把状态外置到存档层"。

## 玩家所在分组（约定：全局唯一）。
const PLAYER_GROUP: StringName = &"player"
## 出生点所在分组，由 [SpawnPoint] 自动加入。
const SPAWN_GROUP: StringName = &"spawn_point"
## 世界场景宿主所在分组，由 [Main] 注册。
const WORLD_HOST_GROUP: StringName = &"world_host"

## 淡出 / 淡入时长（秒）。
@export var fade_out_duration: float = 0.25
@export var fade_in_duration: float = 0.25
## 遮罩颜色。
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)

var _overlay: CanvasLayer
var _rect: ColorRect
var _transitioning: bool = false

## 已实例化的世界场景：场景路径 → 节点。
var _world_cache: Dictionary[String, Node] = {}
## 当前挂载中的世界场景。
var _current_world: Node
## 最近一次落地的出生点，存档时要记下来。
var _last_spawn_id: StringName = &"default"
## 读档时记录"存档所在地图"，等世界重建完再消费。
var _pending_world_path: String = ""
var _pending_spawn_id: StringName = &"default"


func _ready() -> void:
	_build_overlay()
	# 常驻在场景树里，切换场景不会销毁。
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	# 退出时主动释放缓存的世界场景，避免退出期出现一堆"资源仍在使用"的报错。
	clear_world_cache()


## 是否正在切换中。
func is_transitioning() -> bool:
	return _transitioning


## 切换世界场景并把玩家放到 [param spawn_id] 对应的出生点。
##
## 世界场景会被挂到 [constant WORLD_HOST_GROUP] 组的节点下，
## 而不是用 [method SceneTree.change_scene_to_file] 顶掉当前场景——
## 这样 [Main] 与 UI 层始终常驻，不会因为一次传送就被销毁重建。
func change_scene_to(scene_path: String, spawn_id: StringName = &"default") -> void:
	if _transitioning:
		push_warning("SceneRouter: 上一次切换尚未结束，忽略 '%s'" % scene_path)
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: 无法加载场景 '%s'" % scene_path)
		return

	_transitioning = true
	EventBus.scene_transition_started.emit(spawn_id)

	var was_paused: bool = GameClock.paused
	GameClock.paused = true

	await _fade_to(1.0, fade_out_duration)
	await _swap_world(scene_path, packed, spawn_id)
	_place_player(spawn_id)
	await _fade_to(0.0, fade_in_duration)

	GameClock.paused = was_paused
	_transitioning = false
	EventBus.scene_transition_finished.emit(spawn_id)


## 重载当前世界场景（读档 / 重开当天）。
##
## 会丢弃缓存里的那份实例，强制走一次完整的 [code]_ready()[/code]。
func reload_current_scene(spawn_id: StringName = &"default") -> void:
	var path := current_world_path()
	if path.is_empty():
		return
	_discard_world(path)
	await change_scene_to(path, spawn_id)


## 当前挂载中的世界场景；没有则返回 null。
func current_world() -> Node:
	return _current_world if is_instance_valid(_current_world) else null


## 当前世界场景的资源路径。
func current_world_path() -> String:
	var world := current_world()
	return world.scene_file_path if world != null else ""


## 世界场景的宿主节点。
func world_host() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(WORLD_HOST_GROUP)


## 清空世界缓存。
##
## 新游戏或读档到别的地图时调用，避免旧地图带着上一局的进度被复用。
func clear_world_cache() -> void:
	for path: String in _world_cache.keys():
		_discard_world(path)
	_world_cache.clear()
	_current_world = null


# ---------------------------------------------------------------- 读档

## 读档后把世界恢复到存档记录的那张地图。
##
## [SaveManager] 恢复完核心单例后调用；调用方随后还需要
## [method SaveManager.apply_node_state] 把节点状态灌进新场景。
func restore_saved_world() -> void:
	var target_path := _pending_world_path
	var target_spawn := _pending_spawn_id
	_pending_world_path = ""
	_pending_spawn_id = &"default"

	if target_path.is_empty() or target_path == current_world_path():
		# 同一张地图：复用现有实例，节点状态会被 apply_node_state() 覆盖。
		_place_player(target_spawn)
		return

	# 目标地图可能是本局早先缓存的旧实例，先丢掉再按存档重建。
	_discard_world(target_path)
	await change_scene_to(target_path, target_spawn)


func to_dict() -> Dictionary:
	return {
		"world_path": current_world_path(),
		"spawn_id": String(_last_spawn_id),
	}


func from_dict(data: Dictionary) -> void:
	_pending_world_path = str(data.get("world_path", ""))
	_pending_spawn_id = StringName(str(data.get("spawn_id", "default")))


# ---------------------------------------------------------------- 内部

func _swap_world(scene_path: String, packed: PackedScene, spawn_id: StringName) -> void:
	var host := world_host()
	if host == null:
		push_error("SceneRouter: 场景树中没有 world_host 组节点，无法挂载世界")
		return

	_detach_current_world(host)

	if not _world_cache.has(scene_path):
		_world_cache[scene_path] = packed.instantiate()
	_current_world = _world_cache[scene_path]
	host.add_child(_current_world)

	# 等两帧，确保新场景的 _ready() 全部跑完、节点进入场景树。
	await get_tree().process_frame
	await get_tree().process_frame

	if _current_world.has_method(&"on_world_enter"):
		_current_world.call(&"on_world_enter", spawn_id)


## 把当前世界摘出场景树但保留实例。
##
## 必须先 remove_child 再 queue_free：queue_free 要等到帧末才生效，
## 期间旧玩家仍在 player 分组里，_place_player 会抓到已经作废的节点。
func _detach_current_world(host: Node) -> void:
	var world := current_world()
	if world == null:
		_current_world = null
		return
	if world.has_method(&"on_world_exit"):
		world.call(&"on_world_exit")
	if world.get_parent() == host:
		host.remove_child(world)
	_current_world = null


func _discard_world(scene_path: String) -> void:
	if not _world_cache.has(scene_path):
		return
	var world: Node = _world_cache[scene_path]
	_world_cache.erase(scene_path)
	if not is_instance_valid(world):
		return
	if world == _current_world:
		_current_world = null
	var parent := world.get_parent()
	if parent != null:
		parent.remove_child(world)
	world.queue_free()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "ScreenFade"
	_overlay.layer = 128
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.name = "Fade"
	_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ColorRect 需要铺满整个视口。
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_rect.size = viewport_size
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	_overlay.add_child(_rect)
	add_child(_overlay)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	if _rect != null:
		_rect.size = get_viewport().get_visible_rect().size


func _fade_to(alpha: float, duration: float) -> void:
	if _rect == null:
		return
	if duration <= 0.0:
		_rect.color.a = alpha
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_rect, "color:a", alpha, duration)
	await tween.finished


func _place_player(spawn_id: StringName) -> void:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	var target := _find_spawn_point(spawn_id)
	if target == null:
		push_warning("SceneRouter: 场景中没有找到出生点 '%s'" % spawn_id)
		return

	_last_spawn_id = spawn_id
	if player is Node2D:
		(player as Node2D).global_position = target.global_position
	if player.has_method(&"face"):
		player.call(&"face", target.facing)


func _find_spawn_point(spawn_id: StringName) -> SpawnPoint:
	var fallback: SpawnPoint = null
	for node: Node in get_tree().get_nodes_in_group(SPAWN_GROUP):
		var point := node as SpawnPoint
		if point == null:
			continue
		if point.spawn_id == spawn_id:
			return point
		if fallback == null:
			fallback = point
	return fallback
