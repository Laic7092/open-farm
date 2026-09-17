@tool
class_name InteriorWalls
extends TileMapLayer
## 室内墙面层：屋顶压顶、白墙、窗与门廊。
##
## 和 [InteriorGround] 分开后，Ground 只保留木地板与中央石道；
## 墙面是建筑结构，不再和"脚下是什么"混在同一张图层里。
## 碰撞继续走 TileSet 的物理层，与 [WorldBounds] 同一 collision layer。

## 铺设区域（格子坐标），应与同场景的 [InteriorGround.ground_area] 一致。
@export var ground_area: Rect2i = Rect2i(0, 0, 24, 16):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()
## 上方墙面的行数。
@export_range(1, 6) var wall_rows: int = 3


func _ready() -> void:
	paint()


## 用代码铺墙面。
func paint() -> void:
	clear()
	var origin := ground_area.position
	var size := ground_area.size

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
