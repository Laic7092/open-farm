extends GdUnitTestSuite
## 水体形状的可执行版本。
##
## 水面不再是瓦片，而是 [WaterShape] 的一条闭合折线。这份测试脱离地图，
## 只验证三件容易出错的事：
## [br]1. [b]形状[/b]：圆角/扰动都落在给定范围内，不会长出画布
## [br]2. [b]判定[/b]：带符号距离在水里为正、水外为负，且烟测依赖的那几格结论不变
## [br]3. [b]碰撞[/b]：栈桥能真的从碰撞里挖掉一块，且挖掉的不是别处

const WaterShape := preload("res://src/world/water_shape.gd")
const WaterLayout := preload("res://src/world/water_layout.gd")


# ---------------------------------------------------------------- 形状

func test_blob_stays_within_its_radius() -> void:
	var center := Vector2(120.0, 336.0)
	var wobble := 0.09
	var polygon := WaterShape.blob(center, 50.0, 27.0, wobble, 11)
	assert_int(polygon.size()).is_equal(WaterShape.DEFAULT_SEGMENTS)
	for point: Vector2 in polygon:
		var offset := point - center
		assert_float(absf(offset.x)).is_less_equal(50.0 * (1.0 + wobble))
		assert_float(absf(offset.y)).is_less_equal(27.0 * (1.0 + wobble))


func test_blob_is_deterministic() -> void:
	var first := WaterShape.blob(Vector2(120.0, 336.0), 50.0, 27.0, 0.09, 11)
	var second := WaterShape.blob(Vector2(120.0, 336.0), 50.0, 27.0, 0.09, 11)
	assert_array(first).is_equal(second)


func test_rounded_rect_cuts_the_corners() -> void:
	var area := Rect2(0.0, 0.0, 100.0, 60.0)
	var polygon := WaterShape.rounded_rect(area, 12.0)
	assert_array(polygon).is_not_empty()
	# 重心在水里，四个直角点被切掉。
	assert_bool(WaterShape.contains(polygon, area.get_center())).is_true()
	for corner: Vector2 in [area.position, Vector2(area.end.x, area.position.y),
			area.end, Vector2(area.position.x, area.end.y)]:
		assert_bool(WaterShape.contains(polygon, corner)).override_failure_message(
			"圆角矩形不该包含直角点 %s" % corner
		).is_false()


func test_pixel_bounds_pads_the_outline() -> void:
	var polygon := WaterShape.rectangle(Rect2(10.0, 20.0, 30.0, 40.0))
	var bounds := WaterShape.pixel_bounds(polygon, 4)
	assert_int(bounds.position.x).is_equal(6)
	assert_int(bounds.position.y).is_equal(16)
	assert_int(bounds.size.x).is_equal(38)
	assert_int(bounds.size.y).is_equal(48)


# ---------------------------------------------------------------- 判定

func test_signed_distance_is_positive_inside() -> void:
	var polygon := WaterShape.ellipse(Vector2(100.0, 100.0), Vector2(40.0, 20.0))
	assert_float(WaterShape.signed_distance(polygon, Vector2(100.0, 100.0))).is_greater(0.0)
	assert_float(WaterShape.signed_distance(polygon, Vector2(300.0, 300.0))).is_less(0.0)
	# 水面内侧 2px 与外侧 2px 必须异号。
	assert_float(WaterShape.signed_distance(polygon, Vector2(139.0, 100.0))).is_greater(0.0)
	assert_float(WaterShape.signed_distance(polygon, Vector2(143.0, 100.0))).is_less(0.0)


## 烟测断言的格子结论必须与运行期 [code]WaterField.is_water[/code] 一致：
## 这三格是水、那一格不是水。改了水体形状却忘了看烟测时，这条会先红。
func test_layout_keeps_the_smoke_test_cells() -> void:
	var town: WaterLayout.Body = WaterLayout.bodies_for(&"town")[0]
	assert_float(
		WaterShape.signed_distance(town.outline, GridUtils.cell_to_world(Vector2i(6, 20)))
	).override_failure_message("集市 (6,20) 应当在水里").is_greater(0.0)

	var twon: WaterLayout.Body = WaterLayout.bodies_for(&"twon")[0]
	assert_float(
		WaterShape.signed_distance(twon.outline, GridUtils.cell_to_world(Vector2i(24, 43)))
	).override_failure_message("twon (24,43) 应当在水里").is_greater(0.0)

	var beach: WaterLayout.Body = WaterLayout.bodies_for(&"beach")[0]
	assert_float(
		WaterShape.signed_distance(beach.outline, GridUtils.cell_to_world(Vector2i(5, 18)))
	).override_failure_message("海滩 (5,18) 应当在水里").is_greater(0.0)
	assert_float(
		WaterShape.signed_distance(beach.outline, GridUtils.cell_to_world(Vector2i(5, 17)))
	).override_failure_message("海滩 (5,17) 的沙滩不该算水").is_less(-4.0)


# ---------------------------------------------------------------- 碰撞

## 海面碰撞要把栈桥挖空，否则玩家上不了桥。
func test_collision_polygons_subtract_the_walkway() -> void:
	var ocean: WaterLayout.Body = WaterLayout.bodies_for(&"beach")[0]
	var pieces := WaterShape.collision_polygons(ocean.outline, ocean.walkways)
	assert_int(pieces.size()).is_equal(2)
	var total: float = 0.0
	for piece: PackedVector2Array in pieces:
		total += _area(piece)
		assert_bool(
			Geometry2D.is_point_in_polygon(Vector2(320.0, 350.0), piece)
		).override_failure_message("栈桥处不该有水面碰撞").is_false()
	# 挖掉的正好是栈桥压在海里的那一段（64 × 224）。
	assert_float(total).is_equal_approx(736.0 * 224.0 - 64.0 * 224.0, 1.0)
	assert_bool(
		Geometry2D.is_point_in_polygon(Vector2(100.0, 350.0), pieces[0])
		or Geometry2D.is_point_in_polygon(Vector2(100.0, 350.0), pieces[1])
	).is_true()


## 鞋带公式：多边形面积（与绕向无关）。
func _area(polygon: PackedVector2Array) -> float:
	var sum: float = 0.0
	var count := polygon.size()
	for index: int in count:
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % count]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5
