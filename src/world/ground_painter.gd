class_name GroundPainter
extends RefCounted
## 户外地图铺地的公共手法：草地、主路、小径与水面。
##
## 装饰摆件不再写进这里，统一由 [DecorPainter] 生成透明 [WorldProp]；
## Ground 图层只回答"脚下是什么地板"。
##
## [b]为什么抽出来[/b]：世界要"连成一片"，前提是每张地图的路长得一样、
## 在边缘接得上。如果每张地图各写一份铺地代码，"农场东口的路"和
## "村庄西口的路"迟早会长成两种东西；集中在这里之后，
## "主路永远是地图纵向中线上的三格宽路面"就成了一条改不掉的事实。
##
## 所有图案都由坐标算出，不用随机数：同一张地图每次进游戏长得一模一样。

## 路面风格。土路用于乡野，石板用于村镇。
enum Style {
	DIRT,   ## 夯土路：农场与海滩之间的乡道
	STONE,  ## 石板路：村镇里的街道与广场
}

## 草地低频噪声的格子尺度：约每 6 格换一片明暗/色相。
const PATCH_SCALE: int = 6
## 路缘起伏的格子尺度：约每 4 格抖一次。
const EDGE_SCALE: int = 4


## 铺满草地。
static func fill_grass(layer: TileMapLayer, area: Rect2i) -> void:
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, grass_variant(cell))


## 草地明暗：两种草皮按坐标交错，避免一整块纯色看起来像贴图没加载。
static func grass_variant(cell: Vector2i) -> Vector2i:
	var patch := _value_noise(cell.x, cell.y, PATCH_SCALE, 3)
	var detail := _hash01(cell.x, cell.y, 17)
	if patch < 0.15:
		return FarmAtlas.GRASS_DAPPLED
	if patch > 0.86:
		return FarmAtlas.GRASS_DRY
	if detail < 0.20:
		return FarmAtlas.GRASS_LUSH
	if detail > 0.82:
		return FarmAtlas.GRASS_MEADOW
	if detail < 0.5:
		return FarmAtlas.GRASS_ALT
	return FarmAtlas.GRASS


## 横向主路。[param center_row] 是路的中线，[param half_width] 是中线两侧各铺几格
## （0 = 一格宽，1 = 三格宽）。路面越过地图边缘不裁剪——地图外那格没人看得见。
static func horizontal_road(
	layer: TileMapLayer,
	x_start: int,
	x_end: int,
	center_row: int,
	half_width: int,
	style: Style = Style.STONE
) -> void:
	for x: int in range(x_start, x_end + 1):
		var span: Vector2i = road_span(half_width, x, 0)
		for offset: int in range(span.x, span.y + 1):
			_pave(layer, Vector2i(x, center_row + offset), offset, style)


## 纵向主路。[param center_column] 是路的中线。
static func vertical_road(
	layer: TileMapLayer,
	y_start: int,
	y_end: int,
	center_column: int,
	half_width: int,
	style: Style = Style.STONE
) -> void:
	for y: int in range(y_start, y_end + 1):
		var span: Vector2i = road_span(half_width, y, 2)
		for offset: int in range(span.x, span.y + 1):
			_pave(layer, Vector2i(center_column + offset, y), offset, style)


## 一格宽的土路（农舍门口这类小径）。
static func path(layer: TileMapLayer, cells: Array[Vector2i], atlas: Vector2i = FarmAtlas.PATH) -> void:
	for cell: Vector2i in cells:
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)


## 石板广场：底铺小石块、四角与中心点缀大石板，免得一大片地面太单调。
static func plaza(layer: TileMapLayer, area: Rect2i) -> void:
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		var atlas: Vector2i = FarmAtlas.PATH_STONE_ALT
		if (cell.x + cell.y * 2) % 5 == 0:
			atlas = FarmAtlas.PATH_STONE
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)


## 一片水：先铺深水，再在上沿铺一排水岸与浅滩。
##
## [param area] 是水面的格子范围；[param shore_rows] 是水面上沿要压几行浅水，
## 让"深水 → 浅滩 → 沙"这三段读起来是有坡度的岸，而不是一刀切。
static func water(layer: TileMapLayer, area: Rect2i, shore_rows: int = 1) -> void:
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.WATER)
	for row: int in shore_rows:
		for x: int in area.size.x:
			var cell := Vector2i(area.position.x + x, area.position.y + row)
			var atlas: Vector2i = FarmAtlas.WATER_EDGE if row == 0 else FarmAtlas.SHALLOW_WATER
			layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)


# ---------------------------------------------------------------- 内部

static func _pave(layer: TileMapLayer, cell: Vector2i, offset: int, style: Style) -> void:
	# 土路一律用 PATH：DIRT 属于"自然地表"，野生植被会长在上面（见
	# [code]FloraGrowth.NATURAL_GROUND[/code]），路面上冒树就不是路了。
	var atlas: Vector2i = FarmAtlas.PATH
	if style == Style.STONE:
		# 中线铺大石板、两侧铺小块石，街道因此有一条能看出来的走向。
		if offset == 0 or (cell.x + cell.y) % 4 == 0:
			atlas = FarmAtlas.PATH_STONE
		else:
			atlas = FarmAtlas.PATH_STONE_ALT
	layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)


# ---------------------------------------------------------------- 过渡与噪声

## 铺完地后调用：把每块基底的边界格换成对应 mask 的草缘瓦片。
##
## 用两遍（先算 mask 再写）而不是边走边改：第一遍读到的一定是真实基底，
## 不会把上一步刚换上的过渡瓦片误当成邻接材质。
static func transitions(layer: TileMapLayer, area: Rect2i) -> void:
	var pending: Dictionary = {}
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		var surface := FarmAtlas.surface_of(layer.get_cell_atlas_coords(cell))
		if surface == FarmAtlas.Surface.NONE:
			continue
		var mask: int = 0
		if _is_grass(layer, cell + Vector2i(0, -1)):
			mask |= AtlasLayout.TRANSITION_N
		if _is_grass(layer, cell + Vector2i(1, 0)):
			mask |= AtlasLayout.TRANSITION_E
		if _is_grass(layer, cell + Vector2i(0, 1)):
			mask |= AtlasLayout.TRANSITION_S
		if _is_grass(layer, cell + Vector2i(-1, 0)):
			mask |= AtlasLayout.TRANSITION_W
		if mask != 0:
			pending[cell] = FarmAtlas.transition_atlas(surface, mask)
	for cell: Vector2i in pending:
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, pending[cell])


static func _is_grass(layer: TileMapLayer, cell: Vector2i) -> bool:
	return FarmAtlas.is_grass_like(layer.get_cell_atlas_coords(cell))


## 路缘起伏：返回一段 [上/左, 下/右] 偏移范围。
##
## 每次只让一条路缘移动一格，因此三格宽的路只会在 2~4 格之间变化，
## 不会出现两条路缘同时外扩成五格、或同时内收成一格。
## 中心线（offset 0）永远保留；[param half_width] 为 0 时完全不抖动。
static func road_span(half_width: int, index: int, salt: int) -> Vector2i:
	if half_width <= 0:
		return Vector2i.ZERO
	var n := _value_noise(index, salt * 37, EDGE_SCALE, 53 + salt)
	var wobble: int = -1 if n < 0.30 else (1 if n > 0.72 else 0)
	if wobble == 0:
		return Vector2i(-half_width, half_width)
	# 用独立哈希决定这一次收放的是上/左缘还是下/右缘，避免整条路同步鼓包。
	if _hash01(index, salt, 97) < 0.5:
		return Vector2i(-half_width - wobble, half_width)
	return Vector2i(-half_width, half_width + wobble)


## 低频二维 value noise：格点哈希 + 平滑插值，用来选草地「片」。
static func _value_noise(x: int, y: int, scale: int, salt: int) -> float:
	var fx := float(x) / float(maxi(scale, 1))
	var fy := float(y) / float(maxi(scale, 1))
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var n00 := _hash01(x0, y0, salt)
	var n10 := _hash01(x0 + 1, y0, salt)
	var n01 := _hash01(x0, y0 + 1, salt)
	var n11 := _hash01(x0 + 1, y0 + 1, salt)
	return lerpf(lerpf(n00, n10, tx), lerpf(n01, n11, tx), ty)


## 整数坐标哈希 → 0.0~1.0。与 [code]tools/art/art_lib.gd[/code] 的 noise 同源思路，
## 但运行时代码不能依赖 tools/，所以在这里留一份最小实现。
static func _hash01(x: int, y: int, salt: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + salt * 69069
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0
