class_name WaterField
extends Node2D
## 一张地图上的水面。
##
## 水是一个[b]形状[/b]，不是地面 TileMap 里的瓦片——瓦片拼不出圆润的岸线。
## [class WaterLayout] 声明每张图有哪些水体，构建期由
## [code]tools/art/generate_water.gd[/code] 把形状烘成贴图，运行期由这里：
## [br]- 放一张 [Sprite2D] 显示水面（静态部分：深浅、浪花、岸影）
## [br]- 建 [StaticBody2D] + [CollisionPolygon2D] 挡住玩家与 NPC，不让下水
## [br]- 逐帧画会动的东西：岸边浪花呼吸、向岸扩散的水波、水面碎光
##
## 与 [FloraField] 同一套做法：按分组被查询，
## [FarmInteractor] 用 [method Node.get_first_node_in_group] 找到当前地图的水域。

## 加入该分组后，玩家与工具可以找到当前场景的水面。
const GROUP: StringName = &"water_field"

## 水面覆盖层：位于地面（-20）之上、土壤（-10）与摆件（0）之下。
const WATER_Z_INDEX: int = -15
## 水体碰撞所在的世界物理层；玩家与 [NpcNavigator] 都探这一层。
const COLLISION_LAYER: int = 1
## 判格子时向外放宽的像素。
##
## 岸线是弯的，"面前那一格"的中心可能正好落在曲线外侧；不放宽的话，
## 玩家贴着水边站却钓不了鱼。放宽 4px 足够，又不会把岸上的格子误判成水。
const EDGE_GRACE: float = 4.0
## 波光动画速度（弧度/秒）。
const WAVE_SPEED: float = 1.1
## 逐帧画浪花前把岸线重采样的间距（像素）。
const SHORE_SAMPLE_STEP: float = 6.0
## 同时存在几圈扩散的水波（只用于小水面）。
const RIPPLE_COUNT: int = 3
## 横向浪线的间距（像素）与判定"大海"的宽度（像素）。
##
## 海面太宽，把岸线缩成同心圈会读成一个方框；大水面改用一条条横向浪线，
## 小池塘再用环状扩散的水波。
const WAVE_LINE_STEP: float = 14.0
const LARGE_BODY_WIDTH: float = 200.0
## 碎光候选点的采样步长、保留概率与"离岸多深才算深水"（像素）。
const SPARKLE_STEP: int = 13
const SPARKLE_CHANCE: float = 0.22
const SPARKLE_MIN_DEPTH: float = 12.0

## 场景标识；由 [WorldScene] 在挂载前写入，用来查 [WaterLayout]。
var world_id: StringName = &""

## 格子 → 水域类型；[method is_water] 与 [method kind_at] 只读这一份。
var _kind_by_cell: Dictionary[Vector2i, int] = {}
## 每个水体等距重采样后的岸线（画浪花与扩散水波用）。
var _shores: Array[PackedVector2Array] = []
## 每个水体是不是"大海"（宽过 [constant LARGE_BODY_WIDTH]）。
var _large: Array[bool] = []
## 每个水体内可以被碎光点亮的候选点。
var _sparkles: Array[PackedVector2Array] = []
## 全局动画相位。
var _phase: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	z_index = WATER_Z_INDEX
	_build()
	if _shores.is_empty():
		set_process(false)


## 水面动态：推进相位，然后重画浪花 / 水波 / 碎光。
func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * WAVE_SPEED, TAU)
	queue_redraw()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	var bodies := WaterLayout.bodies_for(world_id)
	for index: int in bodies.size():
		var body: WaterLayout.Body = bodies[index]
		_add_surface(body, index)
		_add_collision(body, index)
		_index_cells(body)
		_shores.append(WaterShape.resample(body.outline, SHORE_SAMPLE_STEP))
		_large.append(WaterShape.bounds(body.outline).size.x > LARGE_BODY_WIDTH)
		_sparkles.append(_collect_sparkles(body))


## 水面贴图由构建期烘好；缺图时只警告不出错，地图仍能跑（只是没水色）。
func _add_surface(body: WaterLayout.Body, index: int) -> void:
	var path := WaterLayout.sprite_path(world_id, index)
	if not ResourceLoader.exists(path):
		push_warning("缺少水面贴图 %s（跑一次 ./tools/build_assets.sh）" % path)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Surface%d" % index
	sprite.texture = ResourceLoader.load(path) as Texture2D
	sprite.centered = false
	sprite.position = Vector2(body.pixel_bounds().position)
	# 负 z 让父节点的 _draw()（浪花 / 水波）画在贴图之上。
	sprite.z_index = -1
	add_child(sprite)


## 碰撞多边形 = 岸线减去栈桥通道（[method WaterShape.collision_polygons]）。
func _add_collision(body: WaterLayout.Body, index: int) -> void:
	var pieces := WaterShape.collision_polygons(body.outline, body.walkways)
	if pieces.is_empty():
		return
	var solid := StaticBody2D.new()
	solid.name = "Solid%d" % index
	solid.collision_layer = COLLISION_LAYER
	solid.collision_mask = 0
	add_child(solid)
	for piece: PackedVector2Array in pieces:
		var shape := CollisionPolygon2D.new()
		shape.polygon = piece
		solid.add_child(shape)


## 把水体覆盖到的格子记进缓存。判定用"格子中心到岸线的带符号距离"，
## 向外放宽 [constant EDGE_GRACE] 像素，这样钓鱼时面前那一格始终算得进水。
func _index_cells(body: WaterLayout.Body) -> void:
	var bounds := body.pixel_bounds()
	var grace := Vector2(EDGE_GRACE, EDGE_GRACE)
	var from := GridUtils.world_to_cell(Vector2(bounds.position) - grace)
	var to := GridUtils.world_to_cell(Vector2(bounds.end) + grace)
	for cell: Vector2i in GridUtils.cells_in_area(from, to - from + Vector2i.ONE):
		if _kind_by_cell.has(cell):
			continue
		var center := GridUtils.cell_to_world(cell)
		if WaterShape.signed_distance(body.outline, center) > -EDGE_GRACE:
			_kind_by_cell[cell] = body.kind


## 深水区里的碎光候选点：只留离岸够远的格子中心，免得浪花和碎光挤在一起。
func _collect_sparkles(body: WaterLayout.Body) -> PackedVector2Array:
	var points := PackedVector2Array()
	var bounds := body.pixel_bounds()
	var y: int = bounds.position.y + SPARKLE_STEP
	while y < bounds.end.y - SPARKLE_STEP:
		var x: int = bounds.position.x + SPARKLE_STEP
		while x < bounds.end.x - SPARKLE_STEP:
			if WaterShape.signed_distance(body.outline, Vector2(float(x), float(y))) > SPARKLE_MIN_DEPTH:
				if WaterShape.hash01(x, y, 5) < SPARKLE_CHANCE:
					points.append(Vector2(float(x), float(y)))
			x += SPARKLE_STEP
		y += SPARKLE_STEP
	return points


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	var foam := ArtPalette.WATER_FOAM
	var shine := ArtPalette.WATER_LIGHT
	for index: int in _shores.size():
		_draw_foam(_shores[index], foam, index)
		if _large[index]:
			_draw_wave_lines(_shores[index], shine, index)
		else:
			_draw_ripples(_shores[index], shine, index)
		_draw_sparkles(_sparkles[index], shine)


## 岸边浪花：沿重采样后的岸线一段段亮灭，像浪打在岸上又退回去。
func _draw_foam(shore: PackedVector2Array, color: Color, salt: int) -> void:
	for index: int in shore.size():
		var pulse := sin(_phase * 2.0 + float(index) * 0.55 + float(salt))
		if pulse < 0.25:
			continue
		var at: Vector2 = shore[index]
		var alpha := 0.22 + 0.40 * pulse
		draw_rect(Rect2(at - Vector2(1.5, 0.5), Vector2(3.0, 1.0)), Color(color, alpha))


## 扩散的水波：把岸线绕重心一圈圈缩向中心，读起来就是水波从中央荡到岸边。
func _draw_ripples(shore: PackedVector2Array, color: Color, salt: int) -> void:
	if shore.size() < 3:
		return
	for ring: int in RIPPLE_COUNT:
		var t := fposmod(
			_phase * 0.45 + float(ring) / float(RIPPLE_COUNT) + float(salt) * 0.13, 1.0
		)
		var alpha := (1.0 - t) * 0.22
		if alpha <= 0.01:
			continue
		var points := WaterShape.scaled_about(shore, lerpf(0.35, 1.0, t))
		points.append(points[0])
		draw_polyline(points, Color(color, alpha), 1.0, false)


## 大水面（海）的横向浪线：一行行随相位左右起伏，比同心圈更像海。
##
## 用扫描线求出"这一行落在水里的每一段"，所以浪线不会画到岸上去。
func _draw_wave_lines(shore: PackedVector2Array, color: Color, salt: int) -> void:
	var box := WaterShape.bounds(shore)
	var offset := fposmod(_phase * 2.0 + float(salt) * 3.0, WAVE_LINE_STEP)
	var y: float = box.position.y + offset
	while y < box.end.y:
		var alpha := 0.05 + 0.05 * absf(sin(y * 0.25 + _phase))
		for span: Vector2 in _scanline_spans(shore, y):
			var points := PackedVector2Array()
			var x: float = span.x
			while x <= span.y:
				points.append(
					Vector2(x, y + sin(x * 0.07 + _phase * 2.0) * 0.8)
				)
				x += 6.0
			if points.size() >= 2:
				draw_polyline(points, Color(color, alpha), 1.0, false)
		y += WAVE_LINE_STEP


## 一条水平线与折线的所有相交区间（成对取），即这一行落在水里的几段。
func _scanline_spans(polygon: PackedVector2Array, y: float) -> Array[Vector2]:
	var crossings: Array[float] = []
	var count := polygon.size()
	for index: int in count:
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % count]
		if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
			crossings.append(a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y))
	crossings.sort()
	var spans: Array[Vector2] = []
	var index: int = 0
	while index + 1 < crossings.size():
		spans.append(Vector2(crossings[index], crossings[index + 1]))
		index += 2
	return spans


## 水面碎光：几段随相位轻轻平移的亮线，让大片水面不呆板。
func _draw_sparkles(points: PackedVector2Array, color: Color) -> void:
	for index: int in points.size():
		var at: Vector2 = points[index]
		var drift := sin(_phase * 1.4 + float(index) * 0.7) * 2.0
		var alpha := 0.08 + 0.16 * absf(sin(_phase * 0.8 + float(index) * 1.3))
		draw_rect(Rect2(at + Vector2(drift, 0.0), Vector2(3.0, 1.0)), Color(color, alpha))


# ---------------------------------------------------------------- 查询

## 这一格是否是水。
func is_water(cell: Vector2i) -> bool:
	return _kind_by_cell.has(cell)


## 这一格的水域类型；不是水返回 -1。
func kind_at(cell: Vector2i) -> int:
	return _kind_by_cell.get(cell, -1)
