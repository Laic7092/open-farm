extends SceneTree
## 场景道具生成器 → [code]assets/sprites/props/*.png[/code]
##
## 建筑与家具是"一个物件一张图"，而不是塞进 16×16 的图集：
## 树、房子、床都大于一格，单独出图才能在场景里当普通 [Sprite2D] 摆，
## 并且天然参与 Y 排序（玩家可以走到树后面）。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_props.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/props"


func _initialize() -> void:
	Art.save_png(_house(), DIR.path_join("house.png"))
	Art.save_png(_barn(), DIR.path_join("barn.png"))
	Art.save_png(_tree(0), DIR.path_join("tree.png"))
	Art.save_png(_tree(1), DIR.path_join("tree_pine.png"))
	Art.save_png(_stump(), DIR.path_join("stump.png"))
	Art.save_png(_rock(16, 16, 0), DIR.path_join("rock.png"))
	Art.save_png(_rock(32, 24, 1), DIR.path_join("rock_big.png"))
	Art.save_png(_bed(), DIR.path_join("bed.png"))
	Art.save_png(_shipping_bin(), DIR.path_join("shipping_bin.png"))
	Art.save_png(_signpost(), DIR.path_join("signpost.png"))
	Art.save_png(_well(), DIR.path_join("well.png"))
	Art.save_png(_mailbox(), DIR.path_join("mailbox.png"))
	Art.save_png(_lamp(), DIR.path_join("lamp.png"))
	Art.save_png(_flower_pot(), DIR.path_join("flower_pot.png"))
	Art.save_png(_chicken(), DIR.path_join("chicken.png"))
	print("场景道具生成完成 → ", DIR)
	quit()


# ---------------------------------------------------------------- 建筑

## 农舍：64×64，屋顶 + 白墙木筋 + 门 + 两扇窗 + 烟囱。
func _house() -> Image:
	var image := Art.new_image(64, 64)
	Art.ground_shadow(image, 64, 64, 8)

	# 墙体
	var body := Rect2i(8, 26, 48, 34)
	Art.rect(image, body, P.WALL)
	Art.scatter(image, body, P.WALL_DARK, 0.10, 7)
	Art.rect(image, Rect2i(body.position.x, body.position.y, 2, body.size.y), P.WALL_DARK)
	Art.h_line(image, body.position.x, body.position.y, body.size.x, P.WALL_LIGHT)
	# 木筋
	Art.rect(image, Rect2i(8, 26, 48, 2), P.WOOD_DARK)
	Art.rect(image, Rect2i(8, 56, 48, 4), P.WOOD_DARK)
	Art.rect(image, Rect2i(10, 28, 2, 28), P.WOOD_DARK)
	Art.rect(image, Rect2i(52, 28, 2, 28), P.WOOD_DARK)

	# 屋顶：上窄下宽的梯形 + 出檐
	for row: int in 26:
		var t := float(row) / 25.0
		var half := int(round(lerpf(20.0, 32.0, t)))
		var color: Color = P.ROOF if (row / 4) % 2 == 0 else P.ROOF.lerp(P.ROOF_DARK, 0.35)
		Art.h_line(image, 32 - half, 2 + row, half * 2, color)
	Art.rect(image, Rect2i(0, 24, 64, 4), P.ROOF_DARK)
	Art.h_line(image, 0, 24, 64, P.ROOF_LIGHT)
	Art.h_line(image, 0, 27, 64, P.ROOF_DARK)

	# 烟囱
	Art.rect(image, Rect2i(44, 2, 8, 16), P.STONE)
	Art.rect(image, Rect2i(43, 0, 10, 4), P.STONE_DARK)
	Art.scatter(image, Rect2i(44, 2, 8, 16), P.STONE_DARK, 0.25, 13)

	# 门
	Art.rect(image, Rect2i(26, 38, 14, 22), P.WOOD)
	Art.frame_rect(image, Rect2i(26, 38, 14, 22), P.WOOD_DARK)
	Art.v_line(image, 33, 39, 20, P.WOOD_DARK)
	Art.h_line(image, 27, 40, 12, P.WOOD_LIGHT)
	Art.px(image, 30, 49, P.COIN)
	Art.px(image, 36, 49, P.COIN)

	# 窗
	_window(image, Rect2i(12, 32, 10, 10))
	_window(image, Rect2i(44, 32, 10, 10))

	Art.outline(image, P.OUTLINE)
	return image


func _window(image: Image, area: Rect2i) -> void:
	Art.rect(image, area, P.GLASS_DARK)
	Art.rect(image, Rect2i(area.position.x + 1, area.position.y + 1, area.size.x - 2, area.size.y - 2), P.GLASS)
	Art.h_line(image, area.position.x + 1, area.position.y + 1, area.size.x - 2, P.WATER_FOAM)
	Art.frame_rect(image, area, P.WOOD_DARK)
	Art.v_line(image, area.position.x + area.size.x / 2, area.position.y, area.size.y, P.WOOD_DARK)


## 谷仓：64×56，红色屋顶 + 双开大门 + 干草阁楼窗。
func _barn() -> Image:
	var image := Art.new_image(64, 56)
	Art.ground_shadow(image, 64, 56, 6)

	var body := Rect2i(6, 18, 52, 36)
	Art.rect(image, body, P.ROOF_DARK.lerp(P.WALL, 0.25))
	Art.scatter(image, body, P.ROOF_DARK, 0.12, 17)
	Art.h_line(image, 6, 18, 52, P.ROOF)

	# 复折屋顶（gambrel）
	for row: int in 18:
		var t := float(row) / 17.0
		var half := int(round(lerpf(18.0, 32.0, sqrt(t))))
		var color: Color = P.ROOF if row < 9 else P.ROOF.lerp(P.ROOF_DARK, 0.3)
		Art.h_line(image, 32 - half, row, half * 2, color)
	Art.rect(image, Rect2i(0, 16, 64, 3), P.ROOF_DARK)
	Art.h_line(image, 0, 16, 64, P.ROOF_LIGHT)

	# 大门 + 交叉支撑
	Art.rect(image, Rect2i(20, 28, 24, 26), P.WOOD)
	Art.frame_rect(image, Rect2i(20, 28, 24, 26), P.WOOD_DARK)
	Art.v_line(image, 32, 28, 26, P.WOOD_DARK)
	for i in 22:
		Art.px(image, 21 + i, 29 + i, P.WOOD_DARK)
		Art.px(image, 42 - i, 29 + i, P.WOOD_DARK)
	Art.h_line(image, 21, 30, 10, P.WOOD_LIGHT)

	# 阁楼窗
	Art.rect(image, Rect2i(28, 20, 8, 7), P.WOOD_DARK)
	Art.rect(image, Rect2i(29, 21, 6, 5), P.GLASS_DARK)
	Art.rect(image, Rect2i(8, 30, 8, 8), P.WOOD_DARK)
	Art.rect(image, Rect2i(48, 30, 8, 8), P.WOOD_DARK)

	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 植被 / 石头

## [param variant] 0 = 阔叶树、1 = 松树。
func _tree(variant: int) -> Image:
	var image := Art.new_image(32, 48)
	Art.ground_shadow(image, 32, 48, 8)

	# 树干
	Art.taper(image, Vector2i(16, 30), 16, 6, 9, P.TRUNK)
	Art.v_line(image, 14, 32, 14, P.TRUNK_DARK)
	Art.v_line(image, 18, 32, 14, P.WOOD_LIGHT)
	Art.h_line(image, 12, 45, 9, P.TRUNK_DARK)

	if variant == 1:
		# 松树：三层越来越小的三角
		for layer: int in 3:
			var top: int = 2 + layer * 9
			var half: int = 12 - layer * 3
			var height: int = 14
			for row: int in height:
				var t := float(row) / float(height - 1)
				var width := int(round(lerpf(1.0, float(half) * 2.0, t)))
				var color: Color = P.LEAF_DARK if layer % 2 == 0 else P.LEAF
				Art.h_line(image, 16 - width / 2, top + row, width, color)
			Art.h_line(image, 16 - half, top + height - 1, half * 2, P.LEAF_DARK)
		Art.h_line(image, 11, 8, 4, P.LEAF_LIGHT)
	else:
		# 阔叶树：三团错位树冠
		Art.ellipse(image, Vector2i(11, 20), Vector2i(9, 8), P.LEAF_DARK)
		Art.ellipse(image, Vector2i(21, 19), Vector2i(9, 8), P.LEAF_DARK)
		Art.ellipse(image, Vector2i(16, 13), Vector2i(10, 8), P.LEAF_DARK)
		Art.ellipse(image, Vector2i(11, 20), Vector2i(7, 6), P.LEAF)
		Art.ellipse(image, Vector2i(21, 19), Vector2i(7, 6), P.LEAF)
		Art.ellipse(image, Vector2i(16, 13), Vector2i(8, 6), P.LEAF)
		Art.ellipse(image, Vector2i(14, 10), Vector2i(5, 3), P.LEAF_LIGHT)
		Art.px(image, 9, 17, P.FRUIT_RED)
		Art.px(image, 23, 16, P.FRUIT_RED)

	Art.outline(image, P.OUTLINE)
	return image


func _stump() -> Image:
	var image := Art.new_image(16, 16)
	Art.ground_shadow(image, 16, 16, 3)
	Art.ellipse(image, Vector2i(8, 10), Vector2i(6, 5), P.TRUNK_DARK)
	Art.ellipse(image, Vector2i(8, 9), Vector2i(6, 4), P.TRUNK)
	Art.ellipse(image, Vector2i(8, 9), Vector2i(3, 2), P.WOOD_LIGHT)
	Art.px(image, 8, 9, P.TRUNK_DARK)
	Art.outline(image, P.OUTLINE)
	return image


func _rock(width: int, height: int, variant: int) -> Image:
	var image := Art.new_image(width, height)
	Art.ground_shadow(image, width, height, 3)
	var center := Vector2i(width / 2, height - 5)
	var radius := Vector2i(width / 2 - 2, height / 2 - 2)
	Art.ellipse(image, center, radius, P.STONE_DARK)
	Art.ellipse(image, center - Vector2i(0, 1), radius - Vector2i(1, 1), P.STONE)
	Art.ellipse(image, center - Vector2i(2, 2), Vector2i(maxi(radius.x / 2, 1), maxi(radius.y / 2, 1)), P.STONE_LIGHT)
	if variant == 1:
		Art.ellipse(image, center + Vector2i(5, -2), Vector2i(3, 2), P.STONE_LIGHT)
		Art.h_line(image, center.x - radius.x + 2, center.y + radius.y - 1, 4, P.STONE_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 家具 / 交互物

## 床：16×24，木框 + 枕头 + 被子。
func _bed() -> Image:
	var image := Art.new_image(16, 24)
	Art.ground_shadow(image, 16, 24, 2)
	Art.rect(image, Rect2i(1, 2, 14, 21), P.WOOD_DARK)
	Art.rect(image, Rect2i(2, 3, 12, 19), P.WOOD)
	Art.rect(image, Rect2i(2, 3, 12, 6), P.WHITE)
	Art.rect(image, Rect2i(3, 4, 10, 4), P.APRON)
	Art.rect(image, Rect2i(2, 10, 12, 12), P.FRUIT_RED)
	Art.h_line(image, 2, 10, 12, P.FLOWER_WHITE)
	Art.stripes(image, Rect2i(2, 11, 12, 11), P.ROOF_DARK, 4, 0)
	Art.rect(image, Rect2i(1, 1, 14, 2), P.WOOD_DARK)
	Art.h_line(image, 2, 2, 12, P.WOOD_LIGHT)
	Art.outline(image, P.OUTLINE)
	return image


## 出货箱：24×20，敞口木箱 + 一小堆货物。
func _shipping_bin() -> Image:
	var image := Art.new_image(24, 20)
	Art.ground_shadow(image, 24, 20, 3)
	Art.rect(image, Rect2i(1, 5, 22, 14), P.WOOD)
	Art.frame_rect(image, Rect2i(1, 5, 22, 14), P.WOOD_DARK)
	Art.h_line(image, 3, 7, 18, P.WOOD_LIGHT)
	Art.v_line(image, 7, 6, 13, P.WOOD_DARK)
	Art.v_line(image, 16, 6, 13, P.WOOD_DARK)
	# 盖子内侧
	Art.rect(image, Rect2i(2, 3, 20, 3), P.WOOD_DARK)
	Art.px(image, 6, 3, P.FRUIT_RED)
	Art.px(image, 7, 3, P.FRUIT_RED)
	Art.px(image, 12, 3, P.FRUIT_GREEN)
	Art.px(image, 17, 3, P.FRUIT_ORANGE)
	Art.outline(image, P.OUTLINE)
	return image


## 路牌：两根木柱 + 指路板。
func _signpost() -> Image:
	var image := Art.new_image(16, 24)
	Art.ground_shadow(image, 16, 24, 4)
	Art.rect(image, Rect2i(7, 6, 3, 17), P.WOOD_DARK)
	Art.rect(image, Rect2i(1, 3, 14, 7), P.WOOD)
	Art.frame_rect(image, Rect2i(1, 3, 14, 7), P.WOOD_DARK)
	Art.h_line(image, 3, 6, 8, P.WOOD_DARK)
	Art.h_line(image, 3, 8, 5, P.WOOD_DARK)
	Art.h_line(image, 8, 14, 6, P.WOOD)
	Art.outline(image, P.OUTLINE)
	return image


## 水井：石砌井台 + 木架 + 小屋顶。
func _well() -> Image:
	var image := Art.new_image(32, 32)
	Art.ground_shadow(image, 32, 32, 5)
	Art.rect(image, Rect2i(5, 18, 22, 12), P.STONE)
	Art.rect(image, Rect2i(5, 18, 22, 2), P.STONE_LIGHT)
	Art.scatter(image, Rect2i(5, 18, 22, 12), P.STONE_DARK, 0.22, 29)
	Art.rect(image, Rect2i(8, 18, 16, 3), P.WATER_DARK)
	Art.rect(image, Rect2i(10, 18, 12, 2), P.WATER)
	Art.rect(image, Rect2i(7, 6, 2, 14), P.WOOD_DARK)
	Art.rect(image, Rect2i(23, 6, 2, 14), P.WOOD_DARK)
	for row: int in 7:
		var half := 6 + row * 2
		Art.h_line(image, 16 - half, row + 2, half * 2, P.ROOF if row % 2 == 0 else P.ROOF_DARK)
	Art.h_line(image, 4, 6, 24, P.ROOF_DARK)
	Art.outline(image, P.OUTLINE)
	return image


## 信箱：木柱 + 箱体 + 红旗。
func _mailbox() -> Image:
	var image := Art.new_image(16, 24)
	Art.ground_shadow(image, 16, 24, 4)
	Art.rect(image, Rect2i(7, 10, 3, 13), P.WOOD_DARK)
	Art.rect(image, Rect2i(2, 5, 12, 7), P.FRUIT_RED)
	Art.frame_rect(image, Rect2i(2, 5, 12, 7), P.ROOF_DARK)
	Art.rect(image, Rect2i(2, 8, 12, 4), P.ROOF_DARK)
	Art.px(image, 11, 3, P.COIN)
	Art.v_line(image, 11, 3, 3, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


## 路灯：铁柱 + 暖光灯笼。
func _lamp() -> Image:
	var image := Art.new_image(16, 32)
	Art.ground_shadow(image, 16, 32, 5)
	Art.rect(image, Rect2i(7, 12, 3, 19), P.STONE_DARK)
	Art.rect(image, Rect2i(5, 30, 7, 2), P.STONE_DARK)
	Art.rect(image, Rect2i(4, 5, 9, 8), P.WOOD_DARK)
	Art.rect(image, Rect2i(5, 6, 7, 6), P.SUN)
	Art.rect(image, Rect2i(6, 7, 5, 4), P.SUN_CORE)
	Art.rect(image, Rect2i(3, 3, 11, 2), P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


func _flower_pot() -> Image:
	var image := Art.new_image(16, 16)
	Art.ground_shadow(image, 16, 16, 4)
	Art.taper(image, Vector2i(8, 8), 7, 12, 8, P.FRUIT_ORANGE)
	Art.rect(image, Rect2i(2, 7, 12, 2), P.ROOF_LIGHT)
	Art.px(image, 6, 5, P.LEAF_DARK)
	Art.px(image, 9, 4, P.LEAF)
	Art.px(image, 6, 4, P.FLOWER_PINK)
	Art.px(image, 5, 4, P.FLOWER_PINK)
	Art.px(image, 6, 3, P.FLOWER_PINK)
	Art.px(image, 9, 3, P.FLOWER_YELLOW)
	Art.px(image, 10, 3, P.FLOWER_YELLOW)
	Art.px(image, 9, 2, P.FLOWER_YELLOW)
	Art.outline(image, P.OUTLINE)
	return image


## 小鸡：牧场气氛组，纯装饰。
func _chicken() -> Image:
	var image := Art.new_image(16, 16)
	Art.ground_shadow(image, 16, 16, 4)
	Art.ellipse(image, Vector2i(8, 9), Vector2i(5, 4), P.WHITE)
	Art.ellipse(image, Vector2i(10, 6), Vector2i(3, 3), P.WHITE)
	Art.px(image, 12, 5, P.STONE_DARK)
	Art.rect(image, Rect2i(12, 6, 2, 1), P.FRUIT_ORANGE)
	Art.px(image, 11, 5, P.OUTLINE)
	Art.rect(image, Rect2i(7, 13, 1, 2), P.FRUIT_ORANGE)
	Art.rect(image, Rect2i(9, 13, 1, 2), P.FRUIT_ORANGE)
	Art.rect(image, Rect2i(11, 5, 2, 3), P.FRUIT_RED)
	Art.outline(image, P.OUTLINE)
	return image
