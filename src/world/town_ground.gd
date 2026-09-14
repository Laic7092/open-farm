@tool
class_name TownGround
extends TileMapLayer
## 小镇地面：铺草地 + 十字街道 + 广场 + 池塘。
##
## 农场的地面由 [FarmGrid] 负责（它同时还要管土壤层），
## 而小镇只需要一块静态地面，所以单独抽成这个小脚本，
## 避免为了铺地而把一个空的 FarmGrid 塞进小镇场景。
##
## 与农场一样：地面由脚本按坐标画出，改布局只要改这个文件，
## 不需要在编辑器里手绘 TileMap 数据（那种数据在 git 里根本看不懂）。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 40, 26):
	set(value):
		ground_area = value
		# 编辑器中改数值即时刷新；场景实例化阶段还没进树，交给 _ready()。
		if is_inside_tree():
			paint()


func _ready() -> void:
	paint()


## 用代码铺地：横向主街 + 纵向支路 + 广场 + 右下角池塘。
func paint() -> void:
	clear()
	var center_row: int = ground_area.position.y + ground_area.size.y / 2
	var center_column: int = ground_area.position.x + ground_area.size.x / 2

	for cell: Vector2i in GridUtils.cells_in_area(ground_area.position, ground_area.size):
		var atlas: Vector2i = _grass_variant(cell)
		# 主街（两格宽）与纵向支路
		if cell.y == center_row or cell.y == center_row + 1:
			atlas = FarmAtlas.PATH
		if cell.x == center_column:
			atlas = FarmAtlas.PATH
		set_cell(cell, FarmAtlas.SOURCE_ID, atlas)

	# 广场：主街中央铺石板。
	var plaza := Rect2i(center_column - 4, center_row - 4, 9, 5)
	for cell: Vector2i in GridUtils.cells_in_area(plaza.position, plaza.size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)
	# 广场四角点木地板，两处摆花圃。
	for cell: Vector2i in [
		Vector2i(plaza.position.x, plaza.position.y),
		Vector2i(plaza.end.x - 1, plaza.position.y),
		Vector2i(plaza.position.x, plaza.end.y - 1),
		Vector2i(plaza.end.x - 1, plaza.end.y - 1),
	]:
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WOOD)
	for cell: Vector2i in [
		Vector2i(plaza.position.x + 1, plaza.position.y + 2),
		Vector2i(plaza.end.x - 2, plaza.position.y + 2),
	]:
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FLOWER_BED)

	# 右下角的小池塘：给小镇一个视觉重心。
	_pond(Vector2i(ground_area.end.x - 8, ground_area.end.y - 6))

	# 街道两侧的零散点缀。
	for cell: Vector2i in [
		Vector2i(ground_area.position.x + 3, center_row - 6),
		Vector2i(ground_area.position.x + 7, center_row + 6),
		Vector2i(ground_area.end.x - 4, center_row - 6),
		Vector2i(ground_area.end.x - 8, center_row + 6),
		Vector2i(ground_area.end.x - 11, center_row - 4),
		Vector2i(ground_area.position.x + 12, center_row - 5),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FLOWERS)


## 草地明暗交错，避免整片纯色。
func _grass_variant(cell: Vector2i) -> Vector2i:
	if (cell.x * 5 + cell.y * 3) % 9 < 4:
		return FarmAtlas.GRASS_ALT
	return FarmAtlas.GRASS


## 池塘：4×3 的水面，外围一圈沙岸。
func _pond(origin: Vector2i) -> void:
	var water := Rect2i(origin.x, origin.y, 4, 3)
	for cell: Vector2i in GridUtils.cells_in_area(water.position, water.size):
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WATER)
	for cell: Vector2i in [
		Vector2i(water.position.x - 1, water.position.y),
		Vector2i(water.end.x, water.position.y),
		Vector2i(water.position.x - 1, water.end.y - 1),
		Vector2i(water.end.x, water.end.y - 1),
		Vector2i(water.position.x, water.end.y),
		Vector2i(water.position.x + 2, water.end.y),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WATER_EDGE)
