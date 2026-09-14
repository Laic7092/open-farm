class_name WorldProp
extends Sprite2D
## 场景摆件：房子、树、水井这类"站在地图上的东西"。
##
## 贴图直接在 [code].tscn[/code] 里指定（[code]assets/sprites/props/*.png[/code]），
## 本脚本只负责一件事：按需生成一个[b]静态碰撞体[/b]，
## 让房子和树能真的挡住玩家，而不是"看起来像房子、走上去像空气"。
##
## 之所以用脚本生成碰撞体而不是在场景里手写 [StaticBody2D]：
## 一张 64×64 的房子图，只有底部一小条该挡人；
## 把"可通行区域"当成参数写清楚，比在每个场景里试坐标可靠得多。

## 碰撞盒尺寸；[code]Vector2.ZERO[/code] 表示这个摆件可以穿过去（花、草、小鸡）。
@export var solid_size: Vector2 = Vector2.ZERO
## 碰撞盒相对精灵中心的偏移。房子这类"下实上虚"的图形通常填一个正数（往下）。
@export var solid_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if solid_size == Vector2.ZERO:
		return
	add_child(_build_body())


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
