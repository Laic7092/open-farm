@tool
class_name MarketGround
extends TileMapLayer
## 集市地面：一条石板街 + 北侧广场 + 南侧水塘绿地。
##
## 集市是村庄与海滩之间的一站，所以地面刻意做得比村庄"硬"：
## 主街铺石板、北侧整片广场，只有南侧留一角水塘与草地。
##
## 铺地手法全部来自 [GroundPainter]：主路永远是地图纵向中线上的三格宽路面，
## 于是从村庄东口走进来、再往海滩走出去，脚下的路是连着的。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 40, 26):
	set(value):
		ground_area = value
		# 编辑器中改数值即时刷新；场景实例化阶段还没进树，交给 _ready()。
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
	var size := ground_area.size
	var center_row: int = origin.y + size.y / 2

	GroundPainter.fill_grass(self, ground_area)

	# 贯穿东西的主街（三格宽），两端正好接住通往村庄与海滩的出口。
	GroundPainter.horizontal_road(
		self, origin.x, origin.x + size.x - 1, center_row, 1, GroundPainter.Style.STONE
	)

	# 北侧的集市广场：石板铺开一片，赶集、摆摊都在这里。
	GroundPainter.plaza(self, Rect2i(origin.x + 8, center_row - 6, 24, 5))

	# 南侧的水塘：给集市一个能喘气的绿角。
	GroundPainter.water(self, Rect2i(origin.x + 4, center_row + 6, 7, 4), 2)

	# 街道两侧的点缀：花圃、灌木与踩秃的草。
	DecorPainter.spawn_many(
		decor_root,
		{
			Vector2i(origin.x + 6, center_row - 2): &"flower_bed",
			Vector2i(origin.x + 7, center_row - 2): &"flower_bed",
			Vector2i(origin.x + 33, center_row - 2): &"flower_bed",
			Vector2i(origin.x + 34, center_row - 2): &"flower_bed",
			Vector2i(origin.x + 2, center_row + 2): &"bush",
			Vector2i(origin.x + 37, center_row + 3): &"bush",
			Vector2i(origin.x + 31, center_row + 5): &"tall_grass",
			Vector2i(origin.x + 12, center_row + 5): &"tall_grass",
			Vector2i(origin.x + 20, center_row + 7): &"flowers",
			Vector2i(origin.x + 14, center_row + 8): &"flower_red",
			Vector2i(origin.x + 27, center_row + 2): &"pebble",
			Vector2i(origin.x + 3, center_row - 4): &"pebble",
			Vector2i(origin.x + 36, center_row - 3): &"stump_tile",
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
