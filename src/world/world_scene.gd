class_name WorldScene
extends Node2D
## 世界场景根节点基类（农场 / 小镇 / 室内）。
##
## 世界场景只描述"这个地方长什么样、从哪进从哪出"，
## 相机边界、默认出生点这类元信息集中在这里，避免散落到各处脚本里。

## 场景标识，供传送表引用。
@export var world_id: StringName = &"farm"
## 相机可移动的矩形范围（世界坐标），防止镜头拍到地图外的空白。
@export var camera_limits: Rect2 = Rect2(0, 0, 640, 360)
## 外部没有指定出生点时使用哪个。
@export var default_spawn_id: StringName = &"default"


func _ready() -> void:
	_apply_camera_limits()


## 每次本场景被切换到时调用（包括从 [SceneRouter] 的缓存里重新挂载）。
##
## 注意：[code]_ready()[/code] 一个节点一生只跑一次，而世界场景会被缓存复用，
## 所以"每次进入都要做一遍"的事情必须放在这里，不能放在 [code]_ready()[/code]。
func on_world_enter(spawn_id: StringName) -> void:
	if spawn_id == &"":
		spawn_id = default_spawn_id
	_apply_camera_limits()


## 本场景被切出（但实例仍保留在缓存里）时调用。
func on_world_exit() -> void:
	pass


func _apply_camera_limits() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.camera == null:
		return
	var camera: Camera2D = player.camera
	camera.limit_left = int(camera_limits.position.x)
	camera.limit_top = int(camera_limits.position.y)
	camera.limit_right = int(camera_limits.end.x)
	camera.limit_bottom = int(camera_limits.end.y)
	camera.reset_smoothing()
