class_name TileCollision
extends RefCounted
## TileMap 里结构瓦片的碰撞策略。
##
## 花、蘑菇、栅栏、牌子等装饰已改由 [DecorPainter] 生成 [WorldProp]，
## 碰撞写在 `DecorPainter.SOLID_SIZES`；这里只为仍留在 TileMap 里的
## 崖壁、墙面、门窗以及历史遗留装饰瓦片生成物理层。
##
## 规则：绝大多数实心瓦片默认挡人；只有牧草这类低矮地被、以及打开的门 /
## 栅栏门这类功能性通道，才显式列进 [constant PASSABLE_TILES]。

## 生成 TileSet 碰撞多边形的实心装饰 / 建筑瓦片。
const SOLID_TILES: Array[Vector2i] = [
	FarmAtlas.BUSH,
	FarmAtlas.SIGN,
	FarmAtlas.FENCE,
	FarmAtlas.WELL_TOP,
	FarmAtlas.STUMP_TILE,
	FarmAtlas.CRATE,
	FarmAtlas.FLOWER_BED,
	FarmAtlas.HAY,
	FarmAtlas.ROOF,
	FarmAtlas.WALL,
	FarmAtlas.WINDOW,
	FarmAtlas.CLIFF,
]

## 明确可穿过的低矮地被与功能性通道。
const PASSABLE_TILES: Array[Vector2i] = [
	FarmAtlas.TALL_GRASS,
	FarmAtlas.FLOWERS,
	FarmAtlas.FLOWER_RED,
	FarmAtlas.FLOWER_BLUE,
	FarmAtlas.MUSHROOM,
	FarmAtlas.PEBBLE,
	FarmAtlas.SAND_PEBBLE,
	FarmAtlas.FENCE_GATE,
	FarmAtlas.DOORWAY,
]


## 这块装饰瓦片是否应当生成碰撞。
static func is_solid(atlas: Vector2i) -> bool:
	return SOLID_TILES.has(atlas)
