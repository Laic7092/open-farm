@tool
class_name NorthWoodsGround
extends TileMapLayer
## 农场北面林道的地面：一条土路从南口（农场北门）直通北端林间空地。
##
## 和别的户外地面一样，铺地手法全部来自 [GroundPainter]：
## 草地打底、土路从出口延伸进来、再由 [DecorPainter] 撒上灌木与蘑菇。
## 所有图案都由坐标算出，同一个种子每次进游戏长得一模一样。

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

	# 南北向土路：南口接农场北门，一直通到北端。
	GroundPainter.vertical_road(
		self, origin.y, ground_area.end.y - 1, center_column, 1, GroundPainter.Style.DIRT
	)
	# 北端林间空地：土路在此横向铺开，尽头是一片可以砍伐的林子。
	GroundPainter.horizontal_road(
		self, origin.x + 9, ground_area.end.x - 9, origin.y + 4, 1, GroundPainter.Style.DIRT
	)

	DecorPainter.spawn_many(
		decor_root,
		{
			Vector2i(origin.x + 6, origin.y + 9): &"bush",
			Vector2i(origin.x + 33, origin.y + 10): &"bush",
			Vector2i(origin.x + 12, origin.y + 16): &"stump_tile",
			Vector2i(origin.x + 27, origin.y + 18): &"mushroom",
			Vector2i(origin.x + 9, origin.y + 21): &"tall_grass",
			Vector2i(origin.x + 30, origin.y + 8): &"tall_grass",
			Vector2i(origin.x + 17, origin.y + 20): &"pebble",
			Vector2i(origin.x + 24, origin.y + 13): &"mushroom",
			Vector2i(origin.x + 4, origin.y + 13): &"tall_grass",
			Vector2i(origin.x + 35, origin.y + 15): &"pebble",
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
