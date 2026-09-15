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
## 本场景水面的类型（见 [enum WaterKind.Kind]）；-1 表示这张地图没有可垂钓的水面。
@export var water_kind: int = -1
## 本场景白天播放的 BGM id；由 [SceneAudio] 读取，地图自己声明自己听起来什么样。
@export var bgm_track: StringName = &"farm"
## 本场景夜晚播放的 BGM id；空表示夜晚也沿用白天曲。
@export var bgm_night_track: StringName = &"night"
## 本场景的脚步音效 id；由 [SceneAudio] 按玩家走过的距离触发。
@export var footstep_sfx: StringName = &"footstep_grass"

## 组合根注入的玩家档案；世界节点在进入树前就会收到。
var player_profile: PlayerProfile
## 组合根注入的时钟状态；世界节点在进入树前就会收到。
var clock_state: GameDateClock
## 组合根注入的领域服务；世界节点在进入树前就会收到。
var weather_service: WeatherService
var relationship_service: RelationshipService
var calendar_service: CalendarService


## 由 [SceneRouter] 在世界场景 [method Node.add_child] 之前调用。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	player_profile = profile
	clock_state = clock
	_distribute_dependencies()


## 由 [SceneRouter] 在世界场景 [method Node.add_child] 之前调用。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	weather_service = weather
	relationship_service = relationships
	calendar_service = calendar
	_distribute_services()


func _enter_tree() -> void:
	# 父节点的 _enter_tree 先于子节点执行；在这里把状态推给场景里的服务节点，
	# 它们的 _enter_tree / _ready 就能立即使用组合根依赖。
	_distribute_dependencies()
	_distribute_services()


func _ready() -> void:
	_apply_camera_limits()
	if weather_effects:
		_ensure_weather_fx()
	if lighting_effects:
		_ensure_lighting()
	if navigation_enabled:
		_ensure_navigator()
	if water_kind >= 0:
		_ensure_water_field()


## 天气特效由基类统一挂载，而不是每个世界场景各写一份：
## 新增一张地图时，"下雨要看得见"这件事自动成立。
func _ensure_weather_fx() -> void:
	if get_node_or_null(^"WeatherFx") != null:
		return
	var fx := WeatherFx.new()
	fx.name = "WeatherFx"
	fx.bind_dependencies(player_profile, clock_state)
	fx.bind_services(weather_service, relationship_service, calendar_service)
	add_child(fx)


## 昼夜光照同样由基类挂载：Godot 每张画布只认一个 [CanvasModulate]，
## 所以环境光染色与路灯统一交给 [WorldLighting] 管。
func _ensure_lighting() -> void:
	if get_node_or_null(^"WorldLighting") != null:
		return
	var lighting := WorldLighting.new()
	lighting.name = "WorldLighting"
	lighting.bind_dependencies(player_profile, clock_state)
	lighting.bind_services(weather_service, relationship_service, calendar_service)
	add_child(lighting)


## 水面标记同样由基类按 [member water_kind] 挂载：
## 新增一张带水的地图，只要在场景里填上水域类型，鱼就自动能钓。
func _ensure_water_field() -> void:
	if get_node_or_null(^"WaterField") != null:
		return
	var ground := find_child("Ground", true, false) as TileMapLayer
	if ground == null:
		return
	var water := WaterField.new()
	water.name = "WaterField"
	water.ground_layer = ground
	water.water_kind = water_kind
	add_child(water)


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
	_distribute_services()
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


## 把领域服务推给所有实现了 `bind_services()` 的子节点。
func _distribute_services() -> void:
	for node: Node in find_children("*", "", true, false):
		if node.has_method(&"bind_services"):
			node.call(
				&"bind_services", weather_service, relationship_service, calendar_service
			)


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
