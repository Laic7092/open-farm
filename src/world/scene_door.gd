class_name SceneDoor
extends Interactable
## 场景传送门：交互后切换到目标世界场景。
##
## 目标场景与出生点都是导出属性，因此"农场 ↔ 小镇"这类连接关系
## 完全由场景文件描述，不需要任何中央传送表。
##
## 两种走法：
## [br]- [b]建筑门口[/b]（[member auto_enter] 关）：按 E 进入。留着这一步，
##   玩家从店门口走过时才不会被吸进去。
## [br]- [b]地图边缘的出口[/b]（[member auto_enter] 开）：走进去就换图，
##   两张地图因此连成一条能一直走下去的路，而不是"对着一个格子按 E"。

## 玩家所在物理层（与 [code]scenes/player/player.tscn[/code] 一致）。
const PLAYER_LAYER: int = 2

## 判定"玩家真的在门里"时，给门框留的边距（像素）。
##
## 玩家碰撞体先于中心碰到门，信号就发了；这段边距把这提前量算进去。
const EDGE_TOLERANCE: float = 8.0

## 目标场景路径。
@export_file("*.tscn") var target_scene: String = ""
## 落在目标场景的哪个出生点。
@export var target_spawn_id: StringName = &"default"
## 需要哪个剧情旗标才开放（留空表示始终可用）。
@export var required_flag: StringName = &""

## 玩家走进范围就自动传送（用于地图边缘的无缝出口）。
@export var auto_enter: bool = false
## 这个出口是"乡道的延续"：门开在地图左右边缘，对面那条路就在同一高度上。
##
## 洞口、建筑门口这类"点对点传送"保持 false——它们只需要 [member auto_enter]
## 或按 E 进入，不承诺"门在中线上"。
## [code]tests/unit/test_world_map.gd[/code] 按这个标志检查世界是不是接得整齐。
@export var road_exit: bool = false

## 组合根注入的玩家档案；required_flag 判定使用。
var _profile: PlayerProfile


func bind_dependencies(profile: PlayerProfile, _clock: GameDateClock) -> void:
	_profile = profile


func _ready() -> void:
	if prompt_key == &"PROMPT_INTERACT":
		prompt_key = &"PROMPT_ENTER"
	if auto_enter:
		# 交互靠玩家的 InteractionArea 反向探测（它 mask 8）；
		# 自动进入要反过来由本区域探测玩家本体，所以这里补上玩家那一层。
		collision_mask |= PLAYER_LAYER
		body_entered.connect(_on_body_entered)


func can_interact() -> bool:
	if not super.can_interact():
		return false
	return required_flag == &"" or (_profile != null and _profile.has_flag(required_flag))


func interact(actor: Node2D) -> void:
	super.interact(actor)
	_enter_target()


## 走进出口。只在玩家本体进入时触发，NPC 路过不会把地图换掉。
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Player.GROUP):
		return
	# 缓存复用的地图挂回场景树时，Area2D 会补发一次玩家离图那一刻（可能正站在
	# 门里）的 body_entered；此刻玩家已被摆到出生点。物理服务器的重叠缓存还会
	# 滞后一两帧，所以这里不信它，直接用节点坐标确认玩家真的压在门上。
	if not _covers(body):
		return
	if not can_interact():
		return
	# 刚落地的那一瞬间玩家可能正压在出口上，等切换结束再说。
	var host := get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host == null or host.is_transitioning():
		return
	_enter_target()


## 玩家当前是否真的压在门上（不看物理服务器可能滞后的重叠缓存）。
##
## 信号在碰撞体刚碰到门时就发，而 [member Node2D.global_position] 还在门外，
## 所以用 [constant EDGE_TOLERANCE] 补上这段提前量。
func _covers(body: Node2D) -> bool:
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	var rect := shape_node.shape as RectangleShape2D if shape_node != null else null
	if rect == null:
		# 形状不是矩形（本项目都是）时退回旧行为，交给物理服务器判断。
		return overlaps_body(body)
	var local := to_local(body.global_position)
	return (
		absf(local.x) <= rect.size.x * 0.5 + EDGE_TOLERANCE
		and absf(local.y) <= rect.size.y * 0.5 + EDGE_TOLERANCE
	)


func _enter_target() -> void:
	if target_scene.is_empty():
		push_warning("SceneDoor: 未设置 target_scene")
		return
	var host := get_tree().get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host == null:
		push_error("SceneDoor: 场景树中没有 WorldHost")
		return
	# 这里不 await：传送是"发出去就不用管"的演出，交互本身应当立即结束。
	SceneRouter.change_scene_to(host, target_scene, target_spawn_id)
