@tool
class_name MineGround
extends TileMapLayer
## 矿洞地面：岩壁封边 + 砾石矿道 + 一条竖井通往矿工营地。
##
## 边缘的岩壁只是视觉封边，真正的碰撞由 [WorldBounds] 负责——
## 和农场 / 集市一致，TileMap 不参与物理。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 48, 30):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()


func _ready() -> void:
	paint()


## 用代码铺地。
func paint() -> void:
	clear()
	var origin := ground_area.position
	var size := ground_area.size
	var center_row: int = origin.y + size.y / 2

	# 砾石打底。
	for cell: Vector2i in GridUtils.cells_in_area(origin, size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.GRAVEL)

	# 洞壁：外圈两格岩壁，越往边越黑，视觉上封住洞口。
	for y: int in size.y:
		for x: int in size.x:
			var edge: int = mini(mini(x, size.x - 1 - x), mini(y, size.y - 1 - y))
			if edge < 2:
				set_cell(
					Vector2i(origin.x + x, origin.y + y), FarmAtlas.SOURCE_ID, FarmAtlas.CLIFF
				)
			elif edge == 2 and (x + y) % 3 != 0:
				set_cell(
					Vector2i(origin.x + x, origin.y + y), FarmAtlas.SOURCE_ID, FarmAtlas.STONE
				)

	# 主矿道：从西口（海滩洞口）横穿到深处。
	GroundPainter.horizontal_road(
		self, origin.x + 3, origin.x + 33, center_row, 1, GroundPainter.Style.STONE
	)
	# 竖井：从中段下探到矿脉深处。
	GroundPainter.vertical_road(
		self, center_row, origin.y + size.y - 4, origin.x + 33, 1, GroundPainter.Style.STONE
	)

	# 矿工营地：东北角一块夯土空地，木屋、木箱与草垛都摆在这。
	for cell: Vector2i in GridUtils.cells_in_area(Vector2i(origin.x + 34, origin.y + 4), Vector2i(10, 5)):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.DIRT)
	GroundPainter.horizontal_road(
		self, origin.x + 33, origin.x + 43, origin.y + 6, 0, GroundPainter.Style.DIRT
	)

	# 点缀：矿脉碎屑与几块裸岩（两种都自带砾石底，不会在洞里露出绿块）。
	GroundPainter.decorate(
		self,
		{
			Vector2i(origin.x + 6, origin.y + 8): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 12, origin.y + 22): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 20, origin.y + 9): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 26, origin.y + 21): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 40, origin.y + 12): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 42, origin.y + 24): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 16, origin.y + 18): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 38, origin.y + 18): FarmAtlas.GRAVEL_ORE,
			Vector2i(origin.x + 8, origin.y + 20): FarmAtlas.STONE,
			Vector2i(origin.x + 24, origin.y + 5): FarmAtlas.STONE,
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
