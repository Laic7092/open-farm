extends Node
## 冒烟测试的公共基座：断言 / 报告、场景取用器、跨域共享状态。
##
## [b]谁继承它[/b]：根脚本 tools/smoke_test.gd，以及 tools/smoke/checks_*.gd（按域拆分的检查）。
## 域之间[b]不互相调用[/b]；只用到公共工具时就写在基座里，用到单一域时就写在那个域文件里。
##
## [b]状态怎么共享[/b]：每个检查器都是独立节点，根节点在 _setup_checkers() 里调用
## share_state_from() 把 _main / _clock / _profile 等引用分给它们；断言计数走同一个 Report 对象。

## 所有实例共享的断言计数与失败列表。
class Report extends RefCounted:
	var checks: int = 0
	var failures: PackedStringArray = PackedStringArray()


const TEST_SAVE_ROOT: String = "res://.tmp/smoke_saves"
## 最多等待多少帧（超时即判失败，避免 CI 卡死）。
const MAX_FRAMES: int = 6000

const FARM_SCENE: String = "res://scenes/world/farm.tscn"
const TOWN_SCENE: String = "res://scenes/world/town.tscn"
const TWON_SCENE: String = "res://scenes/world/twon.tscn"
const BEACH_SCENE: String = "res://scenes/world/beach.tscn"
const MINE_SCENE: String = "res://scenes/world/mine.tscn"
const LIBRARY_SCENE: String = "res://scenes/world/library.tscn"


var _frames: int = 0
var _phase: int = 0
## 本局 Main（组合根）及其实例状态，后面的检查直接读它。
var _main: Main
var _profile: PlayerProfile
var _clock: GameDateClock
var _weather: WeatherService
var _relationships: RelationshipService
var _calendar: CalendarService

## 跨场景往返测试用的锚点。
var _anchor_cell: Vector2i = Vector2i.ZERO
var _anchor_tilled: int = 0
## 野生植被锚点：验证"离开这几天，世界也在长"。
var _anchor_flora_cell: Vector2i = Vector2i(-1, -1)
var _anchor_flora_days: int = 0
var _anchor_flora_total: int = 0
## 日程寻路：记录 NPC 起始位置，等几帧后确认它们真的移动了。
var _npc_positions: Dictionary = {}
var _twon_wait: int = 0
## 无缝出口：等传送真的发生（走出边缘 → 淡出 → 换图 → 落地）。
var _edge_wait: int = 0
## 钓鱼端到端：真实状态机实例、咬钩信号与背包基线。
var _fishing_state: State
var _fishing_before: int = 0
var _fishing_frames: int = 0
var _fish_bit: bool = false
var _fish_reeled: bool = false


## 把根节点持有的运行时引用（组合根 / 时钟 / 天气……）与本 Report 分给本检查器。
func share_state_from(root) -> void:
	report = root.report
	_main = root._main
	_profile = root._profile
	_clock = root._clock
	_weather = root._weather
	_relationships = root._relationships
	_calendar = root._calendar


## 断言计数与失败列表由所有检查器共用。
var report := Report.new()


func _check(condition: bool, message: String) -> void:
	report.checks += 1
	if not condition:
		_fail(message)


func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	report.checks += 1
	if actual != expected:
		_fail("%s（期望 %s，实际 %s）" % [message, expected, actual])


func _fail(message: String) -> void:
	report.failures.append(message)


func _report() -> void:
	_cleanup_saves()
	if report.failures.is_empty():
		print("SMOKE OK：%d 项检查全部通过" % report.checks)
		get_tree().quit(0)
		return
	print("SMOKE FAILED：%d / %d 项失败" % [report.failures.size(), report.checks])
	for failure: String in report.failures:
		print("  ✗ ", failure)
	get_tree().quit(1)


func _tool_id_for_kind(kind: ToolData.Kind) -> StringName:
	match kind:
		ToolData.Kind.HOE:
			return &"hoe"
		ToolData.Kind.WATERING_CAN:
			return &"watering_can"
		ToolData.Kind.AXE:
			return &"axe"
		ToolData.Kind.PICKAXE:
			return &"pickaxe"
		ToolData.Kind.SICKLE:
			return &"sickle"
		_:
			return &"seed_bag"


## 建筑外观：每栋房子都要挂上角色专属贴图，且不能两栋共用一张。
##
## [param expected] 是"节点名 → 贴图路径"；路径写全，免得"换了图但换错人"。
func _check_buildings(world: Node, expected: Dictionary) -> void:
	var used: Dictionary = {}
	for node_name: String in expected.keys():
		var prop := world.find_child(node_name, true, false) as Sprite2D
		_check(prop != null, "应当有建筑 %s" % node_name)
		if prop == null or prop.texture == null:
			continue
		var path: String = prop.texture.resource_path
		_check_eq(path, expected[node_name], "%s 应当用角色专属住宅贴图" % node_name)
		_check(
			not used.has(path),
			"建筑 %s 与 %s 共用贴图 %s（每栋房子都该有自己的外观）" % [node_name, used.get(path, ""), path]
		)
		used[path] = node_name


## 出口检查：节点名、目标场景、目标出生点、是否"走进即传送"都要对得上。
##
## 世界的连通性完全写在场景文件的 [SceneDoor] 上，所以这条断言就是
## "各张地图真的连在一起"这个承诺的可执行版本：改名、改路径、改出生点都会红。
func _check_door_target(
	world: Node, node_name: String, scene_path: String, spawn_id: StringName, auto: bool = true
) -> void:
	var door := world.find_child(node_name, true, false) as SceneDoor
	_check(door != null, "应当有出口 %s" % node_name)
	if door == null:
		return
	_check_eq(door.target_scene, scene_path, "%s 的目标场景" % node_name)
	_check_eq(String(door.target_spawn_id), String(spawn_id), "%s 的目标出生点" % node_name)
	_check_eq(door.auto_enter, auto, "%s 的进入方式" % node_name)


func _find_npc(npc_id: StringName) -> Npc:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == npc_id:
			return npc
	return null


func _find_schedule_point(point_id: StringName) -> SchedulePoint:
	for node: Node in get_tree().get_nodes_in_group(SchedulePoint.GROUP):
		var point := node as SchedulePoint
		if point != null and point.point_id == point_id:
			return point
	return null


func _world_host() -> WorldHost:
	return get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost


func _is_transitioning() -> bool:
	var host := _world_host()
	return host != null and host.is_transitioning()


func _world() -> Node:
	return _world_host().current_world()


func _farm_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


func _livestock() -> LivestockManager:
	return get_tree().get_first_node_in_group(LivestockManager.GROUP) as LivestockManager


func _flora_field() -> FloraField:
	return get_tree().get_first_node_in_group(FloraField.GROUP) as FloraField


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _find_spawn(spawn_id: StringName) -> SpawnPoint:
	for node: Node in get_tree().get_nodes_in_group(SceneRouter.SPAWN_GROUP):
		var point := node as SpawnPoint
		if point != null and point.spawn_id == spawn_id:
			return point
	return null


func _cleanup_saves() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_SAVE_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
