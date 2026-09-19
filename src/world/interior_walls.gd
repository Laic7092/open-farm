@tool
class_name InteriorWalls
extends Node2D
## 室内墙面：屋顶压顶、白墙、窗与门廊。
##
## 墙面是建筑结构，不占图集格子（见 [AtlasLayout]）：贴图由
## [code]tools/art/generate_terrain.gd[/code] 导出到
## [code]assets/sprites/interior/[/code]，这里按 [member ground_area] 摆成
## [Sprite2D]，并用自己的 [StaticBody2D] 挡住玩家——门洞那一格留空。
## 碰撞与 [WorldBounds] 同一 collision layer，不再依赖 TileSet 物理层。

const Layout := preload("res://src/art/atlas_layout.gd")

## 与 [WorldBounds] 共用的 collision layer。
const COLLISION_LAYER: int = 1

## 构件 id → 贴图路径；与 [constant AtlasLayout.INTERIOR_SPRITES] 一一对应。
const TEXTURES: Dictionary = {
	&"roof": "res://assets/sprites/interior/roof.png",
	&"wall": "res://assets/sprites/interior/wall.png",
	&"window": "res://assets/sprites/interior/window.png",
	&"doorway": "res://assets/sprites/interior/doorway.png",
}

## 铺设区域（格子坐标），应与同场景的 [InteriorGround.ground_area] 一致。
@export var ground_area: Rect2i = Rect2i(0, 0, 24, 16):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()
## 上方墙面的行数。
@export_range(1, 6) var wall_rows: int = 3

var _body: StaticBody2D


func _ready() -> void:
	paint()


## 用代码铺墙面：逐格贴图，再按行把实心格合并成一条条碰撞带。
func paint() -> void:
	_clear()
	var origin := ground_area.position
	var size := ground_area.size
	var door_cell := Vector2i(origin.x + size.x / 2, origin.y + wall_rows - 1)

	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = COLLISION_LAYER
	_body.collision_mask = 0
	add_child(_body)

	for y: int in wall_rows:
		var run_start: int = -1
		# 多跑一格：让最后一格也能收尾。
		for x: int in size.x + 1:
			var cell := Vector2i(origin.x + x, origin.y + y)
			var solid: bool = x < size.x and cell != door_cell
			if x < size.x:
				_add_sprite(cell, _piece_id(cell, y, door_cell))
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				_add_collision(origin.x + run_start, cell.y, x - run_start)
				run_start = -1


## 这一格摆哪种构件：顶行压屋顶，第二行每五格开一扇窗，中间是门洞。
func _piece_id(cell: Vector2i, row: int, door_cell: Vector2i) -> StringName:
	if cell == door_cell:
		return &"doorway"
	if row == 0:
		return &"roof"
	if row == 1 and cell.x % 5 == 2:
		return &"window"
	return &"wall"


func _add_sprite(cell: Vector2i, piece_id: StringName) -> void:
	var texture := load(TEXTURES[piece_id]) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Wall_%d_%d_%s" % [cell.x, cell.y, String(piece_id)]
	sprite.texture = texture
	sprite.position = GridUtils.cell_to_world(cell)
	add_child(sprite)


## 一段横跨 [param length] 格的实心墙；[param start_x] 是世界格子坐标。
func _add_collision(start_x: int, y: int, length: int) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(length * Layout.TILE, Layout.TILE)
	shape.shape = rectangle
	shape.position = (
		GridUtils.cell_to_world(Vector2i(start_x, y))
		+ Vector2((length - 1) * Layout.TILE * 0.5, 0.0)
	)
	_body.add_child(shape)


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
