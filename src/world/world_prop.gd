class_name WorldProp
extends Sprite2D
## 场景摆件：房子、树、水井这类"站在地图上的东西"。
##
## 贴图直接在 [code].tscn[/code] 里指定（[code]assets/sprites/props/*.png[/code]），
## 本脚本负责三件按需生成的东西：
## [br]- [b]静态碰撞体[/b]：让房子和树能真的挡住玩家；
## [br]- [b]身后淡出[/b]：玩家绕到北侧、贴图正要挡住人时整张淡出，离开恢复；
## [br]- [b]夜晚点光源[/b]：给了 [member light_radius] 的路灯 / 窗灯自动发光。
##
## 之所以用脚本生成而不是在场景里手写：
## 一张 64×64 的房子图，只有底部一小条该挡人；
## 把"可通行区域"当成参数写清楚，比在每个场景里试坐标可靠得多。
## 灯光同理——场景里只填半径，亮度曲线由 [WorldLighting] 统一给。

## 碰撞盒尺寸；[code]Vector2.ZERO[/code] 表示这个摆件可以穿过去（花、草、小鸡）。
@export var solid_size: Vector2 = Vector2.ZERO
## 碰撞盒相对精灵中心的偏移。房子这类"下实上虚"的图形通常填一个正数（往下）。
@export var solid_offset: Vector2 = Vector2.ZERO

## 夜晚点光源半径（世界像素）；0 表示这个摆件不发光。
@export var light_radius: float = 0.0
## 点光源颜色。
@export var light_color: Color = ArtPalette.LAMP_GLOW
## 点光源相对精灵中心的偏移（灯头通常在上方，填一个负数）。
@export var light_offset: Vector2 = Vector2.ZERO
## 深夜时的亮度倍率。加色光很容易过曝，默认留一点余量。
@export var light_energy: float = 0.65

## 玩家走到身后时是否把整张图淡出。所有实心摆件（房子 / 树 / 柜台）默认开启；
## 个别家具不希望淡出时，在场景里关掉这一项即可。
@export var fade_when_behind: bool = true
## 玩家在身后时保留的不透明度。太低会连"这里有栋房子"都看不出来。
@export_range(0.05, 1.0, 0.05) var behind_alpha: float = 0.42
## 淡出 / 淡入速度（不透明度 / 秒）。
@export var fade_speed: float = 5.0

## 玩家分组；与 [constant Player.GROUP] 一致。写成字面量避免 world 层反向依赖 player 层。
const FADE_PLAYER_GROUP: StringName = &"player"
## 玩家横向只要在"碰撞盒半宽 + 这个余量"内就算走到身后。
const FADE_X_MARGIN: float = 10.0

## 所有发光摆件都在这个组里，由 [WorldLighting] 统一调节亮度。
const NIGHT_LIGHT_GROUP: StringName = &"night_lights"

## 从贴图 alpha 提取遮挡多边形的简化容差；越大轮廓越粗、越省节点。
const OCCLUDER_EPSILON: float = 1.0
## 同一张贴图只提取一次遮挡多边形，房子 / 树重复摆放时复用。
static var _occluder_cache: Dictionary = {}

## 所有灯共用同一张径向渐变，避免每个摆件各建一份。
static var _light_texture: GradientTexture2D

var _light: PointLight2D
var _player: Node2D
var _fade_active: bool = false


func _ready() -> void:
	if solid_size != Vector2.ZERO:
		add_child(_build_body())
		_build_occluders()
	_fade_active = _should_fade_behind()
	set_process(_fade_active)
	_build_light()


func _build_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid"
	# 与 [WorldBounds] 同一层：玩家与 NPC 都靠 layer 1 判定障碍。
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = solid_offset

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = solid_size
	shape.shape = rectangle
	body.add_child(shape)
	return body


## 从贴图 alpha 自动提取轮廓，挂成 [LightOccluder2D]。
##
## 这样房子的屋顶、树冠这些"看起来有体积"的部分才能真正挡住方向光。
## 多边形按贴图资源路径缓存，同一棵树摆十次也只解析一次 alpha。
func _build_occluders() -> void:
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	var key: String = texture.resource_path
	if key.is_empty():
		key = str(texture.get_instance_id())
	var polygons: Array = _occluder_cache.get(key, [])
	if polygons.is_empty():
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image, 0.5)
		polygons = bitmap.opaque_to_polygons(
			Rect2i(Vector2i.ZERO, image.get_size()), OCCLUDER_EPSILON
		)
		_occluder_cache[key] = polygons
	if polygons.is_empty():
		return
	var origin := offset
	if centered:
		origin += Vector2(-float(image.get_width()) * 0.5, -float(image.get_height()) * 0.5)
	for points: PackedVector2Array in polygons:
		var transformed := PackedVector2Array()
		for point: Vector2 in points:
			transformed.append(point + origin)
		var occluder := LightOccluder2D.new()
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = transformed
		occluder.occluder = polygon
		occluder.occluder_light_mask = 1
		add_child(occluder)


## 玩家走到摆件身后时把整张图淡出，离开再淡入。
##
## 摆件仍按正常 Y 排序，所以正面时玩家完整在前；只有玩家贴到它的北侧、
## 贴图正要挡住人时才降不透明度。碰撞与 [LightOccluder2D] 都按完整底图计算，
## 所以地面阴影不会跟着淡。
func _process(delta: float) -> void:
	if not _fade_active:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(FADE_PLAYER_GROUP) as Node2D
		if _player == null:
			return
	var target: float = behind_alpha if _player_is_behind() else 1.0
	var tint := modulate
	tint.a = move_toward(tint.a, target, fade_speed * delta)
	modulate = tint


## 只有实心摆件需要淡出；花、草、小鸡这类可穿过的装饰不处理。
func _should_fade_behind() -> bool:
	return fade_when_behind and texture != null and solid_size != Vector2.ZERO


## 玩家是否正好在这个摆件的纵向投影内、且落在它的北侧（身后）。
func _player_is_behind() -> bool:
	if _player == null or texture == null:
		return false
	var top_y: float = global_position.y + offset.y
	if centered:
		top_y -= float(texture.get_height()) * 0.5
	var front_y: float = global_position.y + solid_offset.y
	var player_y: float = _player.global_position.y
	if player_y < top_y or player_y > front_y:
		return false
	var half_width: float = solid_size.x * 0.5 + FADE_X_MARGIN
	return absf(_player.global_position.x - global_position.x) <= half_width


## 按 [param factor]（0~1）调节灯光亮度；由 [WorldLighting] 在时间推进时调用。
func apply_night_energy(factor: float) -> void:
	if _light != null:
		_light.energy = light_energy * factor


# ---------------------------------------------------------------- 灯光

func _build_light() -> void:
	if light_radius <= 0.0:
		return
	var texture := _radial_texture()
	_light = PointLight2D.new()
	_light.name = "Light"
	_light.texture = texture
	_light.color = light_color
	_light.energy = 0.0
	# 纹理是 128×128 的径向渐变：半径 = 半宽 × texture_scale。
	_light.texture_scale = light_radius / (float(texture.get_width()) * 0.5)
	_light.position = light_offset
	add_child(_light)
	add_to_group(NIGHT_LIGHT_GROUP)


## 中心不透明、边缘透明的径向渐变，决定灯光的形状。
static func _radial_texture() -> GradientTexture2D:
	if _light_texture != null:
		return _light_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.5))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_light_texture = texture
	return _light_texture
