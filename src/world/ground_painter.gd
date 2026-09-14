class_name GroundPainter
extends RefCounted
## 户外地图铺地的公共手法：草地、主路、小径、水面与点缀。
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


## 铺满草地。
static func fill_grass(layer: TileMapLayer, area: Rect2i) -> void:
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, grass_variant(cell))


## 草地明暗：两种草皮按坐标交错，避免一整块纯色看起来像贴图没加载。
static func grass_variant(cell: Vector2i) -> Vector2i:
	if (cell.x * 5 + cell.y * 3) % 9 < 4:
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
		for offset: int in range(-half_width, half_width + 1):
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
		for offset: int in range(-half_width, half_width + 1):
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


## 按表撒装饰：[code]{ Vector2i 格子: Vector2i 图集坐标 }[/code]。
## 越界或落在 [param skip] 里的格子自动跳过，于是表格可以写得宽松一些。
static func decorate(
	layer: TileMapLayer, tiles: Dictionary, area: Rect2i, skip: Array[Vector2i] = []
) -> void:
	for cell: Variant in tiles:
		var at: Vector2i = cell
		if not area.has_point(at) or skip.has(at):
			continue
		layer.set_cell(at, FarmAtlas.SOURCE_ID, tiles[at])


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
