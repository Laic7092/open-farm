extends GdUnitTestSuite
## 室内墙面：按格子摆 [Sprite2D]，并用按行合并的 [StaticBody2D] 挡住玩家。
##
## 图集只放地板之后（见 [AtlasLayout]），墙面改成独立贴图 + 自己的碰撞体，
## 这里锁住"门洞必须留空、其余实心处必须挡人"这条规则——它以前由 TileSet
## 物理层保证，现在换人做了，就必须有测试顶上。

const Layout := preload("res://src/art/atlas_layout.gd")

const AREA := Rect2i(0, 0, 24, 16)
const ROWS: int = 3

var _walls: InteriorWalls


func before_test() -> void:
	_walls = InteriorWalls.new()
	_walls.ground_area = AREA
	_walls.wall_rows = ROWS
	_walls.paint()


func after_test() -> void:
	_walls.free()


func test_paints_one_sprite_per_cell() -> void:
	var sprites := _sprites()
	assert_int(sprites.size()).is_equal(AREA.size.x * ROWS)
	for sprite: Sprite2D in sprites:
		assert_object(sprite.texture).is_not_null()
		if sprite.texture != null:
			assert_int(sprite.texture.get_width()).is_equal(Layout.TILE)


## 门洞画门廊但不挡人；其余每行合并成一条碰撞带，门洞那行因此断成两条。
func test_collision_bands_leave_the_doorway_open() -> void:
	var door := Vector2i(AREA.position.x + AREA.size.x / 2, AREA.position.y + ROWS - 1)
	var boxes := _collision_boxes()
	assert_int(boxes.size()).is_equal(ROWS + 1)
	assert_bool(_covers(boxes, GridUtils.cell_to_world(door))).override_failure_message(
		"背墙门洞不该被挡住"
	).is_false()
	for row: int in ROWS:
		var cell := Vector2i(AREA.position.x + 1, AREA.position.y + row)
		assert_bool(_covers(boxes, GridUtils.cell_to_world(cell))).override_failure_message(
			"第 %d 行实心墙面没挡住" % row
		).is_true()


## 立面规则：顶行压屋顶、第二行每五格开一扇窗、其余是白墙。
func test_piece_ids_follow_the_facade_rule() -> void:
	assert_str(_sprite_at(Vector2i(0, 0)).name).contains("roof")
	assert_str(_sprite_at(Vector2i(1, 1)).name).contains("wall")
	assert_str(_sprite_at(Vector2i(2, 1)).name).contains("window")
	assert_str(_sprite_at(Vector2i(12, 2)).name).contains("doorway")


func _sprites() -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child: Node in _walls.get_children():
		if child is Sprite2D:
			found.append(child as Sprite2D)
	return found


func _sprite_at(cell: Vector2i) -> Sprite2D:
	var want := GridUtils.cell_to_world(cell)
	for sprite: Sprite2D in _sprites():
		if sprite.position == want:
			return sprite
	return null


func _collision_boxes() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var body := _walls.get_node_or_null(^"Body")
	if body == null:
		return found
	for child: Node in body.get_children():
		if child is not CollisionShape2D:
			continue
		var shape_node := child as CollisionShape2D
		var rectangle := shape_node.shape as RectangleShape2D
		found.append(Rect2(shape_node.position - rectangle.size * 0.5, rectangle.size))
	return found


func _covers(boxes: Array[Rect2], point: Vector2) -> bool:
	for box: Rect2 in boxes:
		if box.has_point(point):
			return true
	return false
