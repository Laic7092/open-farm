@tool
class_name TownGround
extends TileMapLayer
## 小镇地面：铺草地 + 十字街道 + 广场。
##
## 农场的地面由 [FarmGrid] 负责（它同时还要管土壤层），
## 而小镇只需要一块静态地面，所以单独抽成这个小脚本，
## 避免为了铺地而把一个空的 FarmGrid 塞进小镇场景。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 40, 26):
	set(value):
		ground_area = value
		# 编辑器中改数值即时刷新；场景实例化阶段还没进树，交给 _ready()。
		if is_inside_tree():
			paint()


func _ready() -> void:
	paint()


## 用代码铺地：横向主街 + 纵向支路，其余为草地，边缘点缀花丛。
func paint() -> void:
	clear()
	var center_row: int = ground_area.position.y + ground_area.size.y / 2
	var center_column: int = ground_area.position.x + ground_area.size.x / 2

	for cell: Vector2i in GridUtils.cells_in_area(ground_area.position, ground_area.size):
		var atlas: Vector2i = FarmAtlas.GRASS
		if (cell.y - center_row) % 2 == 0:
			atlas = FarmAtlas.GRASS_ALT
		if cell.y == center_row or cell.y == center_row + 1:
			atlas = FarmAtlas.PATH
		if cell.x == center_column:
			atlas = FarmAtlas.PATH
		set_cell(cell, FarmAtlas.SOURCE_ID, atlas)

	# 广场：主街中央铺一圈木地板。
	var plaza := Rect2i(center_column - 4, center_row - 4, 9, 5)
	for cell: Vector2i in GridUtils.cells_in_area(plaza.position, plaza.size):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WOOD)

	# 装饰
	for cell: Vector2i in [
		Vector2i(ground_area.position.x + 3, center_row - 6),
		Vector2i(ground_area.position.x + 7, center_row + 6),
		Vector2i(ground_area.end.x - 4, center_row - 6),
		Vector2i(ground_area.end.x - 8, center_row + 6),
	]:
		if ground_area.has_point(cell):
			set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FLOWERS)
