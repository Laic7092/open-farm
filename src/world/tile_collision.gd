class_name TileCollision
extends RefCounted
## TileMap 里剩下的实心地形。
##
## 图集只放地板（见 [AtlasLayout]）：装饰是 [DecorPainter] 生成的 [WorldProp]，
## 室内墙面是 [InteriorWalls] 自带的 [StaticBody2D]，两者都不再走 TileSet 物理层。
## 于是这里只剩崖壁这一种"本身就挡人的地形"。

## 生成 TileSet 碰撞多边形的实心瓦片。
const SOLID_TILES: Array[Vector2i] = [
	FarmAtlas.CLIFF,
]


## 这块瓦片是否应当生成碰撞。
static func is_solid(atlas: Vector2i) -> bool:
	return SOLID_TILES.has(atlas)
