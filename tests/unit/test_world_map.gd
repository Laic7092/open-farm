extends GdUnitTestSuite
## 世界连通性的可执行版本。
##
## "各张地图真的连在一起"这件事不能只靠肉眼：它由三组断言守住——
## [br]1. [b]可达[/b]：从农场出发，顺着 [SceneDoor] 一路能走到每一张地图；
## [br]2. [b]落地[/b]：每个出口指向的场景都存在，且目标场景里真有那个出生点；
## [br]3. [b]对齐[/b]：标了 [code]road_exit[/code] 的乡道出口都压在地图纵向中线上，
##    对面的出生点也是——换句话说，从农场东口走出去，脚下的路与村庄西口
##    那条路在同一个高度，玩家不会"走着走着被扔到地图的另一头"。
##
## 只读场景文件、不把地图挂进场景树，所以 _ready 不会跑，测试里没有副作用；
## 实例化过的地图在 [method after_test] 里统一释放——留着会让 gdUnit4
## 把它们当成泄漏节点，从而让 CI 的退出码非 0。

const FARM: String = "res://scenes/world/farm.tscn"
const TWON: String = "res://scenes/world/twon.tscn"
const TOWN: String = "res://scenes/world/town.tscn"
const BEACH: String = "res://scenes/world/beach.tscn"
const MINE: String = "res://scenes/world/mine.tscn"
const LIBRARY: String = "res://scenes/world/library.tscn"

## 世界里的全部地图。新增地图时这里必须一起加，否则可达性检查形同虚设。
const MAPS: Array[String] = [FARM, TWON, TOWN, BEACH, MINE, LIBRARY]

## 出口离地图左 / 右边缘多近才算"横向出口"（像素）。
const EDGE_MARGIN: float = 24.0
## 横向出口允许偏离地图纵向中线多少像素。
const CENTER_TOLERANCE: float = 16.0

## 场景路径 → 已实例化的地图（每个用例内复用同一份，结束后统一释放）。
var _cache: Dictionary = {}


func after_test() -> void:
	for world: Variant in _cache.values():
		var node := world as Node
		if node != null and is_instance_valid(node):
			node.free()
	_cache.clear()


func test_every_map_is_reachable_from_the_farm() -> void:
	var graph := _door_graph()
	var seen: Dictionary = {FARM: true}
	var queue: Array[String] = [FARM]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for target: Variant in graph.get(current, []):
			if not seen.has(target):
				seen[target] = true
				queue.append(String(target))
	for path: String in MAPS:
		assert_bool(seen.has(path)).override_failure_message(
			"从农场出发走不到 %s（世界断成了两半）" % path
		).is_true()


func test_every_door_leads_to_an_existing_spawn() -> void:
	for path: String in MAPS:
		var world := _map(path)
		assert_bool(_spawn_ids(world).size() > 0).override_failure_message(
			"%s 没有任何出生点，玩家进得来出不去" % path
		).is_true()
		for door: SceneDoor in _doors(world):
			assert_bool(ResourceLoader.exists(door.target_scene)).override_failure_message(
				"%s 的 %s 指向不存在的场景 %s" % [path, door.name, door.target_scene]
			).is_true()
			if not ResourceLoader.exists(door.target_scene):
				continue
			var target_ids := _spawn_ids(_map(door.target_scene))
			assert_bool(target_ids.has(String(door.target_spawn_id))).override_failure_message(
				"%s 的 %s 想落在 %s 的出生点 '%s'，但那里没有这个出生点（现有 %s）"
					% [path, door.name, door.target_scene, door.target_spawn_id, target_ids]
			).is_true()


## 乡道出口：门开在左右边缘、压在中线上，对面的出生点也在中线上——
## 这样"农场东口的路"与"村庄西口的路"才在同一条直线上。
func test_road_exits_sit_on_the_map_middle() -> void:
	for path: String in MAPS:
		var world := _map(path)
		var limits: Rect2 = world.get(&"camera_limits")
		var center_y: float = limits.size.y * 0.5
		for door: SceneDoor in _doors(world):
			if not door.road_exit:
				continue
			var at: Vector2 = door.position
			assert_bool(
				at.x <= EDGE_MARGIN or at.x >= limits.size.x - EDGE_MARGIN
			).override_failure_message(
				"%s 的 %s 标了 road_exit，却没开在地图左右边缘（x=%.0f）" % [path, door.name, at.x]
			).is_true()
			assert_bool(door.auto_enter).override_failure_message(
				"%s 的 %s 是乡道出口，应当设置 auto_enter（走进即传送）" % [path, door.name]
			).is_true()
			assert_float(absf(at.y - center_y)).override_failure_message(
				"%s 的 %s 偏离本地图纵向中线 %.0f 像素" % [path, door.name, at.y - center_y]
			).is_less_equal(CENTER_TOLERANCE)

			# 对面那个出生点也要落在中线附近：否则走出边缘会被"甩"到地图另一头。
			var target := _map(door.target_scene)
			var target_limits: Rect2 = target.get(&"camera_limits")
			var spawn := _spawn(target, door.target_spawn_id)
			assert_object(spawn).override_failure_message(
				"%s 的 %s 目标出生点缺失" % [path, door.name]
			).is_not_null()
			if spawn == null:
				continue
			assert_float(absf(spawn.position.y - target_limits.size.y * 0.5)).override_failure_message(
				"%s 的 %s 落在 %s 的出生点 '%s'，但它偏离中线 %.0f 像素"
					% [
						path,
						door.name,
						door.target_scene,
						door.target_spawn_id,
						spawn.position.y - target_limits.size.y * 0.5,
					]
			).is_less_equal(CENTER_TOLERANCE)


## 乡道的两端是农场与海滩，村庄与集市是路过的中间站；
## 矿洞靠海滩上的洞口进入，室内地图由门口按 E 进入——两者都不算乡道。
func test_the_road_has_exactly_two_ends() -> void:
	assert_int(_road_exit_count(FARM)).override_failure_message("农场应当是乡道的起点").is_equal(1)
	assert_int(_road_exit_count(BEACH)).override_failure_message("乡道终点在海边（矿洞靠洞口进）").is_equal(1)
	assert_int(_road_exit_count(TWON)).override_failure_message("村庄两头都该有路").is_equal(2)
	assert_int(_road_exit_count(TOWN)).override_failure_message("集市两头都该有路").is_equal(2)
	assert_int(_road_exit_count(MINE)).override_failure_message("矿洞是洞口进，不该有乡道出口").is_equal(0)
	assert_int(_road_exit_count(LIBRARY)).override_failure_message("室内地图不该有乡道出口").is_equal(0)


# ---------------------------------------------------------------- 内部

## 场景路径 → 该场景里所有门的目标场景列表。
func _door_graph() -> Dictionary:
	var graph: Dictionary = {}
	for path: String in MAPS:
		var targets: Array[String] = []
		for door: SceneDoor in _doors(_map(path)):
			if not targets.has(door.target_scene):
				targets.append(door.target_scene)
		graph[path] = targets
	return graph


func _road_exit_count(path: String) -> int:
	var total: int = 0
	for door: SceneDoor in _doors(_map(path)):
		if door.road_exit:
			total += 1
	return total


## 取（或首次实例化）某张地图。同一个用例里复用同一份，结束后由 [method after_test] 释放。
func _map(path: String) -> Node:
	if _cache.has(path):
		return _cache[path] as Node
	var packed := load(path) as PackedScene
	assert_object(packed).override_failure_message("无法加载 %s" % path).is_not_null()
	var world: Node = packed.instantiate() if packed != null else Node.new()
	_cache[path] = world
	return world


func _doors(world: Node) -> Array[SceneDoor]:
	var found: Array[SceneDoor] = []
	for node: Node in world.find_children("*", "SceneDoor", true, false):
		found.append(node as SceneDoor)
	return found


func _spawn_ids(world: Node) -> Array[String]:
	var ids: Array[String] = []
	for node: Node in world.find_children("*", "SpawnPoint", true, false):
		var spawn := node as SpawnPoint
		if spawn != null and not ids.has(String(spawn.spawn_id)):
			ids.append(String(spawn.spawn_id))
	return ids


func _spawn(world: Node, spawn_id: StringName) -> SpawnPoint:
	for node: Node in world.find_children("*", "SpawnPoint", true, false):
		var spawn := node as SpawnPoint
		if spawn != null and spawn.spawn_id == spawn_id:
			return spawn
	return null
