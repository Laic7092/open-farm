class_name WaterShape
extends RefCounted
## 水体形状：一条闭合折线 + 一组查询函数。
##
## 水面不再是地面 TileMap 里的瓦片——瓦片只能拼出 45° 台阶，拼不出圆润的岸线。
## 这里用一条闭合折线（世界坐标、像素）当唯一表述，喂给三个消费者：
## [br]- [code]tools/art/generate_water.gd[/code]：按"到岸线的距离"逐像素烘水体贴图
## [br]- [class WaterField]：生成碰撞多边形、判定"哪一格是水"
## [br]- [class WaterField] 的逐帧波光：沿同一条折线画浪花与扩散的水波
##
## 全部是纯静态函数、不碰场景树，所以能脱离地图在单元测试里验证。
##
## [b]约定[/b]：折线的首尾点不重复（最后一点自动与第一点相连），
## 符号距离以"[b]正 = 在水里[/b]"为准——上色与判格都按这个方向读。

## 默认顶点数：64 段在 16 像素格子下已经看不出折角。
const DEFAULT_SEGMENTS: int = 64


# ---------------------------------------------------------------- 造形状

## 正椭圆。想让池塘保持规整时用它。
static func ellipse(
	center: Vector2, radius: Vector2, segments: int = DEFAULT_SEGMENTS
) -> PackedVector2Array:
	return blob(center, radius.x, radius.y, 0.0, 0, segments)


## 有机的水塘：半径被两三个不同频率的正弦扰动，得到平滑的自然岸线。
##
## 用正弦而不是逐顶点随机数，是为了"平滑"：随机半径会得到毛刺，
## 而水域的岸线必须是缓的。[param wobble] 0.05~0.12 之间最像水塘。
static func blob(
	center: Vector2, rx: float, ry: float, wobble: float, seed: int,
	segments: int = DEFAULT_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 3)
	for index: int in count:
		var angle := TAU * float(index) / float(count)
		var wave := (
			sin(angle * 2.0 + float(seed) * 1.7) * 0.55
			+ sin(angle * 3.0 + float(seed) * 0.9) * 0.30
			+ sin(angle * 5.0 + float(seed) * 2.3) * 0.15
		)
		var scale := 1.0 + wobble * wave
		points.append(
			center + Vector2(cos(angle) * rx * scale, sin(angle) * ry * scale)
		)
	return points


## 圆角矩形。[param corner] 为 0 时退化成直角矩形。
static func rounded_rect(
	area: Rect2, corner: float, corner_steps: int = 4
) -> PackedVector2Array:
	var radius := clampf(corner, 0.0, minf(area.size.x, area.size.y) * 0.5)
	if radius <= 0.5:
		return rectangle(area)
	var points := PackedVector2Array()
	# 顺时针：右上 → 右下 → 左下 → 左上。
	var corners := [
		[Vector2(area.end.x - radius, area.position.y + radius), -PI * 0.5, 0.0],
		[Vector2(area.end.x - radius, area.end.y - radius), 0.0, PI * 0.5],
		[Vector2(area.position.x + radius, area.end.y - radius), PI * 0.5, PI],
		[Vector2(area.position.x + radius, area.position.y + radius), PI, PI * 1.5],
	]
	var steps: int = maxi(corner_steps, 1)
	for entry: Array in corners:
		var origin: Vector2 = entry[0]
		var from: float = entry[1]
		var to: float = entry[2]
		for step: int in steps + 1:
			var angle := lerpf(from, to, float(step) / float(steps))
			points.append(origin + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 直角矩形（海滩这类开阔水面）。
static func rectangle(area: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	])


# ---------------------------------------------------------------- 查询

## 折线的外接矩形（浮点，世界坐标）。
static func bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var box := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		box = box.expand(point)
	return box


## 贴图要覆盖的整数像素范围：外接矩形向外取整，再各留 [param margin]。
static func pixel_bounds(polygon: PackedVector2Array, margin: int) -> Rect2i:
	var box := bounds(polygon)
	if box.size == Vector2.ZERO:
		return Rect2i()
	var from := Vector2i(floori(box.position.x), floori(box.position.y))
	var to := Vector2i(ceili(box.end.x), ceili(box.end.y))
	var pad := Vector2i(margin, margin)
	return Rect2i(from - pad, (to + pad) - (from - pad))


## 点到折线的最短距离（无符号）。
static func distance_to_outline(polygon: PackedVector2Array, point: Vector2) -> float:
	var count := polygon.size()
	if count == 0:
		return 0.0
	if count == 1:
		return point.distance_to(polygon[0])
	var best := INF
	for index: int in count:
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % count]
		best = minf(best, _segment_distance(a, b, point))
	return best if best < INF else 0.0


## 带符号距离：[b]正在水里面[/b]，负在水外。
static func signed_distance(polygon: PackedVector2Array, point: Vector2) -> float:
	if polygon.size() < 3:
		return -INF
	var distance := distance_to_outline(polygon, point)
	return distance if Geometry2D.is_point_in_polygon(point, polygon) else -distance


## 点是否落在水里（严格：贴着岸线算不算由调用方自己定）。
static func contains(polygon: PackedVector2Array, point: Vector2) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, polygon)


## 折线的重心，用于"向岸扩散"的水波。
static func centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point: Vector2 in polygon:
		sum += point
	return sum / float(polygon.size())


## 绕重心缩放；水波就是把岸线一圈圈缩向中心。
static func scaled_about(polygon: PackedVector2Array, scale: float) -> PackedVector2Array:
	var center := centroid(polygon)
	var points := PackedVector2Array()
	for point: Vector2 in polygon:
		points.append(center + (point - center) * scale)
	return points


## 沿折线等距重采样：逐帧画浪花前先做一次，免得长边上的浪花稀疏。
static func resample(polygon: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var count := polygon.size()
	if count < 2 or spacing <= 0.0:
		return polygon
	var points := PackedVector2Array()
	for index: int in count:
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % count]
		var steps: int = maxi(int(ceil(a.distance_to(b) / spacing)), 1)
		for step: int in steps:
			points.append(a.lerp(b, float(step) / float(steps)))
	return points


## 用一条折线切掉面积：[param cutters] 里的矩形会从碰撞里挖掉
## （木栈桥要能从水上走过去），但外观不受影响。
static func collision_polygons(
	outline: PackedVector2Array, cutters: Array[Rect2]
) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [outline]
	for cutter: Rect2 in cutters:
		var next: Array[PackedVector2Array] = []
		var cutter_polygon := rectangle(cutter)
		for piece: PackedVector2Array in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, cutter_polygon))
		pieces = next
	return pieces


## 与 [code]Art.noise[/code] 同源的坐标哈希（0.0~1.0）。
##
## 运行时代码不能依赖 [code]tools/[/code]（见 [GroundPainter] 的同款注释），
## 所以这里留一份最小实现；它只用来决定"哪几个点闪一下"。
static func hash01(x: int, y: int, salt: int = 0) -> float:
	var h: int = x * 374761393 + y * 668265263 + salt * 69069
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0


# ---------------------------------------------------------------- 内部

static func _segment_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)
