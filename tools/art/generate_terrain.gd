extends SceneTree
## 地形图集生成器 → [code]assets/sprites/tileset_farm.png[/code]
##
## 8 列 × 15 行、每格 16×16，坐标全部来自 [AtlasLayout]。
## 第 0 行的 8 格是骨架阶段就存在的坐标，[b]永远不能改[/b]——
## 已铺好的场景与旧存档都引用它们；新素材一律往后追加。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_terrain.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

## 过渡瓦片的基底材质。
enum Surface { PATH, STONE, SAND, DIRT }


func _initialize() -> void:
	var image := Art.new_image(Layout.TILESET_SIZE.x, Layout.TILESET_SIZE.y)

	# ---- 第 0 行（历史坐标，不得移动）
	_grass(image, Layout.GRASS, false)
	_grass(image, Layout.GRASS_ALT, true)
	_path(image, Layout.PATH)
	_soil(image, Layout.SOIL_DRY, false)
	_soil(image, Layout.SOIL_WET, true)
	_water(image, Layout.WATER)
	_stone(image, Layout.STONE)
	_wood_floor(image, Layout.WOOD)

	# ---- 第 1 行
	_flowers(image, Layout.FLOWERS, [P.FLOWER_PINK, P.FLOWER_YELLOW, P.FLOWER_WHITE])
	_fence(image, Layout.FENCE, false)
	_bush(image, Layout.BUSH)
	_sign(image, Layout.SIGN)
	_tall_grass(image, Layout.TALL_GRASS)
	_dirt(image, Layout.DIRT)
	_gravel(image, Layout.GRAVEL)
	_sand(image, Layout.SAND)

	# ---- 第 2 行
	_water_edge(image, Layout.WATER_EDGE)
	_path_stone(image, Layout.PATH_STONE)
	_roof(image, Layout.ROOF)
	_wall(image, Layout.WALL)
	_window(image, Layout.WINDOW)
	_doorway(image, Layout.DOORWAY)
	_fence(image, Layout.FENCE_GATE, true)
	_flower_bed(image, Layout.FLOWER_BED)

	# ---- 第 3 行
	_flowers(image, Layout.FLOWER_RED, [P.FLOWER_RED, P.FLOWER_RED, P.FLOWER_YELLOW])
	_flowers(image, Layout.FLOWER_BLUE, [P.FLOWER_BLUE, P.FLOWER_WHITE, P.FLOWER_BLUE])
	_mushroom(image, Layout.MUSHROOM)
	_pebbles(image, Layout.PEBBLE)
	_stump_tile(image, Layout.STUMP_TILE)
	_hay(image, Layout.HAY)
	_crate(image, Layout.CRATE)
	_well_top(image, Layout.WELL_TOP)

	# ---- 第 4 行（世界扩建时追加；前三行坐标永不改动）
	_shallow_water(image, Layout.SHALLOW_WATER)
	_path_stone_alt(image, Layout.PATH_STONE_ALT)
	_cliff(image, Layout.CLIFF)

	# ---- 第 5 行（自带正确底色的点缀：沙滩 / 砾石）
	_sand_pebble(image, Layout.SAND_PEBBLE)
	_gravel_ore(image, Layout.GRAVEL_ORE)

	# ---- 第 6~13 行：16 向草缘过渡块（每种基底 4×4）
	_transition_block(image, Layout.PATH_TRANSITION_BLOCK, Surface.PATH)
	_transition_block(image, Layout.STONE_TRANSITION_BLOCK, Surface.STONE)
	_transition_block(image, Layout.SAND_TRANSITION_BLOCK, Surface.SAND)
	_transition_block(image, Layout.DIRT_TRANSITION_BLOCK, Surface.DIRT)

	# ---- 第 14 行：草地变体
	_grass_lush(image, Layout.GRASS_LUSH)
	_grass_dry(image, Layout.GRASS_DRY)
	_grass_dappled(image, Layout.GRASS_DAPPLED)
	_grass_meadow(image, Layout.GRASS_MEADOW)

	Art.save_png(image, Layout.TILESET_PATH)
	print("地形图集生成完成（%d 格）" % (Layout.TILESET_COLUMNS * Layout.TILESET_ROWS))
	quit()


# ---------------------------------------------------------------- 通用地面

## 一格的左上角。
func _origin(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * Layout.TILE, cell.y * Layout.TILE)


func _cell_rect(cell: Vector2i) -> Rect2i:
	return Rect2i(_origin(cell), Vector2i(Layout.TILE, Layout.TILE))


## 先在整格铺一层"草地底"，装饰类瓦片都从这里开始。
func _grass_base(image: Image, cell: Vector2i, alternate: bool = false) -> void:
	_grass(image, cell, alternate)


func _grass(image: Image, cell: Vector2i, alternate: bool) -> void:
	var area := _cell_rect(cell)
	Art.rect(image, area, P.GRASS if not alternate else P.GRASS.lerp(P.GRASS_DARK, 0.25))
	Art.scatter(image, area, P.GRASS_DARK, 0.16, cell.x * 7 + cell.y)
	# 固定位置的草簇：不用随机，保证每次生成完全一致。
	var tufts: Array[Vector2i] = [Vector2i(2, 3), Vector2i(9, 5), Vector2i(5, 11), Vector2i(12, 12)]
	if alternate:
		tufts = [Vector2i(3, 2), Vector2i(11, 8), Vector2i(6, 6), Vector2i(13, 13)]
	var origin := _origin(cell)
	for tuft: Vector2i in tufts:
		var at := origin + tuft
		Art.px(image, at.x, at.y, P.GRASS_LIGHT)
		Art.px(image, at.x + 1, at.y, P.GRASS_LIGHT)
		Art.px(image, at.x + 1, at.y - 1, P.GRASS_LIGHT)


## 低矮茂密的草皮：更暗、草簇更多，用来做低频明暗片里的「暗片」。
func _grass_lush(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	var seed: int = cell.x * 17 + cell.y * 29
	Art.rect(image, area, P.GRASS.lerp(P.GRASS_DARK, 0.18))
	Art.scatter(image, area, P.GRASS_DARK, 0.26, seed)
	for at: Vector2i in [Vector2i(2, 4), Vector2i(6, 9), Vector2i(11, 5), Vector2i(13, 12)]:
		var p := origin + at
		Art.v_line(image, p.x, p.y - 3, 4, P.LEAF_DARK)
		Art.px(image, p.x, p.y - 4, P.LEAF)
		Art.px(image, p.x + 1, p.y - 4, P.GRASS_LIGHT)


## 发干的草皮：掺一点沙色，做低频明暗片里的「亮片」。
func _grass_dry(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	var seed: int = cell.x * 31 + cell.y * 7
	Art.rect(image, area, P.GRASS.lerp(P.SAND_DARK, 0.34))
	Art.scatter(image, area, P.SAND_DARK, 0.16, seed)
	Art.scatter(image, area, P.GRASS_LIGHT, 0.10, seed + 5)
	for at: Vector2i in [Vector2i(3, 6), Vector2i(9, 4), Vector2i(12, 11)]:
		var p := origin + at
		Art.px(image, p.x, p.y, P.PATH_LIGHT)
		Art.px(image, p.x + 1, p.y - 1, P.PATH_LIGHT)


## 斑驳草皮：在普通草上撒浅色小片，制造被云影 / 踩踏打破的色块。
func _grass_dappled(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	var seed: int = cell.x * 13 + cell.y * 23
	Art.rect(image, area, P.GRASS)
	Art.scatter(image, area, P.GRASS_DARK, 0.10, seed + 3)
	Art.scatter(image, area, P.GRASS_LIGHT, 0.26, seed)
	for at: Vector2i in [Vector2i(2, 3), Vector2i(7, 8), Vector2i(12, 5)]:
		Art.h_line(image, origin.x + at.x, origin.y + at.y, 3, P.GRASS_LIGHT)


## 带小野花的草甸，稀疏点缀，不喧宾夺主。
func _grass_meadow(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	var seed: int = cell.x * 19 + cell.y * 11
	Art.rect(image, area, P.GRASS.lerp(P.GRASS_DARK, 0.06))
	Art.scatter(image, area, P.GRASS_LIGHT, 0.12, seed)
	for at: Vector2i in [Vector2i(4, 6), Vector2i(11, 9)]:
		var p := origin + at
		Art.px(image, p.x, p.y - 1, P.FLOWER_WHITE)
		Art.px(image, p.x, p.y, P.FLOWER_YELLOW)
		Art.px(image, p.x, p.y + 1, P.LEAF_DARK)


func _path(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.PATH)
	Art.scatter(image, area, P.PATH_DARK, 0.22, 11 + cell.y)
	Art.scatter(image, area, P.PATH_LIGHT, 0.10, 23 + cell.y)
	for at: Vector2i in [Vector2i(3, 4), Vector2i(10, 9), Vector2i(6, 13)]:
		Art.px(image, origin.x + at.x, origin.y + at.y, P.PATH_DARK)
		Art.px(image, origin.x + at.x + 1, origin.y + at.y, P.PATH_DARK)


func _dirt(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.DIRT)
	Art.scatter(image, area, P.DIRT_DARK, 0.24, 31 + cell.x)
	Art.scatter(image, area, P.SAND, 0.08, 47 + cell.y)
	Art.h_line(image, origin.x + 2, origin.y + 5, 5, P.DIRT_DARK)
	Art.h_line(image, origin.x + 9, origin.y + 11, 5, P.DIRT_DARK)


func _gravel(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.GRAVEL)
	Art.scatter(image, area, P.GRAVEL_DARK, 0.30, 59)
	Art.scatter(image, area, P.STONE_LIGHT, 0.14, 67)
	for at: Vector2i in [Vector2i(2, 2), Vector2i(11, 5), Vector2i(5, 12), Vector2i(13, 10)]:
		Art.px(image, origin.x + at.x, origin.y + at.y, P.STONE_LIGHT)


func _sand(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.SAND)
	Art.scatter(image, area, P.SAND_DARK, 0.18, 71)
	Art.h_line(image, origin.x + 3, origin.y + 6, 4, P.SAND_DARK)
	Art.h_line(image, origin.x + 10, origin.y + 11, 3, P.SAND_DARK)


func _soil(image: Image, cell: Vector2i, watered: bool) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	var base: Color = P.SOIL_WET if watered else P.SOIL
	var dark: Color = P.SOIL_WET_DARK if watered else P.SOIL_DARK
	var light: Color = P.SOIL_WET_LIGHT if watered else P.SOIL_LIGHT
	Art.rect(image, area, base)
	Art.scatter(image, area, dark, 0.14, 149 + (1 if watered else 0))
	# 三道垄：每道"上缘高光 + 下缘阴影"，读起来是被翻过的土而不是木箱。
	for ridge: int in 3:
		var y: int = origin.y + 1 + ridge * 5
		Art.h_line(image, origin.x + 1, y, Layout.TILE - 2, light)
		Art.h_line(image, origin.x + 1, y + 3, Layout.TILE - 2, dark)
		Art.h_line(image, origin.x + 3, y + 1, 4, dark)
		Art.h_line(image, origin.x + 10, y + 1, 4, dark)
	if watered:
		# 湿土上补两点水光，一眼看出"刚浇过"。
		Art.px(image, origin.x + 4, origin.y + 6, P.WATER_LIGHT)
		Art.px(image, origin.x + 11, origin.y + 11, P.WATER_LIGHT)
		Art.px(image, origin.x + 7, origin.y + 14, P.WATER_LIGHT)


func _water(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.WATER)
	Art.h_line(image, origin.x, origin.y + 3, Layout.TILE, P.WATER_DARK)
	Art.h_line(image, origin.x, origin.y + 10, Layout.TILE, P.WATER_DARK)
	# 波光：短线 + 单点，避免大面积规律感。
	for at: Vector2i in [Vector2i(2, 5), Vector2i(9, 7), Vector2i(5, 12), Vector2i(12, 13)]:
		Art.bar(image, origin.x + at.x, origin.y + at.y, 4, P.WATER_LIGHT)
	Art.px(image, origin.x + 6, origin.y + 1, P.WATER_FOAM)
	Art.px(image, origin.x + 13, origin.y + 8, P.WATER_FOAM)


func _water_edge(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	# 上 2/3 是水，下 1/3 是沙滩 + 浪花。
	Art.rect(image, Rect2i(origin.x, origin.y, Layout.TILE, 10), P.WATER)
	Art.rect(image, Rect2i(origin.x, origin.y + 10, Layout.TILE, 6), P.SAND)
	Art.scatter(image, Rect2i(origin.x, origin.y + 10, Layout.TILE, 6), P.SAND_DARK, 0.2, 83)
	Art.h_line(image, origin.x, origin.y + 9, Layout.TILE, P.WATER_DARK)
	Art.h_line(image, origin.x, origin.y + 10, Layout.TILE, P.WATER_FOAM)
	Art.px(image, origin.x + 4, origin.y + 5, P.WATER_LIGHT)
	Art.px(image, origin.x + 11, origin.y + 3, P.WATER_LIGHT)


## 浅水：水与沙滩之间的过渡带，颜色比深水亮一档，浪线更密。
func _shallow_water(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.WATER.lerp(P.SAND, 0.28))
	Art.scatter(image, area, P.WATER_LIGHT, 0.18, 191)
	# 三道横向浪线：越靠下越密，读起来像退去的浪。
	Art.h_line(image, origin.x + 1, origin.y + 4, 6, P.WATER_FOAM)
	Art.h_line(image, origin.x + 9, origin.y + 7, 6, P.WATER_FOAM)
	Art.h_line(image, origin.x + 3, origin.y + 11, 8, P.WATER_LIGHT)
	Art.px(image, origin.x + 13, origin.y + 2, P.WATER_FOAM)
	Art.px(image, origin.x + 2, origin.y + 14, P.WATER_FOAM)


## 石板路的第二版：把石块错位并缩小，与大块石板交替铺出广场的质感。
func _path_stone_alt(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.PATH_DARK)
	# 交错的两行小石块。
	for row: int in 2:
		var y: int = origin.y + 2 + row * 8
		var offset: int = 0 if row % 2 == 0 else 3
		var x: int = origin.x + 1 + offset
		while x + 5 <= origin.x + Layout.TILE:
			Art.rect(image, Rect2i(x, y, 5, 5), P.GRAVEL)
			Art.h_line(image, x, y, 5, P.STONE_LIGHT)
			Art.px(image, x + 4, y + 4, P.GRAVEL_DARK)
			x += 7
	Art.scatter(image, area, P.GRAVEL_DARK, 0.1, 199)


## 岩壁：矿洞 / 海边的封边。3/4 读法 = 上缘受光 + 檐口阴影 + 向下的层理。
func _cliff(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.STONE_DARK)
	Art.scatter(image, area, P.STONE, 0.20, 211)
	# 顶面：一条亮边 + 下一格石色，像能看到崖顶。
	Art.h_line(image, origin.x, origin.y, Layout.TILE, P.STONE_LIGHT)
	Art.h_line(image, origin.x, origin.y + 1, Layout.TILE, P.STONE)
	# 檐口阴影：把顶面和下面的岩壁分开。
	Art.h_line(image, origin.x, origin.y + 3, Layout.TILE, P.OUTLINE)
	# 底部往暗里收，读起来像凹进去的洞壁。
	Art.h_line(image, origin.x, origin.y + Layout.TILE - 1, Layout.TILE, P.OUTLINE)
	# 竖向层理 + 两条错开的裂纹，避免大片岩石变成纯色块。
	for x: int in [4, 9, 13]:
		Art.v_line(image, origin.x + x, origin.y + 5, 7, P.STONE_DARK)
		Art.px(image, origin.x + x, origin.y + 5, P.STONE)
	Art.v_line(image, origin.x + 6, origin.y + 9, 5, P.OUTLINE)
	Art.v_line(image, origin.x + 11, origin.y + 5, 3, P.OUTLINE)
	Art.px(image, origin.x + 7, origin.y + 4, P.STONE_LIGHT)
	Art.px(image, origin.x + 13, origin.y + 12, P.STONE_LIGHT)


func _stone(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.STONE)
	# 2×2 的圆角砖块，缝隙用深色，上沿给高光。
	for block: int in 4:
		var bx: int = origin.x + 1 + (block % 2) * 8
		var by: int = origin.y + 1 + (block / 2) * 8
		Art.rect(image, Rect2i(bx, by, 6, 6), P.STONE)
		Art.h_line(image, bx, by, 6, P.STONE_LIGHT)
		Art.v_line(image, bx, by, 6, P.STONE_LIGHT)
		Art.px(image, bx + 4, by + 4, P.STONE_DARK)
	Art.scatter(image, area, P.STONE_DARK, 0.08, 97)


func _wood_floor(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.PLANK)
	Art.stripes(image, area, P.WOOD_DARK, 5, 0)
	Art.stripes(image, area, P.WOOD_LIGHT, 5, 1)
	# 错位的竖向接缝，像铺过的地板而不是横条纹。
	Art.v_line(image, origin.x + 5, origin.y + 1, 4, P.WOOD_DARK)
	Art.v_line(image, origin.x + 12, origin.y + 6, 4, P.WOOD_DARK)
	Art.v_line(image, origin.x + 3, origin.y + 11, 4, P.WOOD_DARK)


func _path_stone(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.PATH)
	Art.rect(image, Rect2i(origin.x, origin.y, Layout.TILE, Layout.TILE), P.PATH_DARK)
	for stone: Vector2i in [Vector2i(1, 1), Vector2i(9, 1), Vector2i(1, 9), Vector2i(9, 9)]:
		Art.rect(image, Rect2i(origin.x + stone.x, origin.y + stone.y, 6, 6), P.GRAVEL)
		Art.h_line(image, origin.x + stone.x, origin.y + stone.y, 6, P.STONE_LIGHT)
		Art.v_line(image, origin.x + stone.x, origin.y + stone.y, 6, P.STONE_LIGHT)
		Art.px(image, origin.x + stone.x + 5, origin.y + stone.y + 5, P.GRAVEL_DARK)


# ---------------------------------------------------------------- 过渡瓦片

## 画一块 4×4 的过渡矩阵：每个 mask 先把基底材质完整画一遍，
## 再按 mask 在对应边压上参差的草缘。
func _transition_block(image: Image, block: Vector2i, surface: int) -> void:
	for mask: int in 16:
		var cell := Layout.transition_cell(block, mask)
		_base_material(image, cell, surface)
		if mask != 0:
			_grass_fringe(image, cell, mask)


## 过渡瓦片的底色 = 对应的普通地表。
func _base_material(image: Image, cell: Vector2i, surface: int) -> void:
	if surface == Surface.PATH:
		_path(image, cell)
	elif surface == Surface.STONE:
		_path_stone(image, cell)
	elif surface == Surface.SAND:
		_sand(image, cell)
	else:
		_dirt(image, cell)


## 在 [param mask] 指定的边压草缘；草缘厚度 2~4px 且沿边参差。
func _grass_fringe(image: Image, cell: Vector2i, mask: int) -> void:
	var origin := _origin(cell)
	var seed: int = cell.x * 73 + cell.y * 131
	if (mask & Layout.TRANSITION_N) != 0:
		_draw_fringe(image, origin, seed, 0)
	if (mask & Layout.TRANSITION_E) != 0:
		_draw_fringe(image, origin, seed, 1)
	if (mask & Layout.TRANSITION_S) != 0:
		_draw_fringe(image, origin, seed, 2)
	if (mask & Layout.TRANSITION_W) != 0:
		_draw_fringe(image, origin, seed, 3)
	_draw_blades(image, origin, seed, mask)


## [param side]：0=N / 1=E / 2=S / 3=W。
func _draw_fringe(image: Image, origin: Vector2i, seed: int, side: int) -> void:
	for i: int in Layout.TILE:
		var thickness := _fringe_thickness(origin, i, side, seed)
		for d: int in thickness:
			var at := _fringe_cell(origin, i, d, side)
			# 靠内一像素压深色，草缘与铺地之间有一条「根线」，边缘才不发灰。
			Art.px(image, at.x, at.y, P.GRASS_DARK if d == thickness - 1 else P.GRASS)
	# 草缘内侧再补一像素浅色，让厚度有起伏。
	var lip := _fringe_cell(origin, 4, 0, side)
	Art.px(image, lip.x, lip.y, P.GRASS_LIGHT)
	lip = _fringe_cell(origin, 11, 0, side)
	Art.px(image, lip.x, lip.y, P.GRASS_LIGHT)


## 草缘厚度：2~4px，由坐标哈希决定，保证确定性。
func _fringe_thickness(origin: Vector2i, index: int, side: int, seed: int) -> int:
	var a: int = origin.x + index
	var b: int = origin.y
	if side == 1:
		a = origin.y + index
		b = origin.x + 1
	elif side == 2:
		b = origin.y + 2
	elif side == 3:
		a = origin.y + index
		b = origin.x + 3
	return 2 + int(Art.noise(a, b, seed) * 3.0)


## 侧边上的第 [param d] 像素（d=0 最靠外）。
func _fringe_cell(origin: Vector2i, index: int, d: int, side: int) -> Vector2i:
	if side == 0:
		return origin + Vector2i(index, d)
	if side == 1:
		return origin + Vector2i(Layout.TILE - 1 - d, index)
	if side == 2:
		return origin + Vector2i(index, Layout.TILE - 1 - d)
	return origin + Vector2i(d, index)


## 从草缘向铺地伸出几根草叶；用 1~2px 的短线，避免变成锯齿。
func _draw_blades(image: Image, origin: Vector2i, seed: int, mask: int) -> void:
	for k: int in 3:
		var index := 2 + int((seed + k * 7) % 12)
		if (mask & Layout.TRANSITION_N) != 0:
			_side_blade(image, origin, index, seed, 0, k)
		if (mask & Layout.TRANSITION_E) != 0:
			_side_blade(image, origin, index, seed, 1, k)
		if (mask & Layout.TRANSITION_S) != 0:
			_side_blade(image, origin, index, seed, 2, k)
		if (mask & Layout.TRANSITION_W) != 0:
			_side_blade(image, origin, index, seed, 3, k)


func _side_blade(image: Image, origin: Vector2i, index: int, seed: int, side: int, k: int) -> void:
	var thickness := _fringe_thickness(origin, index, side, seed)
	var length := 2 + int(Art.noise(origin.x + k, origin.y + side, seed + 61) * 2.0)
	var color: Color = P.LEAF if k % 2 == 0 else P.LEAF_DARK
	if side == 0:
		Art.v_line(image, origin.x + index, origin.y + thickness, length, color)
		Art.px(image, origin.x + index, origin.y + thickness + length, P.LEAF_LIGHT)
	elif side == 1:
		Art.h_line(
			image, origin.x + Layout.TILE - 1 - thickness - length,
			origin.y + index, length, color
		)
		Art.px(image, origin.x + Layout.TILE - 1 - thickness - length, origin.y + index, P.LEAF_LIGHT)
	elif side == 2:
		Art.v_line(
			image, origin.x + index,
			origin.y + Layout.TILE - 1 - thickness - length, length, color
		)
		Art.px(image, origin.x + index, origin.y + Layout.TILE - 1 - thickness - length, P.LEAF_LIGHT)
	else:
		Art.h_line(image, origin.x + thickness, origin.y + index, length, color)
		Art.px(image, origin.x + thickness + length, origin.y + index, P.LEAF_LIGHT)


# ---------------------------------------------------------------- 植被与装饰

func _flowers(image: Image, cell: Vector2i, colors: Array) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	var spots: Array[Vector2i] = [Vector2i(3, 4), Vector2i(10, 3), Vector2i(6, 10)]
	for index: int in spots.size():
		_flower(image, origin + spots[index], colors[index % colors.size()])


func _flower(image: Image, at: Vector2i, color: Color) -> void:
	# 十字花冠 + 黄色花心 + 一截花茎。
	Art.px(image, at.x, at.y - 1, color)
	Art.px(image, at.x - 1, at.y, color)
	Art.px(image, at.x + 1, at.y, color)
	Art.px(image, at.x, at.y + 1, color)
	Art.px(image, at.x, at.y, P.FLOWER_YELLOW)
	Art.px(image, at.x, at.y + 2, P.LEAF_DARK)


func _tall_grass(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.GRASS.lerp(P.GRASS_DARK, 0.5))
	Art.scatter(image, area, P.GRASS_DARK, 0.2, 101)
	for blade: Vector2i in [
		Vector2i(2, 12), Vector2i(4, 10), Vector2i(6, 13), Vector2i(9, 11), Vector2i(12, 13)
	]:
		var at := origin + blade
		Art.v_line(image, at.x, at.y - 4, 5, P.LEAF_DARK)
		Art.v_line(image, at.x + 1, at.y - 6, 7, P.LEAF)
		Art.px(image, at.x + 1, at.y - 7, P.LEAF_LIGHT)


func _bush(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, false)
	var origin := _origin(cell)
	# 三块错位的椭圆拼出灌木轮廓，比一整块方形自然。
	Art.ellipse(image, origin + Vector2i(6, 10), Vector2i(5, 4), P.LEAF_DARK)
	Art.ellipse(image, origin + Vector2i(11, 10), Vector2i(4, 4), P.LEAF_DARK)
	Art.ellipse(image, origin + Vector2i(5, 9), Vector2i(4, 3), P.LEAF)
	Art.ellipse(image, origin + Vector2i(10, 9), Vector2i(3, 3), P.LEAF)
	Art.h_line(image, origin.x + 4, origin.y + 7, 4, P.LEAF_LIGHT)
	Art.px(image, origin.x + 5, origin.y + 9, P.FRUIT_RED)
	Art.px(image, origin.x + 10, origin.y + 10, P.FRUIT_RED)
	Art.px(image, origin.x + 11, origin.y + 8, P.FLOWER_WHITE)


func _fence(image: Image, cell: Vector2i, with_gate: bool) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	# 地面投影：栅栏不是贴纸，柱脚要落在草上。
	Art.h_line(image, origin.x + 1, origin.y + 14, 14, P.GRASS_DARK)
	if with_gate:
		# 门框：左右立柱 + 两道横档，顶面提亮、正面木色、底面压暗。
		for x: int in [1, 11]:
			Art.rect(image, Rect2i(origin.x + x, origin.y + 5, 3, 10), P.WOOD_DARK)
			Art.h_line(image, origin.x + x, origin.y + 5, 3, P.WOOD_LIGHT)
			Art.v_line(image, origin.x + x, origin.y + 6, 9, P.WOOD_DARK)
		for y: int in [5, 11]:
			Art.rect(image, Rect2i(origin.x + 4, origin.y + y + 1, 7, 1), P.WOOD_DARK)
			Art.rect(image, Rect2i(origin.x + 4, origin.y + y, 7, 1), P.WOOD_LIGHT)
		return
	# 实心栅栏：两根柱子一前一后，两道横杆各带顶面高光。
	for post_x: int in [2, 10]:
		var post: Color = P.WOOD if post_x == 2 else P.WOOD_DARK
		Art.rect(image, Rect2i(origin.x + post_x, origin.y + 2, 3, 12), post)
		Art.h_line(image, origin.x + post_x, origin.y + 2, 3, P.WOOD_LIGHT)
		Art.v_line(image, origin.x + post_x + 2, origin.y + 3, 11, P.WOOD_DARK)
	for rail_y: int in [5, 10]:
		Art.rect(image, Rect2i(origin.x + 1, origin.y + rail_y + 1, 14, 2), P.WOOD_DARK)
		Art.rect(image, Rect2i(origin.x + 1, origin.y + rail_y, 14, 2), P.WOOD)
		Art.h_line(image, origin.x + 1, origin.y + rail_y, 14, P.WOOD_LIGHT)


func _sign(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	Art.rect(image, Rect2i(origin.x + 7, origin.y + 8, 2, 7), P.WOOD_DARK)
	Art.rect(image, Rect2i(origin.x + 2, origin.y + 3, 12, 8), P.WOOD)
	Art.frame_rect(image, Rect2i(origin.x + 2, origin.y + 3, 12, 8), P.WOOD_DARK)
	Art.h_line(image, origin.x + 4, origin.y + 6, 8, P.WOOD_DARK)
	Art.h_line(image, origin.x + 4, origin.y + 8, 5, P.WOOD_DARK)


func _mushroom(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, false)
	var origin := _origin(cell)
	for at: Vector2i in [Vector2i(4, 10), Vector2i(10, 12)]:
		var p := origin + at
		Art.rect(image, Rect2i(p.x, p.y - 3, 2, 4), P.MUSHROOM_STEM)
		Art.rect(image, Rect2i(p.x - 2, p.y - 5, 6, 3), P.MUSHROOM_CAP)
		Art.px(image, p.x - 1, p.y - 4, P.WHITE)
		Art.px(image, p.x + 2, p.y - 4, P.WHITE)


## 沙地上的点缀：几颗卵石与一枚贝壳。底色是沙，不是草。
func _sand_pebble(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.SAND)
	Art.scatter(image, area, P.SAND_DARK, 0.16, 223)
	Art.ellipse(image, origin + Vector2i(5, 9), Vector2i(3, 2), P.STONE_DARK)
	Art.ellipse(image, origin + Vector2i(5, 8), Vector2i(2, 1), P.STONE)
	Art.ellipse(image, origin + Vector2i(11, 5), Vector2i(2, 1), P.SAND_DARK)
	# 贝壳：三片扇形。
	Art.px(image, origin.x + 11, origin.y + 11, P.FLOWER_WHITE)
	Art.h_line(image, origin.x + 9, origin.y + 12, 4, P.FLOWER_WHITE)
	Art.px(image, origin.x + 10, origin.y + 10, P.SAND_DARK)
	Art.px(image, origin.x + 12, origin.y + 10, P.SAND_DARK)


## 砾石上的点缀：矿脉碎屑，给矿洞一点"这里挖得出东西"的暗示。
func _gravel_ore(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.GRAVEL)
	Art.scatter(image, area, P.GRAVEL_DARK, 0.26, 227)
	for at: Vector2i in [Vector2i(4, 5), Vector2i(9, 11), Vector2i(12, 3)]:
		Art.rect(image, Rect2i(origin.x + at.x, origin.y + at.y, 2, 2), P.COIN_DARK)
		Art.px(image, origin.x + at.x, origin.y + at.y, P.COIN)
	Art.px(image, origin.x + 6, origin.y + 12, P.STONE_LIGHT)
	Art.px(image, origin.x + 13, origin.y + 8, P.STONE_LIGHT)


func _pebbles(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	for at: Vector2i in [Vector2i(3, 5), Vector2i(10, 5), Vector2i(6, 11)]:
		var p := origin + at
		Art.ellipse(image, p, Vector2i(2, 1), P.STONE)
		Art.px(image, p.x - 1, p.y - 1, P.STONE_LIGHT)
		Art.px(image, p.x + 1, p.y + 1, P.STONE_DARK)


func _stump_tile(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, false)
	var origin := _origin(cell)
	var center := origin + Vector2i(8, 9)
	Art.ellipse(image, center, Vector2i(5, 4), P.TRUNK_DARK)
	Art.ellipse(image, center - Vector2i(0, 1), Vector2i(4, 3), P.TRUNK)
	Art.ellipse(image, center - Vector2i(0, 1), Vector2i(2, 1), P.WOOD_LIGHT)


func _hay(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	Art.rect(image, Rect2i(origin.x + 2, origin.y + 5, 12, 7), P.FLOWER_YELLOW)
	Art.frame_rect(image, Rect2i(origin.x + 2, origin.y + 5, 12, 7), P.COIN_DARK)
	Art.h_line(image, origin.x + 2, origin.y + 8, 12, P.COIN_DARK)


func _crate(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, false)
	var origin := _origin(cell)
	Art.rect(image, Rect2i(origin.x + 2, origin.y + 4, 12, 10), P.WOOD)
	Art.frame_rect(image, Rect2i(origin.x + 2, origin.y + 4, 12, 10), P.WOOD_DARK)
	Art.h_line(image, origin.x + 2, origin.y + 6, 12, P.WOOD_LIGHT)
	Art.h_line(image, origin.x + 3, origin.y + 9, 10, P.WOOD_DARK)
	Art.v_line(image, origin.x + 7, origin.y + 5, 8, P.WOOD_DARK)


func _well_top(image: Image, cell: Vector2i) -> void:
	_grass_base(image, cell, true)
	var origin := _origin(cell)
	Art.ellipse(image, origin + Vector2i(8, 9), Vector2i(7, 5), P.STONE_DARK)
	Art.ellipse(image, origin + Vector2i(8, 8), Vector2i(6, 4), P.STONE)
	Art.ellipse(image, origin + Vector2i(8, 8), Vector2i(4, 2), P.WATER_DARK)
	Art.ellipse(image, origin + Vector2i(8, 8), Vector2i(2, 1), P.WATER_LIGHT)


# ---------------------------------------------------------------- 建筑构件

func _roof(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.ROOF)
	for row: int in 4:
		var y: int = origin.y + row * 4
		Art.h_line(image, origin.x, y, Layout.TILE, P.ROOF_LIGHT)
		Art.h_line(image, origin.x, y + 3, Layout.TILE, P.ROOF_DARK)
		# 交错竖缝：奇数行偏移 4 像素，读起来像瓦片。
		var offset: int = 0 if row % 2 == 0 else 4
		var x: int = origin.x + offset
		while x < origin.x + Layout.TILE:
			Art.v_line(image, x, y, 3, P.ROOF_DARK)
			x += 8


func _wall(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.WALL)
	Art.scatter(image, area, P.WALL_DARK, 0.12, 131)
	Art.h_line(image, origin.x, origin.y, Layout.TILE, P.WALL_LIGHT)
	# 木筋（半木结构），让白墙不至于太空。
	Art.rect(image, Rect2i(origin.x, origin.y + Layout.TILE - 3, Layout.TILE, 3), P.WOOD_DARK)
	Art.v_line(image, origin.x + 2, origin.y, 5, P.WOOD_DARK)
	Art.v_line(image, origin.x + 13, origin.y + 7, 6, P.WOOD_DARK)


func _window(image: Image, cell: Vector2i) -> void:
	_wall(image, cell)
	var origin := _origin(cell)
	var glass := Rect2i(origin.x + 3, origin.y + 3, 10, 9)
	Art.rect(image, glass, P.GLASS_DARK)
	Art.rect(image, Rect2i(glass.position.x + 1, glass.position.y + 1, 8, 7), P.GLASS)
	Art.h_line(image, glass.position.x + 1, glass.position.y + 1, 8, P.WATER_FOAM)
	Art.frame_rect(image, glass, P.WOOD_DARK)
	Art.v_line(image, origin.x + 8, glass.position.y, glass.size.y, P.WOOD_DARK)


func _doorway(image: Image, cell: Vector2i) -> void:
	_wall(image, cell)
	var origin := _origin(cell)
	var door := Rect2i(origin.x + 3, origin.y + 3, 10, 13)
	Art.rect(image, door, P.WOOD)
	Art.frame_rect(image, door, P.WOOD_DARK)
	Art.v_line(image, origin.x + 8, door.position.y + 1, 11, P.WOOD_DARK)
	Art.px(image, origin.x + 5, origin.y + 9, P.COIN)
	Art.px(image, origin.x + 11, origin.y + 9, P.COIN)
	Art.h_line(image, origin.x + 4, origin.y + 3, 8, P.WOOD_LIGHT)


func _flower_bed(image: Image, cell: Vector2i) -> void:
	var area := _cell_rect(cell)
	var origin := _origin(cell)
	Art.rect(image, area, P.SOIL)
	Art.frame_rect(image, area, P.WOOD_DARK)
	_flower(image, origin + Vector2i(4, 5), P.FLOWER_PINK)
	_flower(image, origin + Vector2i(9, 4), P.FLOWER_YELLOW)
	_flower(image, origin + Vector2i(6, 10), P.FLOWER_BLUE)
	_flower(image, origin + Vector2i(12, 11), P.FLOWER_WHITE)
