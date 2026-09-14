@tool
class_name WorldBounds
extends StaticBody2D
## 地图四周的隐形墙。
##
## 用代码生成四块碰撞体，而不是在场景里摆 4 个 [CollisionShape2D]：
## 改一行 [member bounds] 就能重排整个地图的可行走范围，不会漏改某一边。

## 玩家可活动的矩形（世界坐标）。
@export var bounds: Rect2 = Rect2(0, 0, 640, 360):
	set(value):
		bounds = value
		if is_inside_tree():
			rebuild()

## 墙体厚度，取大一些可以防止高速穿模。
@export var thickness: float = 32.0


func _ready() -> void:
	rebuild()


## 按 [member bounds] 重建四面墙。
func rebuild() -> void:
	for owner_id: int in get_shape_owners():
		remove_shape_owner(owner_id)

	var t: float = maxf(thickness, 1.0)
	var left: float = bounds.position.x
	var top: float = bounds.position.y
	var width: float = bounds.size.x
	var height: float = bounds.size.y

	_add_wall(Rect2(left - t, top - t, width + t * 2.0, t))              # 上
	_add_wall(Rect2(left - t, top + height, width + t * 2.0, t))         # 下
	_add_wall(Rect2(left - t, top, t, height))                           # 左
	_add_wall(Rect2(left + width, top, t, height))                       # 右


func _add_wall(rect: Rect2) -> void:
	var owner_id: int = create_shape_owner(self)
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_owner_add_shape(owner_id, shape)
	shape_owner_set_transform(owner_id, Transform2D(0.0, rect.get_center()))
