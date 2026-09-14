@tool
class_name BeachGround
extends TileMapLayer
## 海滩地面：上方草坡、中间沙滩、下方海水，一条木栈桥伸进海里。
##
## 与 [TownGround] / [FarmGrid] 同一套做法：地面由脚本按坐标画出，
## 改布局只要改这个文件，不需要在编辑器里手绘难以 diff 的 TileMap 数据。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 40, 26):
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

	# 沙滩打底。
	for cell: Vector2i in GridUtils.cells_in_area(origin, size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.SAND)

	# 上方草坡：与内陆接壤，也给野生植被一点变化。
	for y: int in 4:
		for x: int in size.x:
			var cell := Vector2i(origin.x + x, origin.y + y)
			set_cell(cell, FarmAtlas.SOURCE_ID, _grass_variant(cell))

	# 下方海水 + 一条浪线。留 6 行海面，让出生点抬头就能看见海。
	var water_top: int = origin.y + size.y - 6
	for cell: Vector2i in GridUtils.cells_in_area(
		Vector2i(origin.x, water_top), Vector2i(size.x, 6)
	):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WATER)
	for x: int in size.x:
		set_cell(Vector2i(origin.x + x, water_top - 1), FarmAtlas.SOURCE_ID, FarmAtlas.WATER_EDGE)

	# 从左侧入口到栈桥的石板路（两格宽）。
	var lane_y: int = origin.y + size.y / 2
	for x: int in range(origin.x, origin.x + 20):
		set_cell(Vector2i(x, lane_y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH)
		set_cell(Vector2i(x, lane_y + 1), FarmAtlas.SOURCE_ID, FarmAtlas.PATH)

	# 通往矿洞的上坡路：先沿 x=20 北上，再折向右侧洞口。
	for y: int in range(origin.y + 6, lane_y + 1):
		set_cell(Vector2i(origin.x + 20, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH)
	for x: int in range(origin.x + 20, origin.x + 37):
		set_cell(Vector2i(x, origin.y + 6), FarmAtlas.SOURCE_ID, FarmAtlas.PATH)

	# 木栈桥：从沙滩一路铺进水里。
	for y: int in range(origin.y + 15, origin.y + size.y):
		for x: int in range(origin.x + 18, origin.x + 22):
			if ground_area.has_point(Vector2i(x, y)):
				set_cell(Vector2i(x, y), FarmAtlas.SOURCE_ID, FarmAtlas.WOOD)

	# 零散点缀：卵石与野花。
	for cell: Vector2i in [
		Vector2i(origin.x + 4, origin.y + 8),
		Vector2i(origin.x + 32, origin.y + 10),
		Vector2i(origin.x + 8, origin.y + 18),
		Vector2i(origin.x + 28, origin.y + 20),
		Vector2i(origin.x + 34, origin.y + 16),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.PEBBLE)
	for cell: Vector2i in [
		Vector2i(origin.x + 10, origin.y + 2),
		Vector2i(origin.x + 26, origin.y + 2),
	]:
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FLOWERS)


## 草地明暗交错，避免整片纯色。
func _grass_variant(cell: Vector2i) -> Vector2i:
	if (cell.x * 5 + cell.y * 3) % 9 < 4:
		return FarmAtlas.GRASS_ALT
	return FarmAtlas.GRASS
