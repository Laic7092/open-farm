@tool
class_name InteriorGround
extends TileMapLayer
## 室内地板：木地板 + 一条通到门口的中央石道。
##
## 墙面 / 屋顶 / 门窗由同场景的 [InteriorWalls] 单独绘制，花砖由
## [DecorPainter] 生成摆件；本层只保留脚下地板。
## 室内地图共用这一张脚本：改 [member ground_area] 就能得到不同大小的房间。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 24, 16):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()
## 装饰节点的父节点（通常是 Props，参与 Y 排序）。
@export var decor_root: Node2D
## 是否自动撒四角花砖摆件。住宅这类要自己摆家具的房间可以关掉。
@export var decor_enabled: bool = true


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

	# 中央石道：从背墙门口一路铺到正门（背墙与门窗由 [InteriorWalls] 单独绘制）。
	var door_x: int = origin.x + size.x / 2
	var wall_rows: int = 3
	var walls := get_parent().get_node_or_null(^"Walls") as InteriorWalls
	if walls != null:
		wall_rows = walls.wall_rows
	for y: int in range(origin.y + wall_rows, origin.y + size.y):
		set_cell(Vector2i(door_x, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)

	# 两侧花砖点缀：改成透明摆件，放在地板上不占 TileMap。
	if decor_enabled:
		DecorPainter.spawn_many(
			decor_root,
			{
				Vector2i(origin.x + 3, origin.y + 6): &"flower_bed",
				Vector2i(origin.x + size.x - 4, origin.y + 6): &"flower_bed",
				Vector2i(origin.x + 3, origin.y + size.y - 4): &"flower_bed",
				Vector2i(origin.x + size.x - 4, origin.y + size.y - 4): &"flower_bed",
			},
			ground_area
		)
