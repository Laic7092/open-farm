@tool
class_name MineGround
extends TileMapLayer
## 矿洞地面：砾石洞穴 + 岩石边带 + 中央矿道。
##
## 边缘的岩石带只是视觉封边，真正的碰撞由 [WorldBounds] 负责——
## 和农场 / 小镇一致，TileMap 不参与物理。

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

	# 砾石打底。
	for cell: Vector2i in GridUtils.cells_in_area(origin, size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.GRAVEL)

	# 洞穴边缘的岩石带（视觉上的洞壁）。
	for y: int in size.y:
		for x: int in size.x:
			if x < 2 or y < 2 or x >= size.x - 2 or y >= size.y - 2:
				set_cell(
					Vector2i(origin.x + x, origin.y + y),
					FarmAtlas.SOURCE_ID,
					FarmAtlas.STONE,
				)

	# 顶部一条泥土地：矿工的营地。
	for cell: Vector2i in GridUtils.cells_in_area(
		Vector2i(origin.x + 2, origin.y + 2), Vector2i(size.x - 4, 4)
	):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.DIRT)

	# 主矿道：从左侧入口横穿到深处，再竖直下探。
	var lane_y: int = origin.y + size.y / 2
	for x: int in range(origin.x + 2, origin.x + 34):
		set_cell(Vector2i(x, lane_y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)
		set_cell(Vector2i(x, lane_y + 1), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)
	for y: int in range(lane_y, origin.y + size.y - 3):
		set_cell(Vector2i(origin.x + 33, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)

	# 点缀：碎石。
	for cell: Vector2i in [
		Vector2i(origin.x + 6, origin.y + 8),
		Vector2i(origin.x + 12, origin.y + 22),
		Vector2i(origin.x + 20, origin.y + 9),
		Vector2i(origin.x + 26, origin.y + 21),
		Vector2i(origin.x + 40, origin.y + 12),
		Vector2i(origin.x + 42, origin.y + 24),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.PEBBLE)
