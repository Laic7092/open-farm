@tool
class_name InteriorGround
extends TileMapLayer
## 室内地板：木地板 + 上方墙面 + 一条通到门口的中央石道。
##
## 室内地图共用这一张脚本：改 [member wall_rows] / [member ground_area]
## 就能得到不同大小的房间，不必为每间屋子再写一份铺地代码。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 24, 16):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()
## 上方墙面的行数。
@export_range(1, 6) var wall_rows: int = 3


func _ready() -> void:
	paint()


## 用代码铺地。
func paint() -> void:
	clear()
	var origin := ground_area.position
	var size := ground_area.size

	# 木地板。
	for cell: Vector2i in GridUtils.cells_in_area(origin, size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WOOD)

	# 上方墙面：屋檐压顶 + 一排窗。
	for y: int in wall_rows:
		for x: int in size.x:
			var tile: Vector2i = FarmAtlas.WALL
			if y == 0:
				tile = FarmAtlas.ROOF
			elif y == 1 and x % 5 == 2:
				tile = FarmAtlas.WINDOW
			set_cell(Vector2i(origin.x + x, origin.y + y), FarmAtlas.SOURCE_ID, tile)

	# 背墙正中开一个门洞，作为视觉焦点。
	var door_x: int = origin.x + size.x / 2
	set_cell(
		Vector2i(door_x, origin.y + wall_rows - 1), FarmAtlas.SOURCE_ID, FarmAtlas.DOORWAY
	)

	# 中央石道：从背墙门口一路铺到正门。
	for y: int in range(origin.y + wall_rows, origin.y + size.y):
		set_cell(Vector2i(door_x, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)

	# 两侧花砖点缀。
	for cell: Vector2i in [
		Vector2i(origin.x + 3, origin.y + 6),
		Vector2i(origin.x + size.x - 4, origin.y + 6),
		Vector2i(origin.x + 3, origin.y + size.y - 4),
		Vector2i(origin.x + size.x - 4, origin.y + size.y - 4),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FLOWER_BED)
