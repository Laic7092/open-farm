class_name ItemUse
extends RefCounted
## 手上道具的"用法"：工具之外还有一类可持有的东西，目前是种子。
##
## 工具的行为在 [Tool] 单元里，由 [FarmInteractor] 驱动；播种不属于工具——
## 它是"手机拿着一颗种子用一下"，因此规则放在这里：保持纯逻辑、可脱离世界单测。
##
## 只做两件事：向 [FarmGrid] 请求播种、成功后从背包扣掉一颗。
## 网格 / 背包 / 季节由调用方传入，本单元不读全局时钟、不碰界面。

## 把 [param seed_id] 种进 [param cell]；成功才扣道具。
##
## [FarmGrid.plant] 只管地里那一份状态、自己不消耗道具，所以"扣一颗"必须和
## "种下去"绑在同一处：种失败就不能扣，否则玩家会莫名掉种子。
static func plant_seed(
	grid: FarmGrid,
	inventory: Inventory,
	seed_id: StringName,
	cell: Vector2i,
	season: Season.Type
) -> bool:
	if grid == null or inventory == null or seed_id == &"":
		return false
	if not inventory.has(seed_id):
		return false
	if not grid.plant(cell, seed_id, season):
		return false
	inventory.remove(seed_id, 1)
	return true
