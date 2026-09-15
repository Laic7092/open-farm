extends Node
## 场景路由（Autoload：`SceneRouter`），只保留无状态过渡方法。
##
## 世界实例缓存、当前地图与读档待恢复目标全部移到 [WorldHost]；本节点不再
## 保存任何 [Node] 引用，也不写死节点路径。调用方必须显式传入 [WorldHost]。

## 玩家所在分组（约定：全局唯一）。
const PLAYER_GROUP: StringName = &"player"
## 出生点所在分组，由 [SpawnPoint] 自动加入。
const SPAWN_GROUP: StringName = &"spawn_point"
## 世界场景宿主所在分组；与 [WorldHost.GROUP] 保持一致。
const WORLD_HOST_GROUP: StringName = &"world_host"


## 切换世界场景并把玩家放到 [param spawn_id] 对应的出生点。
##
## 世界实例、缓存与暂停恢复目标由 [param host] 持有。
func change_scene_to(
	host: WorldHost,
	scene_path: String,
	spawn_id: StringName = &"default"
) -> void:
	if host == null or not is_instance_valid(host):
		push_error("SceneRouter: 缺少有效的 WorldHost")
		return
	if host.is_transitioning():
		push_warning("SceneRouter: 上一次切换尚未结束，忽略 '%s'" % scene_path)
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: 无法加载场景 '%s'" % scene_path)
		return

	host.begin_transition()
	EventBus.scene_transition_started.emit(spawn_id)

	var tree := host.get_tree()
	if tree == null:
		host.finish_transition(spawn_id)
		return
	# 统一以 SceneTree.paused 作为唯一暂停真值；进出世界时只在这里短暂压栈。
	var was_paused: bool = tree.paused
	tree.paused = true

	await host.fade_to(1.0, host.fade_out_duration)
	await host.install_world(scene_path, packed, spawn_id)
	place_player(host, spawn_id)
	await host.fade_to(0.0, host.fade_in_duration)

	if is_instance_valid(tree):
		tree.paused = was_paused
	host.finish_transition(spawn_id)
	EventBus.scene_transition_finished.emit(spawn_id)


## 重载当前世界场景（读档 / 重开当天）。
func reload_current_scene(host: WorldHost, spawn_id: StringName = &"default") -> void:
	if host == null or not is_instance_valid(host):
		return
	var path := host.current_world_path()
	if path.is_empty():
		return
	host.discard_world(path)
	await change_scene_to(host, path, spawn_id)


## 当前挂载中的世界场景；没有则返回 null。
func current_world(host: WorldHost) -> Node:
	return host.current_world() if host != null else null


## 当前世界场景的资源路径。
func current_world_path(host: WorldHost) -> String:
	return host.current_world_path() if host != null else ""


## 是否正在切换中。
func is_transitioning(host: WorldHost) -> bool:
	return host != null and host.is_transitioning()


## 按分组查找当前 [WorldHost]；只用于 SaveManager 等没有组合根引用的入口。
func world_host(tree: SceneTree) -> WorldHost:
	if tree == null:
		return null
	return tree.get_first_node_in_group(WORLD_HOST_GROUP) as WorldHost


## 把玩家放到 [param spawn_id] 对应的出生点，并记录为最近一次落地。
func place_player(host: WorldHost, spawn_id: StringName) -> void:
	if host == null:
		return
	var tree := host.get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	var target := _find_spawn_point(tree, spawn_id)
	if target == null:
		push_warning("SceneRouter: 场景中没有找到出生点 '%s'" % spawn_id)
		return
	host.set_last_spawn(spawn_id)
	if player is Node2D:
		(player as Node2D).global_position = target.global_position
	if player.has_method(&"face"):
		player.call(&"face", target.facing)


func _find_spawn_point(tree: SceneTree, spawn_id: StringName) -> SpawnPoint:
	var fallback: SpawnPoint = null
	for node: Node in tree.get_nodes_in_group(SPAWN_GROUP):
		var point := node as SpawnPoint
		if point == null:
			continue
		if point.spawn_id == spawn_id:
			return point
		if fallback == null:
			fallback = point
	return fallback
