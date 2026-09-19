extends SceneTree
## 野生植被生成器 → [code]assets/sprites/flora/*.png[/code]
##
## 每种野生植物一张[b]阶段表[/b]：固定 [constant AtlasLayout.FLORA_COLUMNS] 列，
## 用不到的列留空。运行时 [Flora] 只做 [code]frame = stage_of(...)[/code]，
## 不需要知道"这种草有几个阶段"。
##
## 树苗 → 小树 → 成树 → 老树是[b]同一套参数化画法[/b]逐级放大，
## 而不是四张各画各的图：这样调整"树的形状"只用改一处。
##
## 规范（见 AGENTS.md）：颜色只来自调色板、坐标只来自 AtlasLayout、
## 禁止 RandomNumberGenerator（质感一律用 [code]Art.noise[/code] 的坐标哈希），
## 保证连跑两次得到逐像素相同的结果。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_flora.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")
const SeasonPalette := preload("res://src/art/season_palette.gd")
const SeasonExport := preload("res://tools/art/season_export.gd")

const DIR: String = "res://assets/sprites/flora"

## 全部要导出的植被 id。
const IDS: Array[String] = [
	"tree_oak", "tree_pine", "weed", "rock", "boulder", "flower", "mushroom",
	"copper_ore", "iron_ore", "gold_ore",
]

## 有叶子的植被 id：为它们额外出季节变体。
## [b]新增带叶子的植被时记得把它加进来[/b]，否则冬季会残留绿色。
const SEASONAL_IDS: Array[String] = ["tree_oak", "tree_pine", "weed"]

## 树干高度 / 宽度随阶段增长（树苗 → 老树）。
const TREE_TRUNK_HEIGHTS: Array[int] = [7, 13, 19, 22]
const TREE_TRUNK_WIDTHS: Array[int] = [3, 4, 6, 7]
## 树冠半径随阶段增长。
const TREE_CANOPY_RADII: Array[int] = [4, 6, 8, 9]

## 当前这一遍在画哪个季节的叶色。
var _season: Season.Type = SeasonPalette.BASE_SEASON


func _initialize() -> void:
	for flora_id: String in IDS:
		var path := _path(flora_id)
		if SEASONAL_IDS.has(flora_id):
			SeasonExport.write(path, _build_for.bind(flora_id))
		else:
			Art.save_png(_build_for(SeasonPalette.BASE_SEASON, flora_id), path)
	print("野生植被生成完成 → ", DIR)
	quit()


func _path(flora_id: String) -> String:
	return DIR.path_join("%s.png" % flora_id)


## 当前这一遍在画哪个季节的材质三色。
func _mat(name: StringName) -> PackedColorArray:
	return SeasonPalette.material(_season, name)


## 把某个季节的某个植被画一遍；[code]SeasonExport.write[/code] 把 flora_id 绑在 season 后面。
func _build_for(season: Season.Type, flora_id: String) -> Image:
	_season = season
	return _build(flora_id)


## 单个植被 id 的阶段表；基础一遍与季节一遍共用它。
func _build(flora_id: String) -> Image:
	match flora_id:
		"tree_oak":
			return _sheet(Layout.FLORA_TREE_CELL, _tree_stages(0))
		"tree_pine":
			return _sheet(Layout.FLORA_TREE_CELL, _tree_stages(1))
		"weed":
			return _sheet(Layout.FLORA_SMALL_CELL, [_weed(0), _weed(1), _weed(2)])
		"boulder":
			return _sheet(Layout.FLORA_ROCK_CELL, [_rock_big()])
		"flower":
			return _sheet(Layout.FLORA_SMALL_CELL, [_flower(0), _flower(1)])
		"mushroom":
			return _sheet(Layout.FLORA_SMALL_CELL, [_mushroom()])
		"copper_ore":
			return _sheet(Layout.FLORA_SMALL_CELL, [_ore(P.COPPER_DARK, P.COPPER, P.COPPER_LIGHT)])
		"iron_ore":
			return _sheet(Layout.FLORA_SMALL_CELL, [_ore(P.IRON_DARK, P.IRON, P.IRON_LIGHT)])
		"gold_ore":
			return _sheet(Layout.FLORA_SMALL_CELL, [_ore(P.GOLD_DARK, P.GOLD, P.GOLD_LIGHT)])
		_:
			return _sheet(Layout.FLORA_SMALL_CELL, [_rock_small()])


## 把若干张"一格一张"的图按列拼成阶段表。
func _sheet(cell: Vector2i, stages: Array) -> Image:
	var image := Art.new_image(Layout.FLORA_COLUMNS * cell.x, cell.y)
	for index: int in mini(stages.size(), Layout.FLORA_COLUMNS):
		var stage: Image = stages[index] as Image
		if stage != null:
			Art.blit(image, stage, Vector2i(index * cell.x, 0))
	return image


# ---------------------------------------------------------------- 树

## 一棵树的四个阶段。变体 0 阔叶、变体 1 松树。
func _tree_stages(variant: int) -> Array[Image]:
	var stages: Array[Image] = []
	for level: int in Layout.FLORA_COLUMNS:
		stages.append(_tree_stage(variant, level))
	return stages


func _tree_stage(variant: int, level: int) -> Image:
	var image := Art.new_image(Layout.FLORA_TREE_CELL.x, Layout.FLORA_TREE_CELL.y)
	Art.ground_shadow(image, Layout.FLORA_TREE_CELL.x, Layout.FLORA_TREE_CELL.y, 8)

	# 树干：随阶段变高变粗，底边永远贴着格子底部。
	var trunk_height: int = TREE_TRUNK_HEIGHTS[level]
	var trunk_width: int = TREE_TRUNK_WIDTHS[level]
	var top: int = 46 - trunk_height
	var left: int = 16 - trunk_width / 2
	Art.rect(image, Rect2i(left, top, trunk_width, trunk_height), P.TRUNK)
	Art.v_line(image, left, top, trunk_height, P.TRUNK_DARK)
	Art.v_line(image, left + trunk_width - 1, top, trunk_height, P.WOOD_LIGHT)
	# 根部：往两边各伸一像素，让树"站得住"。
	Art.h_line(image, left - 1, 46, trunk_width + 2, P.TRUNK_DARK)

	if variant == 1:
		_pine_canopy(image, top, level)
	else:
		_oak_canopy(image, top, level)

	Art.outline(image)
	return image


## 阔叶树：三团错位的树冠，越大越饱满，成树后挂果。
func _oak_canopy(image: Image, top: int, level: int) -> void:
	var radius: int = TREE_CANOPY_RADII[level]
	var center_y: int = top - radius + 2
	var big := Vector2i(radius, radius)
	var inner := Vector2i(maxi(radius - 2, 1), maxi(radius - 2, 1))
	var leaf := _mat(&"leaf")
	Art.ellipse(image, Vector2i(11, center_y + 2), big, leaf[1])
	Art.ellipse(image, Vector2i(21, center_y + 1), big, leaf[1])
	Art.ellipse(image, Vector2i(16, center_y - 2), big, leaf[1])
	Art.ellipse(image, Vector2i(11, center_y + 2), inner, leaf[0])
	Art.ellipse(image, Vector2i(21, center_y + 1), inner, leaf[0])
	Art.ellipse(image, Vector2i(16, center_y - 2), inner, leaf[0])
	Art.ellipse(image, Vector2i(14, center_y - 5), Vector2i(4, 2), leaf[2])
	if level >= 2:
		Art.px(image, 10, center_y, P.FRUIT_RED)
		Art.px(image, 22, center_y - 1, P.FRUIT_RED)


## 松树：一层比一层小的三角，越大层数越多。
func _pine_canopy(image: Image, top: int, level: int) -> void:
	var leaf := _mat(&"leaf")
	var layers: int = level + 1
	var layer_height: int = 7 + level
	var widest: int = 7 + level * 3
	for layer: int in layers:
		var bottom: int = top + 2 - layer * (layer_height - 2)
		var half: int = maxi(widest - layer * 3, 2)
		for row: int in layer_height:
			var t := float(row) / float(maxi(layer_height - 1, 1))
			var width: int = maxi(int(round(lerpf(1.0, float(half) * 2.0, t))), 1)
			var row_y: int = bottom - layer_height + 1 + row
			var color: Color = leaf[1] if (row / 3) % 2 == 0 else leaf[0]
			Art.h_line(image, 16 - width / 2, row_y, width, color)
		Art.h_line(image, 16 - half, bottom, half * 2, leaf[1])
	Art.v_line(image, 15, top - 4, 4, leaf[2])


# ---------------------------------------------------------------- 杂草

## 0 = 刚冒头，1 = 长成，2 = 抽穗。
func _weed(stage: int) -> Image:
	var cell := Layout.FLORA_SMALL_CELL
	var image := Art.new_image(cell.x, cell.y)
	var leaf := _mat(&"leaf")
	Art.ground_shadow(image, cell.x, cell.y, 4)
	if stage == 0:
		Art.v_line(image, 8, 9, 4, leaf[0])
		Art.px(image, 7, 9, leaf[1])
		Art.px(image, 9, 10, leaf[1])
		Art.px(image, 8, 8, leaf[2])
	else:
		for blade: int in 3:
			var x: int = 5 + blade * 3
			var height: int = 8 + (blade % 2) * 2
			var top: int = 14 - height
			Art.v_line(image, x, top, height, leaf[0])
			Art.px(image, x - 1, top + 1, leaf[1])
			Art.px(image, x + 1, top + 2, leaf[1])
			Art.px(image, x, top, leaf[2])
		if stage >= 2:
			# 抽穗：顶上几粒种子，一眼能看出"该割了"。
			Art.px(image, 8, 4, P.SEED_BROWN)
			Art.px(image, 7, 5, P.SEED_BROWN)
			Art.px(image, 9, 5, P.SEED_BROWN)
			Art.px(image, 8, 3, leaf[2])
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 石头

func _rock_small() -> Image:
	var cell := Layout.FLORA_SMALL_CELL
	var image := Art.new_image(cell.x, cell.y)
	Art.ground_shadow(image, cell.x, cell.y, 3)
	Art.ellipse(image, Vector2i(8, 11), Vector2i(6, 4), P.STONE_DARK)
	Art.ellipse(image, Vector2i(8, 10), Vector2i(5, 4), P.STONE)
	Art.ellipse(image, Vector2i(6, 8), Vector2i(2, 1), P.STONE_LIGHT)
	Art.outline(image)
	return image


## 矿石：石头底 + 金属矿脉。
func _ore(dark: Color, base: Color, light: Color) -> Image:
	var cell := Layout.FLORA_SMALL_CELL
	var image := Art.new_image(cell.x, cell.y)
	Art.ground_shadow(image, cell.x, cell.y, 3)
	Art.ellipse(image, Vector2i(8, 11), Vector2i(6, 4), P.STONE_DARK)
	Art.ellipse(image, Vector2i(8, 10), Vector2i(5, 4), P.STONE)
	Art.ellipse(image, Vector2i(7, 9), Vector2i(3, 2), base)
	Art.ellipse(image, Vector2i(9, 11), Vector2i(2, 1), dark)
	Art.ellipse(image, Vector2i(6, 8), Vector2i(1, 1), light)
	Art.outline(image)
	return image


func _rock_big() -> Image:
	var cell := Layout.FLORA_ROCK_CELL
	var image := Art.new_image(cell.x, cell.y)
	Art.ground_shadow(image, cell.x, cell.y, 4)
	var center := Vector2i(15, 15)
	var radius := Vector2i(11, 8)
	Art.ellipse(image, center, radius, P.STONE_DARK)
	Art.ellipse(image, center - Vector2i(0, 1), radius - Vector2i(1, 1), P.STONE)
	# 顶上加两块小凸起：没有它，光靠一个椭圆会平得像张饼。
	Art.ellipse(image, Vector2i(11, 7), Vector2i(5, 3), P.STONE)
	Art.ellipse(image, Vector2i(22, 10), Vector2i(4, 3), P.STONE)
	Art.ellipse(image, Vector2i(10, 10), Vector2i(4, 3), P.STONE_LIGHT)
	Art.ellipse(image, Vector2i(21, 12), Vector2i(2, 2), P.STONE_LIGHT)
	Art.h_line(image, 6, 20, 6, P.STONE_DARK)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 野花与蘑菇

## 0 = 花苞，1 = 盛开。
func _flower(stage: int) -> Image:
	var cell := Layout.FLORA_SMALL_CELL
	var image := Art.new_image(cell.x, cell.y)
	Art.ground_shadow(image, cell.x, cell.y, 4)
	Art.v_line(image, 8, 8, 6, P.LEAF_DARK)
	Art.px(image, 6, 11, P.LEAF)
	Art.px(image, 10, 10, P.LEAF)
	if stage == 0:
		Art.px(image, 8, 7, P.FLOWER_PINK)
		Art.px(image, 7, 8, P.FLOWER_PINK)
		Art.px(image, 9, 8, P.FLOWER_PINK)
	else:
		Art.circle(image, Vector2i(8, 6), 3, P.FLOWER_PINK)
		Art.px(image, 8, 6, P.FLOWER_YELLOW)
		Art.px(image, 8, 5, P.FLOWER_WHITE)
	Art.outline(image)
	return image


func _mushroom() -> Image:
	var cell := Layout.FLORA_SMALL_CELL
	var image := Art.new_image(cell.x, cell.y)
	Art.ground_shadow(image, cell.x, cell.y, 4)
	Art.rect(image, Rect2i(7, 9, 3, 5), P.MUSHROOM_STEM)
	Art.ellipse(image, Vector2i(8, 8), Vector2i(6, 4), P.MUSHROOM_CAP)
	Art.ellipse(image, Vector2i(8, 6), Vector2i(5, 3), P.MUSHROOM_CAP)
	Art.px(image, 6, 6, P.WHITE)
	Art.px(image, 10, 7, P.WHITE)
	Art.px(image, 8, 5, P.WHITE)
	Art.outline(image)
	return image
