class_name FarmAtlas
extends RefCounted
## 地形图集坐标的运行时别名。
##
## 真正的定义在 [AtlasLayout]——那里是[b]生成器与运行时代码共用[/b]的唯一事实来源。
## 这个类只是把常用格子再导出一次，让 [code]FarmGrid[/code] / [code]TownGround[/code]
## 里写 [code]FarmAtlas.GRASS[/code] 比 [code]AtlasLayout.GRASS[/code] 更贴近语境。
##
## [b]规范[/b]：不要在别处再写死坐标；需要新格子时先加到 [AtlasLayout]，
## 在这里补一行别名，然后跑 [code]./tools/build_assets.sh[/code]。

## TileSet 中唯一图集源的下标。
const SOURCE_ID: int = 0

# ---- 基础地表
const GRASS := AtlasLayout.GRASS
const GRASS_ALT := AtlasLayout.GRASS_ALT
const GRASS_LUSH := AtlasLayout.GRASS_LUSH
const GRASS_DRY := AtlasLayout.GRASS_DRY
const GRASS_DAPPLED := AtlasLayout.GRASS_DAPPLED
const GRASS_MEADOW := AtlasLayout.GRASS_MEADOW
const PATH := AtlasLayout.PATH
const SOIL_DRY := AtlasLayout.SOIL_DRY
const SOIL_WET := AtlasLayout.SOIL_WET

# ---- 水与石木
const WATER := AtlasLayout.WATER
const WATER_EDGE := AtlasLayout.WATER_EDGE
const SHALLOW_WATER := AtlasLayout.SHALLOW_WATER

## 这一格图集坐标是否属于水面（深水 / 水岸 / 浅滩）。
## 钓鱼的"面前是不是水"完全由它判定，因此水面瓦片只有这三种。
static func is_water(atlas: Vector2i) -> bool:
	return atlas == WATER or atlas == WATER_EDGE or atlas == SHALLOW_WATER
const STONE := AtlasLayout.STONE
const CLIFF := AtlasLayout.CLIFF
const WOOD := AtlasLayout.WOOD
const PATH_STONE := AtlasLayout.PATH_STONE
const PATH_STONE_ALT := AtlasLayout.PATH_STONE_ALT
const GRAVEL := AtlasLayout.GRAVEL
const SAND := AtlasLayout.SAND
const DIRT := AtlasLayout.DIRT

# ---- 植被与装饰
const FLOWERS := AtlasLayout.FLOWERS
const FLOWER_RED := AtlasLayout.FLOWER_RED
const FLOWER_BLUE := AtlasLayout.FLOWER_BLUE
const FLOWER_BED := AtlasLayout.FLOWER_BED
const BUSH := AtlasLayout.BUSH
const TALL_GRASS := AtlasLayout.TALL_GRASS
const MUSHROOM := AtlasLayout.MUSHROOM
const PEBBLE := AtlasLayout.PEBBLE
const SAND_PEBBLE := AtlasLayout.SAND_PEBBLE
const GRAVEL_ORE := AtlasLayout.GRAVEL_ORE
const STUMP_TILE := AtlasLayout.STUMP_TILE
const HAY := AtlasLayout.HAY
const CRATE := AtlasLayout.CRATE

# ---- 人造物
const FENCE := AtlasLayout.FENCE
const FENCE_GATE := AtlasLayout.FENCE_GATE
const SIGN := AtlasLayout.SIGN
const WELL_TOP := AtlasLayout.WELL_TOP
const ROOF := AtlasLayout.ROOF
const WALL := AtlasLayout.WALL
const WINDOW := AtlasLayout.WINDOW
const DOORWAY := AtlasLayout.DOORWAY


# ---------------------------------------------------------------- 地表过渡

## 可被草缘替换的基底材质；见 [AtlasLayout] 的过渡块。
enum Surface { NONE, PATH, STONE, SAND, DIRT }

const PATH_TRANSITION_BLOCK := AtlasLayout.PATH_TRANSITION_BLOCK
const STONE_TRANSITION_BLOCK := AtlasLayout.STONE_TRANSITION_BLOCK
const SAND_TRANSITION_BLOCK := AtlasLayout.SAND_TRANSITION_BLOCK
const DIRT_TRANSITION_BLOCK := AtlasLayout.DIRT_TRANSITION_BLOCK


## 这块地表属于哪一种可过渡基底；不是基底返回 [constant Surface.NONE]。
static func surface_of(atlas: Vector2i) -> int:
	if atlas == PATH:
		return Surface.PATH
	if atlas == PATH_STONE or atlas == PATH_STONE_ALT:
		return Surface.STONE
	if atlas == SAND:
		return Surface.SAND
	if atlas == DIRT:
		return Surface.DIRT
	return Surface.NONE


static func transition_block(surface: int) -> Vector2i:
	if surface == Surface.PATH:
		return PATH_TRANSITION_BLOCK
	if surface == Surface.STONE:
		return STONE_TRANSITION_BLOCK
	if surface == Surface.SAND:
		return SAND_TRANSITION_BLOCK
	if surface == Surface.DIRT:
		return DIRT_TRANSITION_BLOCK
	return Vector2i(-1, -1)


## 某种基底在 [param mask]（位见 AtlasLayout.TRANSITION_N/E/S/W）下的过渡瓦片。
static func transition_atlas(surface: int, mask: int) -> Vector2i:
	var block := transition_block(surface)
	if block.x < 0:
		return Vector2i(-1, -1)
	return AtlasLayout.transition_cell(block, mask)


## 这一格是不是某种基底的过渡瓦片。野生植被白名单用它把沙/土过渡格也算回自然地表。
static func is_transition_of(surface: int, atlas: Vector2i) -> bool:
	var block := transition_block(surface)
	if block.x < 0:
		return false
	var local := atlas - block
	return local.x >= 0 and local.x < 4 and local.y >= 0 and local.y < 4


## 在草缘判定里，哪些瓦片的底色是草地。
##
## 装饰瓦片（花 / 灌木 / 栅栏）自带草底，所以它们旁边同样应该有草缘；
## 花圃 / 干草 / 木箱则属于「人摆过的东西」，不算草地。
const GRASS_LIKE: Array[Vector2i] = [
	GRASS, GRASS_ALT, GRASS_LUSH, GRASS_DRY, GRASS_DAPPLED, GRASS_MEADOW,
	TALL_GRASS, PEBBLE, FLOWERS, FLOWER_RED, FLOWER_BLUE, MUSHROOM,
	BUSH, SIGN, FENCE, FENCE_GATE,
]


static func is_grass_like(atlas: Vector2i) -> bool:
	return GRASS_LIKE.has(atlas)
