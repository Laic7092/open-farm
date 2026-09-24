class_name GroundPainter
extends RefCounted
## 户外地图铺地的公共手法：草地、主路与小径。
##
## 水面不在这里：它是一条闭合曲线 + 烘出来的贴图（见 [WaterLayout] /
## [WaterField]），因为瓦片拼不出圆润的岸线。
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

## 草地色块连贯性判断用的四邻方向。
const PATCH_NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]


## 铺满草地。
##
## 先用低频噪声算出每格的草皮，再看一眼四邻去掉孤格，最后才写进图层：
## 深/浅草皮必须是「片」，单格墨绿会像噪点而不是第二层草。
static func fill_grass(layer: TileMapLayer, area: Rect2i) -> void:
	var cells := GridUtils.cells_in_area(area.position, area.size)
	var variants: Dictionary = {}
	for cell: Vector2i in cells:
		variants[cell] = grass_variant(cell)
	_cohere_grass_patches(variants)
	for cell: Vector2i in cells:
		layer.set_cell(cell, FarmAtlas.SOURCE_ID, variants[cell])


## 草地明暗：低频噪声决定大片深色/亮色，高频细节决定普通草里的形态。
##
## 普通草和亮草都带一层向右下错开的深色根层（见 generate_terrain.gd），
## 所以相邻格拼起来时仍是一整片草，不会在格边出现描边。
static func grass_variant(cell: Vector2i) -> Vector2i:
	var patch := _value_noise(cell.x, cell.y, PATCH_SCALE, 3)
	if patch < 0.28:
		return FarmAtlas.GRASS_LUSH
	if patch > 0.76:
		return FarmAtlas.GRASS_DRY
	return _grass_detail_variant(cell)


## 不参与大片明暗的普通草细节变体。
static func _grass_detail_variant(cell: Vector2i) -> Vector2i:
	var detail := _hash01(cell.x, cell.y, 17)
	if detail < 0.20:
		return FarmAtlas.GRASS_DAPPLED
	if detail > 0.82:
		return FarmAtlas.GRASS_MEADOW
	if detail < 0.5:
		return FarmAtlas.GRASS_ALT
	return FarmAtlas.GRASS


## 检查深/亮草块是否成片：没有同色四邻的孤格退回普通草细节。
##
## 做替换时先收集再统一写回，和 [method transitions] 的两遍做法一致，
## 避免把刚换上的普通草误当成邻居继续传播。
static func _cohere_grass_patches(variants: Dictionary) -> void:
	var replacements: Dictionary = {}
	for cell: Vector2i in variants:
		var atlas: Vector2i = variants[cell]
		if not _is_extreme_grass(atlas):
			continue
		var same := 0
		for offset: Vector2i in PATCH_NEIGHBOR_OFFSETS:
			if variants.get(cell + offset) == atlas:
				same += 1
		if same == 0:
			replacements[cell] = _grass_detail_variant(cell)
	for cell: Vector2i in replacements:
		variants[cell] = replacements[cell]


## 是否是需要成片出现的大明暗草块。
static func _is_extreme_grass(atlas: Vector2i) -> bool:
	return atlas == FarmAtlas.GRASS_LUSH or atlas == FarmAtlas.GRASS_DRY


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


# ---------------------------------------------------------------- 内部

static func _pave(layer: TileMapLayer, cell: Vector2i, offset: int, style: Style) -> void:
	# 土路一律用 PATH：DIRT 属于"自然地表"，野生植被会长在上面（见
	# FloraGrowth.NATURAL_GROUND），路面上冒树就不是路了。
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
##
## 深/浅草过渡与草+泥土同理，只是“基底”是深草、“草缘”是浅草，
## 并且写进 source 1；判定邻居时只认浅草，两块深草之间不会互相压边。
static func transitions(layer: TileMapLayer, area: Rect2i) -> void:
	var pending: Dictionary = {}
	for cell: Vector2i in GridUtils.cells_in_area(area.position, area.size):
		var surface := FarmAtlas.surface_of(layer.get_cell_atlas_coords(cell))
		if surface == FarmAtlas.Surface.NONE:
			continue
		var mask: int = 0
		if _has_fringe_neighbor(layer, cell + Vector2i(0, -1), surface):
			mask |= AtlasLayout.TRANSITION_N
		if _has_fringe_neighbor(layer, cell + Vector2i(1, 0), surface):
			mask |= AtlasLayout.TRANSITION_E
		if _has_fringe_neighbor(layer, cell + Vector2i(0, 1), surface):
			mask |= AtlasLayout.TRANSITION_S
		if _has_fringe_neighbor(layer, cell + Vector2i(-1, 0), surface):
			mask |= AtlasLayout.TRANSITION_W
		if mask != 0:
			var atlas := FarmAtlas.transition_atlas(surface, mask)
			var source := FarmAtlas.transition_source(surface)
			pending[cell] = Vector3i(source, atlas.x, atlas.y)
	for cell: Vector2i in pending:
		var tile: Vector3i = pending[cell]
		layer.set_cell(cell, tile.x, Vector2i(tile.y, tile.z))


## 这一格的邻居是否会让 [param surface] 在对应边压草缘。
##
## 普通基底：任何草地都算；深草基底：只有浅草算，深草之间保持连续。
static func _has_fringe_neighbor(
	layer: TileMapLayer,
	cell: Vector2i,
	surface: int
) -> bool:
	var atlas := layer.get_cell_atlas_coords(cell)
	if surface == FarmAtlas.Surface.GRASS_DARK:
		return FarmAtlas.is_light_grass(atlas)
	return FarmAtlas.is_grass_like(atlas)


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
