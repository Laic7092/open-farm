class_name NpcField
extends Node2D
## 一张地图上所有 [Npc] 的协作根。
##
## [b]它是本图 NPC 的收件箱[/b]：全局信号先落到这里，再由它转给该响应的人。
## 于是单个 NPC 不订阅任何全局信号，也没有需要自己断开的连接
## （地图实例会被缓存复用，连断时机最容易写错）。
##
## 它同时持有本图的 [NpcNavigator] 与日程地点索引：地图只要声明"这里要有 NPC
## 活动"，行走网格就跟着协作根一起出现，NPC 不必每帧扫全场找同类节点。
##
## 由 [WorldScene] 在本图子节点进树前自动挂载并注入到每个 NPC 身上。

## 本图协作根所在分组。
const GROUP: StringName = &"npc_field"

## 本图导航网格覆盖的世界矩形；由地图下发。
@export var area: Rect2 = Rect2(0, 0, 640, 360)
## 是否挂载导航网格；没有 NPC 的地图可以关掉省一点物理探测。
@export var navigation_enabled: bool = true

## 组合根注入的时钟；日程推进读当天分钟。
var clock: GameDateClock
## 组合根注入的玩家档案；NPC 的 required_flag 判定用。
var profile: PlayerProfile

## 本图导航网格；[member navigation_enabled] 为 false 时始终为空。
var _navigator: NpcNavigator
## 本图日程地点索引：[member SchedulePoint.point_id] → 地点。
var _points: Dictionary = {}
## 本图当前正在播放的对白由谁发起（同一时间只有一段）。
var _speaker: Npc
var _dialogue: DialogueData


func bind_dependencies(p_profile: PlayerProfile, p_clock: GameDateClock) -> void:
	profile = p_profile
	clock = p_clock


func _enter_tree() -> void:
	add_to_group(GROUP)
	_connect_events()


func _exit_tree() -> void:
	_disconnect_events()


func _ready() -> void:
	# 此时本图所有子节点的 _enter_tree() 都跑完了，日程点已经报到过。
	_index_points()
	navigator()


# ---------------------------------------------------------------- 对外

## 本图导航网格；首次询问时挂载。地图关掉导航时返回 null。
func navigator() -> NpcNavigator:
	if _navigator == null and navigation_enabled:
		_mount_navigator()
	return _navigator


## [param location_id] 对应的日程地点；本图没有这个地点时返回 null。
##
## 索引按需建立：NPC 的 `_ready()` 早于本节点的 `_ready()`（子节点先就绪），
## 那会儿还没人给日程点建过表，但 [SchedulePoint] 已经在 `_enter_tree()` 里报到过了。
func schedule_point(location_id: StringName) -> SchedulePoint:
	if _points.is_empty():
		_index_points()
	return _points.get(location_id) as SchedulePoint


## 替 NPC 开一段对白。
##
## 本图同一时间只有一段对白，所以"谁在说话"记在这里；对白结束 / 选完选项时
## 才找得回发起者，NPC 自己不必去订阅界面信号。
func open_dialogue(npc: Npc, dialogue: DialogueData) -> void:
	_speaker = npc
	_dialogue = dialogue
	EventBus.ui.dialogue_requested.emit(dialogue)


# ---------------------------------------------------------------- 收件

## 到点推进本图所有村民的日程。
func _on_minute_changed(_hour: int, _minute: int) -> void:
	for npc: Npc in _villagers():
		npc.tick_schedule()


## 跨天：重算谁还在场上（例如"还没出生的孩子"）。
func _on_day_changed(_date: GameDate) -> void:
	for npc: Npc in _villagers():
		npc.refresh_availability()


## 孩子出生：同样只影响"靠旗标才存在"的那些人。
func _on_child_born(_child_id: StringName) -> void:
	for npc: Npc in _villagers():
		npc.refresh_availability()


## 好感变化：只回传给对应的那个人，其余人不必知道。
func _on_affection_changed(npc_id: StringName, value: int, _delta: int) -> void:
	var npc := _villager(npc_id)
	if npc != null:
		npc.mirror_affection(value)


## 对白结束：只回传给发起者，并清掉"谁在说话"。
func _on_dialogue_finished(_dialogue: DialogueData) -> void:
	var speaker := _speaker
	_speaker = null
	_dialogue = null
	if is_instance_valid(speaker):
		speaker.finish_dialogue()


## 选完选项：同样只回传给发起者，且必须还是同一段对白。
func _on_dialogue_choice_made(dialogue: DialogueData, choice: DialogueChoice) -> void:
	if dialogue != _dialogue or not is_instance_valid(_speaker):
		return
	_speaker.apply_dialogue_choice(choice)


# ---------------------------------------------------------------- 内部

## 本图在场的村民。
##
## 同一时间只会有一张地图挂在树上（换图先摘旧的再挂新的），
## 所以 [constant Npc.GROUP] 里就是本图的人；仍按祖先关系兜一层底。
func _villagers() -> Array[Npc]:
	var found: Array[Npc] = []
	var tree := get_tree()
	if tree == null:
		return found
	for node: Node in tree.get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and _owns(npc):
			found.append(npc)
	return found


func _villager(npc_id: StringName) -> Npc:
	for npc: Npc in _villagers():
		if npc.npc_id == npc_id:
			return npc
	return null


func _owns(node: Node) -> bool:
	var world := get_parent()
	return world == null or world.is_ancestor_of(node)


func _mount_navigator() -> void:
	var mounted := NpcNavigator.new()
	mounted.name = "NpcNavigator"
	mounted.area = area
	# 必须在 add_child 前注入：导航网格在 _enter_tree() 里就要注册日结转钩子。
	mounted.bind_dependencies(profile, clock)
	add_child(mounted)
	_navigator = mounted


func _index_points() -> void:
	_points.clear()
	var tree := get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(SchedulePoint.GROUP):
		var point := node as SchedulePoint
		if point != null and _owns(point):
			_points[point.point_id] = point


func _connect_events() -> void:
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	if not EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.connect(_on_day_changed)
	if not EventBus.player.npc_affection_changed.is_connected(_on_affection_changed):
		EventBus.player.npc_affection_changed.connect(_on_affection_changed)
	if not EventBus.player.child_born.is_connected(_on_child_born):
		EventBus.player.child_born.connect(_on_child_born)
	if not EventBus.ui.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.ui.dialogue_finished.connect(_on_dialogue_finished)
	if not EventBus.ui.dialogue_choice_made.is_connected(_on_dialogue_choice_made):
		EventBus.ui.dialogue_choice_made.connect(_on_dialogue_choice_made)


func _disconnect_events() -> void:
	if EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.disconnect(_on_minute_changed)
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.player.npc_affection_changed.is_connected(_on_affection_changed):
		EventBus.player.npc_affection_changed.disconnect(_on_affection_changed)
	if EventBus.player.child_born.is_connected(_on_child_born):
		EventBus.player.child_born.disconnect(_on_child_born)
	if EventBus.ui.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.ui.dialogue_finished.disconnect(_on_dialogue_finished)
	if EventBus.ui.dialogue_choice_made.is_connected(_on_dialogue_choice_made):
		EventBus.ui.dialogue_choice_made.disconnect(_on_dialogue_choice_made)
