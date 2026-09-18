@tool
class_name SouthPastureGround
extends TileMapLayer
## 农场南面草坡的地面：一条土路从北口（农场南门）顺坡而下，尽头是一块开阔草地。
##
## 铺地手法全部来自 [GroundPainter]；南坡刻意比林地更“亮”：
## 灌木少、野花多，给玩家一个适合放牧与采集的地方。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 40, 26):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()

## 装饰节点的父节点（通常是 Props，参与 Y 排序）。
@export var decor_root: Node2D


func _ready() -> void:
	paint()


## 用代码铺地。
func paint() -> void:
	clear()
	var origin := ground_area.position
	var center_column: int = origin.x + ground_area.size.x / 2

	GroundPainter.fill_grass(self, ground_area)

	# 南北向土路：北口接农场南门，顺坡铺到草坡深处。
	GroundPainter.vertical_road(
		self, origin.y, ground_area.end.y - 3, center_column, 1, GroundPainter.Style.DIRT
	)
	# 坡底的空地：靠近南端横向铺开，当作一块天然的牧场。
	GroundPainter.horizontal_road(
		self, origin.x + 10, ground_area.end.x - 10, origin.y + 21, 1, GroundPainter.Style.DIRT
	)

	DecorPainter.spawn_many(
		decor_root,
		{
			Vector2i(origin.x + 8, origin.y + 7): &"flowers",
			Vector2i(origin.x + 31, origin.y + 8): &"flower_red",
			Vector2i(origin.x + 13, origin.y + 12): &"flower_blue",
			Vector2i(origin.x + 26, origin.y + 13): &"flowers",
			Vector2i(origin.x + 7, origin.y + 17): &"tall_grass",
			Vector2i(origin.x + 32, origin.y + 18): &"tall_grass",
			Vector2i(origin.x + 15, origin.y + 18): &"flower_bed",
			Vector2i(origin.x + 16, origin.y + 18): &"flower_bed",
			Vector2i(origin.x + 24, origin.y + 18): &"flower_bed",
			Vector2i(origin.x + 25, origin.y + 18): &"flower_bed",
			Vector2i(origin.x + 11, origin.y + 9): &"pebble",
			Vector2i(origin.x + 29, origin.y + 16): &"pebble",
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
