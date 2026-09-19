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
## 是否跟着季节换地面与树木外观。室内场景关掉（室外换季、屋里不能下雪）。
@export var season_effects: bool = true
## 是否自动挂载 NPC 行走网格。没有 NPC 的地图可以关掉省一点探测。
@export var navigation_enabled: bool = true
## 本场景白天播放的 BGM id；由地图自己的 [BgmPlayer] 播放。
@export var bgm_track: StringName = &"farm"
## 本场景夜晚播放的 BGM id；空表示夜晚也沿用白天曲。
@export var bgm_night_track: StringName = &"night"
## 本场景的脚步音效 id；由 [Player] 按走过的距离触发。
@export var footstep_sfx: StringName = &"footstep_grass"

## 组合根注入的玩家档案；世界节点在进入树前就会收到。
var player_profile: PlayerProfile
## 组合根注入的时钟状态；世界节点在进入树前就会收到。
var clock_state: GameDateClock
## 组合根注入的领域服务；世界节点在进入树前就会收到。
var weather_service: WeatherService
var relationship_service: RelationshipService
var calendar_service: CalendarService
## 季节外观服务；[member season_effects] 为 false 时始终为空。
var _season_look: SeasonLook
## 本图的 BGM 播放器（BGM 归地图所有）。
var _bgm: BgmPlayer
## 本图的氛围音效播放器（如清晨鸣叫）。
var _sfx: SfxPlayer


## 由 [SceneRouter] 在世界场景 [method Node.add_child] 之前调用。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	player_profile = profile
	clock_state = clock


## 由 [SceneRouter] 在世界场景 [method Node.add_child] 之前调用。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	weather_service = weather
	relationship_service = relationships
	calendar_service = calendar


func _enter_tree() -> void:
	# 父节点的 _enter_tree 先于子节点执行；组合根已在 add_child 前调完 bind_*，
	# 这里一次遍历把状态与服务推下去，子节点的 _enter_tree / _ready 就能用。
	# 注入只在这里做一遍：换图一定会触发 _enter_tree，重复下发纯属浪费。
	_distribute_dependencies()
	_distribute_services()


func _ready() -> void:
	_apply_camera_limits()
	if weather_effects:
		_ensure_weather_fx()
	if lighting_effects:
		_ensure_lighting()
	if season_effects:
		_ensure_season_look()
	if navigation_enabled:
		_ensure_navigator()
	if _has_water():
		_ensure_water_field()
	_ensure_bgm()
	_ensure_ambience()


## 地图自己的 BGM：曲目由本场景声明，播放器是本节点的子节点。
func _ensure_bgm() -> void:
	var existing := get_node_or_null(^"Bgm") as BgmPlayer
	if existing != null:
		_bgm = existing
		return
	var bgm := BgmPlayer.new()
	bgm.name = "Bgm"
	bgm.track = bgm_track
	bgm.night_track = bgm_night_track
	bgm.bind_clock(clock_state)
	add_child(bgm)
	_bgm = bgm


## 清晨鸣叫等氛围音：地图自己发声（缓存里的旧地图不响）。
func _ensure_ambience() -> void:
	if _sfx != null:
		return
	_sfx = SfxPlayer.attach(self, &"Ambience")
	EventBus.day_changed.connect(_on_day_changed)


func _on_day_changed(_date: GameDate) -> void:
	# 只有当前挂载的地图才鸣晨；凌晨 02:00 的自然跨天不放鸡叫，只有睡到早上的才放。
	if not is_inside_tree() or _hour() < 5:
		return
	_sfx.play(AudioCatalog.SFX_MORNING, 1.0, -6.0)


func _hour() -> int:
	if clock_state == null:
		return 0
	return int(clock_state.minute_of_day / GameDateClock.MINUTES_PER_HOUR)


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


## 季节外观同样由基类挂载：
## 新地图只要不显式关掉 [member season_effects]，"冬天地面变雪"就自动成立。
func _ensure_season_look() -> void:
	var existing := get_node_or_null(^"SeasonLook") as SeasonLook
	if existing != null:
		_season_look = existing
		return
	var look := SeasonLook.new()
	look.name = "SeasonLook"
	look.bind_dependencies(player_profile, clock_state)
	add_child(look)
	_season_look = look


## 水面同样由基类自动挂载：水体形状写在 [WaterLayout] 里（那张图的唯一事实来源），
## 新增一张带水的地图只要在 [method WaterLayout.bodies_for] 里登记，
## 水色贴图、碰撞、钓鱼与 NPC 避让就一起成立。
func _ensure_water_field() -> void:
	if get_node_or_null(^"WaterField") != null:
		return
	var water := WaterField.new()
	water.name = "WaterField"
	water.world_id = world_id
	add_child(water)


## 本场景在 [WaterLayout] 里登记过水面吗。
func _has_water() -> bool:
	return WaterLayout.has_water(world_id)


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
	_apply_camera_limits()
	# 场景会被缓存复用，_ready() 只跑一次；这里才是“每次进图都要对齐季节”的位置。
	if _season_look != null:
		_season_look.refresh()
	# BGM 同样要每次进图重新确认（从缓存挂回来时它已停过）。
	if _bgm != null:
		_bgm.refresh()
	EventBus.world_entered.emit(world_id)


## 本图的 BGM 播放器；测试与调试可读。
func bgm_player() -> BgmPlayer:
	return _bgm


## 当前播放的曲目 id。
func current_bgm() -> StringName:
	return _bgm.current() if _bgm != null else &""


## 临时接管本图 BGM（例：钓鱼抛竿）；由世界内的对象显式调用。
func push_bgm_override(track_id: StringName) -> void:
	if _bgm != null:
		_bgm.push_override(track_id)


## 结束临时接管，还原地图曲目。
func pop_bgm_override() -> void:
	if _bgm != null:
		_bgm.pop_override()


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
