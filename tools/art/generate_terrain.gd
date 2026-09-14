extends SceneTree
## 地形图集生成器 → [code]assets/sprites/tileset_farm.png[/code]
##
## 8 列 × 4 行、每格 16×16，坐标全部来自 [AtlasLayout]。
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
	if with_gate:
		Art.rect(image, Rect2i(origin.x + 1, origin.y + 4, 14, 2), P.WOOD_DARK)
		Art.rect(image, Rect2i(origin.x + 1, origin.y + 10, 14, 2), P.WOOD_DARK)
		Art.rect(image, Rect2i(origin.x + 3, origin.y + 2, 2, 12), P.WOOD)
		return
	Art.rect(image, Rect2i(origin.x + 1, origin.y + 4, 14, 2), P.WOOD)
	Art.rect(image, Rect2i(origin.x + 1, origin.y + 9, 14, 2), P.WOOD)
	Art.h_line(image, origin.x + 1, origin.y + 4, 14, P.WOOD_LIGHT)
	Art.rect(image, Rect2i(origin.x + 3, origin.y + 2, 3, 12), P.WOOD_DARK)
	Art.rect(image, Rect2i(origin.x + 10, origin.y + 2, 3, 12), P.WOOD_DARK)
	Art.h_line(image, origin.x + 3, origin.y + 2, 3, P.WOOD)


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
