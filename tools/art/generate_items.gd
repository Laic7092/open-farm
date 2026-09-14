extends SceneTree
## 道具图标生成器 → [code]assets/sprites/items/<item_id>.png[/code]（16×16）
##
## 每个道具一张独立小图，由 [code]tools/generate_sample_data.gd[/code]
## 写进对应 [ItemData] 的 [code]icon[/code] 字段。
## 于是背包 / 商店 / 手持提示都能显示图标，而不只是文字。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_items.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/items"


func _initialize() -> void:
	Art.save_png(_turnip(), _path("turnip"))
	Art.save_png(_packet(&"turnip"), _path("turnip_seed"))
	Art.save_png(_potato(), _path("potato"))
	Art.save_png(_packet(&"potato"), _path("potato_seed"))
	Art.save_png(_tomato(), _path("tomato"))
	Art.save_png(_packet(&"tomato"), _path("tomato_seed"))
	Art.save_png(_tool_hoe(), _path("hoe"))
	Art.save_png(_tool_axe(), _path("axe"))
	Art.save_png(_tool_pickaxe(), _path("pickaxe"))
	Art.save_png(_watering_can(), _path("watering_can"))
	Art.save_png(_sickle(), _path("sickle"))
	Art.save_png(_wood(), _path("wood"))
	Art.save_png(_stone(), _path("stone"))
	Art.save_png(_fiber(), _path("fiber"))
	Art.save_png(_flower(), _path("flower"))
	Art.save_png(_mushroom(), _path("mushroom"))
	Art.save_png(_seed_bag(), _path("seed_bag"))
	Art.save_png(_egg(), _path("egg"))
	Art.save_png(_milk(), _path("milk"))
	Art.save_png(_hay(), _path("hay"))
	Art.save_png(_chicken_icon(), _path("chicken"))
	Art.save_png(_cow_icon(), _path("cow"))
	print("道具图标生成完成 → ", DIR)
	quit()


func _path(item_id: String) -> String:
	return DIR.path_join("%s.png" % item_id)


func _blank() -> Image:
	return Art.new_image(Layout.ITEM_ICON_SIZE.x, Layout.ITEM_ICON_SIZE.y)


# ---------------------------------------------------------------- 收获物

func _turnip() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(8, 10), Vector2i(5, 4), P.APRON)
	Art.ellipse(image, Vector2i(8, 11), Vector2i(4, 3), P.WHITE)
	Art.h_line(image, 5, 8, 2, P.WALL_DARK)
	Art.px(image, 8, 13, P.WALL_DARK)
	# 顶上的叶子
	Art.v_line(image, 8, 3, 4, P.LEAF_DARK)
	Art.px(image, 6, 3, P.LEAF)
	Art.px(image, 5, 2, P.LEAF)
	Art.px(image, 10, 3, P.LEAF)
	Art.px(image, 11, 2, P.LEAF)
	Art.px(image, 8, 2, P.LEAF_LIGHT)
	Art.outline(image)
	return image


func _potato() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(8, 9), Vector2i(5, 4), P.SOIL_LIGHT)
	Art.ellipse(image, Vector2i(7, 8), Vector2i(3, 2), P.PATH)
	Art.px(image, 5, 9, P.SOIL_DARK)
	Art.px(image, 9, 6, P.SOIL_DARK)
	Art.px(image, 10, 11, P.SOIL_DARK)
	Art.px(image, 6, 12, P.SOIL_DARK)
	Art.h_line(image, 6, 5, 3, P.SAND)
	Art.outline(image)
	return image


func _tomato() -> Image:
	var image := _blank()
	Art.circle(image, Vector2i(8, 9), 5, P.ROOF_DARK)
	Art.circle(image, Vector2i(8, 9), 4, P.FRUIT_RED)
	Art.ellipse(image, Vector2i(6, 7), Vector2i(2, 1), P.FLOWER_PINK)
	# 蒂
	Art.h_line(image, 6, 4, 5, P.LEAF_DARK)
	Art.px(image, 8, 3, P.LEAF)
	Art.px(image, 5, 3, P.LEAF)
	Art.px(image, 11, 3, P.LEAF)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 种子袋

## 种子包：一个纸袋 + 中间的作物小图。
func _packet(crop_id: StringName) -> Image:
	var image := _blank()
	var accent: Color = {
		&"turnip": P.APRON,
		&"potato": P.SOIL_LIGHT,
		&"tomato": P.FRUIT_RED,
	}.get(crop_id, P.SEED_BROWN)

	Art.rect(image, Rect2i(3, 4, 10, 10), P.PATH)
	Art.frame_rect(image, Rect2i(3, 4, 10, 10), P.PATH_DARK)
	Art.h_line(image, 4, 4, 8, P.PATH_LIGHT)
	# 袋口的折边
	Art.rect(image, Rect2i(3, 4, 10, 2), P.PATH_LIGHT)
	Art.rect(image, Rect2i(3, 5, 10, 1), P.PATH_DARK)
	# 中间的作物标识
	Art.ellipse(image, Vector2i(8, 10), Vector2i(3, 3), accent)
	if crop_id == &"tomato":
		Art.h_line(image, 6, 7, 5, P.LEAF_DARK)
	elif crop_id == &"turnip":
		Art.px(image, 8, 6, P.LEAF)
		Art.px(image, 7, 6, P.LEAF_DARK)
		Art.px(image, 9, 6, P.LEAF_DARK)
	else:
		Art.px(image, 7, 9, P.SOIL_DARK)
		Art.px(image, 9, 11, P.SOIL_DARK)
	# 几粒露出来的种子
	Art.px(image, 5, 13, P.SEED_BROWN)
	Art.px(image, 11, 13, P.SEED_BROWN)
	Art.outline(image)
	return image


func _seed_bag() -> Image:
	var image := _blank()
	Art.taper(image, Vector2i(8, 5), 9, 8, 12, P.PATH)
	Art.rect(image, Rect2i(4, 4, 9, 2), P.PATH_DARK)
	Art.h_line(image, 5, 3, 6, P.SEED_BROWN)
	Art.ellipse(image, Vector2i(8, 10), Vector2i(3, 4), P.PATH_LIGHT)
	# 袋口的绳结
	Art.rect(image, Rect2i(5, 5, 6, 1), P.WOOD_DARK)
	Art.px(image, 6, 3, P.SEED_BROWN)
	Art.px(image, 9, 2, P.SEED_BROWN)
	Art.px(image, 11, 3, P.SEED_BROWN)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 工具

func _tool_hoe() -> Image:
	var image := _blank()
	# 斜握的木柄
	for i in 11:
		Art.px(image, 4 + i, 12 - i, P.WOOD)
		Art.px(image, 5 + i, 12 - i, P.WOOD_DARK)
	# 锄头
	Art.rect(image, Rect2i(2, 10, 4, 4), P.STONE)
	Art.rect(image, Rect2i(2, 10, 4, 2), P.STONE_LIGHT)
	Art.h_line(image, 1, 12, 3, P.STONE_DARK)
	Art.outline(image)
	return image


func _watering_can() -> Image:
	var image := _blank()
	Art.rect(image, Rect2i(4, 6, 8, 7), P.WATER_DARK)
	Art.rect(image, Rect2i(5, 7, 6, 5), P.WATER)
	Art.h_line(image, 5, 7, 6, P.WATER_LIGHT)
	# 壶嘴
	Art.rect(image, Rect2i(1, 6, 3, 2), P.WATER_DARK)
	Art.px(image, 1, 5, P.WATER_LIGHT)
	Art.px(image, 0, 4, P.WATER_LIGHT)
	# 提手
	Art.h_line(image, 6, 4, 5, P.WOOD_DARK)
	Art.v_line(image, 6, 5, 1, P.WOOD_DARK)
	Art.v_line(image, 10, 5, 1, P.WOOD_DARK)
	# 水滴
	Art.px(image, 2, 9, P.WATER_LIGHT)
	Art.px(image, 1, 11, P.WATER_LIGHT)
	Art.outline(image)
	return image


func _sickle() -> Image:
	var image := _blank()
	# 弯月形刀刃：用几个短横条拼出弧线
	var blade: Array[Vector2i] = [
		Vector2i(3, 4), Vector2i(5, 3), Vector2i(7, 3), Vector2i(9, 4),
		Vector2i(10, 6), Vector2i(9, 8), Vector2i(7, 9),
	]
	for at: Vector2i in blade:
		Art.px(image, at.x, at.y, P.STONE_LIGHT)
		Art.px(image, at.x, at.y + 1, P.STONE)
	# 木柄
	Art.rect(image, Rect2i(11, 8, 3, 2), P.WOOD)
	Art.rect(image, Rect2i(9, 9, 4, 3), P.WOOD_DARK)
	Art.rect(image, Rect2i(11, 10, 4, 3), P.WOOD)
	Art.outline(image)
	return image


func _wood() -> Image:
	var image := _blank()
	# 两根叠放的圆木
	for row: int in 2:
		var y: int = 6 + row * 4
		Art.rect(image, Rect2i(2, y, 12, 4), P.TRUNK)
		Art.ellipse(image, Vector2i(13, y + 1), Vector2i(1, 1), P.WOOD_LIGHT)
		Art.h_line(image, 3, y + 1, 9, P.WOOD_LIGHT)
		Art.h_line(image, 3, y + 3, 10, P.TRUNK_DARK)
	Art.ellipse(image, Vector2i(3, 7), Vector2i(1, 1), P.WOOD_LIGHT)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 野外素材

## 斧头：木柄 + 单侧斧刃（和锄头共用"斜握木柄"的画法，一眼能认出是一家人）。
func _tool_axe() -> Image:
	var image := _blank()
	for i in 11:
		Art.px(image, 4 + i, 12 - i, P.WOOD)
		Art.px(image, 5 + i, 12 - i, P.WOOD_DARK)
	# 斧刃：靠柄的顶端，一侧加厚
	Art.rect(image, Rect2i(2, 8, 4, 5), P.STONE)
	Art.rect(image, Rect2i(2, 8, 2, 5), P.STONE_LIGHT)
	Art.rect(image, Rect2i(4, 9, 2, 3), P.STONE_DARK)
	Art.outline(image)
	return image


## 镐：木柄 + 两侧对称的尖头。
func _tool_pickaxe() -> Image:
	var image := _blank()
	for i in 11:
		Art.px(image, 4 + i, 12 - i, P.WOOD)
		Art.px(image, 5 + i, 12 - i, P.WOOD_DARK)
	# 横着的镐头：中间粗两端尖
	Art.h_line(image, 2, 8, 5, P.STONE)
	Art.px(image, 1, 9, P.STONE_DARK)
	Art.px(image, 7, 7, P.STONE_LIGHT)
	Art.h_line(image, 3, 7, 3, P.STONE_LIGHT)
	Art.px(image, 2, 9, P.STONE_DARK)
	Art.outline(image)
	return image


func _stone() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(8, 10), Vector2i(6, 5), P.STONE_DARK)
	Art.ellipse(image, Vector2i(8, 9), Vector2i(5, 4), P.STONE)
	Art.ellipse(image, Vector2i(6, 7), Vector2i(2, 1), P.STONE_LIGHT)
	Art.px(image, 11, 12, P.STONE_LIGHT)
	Art.outline(image)
	return image


## 纤维：一小捆割下来的草。
func _fiber() -> Image:
	var image := _blank()
	for blade: int in 3:
		var x: int = 5 + blade * 3
		Art.v_line(image, x, 4 + blade, 9, P.LEAF)
		Art.px(image, x, 4 + blade, P.LEAF_LIGHT)
		Art.px(image, x + 1, 12, P.LEAF_DARK)
	# 中间捆一道绳
	Art.h_line(image, 4, 9, 8, P.SEED_BROWN)
	Art.h_line(image, 4, 10, 8, P.WOOD_DARK)
	Art.outline(image)
	return image


func _flower() -> Image:
	var image := _blank()
	Art.v_line(image, 8, 8, 6, P.LEAF_DARK)
	Art.px(image, 6, 11, P.LEAF)
	Art.px(image, 10, 10, P.LEAF)
	Art.circle(image, Vector2i(8, 6), 3, P.FLOWER_PINK)
	Art.px(image, 8, 6, P.FLOWER_YELLOW)
	Art.px(image, 7, 5, P.FLOWER_WHITE)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 畜产品

func _egg() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(8, 9), Vector2i(4, 5), P.WHITE)
	Art.ellipse(image, Vector2i(7, 7), Vector2i(2, 2), P.WALL_LIGHT)
	Art.px(image, 10, 12, P.WALL_DARK)
	Art.outline(image)
	return image


func _milk() -> Image:
	var image := _blank()
	# 奶瓶：瓶身 + 瓶颈 + 盖子
	Art.rect(image, Rect2i(5, 6, 6, 8), P.WHITE)
	Art.rect(image, Rect2i(6, 3, 4, 3), P.STONE_LIGHT)
	Art.rect(image, Rect2i(6, 2, 4, 1), P.STONE)
	Art.rect(image, Rect2i(6, 9, 4, 4), P.WATER_FOAM)
	Art.px(image, 6, 7, P.WALL_LIGHT)
	Art.outline(image)
	return image


func _hay() -> Image:
	var image := _blank()
	for blade: int in 4:
		var x: int = 4 + blade * 2
		Art.v_line(image, x, 4 + blade, 8, P.HAY)
	Art.h_line(image, 3, 9, 10, P.SEED_BROWN)
	Art.h_line(image, 3, 11, 10, P.PATH_DARK)
	Art.outline(image)
	return image


## 牲畜商品图标：与 [code]assets/sprites/animals[/code] 的成体保持同一配色。
func _chicken_icon() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(7, 9), Vector2i(5, 4), P.WHITE)
	Art.ellipse(image, Vector2i(10, 6), Vector2i(3, 3), P.WHITE)
	Art.px(image, 9, 3, P.FRUIT_RED)
	Art.px(image, 10, 3, P.FRUIT_RED)
	Art.rect(image, Rect2i(12, 6, 2, 1), P.FRUIT_ORANGE)
	Art.px(image, 11, 5, P.OUTLINE)
	Art.rect(image, Rect2i(6, 13, 1, 2), P.FRUIT_ORANGE)
	Art.rect(image, Rect2i(9, 13, 1, 2), P.FRUIT_ORANGE)
	Art.outline(image)
	return image


func _cow_icon() -> Image:
	var image := _blank()
	Art.ellipse(image, Vector2i(6, 9), Vector2i(5, 4), P.ANIMAL_HIDE)
	Art.ellipse(image, Vector2i(10, 6), Vector2i(3, 3), P.ANIMAL_HIDE)
	Art.ellipse(image, Vector2i(4, 8), Vector2i(2, 2), P.ANIMAL_SPOT)
	Art.ellipse(image, Vector2i(11, 6), Vector2i(1, 1), P.ANIMAL_SNOUT)
	Art.px(image, 10, 5, P.OUTLINE)
	Art.rect(image, Rect2i(4, 12, 1, 3), P.ANIMAL_HIDE)
	Art.rect(image, Rect2i(8, 12, 1, 3), P.ANIMAL_HIDE)
	Art.rect(image, Rect2i(4, 14, 1, 1), P.ANIMAL_HOOF)
	Art.rect(image, Rect2i(8, 14, 1, 1), P.ANIMAL_HOOF)
	Art.outline(image)
	return image


func _mushroom() -> Image:
	var image := _blank()
	Art.rect(image, Rect2i(7, 9, 3, 5), P.MUSHROOM_STEM)
	Art.ellipse(image, Vector2i(8, 8), Vector2i(6, 4), P.MUSHROOM_CAP)
	Art.ellipse(image, Vector2i(8, 6), Vector2i(5, 3), P.MUSHROOM_CAP)
	Art.px(image, 6, 6, P.WHITE)
	Art.px(image, 10, 7, P.WHITE)
	Art.px(image, 8, 5, P.WHITE)
	Art.outline(image)
	return image
