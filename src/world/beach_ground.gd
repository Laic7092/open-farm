@tool
class_name BeachGround
extends TileMapLayer
## 海滩地面：上方草坡、中间沙滩与乡道、下方海水，一条木栈桥伸进海里。
##
## 与 [TownGround] / [FarmGrid] 同一套做法：地面由脚本按坐标画出，
## 走 [GroundPainter] 的公共手法，所以从集市走过来的那条土路
## 在海滩西口还是同一条路。

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
	var size := ground_area.size
	var center_row: int = origin.y + size.y / 2

	# 沙滩打底。
	for cell: Vector2i in GridUtils.cells_in_area(origin, size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.SAND)

	# 上方草坡：与内陆接壤，也给野生植被一点变化。
	for y: int in 4:
		for x: int in size.x:
			var cell := Vector2i(origin.x + x, origin.y + y)
			set_cell(cell, FarmAtlas.SOURCE_ID, GroundPainter.grass_variant(cell))

	# 下方海水：深水 → 浅滩 → 浪线，三段读起来才像有坡度的岸。
	GroundPainter.water(self, Rect2i(origin.x, origin.y + size.y - 8, size.x, 8), 2)

	# 从西口（集市）进来的乡道，与集市的主街同宽同高，走到边缘是接得上的。
	GroundPainter.horizontal_road(
		self, origin.x, origin.x + 30, center_row, 1, GroundPainter.Style.DIRT
	)

	# 通往矿洞洞口的上坡路：先沿右侧北上，再折向洞口。
	GroundPainter.vertical_road(
		self, origin.y + 6, center_row, origin.x + 31, 0, GroundPainter.Style.DIRT
	)
	GroundPainter.horizontal_road(
		self, origin.x + 31, origin.x + 37, origin.y + 6, 0, GroundPainter.Style.DIRT
	)

	# 木栈桥：从沙滩一路铺进水里，渔夫的落点在桥头。
	for y: int in range(origin.y + 15, origin.y + size.y):
		for x: int in range(origin.x + 18, origin.x + 22):
			if ground_area.has_point(Vector2i(x, y)):
				set_cell(Vector2i(x, y), FarmAtlas.SOURCE_ID, FarmAtlas.WOOD)

	# 零散点缀：沙滩上是卵石与贝壳，草坡上才是花与草。
	# 贴图透明，摆到沙上再也不会露出绿方块。
	DecorPainter.spawn_many(
		decor_root,
		{
			Vector2i(origin.x + 4, origin.y + 8): &"sand_pebble",
			Vector2i(origin.x + 32, origin.y + 10): &"sand_pebble",
			Vector2i(origin.x + 8, origin.y + 17): &"sand_pebble",
			Vector2i(origin.x + 26, origin.y + 18): &"sand_pebble",
			Vector2i(origin.x + 34, origin.y + 15): &"sand_pebble",
			Vector2i(origin.x + 12, origin.y + 11): &"sand_pebble",
			Vector2i(origin.x + 10, origin.y + 2): &"flowers",
			Vector2i(origin.x + 26, origin.y + 2): &"flowers",
			Vector2i(origin.x + 16, origin.y + 3): &"tall_grass",
			Vector2i(origin.x + 6, origin.y + 1): &"bush",
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
