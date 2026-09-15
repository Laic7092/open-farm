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
## 每次本场景被切换到时使用哪个出生点。
@export var default_spawn_id: StringName = &"default"
## 是否自动挂载天气特效（雨雪）。室内场景可以关掉。
@export var weather_effects: bool = true
## 是否自动挂载昼夜光照（环境光染色与路灯）。室内场景可以关掉。
@export var lighting_effects: bool = true
## 是否自动挂载 NPC 行走网格。没有 NPC 的地图可以关掉省一点探测。
@export var navigation_enabled: bool = true

## 组合根注入的玩家档案；世界节点在进入树前就会收到。
var player_profile: PlayerProfile
## 组合根注入的时钟状态；世界节点在进入树前就会收到。
var clock_state: GameDateClock


## 由 [SceneRouter] 在世界场景 [method Node.add_child] 之前调用。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	player_profile = profile
	clock_state = clock
	_distribute_dependencies()


func _enter_tree() -> void:
	# 父节点的 _enter_tree 先于子节点执行；在这里把状态推给场景里的服务节点，
	# 它们的 _enter_tree / _ready 就能立即使用组合根依赖。
	_distribute_dependencies()


func _ready() -> void:
	_apply_camera_limits()
	if weather_effects:
		_ensure_weather_fx()
	if lighting_effects:
		_ensure_lighting()
	if navigation_enabled:
		_ensure_navigator()


## 天气特效由基类统一挂载，而不是每个世界场景各写一份：
## 新增一张地图时，"下雨要看得见"这件事自动成立。
func _ensure_weather_fx() -> void:
	if get_node_or_null(^"WeatherFx") != null:
		return
	var fx := WeatherFx.new()
	fx.name = "WeatherFx"
	fx.bind_dependencies(player_profile, clock_state)
	add_child(fx)


## 昼夜光照同样由基类挂载：Godot 每张画布只认一个 [CanvasModulate]，
## 所以环境光染色与路灯统一交给 [WorldLighting] 管。
func _ensure_lighting() -> void:
	if get_node_or_null(^"WorldLighting") != null:
		return
	var lighting := WorldLighting.new()
	lighting.name = "WorldLighting"
	lighting.bind_dependencies(player_profile, clock_state)
	add_child(lighting)


## NPC 行走网格同样由基类挂载：新地图上的 NPC 自动会寻路。
func _ensure_navigator() -> void:
	if get_node_or_null(^"NpcNavigator") != null:
		return
	var navigator := NpcNavigator.new()
	navigator.name = "NpcNavigator"
	navigator.area = camera_limits
	navigator.bind_dependencies(player_profile, clock_state)
	add_child(navigator)


## 每次本场景被切换到时调用（包括从 [SceneRouter] 的缓存里重新挂载）。
##
## 注意：[code]_ready()[/code] 一个节点一生只跑一次，而世界场景会被缓存复用，
## 所以"每次进入都要做一遍"的事情必须放在这里，不能放在 [code]_ready()[/code]。
func on_world_enter(spawn_id: StringName) -> void:
	if spawn_id == &"":
		spawn_id = default_spawn_id
	_distribute_dependencies()
	_apply_camera_limits()
	EventBus.world_entered.emit(world_id)


## 本场景被切出（但实例仍保留在缓存里）时调用。
func on_world_exit() -> void:
	pass


## 把组合根依赖推给所有实现了 `bind_dependencies()` 的子节点。
func _distribute_dependencies() -> void:
	for node: Node in find_children("*", "", true, false):
		if node.has_method(&"bind_dependencies"):
			node.call(&"bind_dependencies", player_profile, clock_state)


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
