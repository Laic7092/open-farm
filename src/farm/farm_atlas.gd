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
const PATH := AtlasLayout.PATH
const SOIL_DRY := AtlasLayout.SOIL_DRY
const SOIL_WET := AtlasLayout.SOIL_WET

# ---- 水与石木
const WATER := AtlasLayout.WATER
const WATER_EDGE := AtlasLayout.WATER_EDGE
const STONE := AtlasLayout.STONE
const WOOD := AtlasLayout.WOOD
const PATH_STONE := AtlasLayout.PATH_STONE
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
