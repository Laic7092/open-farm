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
	Art.save_png(_coop(), DIR.path_join("coop.png"))
	Art.save_png(_trough(), DIR.path_join("trough.png"))
	# 新场景专用：海滩（栈桥 / 小船）、矿洞（洞口）、室内（书架 / 柜台）、
	# 小镇（铁匠炉 / 花摊）。
	Art.save_png(_dock(), DIR.path_join("dock.png"))
	Art.save_png(_boat(), DIR.path_join("boat.png"))
	Art.save_png(_cave(), DIR.path_join("cave.png"))
	Art.save_png(_bookshelf(), DIR.path_join("bookshelf.png"))
	Art.save_png(_counter(), DIR.path_join("counter.png"))
	Art.save_png(_forge(), DIR.path_join("forge.png"))
	Art.save_png(_flower_stand(), DIR.path_join("flower_stand.png"))
	print("场景道具生成完成 → ", DIR)
	quit()


# ---------------------------------------------------------------- 建筑

## 农舍：64×64。3/4 视角：右山墙退后 9×6，前山墙 + 两坡屋顶 + 烟囱；
## 建筑走 [WorldProp] 的"身后淡出"，不做局部遮挡。
func _house() -> Image:
	var image := Art.new_image(64, 64)
	Art.ground_shadow(image, 64, 64, 8)
	# 前山墙房子的 3/4：屋脊从前(27,18)向后(36,12)退，两坡屋顶各占一边。
	var front_left := Vector2(3, 35)
	var apex_front := Vector2(27, 22)
	var apex_back := Vector2(34, 17)
	var front_right := Vector2(51, 35)
	var back_left := Vector2(11, 29)
	var back_right := Vector2(57, 29)

	# 右侧墙：向后上方退 9×6，是这栋房子"转过来"的第一层体积。
	Art.quad(image, Vector2(48, 36), Vector2(55, 31), Vector2(55, 55), Vector2(48, 60), P.WALL_DARK)
	Art.v_line(image, 48, 36, 24, P.WALL_DARK.lerp(P.OUTLINE, 0.25))

	# 两坡屋顶：左坡受光、右坡背光。
	Art.quad(image, front_left, apex_front, apex_back, back_left, P.ROOF)
	Art.quad(image, front_right, apex_front, apex_back, back_right, P.ROOF.lerp(P.ROOF_DARK, 0.45))
	# 瓦垄：与檐口平行，从檐边往屋脊推。
	for t: float in [0.34, 0.67]:
		Art.line(image, front_left.lerp(apex_front, t), back_left.lerp(apex_back, t), P.ROOF_LIGHT)
		Art.line(image, front_right.lerp(apex_front, t), back_right.lerp(apex_back, t), P.ROOF_DARK)
	# 屋脊：从前到后压一道亮边。
	Art.line(image, apex_front, apex_back, P.ROOF_LIGHT)
	Art.px(image, int(apex_front.x) + 1, int(apex_front.y), P.ROOF_LIGHT)

	# 正面墙 + 前山墙三角，压住屋顶靠近观众的一半。
	Art.triangle(image, Vector2(6, 36), Vector2(48, 36), Vector2(27, 22), P.WALL)
	Art.rect(image, Rect2i(6, 36, 42, 24), P.WALL)
	Art.scatter(image, Rect2i(6, 22, 42, 38), P.WALL_DARK, 0.05, 7)
	Art.v_line(image, 6, 36, 24, P.WALL_LIGHT)
	Art.v_line(image, 47, 36, 24, P.WALL_DARK)

	# 木筋：横梁 + 竖柱 + 山墙中柱与斜撑。
	Art.rect(image, Rect2i(6, 36, 42, 2), P.WOOD_DARK)
	Art.rect(image, Rect2i(6, 57, 42, 3), P.WOOD_DARK)
	for x: int in [11, 19, 35, 43]:
		Art.v_line(image, x, 38, 19, P.WOOD_DARK)
	Art.v_line(image, 27, 23, 13, P.WOOD_DARK)
	for i: int in 10:
		Art.px(image, 27 - i, 23 + i, P.WOOD_DARK)
		Art.px(image, 27 + i, 23 + i, P.WOOD_DARK)

	# 檐口：沿前山墙两侧斜边压深色，给屋顶厚度。
	Art.line(image, front_left, apex_front, P.ROOF_DARK)
	Art.line(image, apex_front, front_right, P.ROOF_DARK)
	Art.line(image, Vector2(front_left.x, front_left.y + 1), Vector2(apex_front.x, apex_front.y + 1), P.ROOF_DARK)

	# 烟囱：坐在左坡靠屋脊处。
	Art.rect(image, Rect2i(18, 12, 7, 14), P.STONE)
	Art.rect(image, Rect2i(17, 9, 9, 4), P.STONE_DARK)
	Art.scatter(image, Rect2i(18, 12, 7, 14), P.STONE_DARK, 0.22, 13)

	# 正面门 / 两扇窗；右侧墙补一扇小窗说明侧面也有人住。
	Art.rect(image, Rect2i(23, 46, 12, 14), P.WOOD)
	Art.frame_rect(image, Rect2i(23, 46, 12, 14), P.WOOD_DARK)
	Art.v_line(image, 29, 47, 13, P.WOOD_DARK)
	Art.h_line(image, 24, 48, 10, P.WOOD_LIGHT)
	Art.px(image, 26, 53, P.COIN)
	Art.px(image, 32, 53, P.COIN)
	_window(image, Rect2i(9, 42, 9, 9))
	_window(image, Rect2i(37, 42, 9, 9))
	Art.rect(image, Rect2i(50, 38, 4, 6), P.GLASS_DARK)
	Art.rect(image, Rect2i(51, 39, 2, 4), P.GLASS)
	Art.frame_rect(image, Rect2i(50, 38, 4, 6), P.WOOD_DARK)

	Art.outline(image, P.OUTLINE)
	return image


func _window(image: Image, area: Rect2i) -> void:
	Art.rect(image, area, P.GLASS_DARK)
	Art.rect(image, Rect2i(area.position.x + 1, area.position.y + 1, area.size.x - 2, area.size.y - 2), P.GLASS)
	Art.h_line(image, area.position.x + 1, area.position.y + 1, area.size.x - 2, P.WATER_FOAM)
	Art.frame_rect(image, area, P.WOOD_DARK)
	Art.v_line(image, area.position.x + area.size.x / 2, area.position.y, area.size.y, P.WOOD_DARK)


## 谷仓：64×56。与农舍同构的 3/4，但更宽更矮，红顶 + 双开大门 + 干草阁楼窗。
## 建筑走 [WorldProp] 的"身后淡出"，不做局部遮挡。
func _barn() -> Image:
	var image := Art.new_image(64, 56)
	Art.ground_shadow(image, 64, 56, 6)

	# 与农舍同源的 3/4 结构，但更宽、更低，红顶 + 干草阁楼窗一眼认得出是谷仓。
	var front_left := Vector2(3, 29)
	var apex_front := Vector2(26, 17)
	var apex_back := Vector2(33, 12)
	var front_right := Vector2(49, 29)
	var back_left := Vector2(11, 24)
	var back_right := Vector2(56, 24)

	# 右侧墙
	Art.quad(image, Vector2(46, 30), Vector2(54, 25), Vector2(54, 47), Vector2(46, 52), P.WALL_DARK)
	Art.v_line(image, 46, 30, 22, P.WALL_DARK.lerp(P.OUTLINE, 0.3))

	# 双坡屋顶：红瓦，左亮右暗。
	Art.quad(image, front_left, apex_front, apex_back, back_left, P.ROOF)
	Art.quad(image, front_right, apex_front, apex_back, back_right, P.ROOF.lerp(P.ROOF_DARK, 0.5))
	for t: float in [0.34, 0.67]:
		Art.line(image, front_left.lerp(apex_front, t), back_left.lerp(apex_back, t), P.ROOF_LIGHT)
		Art.line(image, front_right.lerp(apex_front, t), back_right.lerp(apex_back, t), P.ROOF_DARK)
	Art.line(image, apex_front, apex_back, P.ROOF_LIGHT)

	# 正面墙 + 山墙，压住屋顶近端。
	Art.triangle(image, Vector2(6, 30), Vector2(46, 30), Vector2(26, 17), P.WALL)
	Art.rect(image, Rect2i(6, 30, 40, 22), P.WALL)
	Art.scatter(image, Rect2i(6, 17, 40, 35), P.WALL_DARK, 0.08, 17)
	Art.v_line(image, 6, 30, 22, P.WALL_LIGHT)
	Art.v_line(image, 45, 30, 22, P.WALL_DARK)

	# 木筋
	Art.rect(image, Rect2i(6, 30, 40, 2), P.WOOD_DARK)
	Art.rect(image, Rect2i(6, 48, 40, 4), P.WOOD_DARK)
	Art.v_line(image, 26, 18, 12, P.WOOD_DARK)
	for i: int in 9:
		Art.px(image, 26 - i, 18 + i, P.WOOD_DARK)
		Art.px(image, 26 + i, 18 + i, P.WOOD_DARK)

	# 前檐：沿山墙斜边压深色。
	Art.line(image, front_left, apex_front, P.ROOF_DARK)
	Art.line(image, apex_front, front_right, P.ROOF_DARK)
	Art.line(image, Vector2(front_left.x, front_left.y + 1), Vector2(apex_front.x, apex_front.y + 1), P.ROOF_DARK)

	# 干草阁楼窗：开在山墙上，比大门高一层。
	Art.rect(image, Rect2i(21, 22, 10, 8), P.WOOD_DARK)
	Art.rect(image, Rect2i(22, 23, 8, 6), P.GLASS_DARK)
	Art.rect(image, Rect2i(23, 24, 6, 4), P.HAY)

	# 双开大门 + 交叉支撑
	Art.rect(image, Rect2i(18, 34, 16, 18), P.WOOD)
	Art.frame_rect(image, Rect2i(18, 34, 16, 18), P.WOOD_DARK)
	Art.v_line(image, 26, 34, 18, P.WOOD_DARK)
	for i: int in 16:
		Art.px(image, 19 + i, 35 + i, P.WOOD_DARK)
		Art.px(image, 33 - i, 35 + i, P.WOOD_DARK)
	Art.h_line(image, 19, 36, 6, P.WOOD_LIGHT)
	# 两侧小窗
	Art.rect(image, Rect2i(8, 34, 7, 7), P.WOOD_DARK)
	Art.rect(image, Rect2i(9, 35, 5, 5), P.GLASS_DARK)
	Art.rect(image, Rect2i(37, 34, 7, 7), P.WOOD_DARK)
	Art.rect(image, Rect2i(38, 35, 5, 5), P.GLASS_DARK)

	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 植被 / 石头

## [param variant] 0 = 阔叶树、1 = 松树。
func _tree(variant: int) -> Image:
	var image := Art.new_image(32, 48)
	Art.ground_shadow(image, 32, 48, 8)
	_tree_trunk(image)
	_tree_canopy(image, variant)
	Art.outline(image, P.OUTLINE)
	return image


## 树干：基部外扩出根盘，避免树像插在土里的一根棍。
func _tree_trunk(image: Image) -> void:
	Art.taper(image, Vector2i(16, 28), 18, 6, 9, P.TRUNK)
	Art.v_line(image, 13, 30, 16, P.TRUNK_DARK)
	Art.v_line(image, 19, 30, 16, P.WOOD_LIGHT)
	# 根盘：左右各探出一像素，贴着地面。
	Art.h_line(image, 11, 45, 11, P.TRUNK_DARK)
	Art.px(image, 10, 44, P.TRUNK_DARK)
	Art.px(image, 21, 44, P.TRUNK_DARK)
	Art.h_line(image, 12, 46, 9, P.TRUNK)


## 树冠（3/4 受光）：暗部偏右下、亮部偏左上，树冠下缘再压一层暗。
func _tree_canopy(image: Image, variant: int) -> void:
	if variant == 1:
		_pine_canopy(image)
	else:
		_oak_canopy(image)


## 阔叶树：三团错位树冠 + 顶部受光 + 底部阴影。
func _oak_canopy(image: Image) -> void:
	Art.ellipse(image, Vector2i(12, 21), Vector2i(9, 8), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(22, 20), Vector2i(9, 8), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(17, 15), Vector2i(10, 8), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(11, 19), Vector2i(8, 7), P.LEAF)
	Art.ellipse(image, Vector2i(21, 18), Vector2i(8, 7), P.LEAF)
	Art.ellipse(image, Vector2i(16, 13), Vector2i(9, 7), P.LEAF)
	Art.ellipse(image, Vector2i(12, 12), Vector2i(6, 4), P.LEAF_LIGHT)
	Art.ellipse(image, Vector2i(9, 17), Vector2i(4, 3), P.LEAF_LIGHT)
	Art.ellipse(image, Vector2i(20, 23), Vector2i(7, 3), P.LEAF_DARK.lerp(P.OUTLINE, 0.18))
	Art.px(image, 9, 18, P.FRUIT_RED)
	Art.px(image, 24, 17, P.FRUIT_RED)


## 松树：三层三角，每层左亮右暗，越往上越小。
func _pine_canopy(image: Image) -> void:
	for layer: int in 3:
		var base: int = 30 - layer * 8
		var half: int = 11 - layer * 3
		var apex := Vector2(16, base - 12)
		Art.triangle(image, apex, Vector2(16 - half, base), Vector2(16 + half, base), P.LEAF)
		Art.triangle(image, apex, Vector2(16 - half, base), Vector2(16 - half / 3, base), P.LEAF_LIGHT)
		Art.triangle(image, apex, Vector2(16, base), Vector2(16 + half, base), P.LEAF_DARK)
		Art.h_line(image, 16 - half, base, half * 2, P.LEAF_DARK)
	Art.v_line(image, 15, 2, 4, P.LEAF_LIGHT)


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


## 鸡舍：比谷仓小一号，配色更暖，门口挂一个下蛋的草窝。
func _coop() -> Image:
	var image := Art.new_image(48, 44)
	Art.ground_shadow(image, 48, 44, 6)

	var body := Rect2i(6, 18, 36, 24)
	Art.rect(image, body, P.WALL)
	Art.scatter(image, body, P.WALL_DARK, 0.10, 19)
	Art.h_line(image, 6, 18, 36, P.WALL_LIGHT)
	# 木筋
	Art.rect(image, Rect2i(6, 18, 36, 2), P.WOOD_DARK)
	Art.rect(image, Rect2i(6, 40, 36, 2), P.WOOD_DARK)
	Art.v_line(image, 8, 20, 20, P.WOOD_DARK)
	Art.v_line(image, 39, 20, 20, P.WOOD_DARK)

	# 单坡屋顶
	for row: int in 16:
		var half := int(round(lerpf(16.0, 24.0, float(row) / 15.0)))
		Art.h_line(image, 24 - half, 2 + row, half * 2, P.ROOF if row % 3 != 0 else P.ROOF_DARK)
	Art.rect(image, Rect2i(0, 16, 48, 3), P.ROOF_DARK)
	Art.h_line(image, 0, 16, 48, P.ROOF_LIGHT)

	# 门与草窝
	Art.rect(image, Rect2i(18, 28, 12, 14), P.WOOD)
	Art.frame_rect(image, Rect2i(18, 28, 12, 14), P.WOOD_DARK)
	Art.h_line(image, 19, 30, 10, P.WOOD_LIGHT)
	Art.ellipse(image, Vector2i(9, 38), Vector2i(5, 3), P.HAY)
	Art.ellipse(image, Vector2i(9, 37), Vector2i(3, 2), P.FRUIT_ORANGE)

	Art.outline(image, P.OUTLINE)
	return image


## 饲料槽：木槽 + 干草。
func _trough() -> Image:
	var image := Art.new_image(16, 16)
	Art.ground_shadow(image, 16, 16, 3)
	Art.taper(image, Vector2i(8, 8), 5, 12, 10, P.WOOD)
	Art.rect(image, Rect2i(3, 7, 11, 2), P.WOOD_DARK)
	Art.h_line(image, 5, 7, 7, P.HAY)
	Art.h_line(image, 6, 6, 5, P.HAY)
	Art.px(image, 8, 5, P.PATH_LIGHT)
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


# ---------------------------------------------------------------- 新场景道具

## 木栈桥：横向桥面 + 四根木桩，铺在沙滩与水面之间。
func _dock() -> Image:
	var image := Art.new_image(48, 24)
	# 木桩先画，让桥面盖住它们的上端。
	for x: int in [2, 14, 26, 38]:
		Art.rect(image, Rect2i(x, 8, 3, 16), P.WOOD_DARK)
		Art.h_line(image, x, 8, 3, P.WOOD_LIGHT)
	# 桥面木板。
	Art.rect(image, Rect2i(0, 4, 48, 8), P.PLANK)
	for y: int in [5, 8, 11]:
		Art.h_line(image, 0, y, 48, P.WOOD_DARK)
	Art.h_line(image, 0, 4, 48, P.WOOD_LIGHT)
	Art.outline(image, P.OUTLINE)
	return image


## 小木船：倒梯形船身 + 一支横桨。
func _boat() -> Image:
	var image := Art.new_image(32, 24)
	Art.taper(image, Vector2i(16, 7), 11, 16, 7, P.WOOD)
	Art.h_line(image, 8, 7, 16, P.WOOD_LIGHT)
	Art.h_line(image, 8, 8, 16, P.WOOD_DARK)
	Art.rect(image, Rect2i(6, 9, 2, 5), P.WOOD_DARK)
	Art.rect(image, Rect2i(24, 9, 2, 5), P.WOOD_DARK)
	Art.h_line(image, 4, 5, 24, P.WOOD_DARK)
	Art.rect(image, Rect2i(2, 3, 3, 4), P.WOOD_LIGHT)
	Art.outline(image, P.OUTLINE)
	return image


## 矿洞入口：一堆岩石里挖出的黑洞，远处一眼能认出来。
func _cave() -> Image:
	var image := Art.new_image(48, 40)
	Art.ground_shadow(image, 48, 40, 6)
	Art.ellipse(image, Vector2i(24, 24), Vector2i(22, 16), P.STONE)
	Art.ellipse(image, Vector2i(16, 18), Vector2i(12, 9), P.STONE_LIGHT)
	Art.scatter(image, Rect2i(2, 8, 44, 28), P.STONE_DARK, 0.16, 29)
	# 洞口：黑色椭圆 + 一圈深色内壁。
	Art.ellipse(image, Vector2i(24, 28), Vector2i(10, 11), P.STONE_DARK)
	Art.ellipse(image, Vector2i(24, 29), Vector2i(8, 9), P.BLACK)
	Art.outline(image, P.OUTLINE)
	return image


## 书架：木框 + 三层彩色书脊。
func _bookshelf() -> Image:
	var image := Art.new_image(32, 32)
	Art.ground_shadow(image, 32, 32, 4)
	Art.rect(image, Rect2i(2, 2, 28, 28), P.WOOD)
	Art.rect(image, Rect2i(4, 4, 24, 24), P.WOOD_DARK)
	var colors: Array[Color] = [
		P.FRUIT_RED, P.FRUIT_GREEN, P.FRUIT_YELLOW, P.FLOWER_BLUE, P.FRUIT_PURPLE,
	]
	for row: int in 3:
		var base: int = 4 + row * 8
		var x: int = 5
		var i: int = 0
		while x < 27:
			var w: int = 2 + (i + row) % 2
			var h: int = 5 + (i * 3 + row) % 3
			Art.rect(image, Rect2i(x, base + 7 - h, w, h), colors[(i + row) % colors.size()])
			x += w + 1
			i += 1
		Art.h_line(image, 4, base + 7, 24, P.PLANK)
	Art.outline(image, P.OUTLINE)
	return image


## 商店柜台：木台面 + 台面上的钱币与玻璃瓶。
func _counter() -> Image:
	var image := Art.new_image(48, 24)
	Art.ground_shadow(image, 48, 24, 6)
	Art.rect(image, Rect2i(2, 6, 44, 16), P.WOOD_DARK)
	Art.rect(image, Rect2i(2, 6, 44, 5), P.PLANK)
	Art.h_line(image, 2, 6, 44, P.WOOD_LIGHT)
	for x: int in [12, 24, 36]:
		Art.v_line(image, x, 11, 11, P.WOOD)
	Art.rect(image, Rect2i(6, 2, 5, 4), P.COIN)
	Art.rect(image, Rect2i(37, 1, 6, 5), P.GLASS)
	Art.outline(image, P.OUTLINE)
	return image


## 铁匠炉：石炉 + 炉火 + 铁砧。
func _forge() -> Image:
	var image := Art.new_image(32, 32)
	Art.ground_shadow(image, 32, 32, 4)
	Art.rect(image, Rect2i(3, 8, 14, 20), P.STONE)
	Art.scatter(image, Rect2i(3, 8, 14, 20), P.STONE_DARK, 0.2, 37)
	Art.h_line(image, 3, 8, 14, P.STONE_LIGHT)
	Art.rect(image, Rect2i(7, 15, 6, 7), P.BLACK)
	Art.rect(image, Rect2i(8, 17, 4, 5), P.FRUIT_ORANGE)
	Art.rect(image, Rect2i(9, 18, 2, 4), P.FRUIT_YELLOW)
	Art.rect(image, Rect2i(19, 18, 11, 3), P.STONE_DARK)
	Art.rect(image, Rect2i(22, 21, 5, 5), P.STONE)
	Art.rect(image, Rect2i(19, 26, 11, 2), P.STONE_DARK)
	Art.rect(image, Rect2i(5, 2, 6, 8), P.STONE_DARK)
	Art.outline(image, P.OUTLINE)
	return image


## 花摊：双层木架，每层摆一排花盆。
func _flower_stand() -> Image:
	var image := Art.new_image(32, 32)
	Art.ground_shadow(image, 32, 32, 4)
	Art.rect(image, Rect2i(3, 14, 26, 14), P.WOOD)
	Art.rect(image, Rect2i(3, 14, 26, 2), P.WOOD_LIGHT)
	Art.rect(image, Rect2i(3, 26, 26, 2), P.WOOD_DARK)
	var bloom: Array[Color] = [P.FLOWER_PINK, P.FLOWER_YELLOW, P.FLOWER_BLUE]
	for row: int in 2:
		var y: int = 3 + row * 8
		for col: int in 3:
			var x: int = 5 + col * 8
			Art.ellipse(image, Vector2i(x + 3, y + 6), Vector2i(4, 3), P.LEAF_DARK)
			Art.px(image, x + 3, y + 1, bloom[col])
			Art.px(image, x + 2, y + 2, bloom[col])
			Art.px(image, x + 4, y + 3, bloom[col])
			Art.rect(image, Rect2i(x, y + 7, 7, 4), P.FRUIT_ORANGE)
			Art.h_line(image, x, y + 7, 7, P.ROOF_LIGHT)
	Art.outline(image, P.OUTLINE)
	return image
