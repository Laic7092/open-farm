class_name WorldProp
extends Sprite2D
## 场景摆件：房子、树、水井这类"站在地图上的东西"。
##
## 贴图直接在 [code].tscn[/code] 里指定（[code]assets/sprites/props/*.png[/code]），
## 本脚本负责两件按需生成的东西：
## [br]- [b]静态碰撞体[/b]：让房子和树能真的挡住玩家；
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

## 所有发光摆件都在这个组里，由 [WorldLighting] 统一调节亮度。
const NIGHT_LIGHT_GROUP: StringName = &"night_lights"

## 从贴图 alpha 提取遮挡多边形的简化容差；越大轮廓越粗、越省节点。
const OCCLUDER_EPSILON: float = 1.0
## 同一张贴图只提取一次遮挡多边形，房子 / 树重复摆放时复用。
static var _occluder_cache: Dictionary = {}

## 所有灯共用同一张径向渐变，避免每个摆件各建一份。
static var _light_texture: GradientTexture2D

var _light: PointLight2D


func _ready() -> void:
	if solid_size != Vector2.ZERO:
		add_child(_build_body())
		_build_occluders()
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
