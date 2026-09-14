class_name FarmAtlas
extends RefCounted
## [code]assets/sprites/tileset_farm.png[/code] 的图集坐标常量。
##
## 把"魔法数字"集中在常量里，TileSet 的排版变化只需要改这一个文件。
## 由 [code]tools/generate_placeholder_art.gd[/code] 保证图集与这些常量一致。

## TileSet 中唯一图集源的下标。
const SOURCE_ID: int = 0

const GRASS := Vector2i(0, 0)
const GRASS_ALT := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const SOIL_DRY := Vector2i(3, 0)
const SOIL_WET := Vector2i(4, 0)
const WATER := Vector2i(5, 0)
const STONE := Vector2i(6, 0)
const WOOD := Vector2i(7, 0)
const FLOWERS := Vector2i(0, 1)
const FENCE := Vector2i(1, 1)
const BUSH := Vector2i(2, 1)
const SIGN := Vector2i(3, 1)
