extends SceneTree
## 牲畜贴图生成器 → [code]assets/sprites/animals/<id>.png[/code]
##
## 每张图固定 [constant AtlasLayout.ANIMAL_COLUMNS] 列 × 16 像素：
## 列 0 = 幼崽、列 1 = 成年、列 2 = 成年且有产出可收。
## [code]tools/generate_sample_data.gd[/code] 会把图挂到对应 [AnimalData] 上。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_animals.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/animals"


func _initialize() -> void:
	Art.save_png(_sheet(_chicken), DIR.path_join("chicken.png"))
	Art.save_png(_sheet(_cow), DIR.path_join("cow.png"))
	print("牲畜贴图生成完成 → ", DIR)
	quit()


## 用同一套函数逐列画出一张表。
func _sheet(draw: Callable) -> Image:
	var cell: int = Layout.ANIMAL_CELL
	var image := Art.new_image(cell * Layout.ANIMAL_COLUMNS, cell)
	for column: int in Layout.ANIMAL_COLUMNS:
		draw.call(image, column)
	return image


# ---------------------------------------------------------------- 鸡

func _chicken(image: Image, column: int) -> void:
	var o := Vector2i(column * Layout.ANIMAL_CELL, 0)
	if column == 0:
		# 幼鸡：更小、更黄，还没有鸡冠。
		Art.ellipse(image, o + Vector2i(7, 10), Vector2i(4, 3), P.ANIMAL_CHICK)
		Art.ellipse(image, o + Vector2i(10, 7), Vector2i(2, 2), P.ANIMAL_CHICK)
		Art.px(image, o.x + 12, o.y + 7, P.FRUIT_ORANGE)
		Art.px(image, o.x + 10, o.y + 6, P.OUTLINE)
		Art.px(image, o.x + 6, o.y + 13, P.FRUIT_ORANGE)
		Art.px(image, o.x + 8, o.y + 13, P.FRUIT_ORANGE)
	else:
		Art.ellipse(image, o + Vector2i(7, 10), Vector2i(5, 4), P.WHITE)
		Art.ellipse(image, o + Vector2i(10, 6), Vector2i(3, 3), P.WHITE)
		# 鸡冠
		Art.px(image, o.x + 9, o.y + 3, P.FRUIT_RED)
		Art.px(image, o.x + 10, o.y + 2, P.FRUIT_RED)
		Art.px(image, o.x + 11, o.y + 3, P.FRUIT_RED)
		# 喙与眼
		Art.rect(image, Rect2i(o.x + 12, o.y + 6, 2, 1), P.FRUIT_ORANGE)
		Art.px(image, o.x + 11, o.y + 5, P.OUTLINE)
		# 尾羽
		Art.px(image, o.x + 2, o.y + 6, P.WHITE)
		Art.px(image, o.x + 1, o.y + 7, P.WHITE)
		# 腿
		Art.rect(image, Rect2i(o.x + 6, o.y + 13, 1, 2), P.FRUIT_ORANGE)
		Art.rect(image, Rect2i(o.x + 9, o.y + 13, 1, 2), P.FRUIT_ORANGE)
		if column == 2:
			# 身边一颗蛋
			Art.ellipse(image, o + Vector2i(13, 12), Vector2i(2, 2), P.WHITE)
	Art.outline(image, P.OUTLINE)


# ---------------------------------------------------------------- 奶牛

func _cow(image: Image, column: int) -> void:
	var o := Vector2i(column * Layout.ANIMAL_CELL, 0)
	if column == 0:
		# 犊牛：小一圈，斑也小。
		Art.ellipse(image, o + Vector2i(8, 10), Vector2i(5, 3), P.ANIMAL_HIDE)
		Art.ellipse(image, o + Vector2i(11, 7), Vector2i(2, 2), P.ANIMAL_HIDE)
		Art.ellipse(image, o + Vector2i(6, 10), Vector2i(1, 1), P.ANIMAL_SPOT)
		Art.px(image, o.x + 13, o.y + 7, P.ANIMAL_SNOUT)
		Art.px(image, o.x + 12, o.y + 6, P.OUTLINE)
		Art.px(image, o.x + 6, o.y + 13, P.ANIMAL_HOOF)
		Art.px(image, o.x + 9, o.y + 13, P.ANIMAL_HOOF)
	else:
		# 成牛：躯干 + 头 + 黑斑 + 角 + 四条腿。
		Art.ellipse(image, o + Vector2i(7, 9), Vector2i(6, 4), P.ANIMAL_HIDE)
		Art.ellipse(image, o + Vector2i(11, 6), Vector2i(3, 3), P.ANIMAL_HIDE)
		Art.ellipse(image, o + Vector2i(4, 9), Vector2i(2, 2), P.ANIMAL_SPOT)
		Art.ellipse(image, o + Vector2i(8, 7), Vector2i(1, 1), P.ANIMAL_SPOT)
		# 角与耳
		Art.px(image, o.x + 9, o.y + 3, P.SAND)
		Art.px(image, o.x + 13, o.y + 3, P.SAND)
		# 口鼻与眼
		Art.ellipse(image, o + Vector2i(13, 7), Vector2i(1, 1), P.ANIMAL_SNOUT)
		Art.px(image, o.x + 12, o.y + 5, P.OUTLINE)
		# 腿
		Art.rect(image, Rect2i(o.x + 4, o.y + 12, 1, 2), P.ANIMAL_HIDE)
		Art.rect(image, Rect2i(o.x + 9, o.y + 12, 1, 2), P.ANIMAL_HIDE)
		Art.px(image, o.x + 4, o.y + 14, P.ANIMAL_HOOF)
		Art.px(image, o.x + 9, o.y + 14, P.ANIMAL_HOOF)
		if column == 2:
			# 身旁一只奶桶
			Art.rect(image, Rect2i(o.x + 13, o.y + 10, 3, 4), P.STONE_LIGHT)
			Art.rect(image, Rect2i(o.x + 14, o.y + 9, 1, 1), P.STONE)
	Art.outline(image, P.OUTLINE)
