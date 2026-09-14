extends SceneTree
## 标题页素材生成器 → [code]assets/title/*.png[/code]
##
## 标题背景按 [b]640×360[/b]（项目逻辑分辨率）1:1 生成：
## 这样背景里的一个像素就是一个屏幕像素，与游戏内的 16×16 瓦片同尺度，
## 不会出现"标题页很精细、进游戏变马赛克"的割裂感。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_title.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/title"

## 地平线高度（像素）。
const HORIZON: int = 208


func _initialize() -> void:
	Art.save_png(_backdrop(), DIR.path_join("backdrop.png"))
	Art.save_png(_cloud(64, 22, 0), DIR.path_join("cloud_a.png"))
	Art.save_png(_cloud(96, 26, 1), DIR.path_join("cloud_b.png"))
	Art.save_png(_plate(), DIR.path_join("plate.png"))
	print("标题页素材生成完成 → ", DIR)
	quit()


# ---------------------------------------------------------------- 背景

func _backdrop() -> Image:
	var width: int = Layout.TITLE_VIEWPORT.x
	var height: int = Layout.TITLE_VIEWPORT.y
	var image := Art.new_image(width, height)

	_sky(image, width, height)
	_stars(image, width)
	_sun(image, Vector2i(486, HORIZON - 34))
	_hills(image, width, HORIZON + 6, 26, P.HILL_FAR, 0.0)
	_hills(image, width, HORIZON + 22, 18, P.HILL_NEAR, 1.7)
	_farm(image, width)
	_field(image, width, height)
	_frame(image, width, height)
	return image


## 天空：从黎明的深蓝过渡到地平线的暖橘。
func _sky(image: Image, width: int, height: int) -> void:
	for y in height:
		var t := clampf(float(y) / float(HORIZON), 0.0, 1.0)
		var color: Color = P.SKY_NIGHT.lerp(P.SKY_DAWN, minf(t * 3.0, 1.0))
		color = color.lerp(P.SKY_DUSK, maxf(0.0, (t - 0.45) / 0.55))
		Art.h_line(image, 0, y, width, color)
		if y > HORIZON:
			Art.h_line(image, 0, y, width, P.SKY_DUSK.lerp(P.HILL_FAR, minf(float(y - HORIZON) / 60.0, 1.0)))


## 天上稀疏的星星：用坐标哈希撒点，越靠上越亮。
func _stars(image: Image, width: int) -> void:
	for i in 90:
		var x: int = int(Art.noise(i, 3, 1) * width)
		var y: int = int(Art.noise(i, 7, 2) * 120.0)
		var brightness: float = 1.0 - float(y) / 120.0
		if Art.noise(i, 11, 3) > 0.55:
			continue
		Art.px(image, x, y, Color(P.WHITE.r, P.WHITE.g, P.WHITE.b, brightness * 0.8))


## 朝阳：核心 + 外层暖色光晕。
func _sun(image: Image, center: Vector2i) -> void:
	for ring: int in range(16, 0, -1):
		var t: float = 1.0 - float(ring) / 16.0
		var glow: Color = P.SKY_DUSK.lerp(P.SUN, t)
		Art.circle(image, center, 8 + ring, Color(glow.r, glow.g, glow.b, 0.035 + 0.03 * t))
	Art.circle(image, center, 9, P.SUN)
	Art.circle(image, center, 6, P.SUN_CORE)


## 一层起伏的山丘：几个正弦叠加，保证可复现。
func _hills(
	image: Image, width: int, base_y: int, amplitude: int, color: Color, phase: float
) -> void:
	for x in width:
		var t := float(x) / float(width)
		var wave := (
			sin(t * TAU * 1.5 + phase) * 0.6
			+ sin(t * TAU * 3.7 + phase * 2.0) * 0.3
			+ sin(t * TAU * 7.1 + phase * 3.0) * 0.1
		)
		var top: int = base_y - int(round(wave * float(amplitude)))
		Art.v_line(image, x, top, Layout.TITLE_VIEWPORT.y - top, color)
		Art.px(image, x, top, color.lerp(P.WHITE, 0.18))


## 中景：农场（房子 + 谷仓 + 树），画在地平线附近，营造"这就是你要经营的农场"。
func _farm(image: Image, width: int) -> void:
	var ground: int = HORIZON + 30
	_building(image, Vector2i(112, ground), 44, 34, P.WALL, P.ROOF)
	_building(image, Vector2i(196, ground), 52, 30, P.ROOF_DARK.lerp(P.WALL, 0.2), P.ROOF)
	# 谷仓大门
	Art.rect(image, Rect2i(212, ground - 16, 16, 16), P.WOOD)
	Art.frame_rect(image, Rect2i(212, ground - 16, 16, 16), P.WOOD_DARK)
	# 烟囱的炊烟
	for i in 12:
		var at := Vector2i(146 + int(Art.noise(i, 5, 9) * 3) - 1, ground - 38 - i * 2)
		Art.px(image, at.x, at.y, Color(P.CLOUD.r, P.CLOUD.g, P.CLOUD.b, 0.35 - float(i) * 0.02))
	for tree_x: int in [58, 84, 268, 296, 322]:
		_mini_tree(image, tree_x, ground + 2, 26 + (tree_x % 3) * 4)
	# 田埂小路
	Art.rect(image, Rect2i(0, ground, width, 2), P.PATH_DARK)


func _building(image: Image, foot: Vector2i, width: int, height: int, wall: Color, roof: Color) -> void:
	var top: int = foot.y - height
	Art.rect(image, Rect2i(foot.x, top, width, height), wall)
	Art.scatter(image, Rect2i(foot.x, top, width, height), P.shade(wall, -0.15), 0.12, foot.x)
	# 屋顶
	for row: int in 12:
		var half: int = int(round(lerpf(float(width) / 2.0 - 6.0, float(width) / 2.0 + 3.0, float(row) / 11.0)))
		Art.h_line(image, foot.x + width / 2 - half, top - 12 + row, half * 2, roof)
	Art.h_line(image, foot.x + width / 2 - width / 2 - 3, top, width + 6, P.shade(roof, -0.3))
	# 门窗
	Art.rect(image, Rect2i(foot.x + width / 2 - 4, foot.y - 12, 9, 12), P.WOOD_DARK)
	Art.rect(image, Rect2i(foot.x + 5, top + 6, 8, 7), P.GLASS)
	Art.frame_rect(image, Rect2i(foot.x + 5, top + 6, 8, 7), P.WOOD_DARK)
	Art.rect(image, Rect2i(foot.x + width - 13, top + 6, 8, 7), P.GLASS)
	Art.frame_rect(image, Rect2i(foot.x + width - 13, top + 6, 8, 7), P.WOOD_DARK)


func _mini_tree(image: Image, x: int, ground: int, height: int) -> void:
	var trunk := maxi(height / 3, 4)
	Art.rect(image, Rect2i(x - 1, ground - trunk, 3, trunk), P.TRUNK_DARK)
	Art.ellipse(image, Vector2i(x, ground - trunk - height / 4), Vector2i(height / 4 + 2, height / 3), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(x, ground - trunk - height / 4 - 1), Vector2i(height / 4, height / 3 - 1), P.LEAF)


## 前景：几垄作物 + 栅栏，把视线"钉"在农场上。
func _field(image: Image, width: int, height: int) -> void:
	var top: int = HORIZON + 46
	var bands: int = 5
	for band: int in bands:
		var y: int = top + band * 20
		var soil: Color = P.SOIL.lerp(P.SOIL_DARK, float(band) / float(bands))
		Art.rect(image, Rect2i(0, y, width, 20), soil)
		# 垄沟
		for row: int in 4:
			Art.h_line(image, 0, y + 3 + row * 5, width, P.shade(soil, -0.18))
		# 作物：按列等距摆放，远小近大
		var step: int = 26 - band * 3
		var size: int = 2 + band
		var x: int = 13
		while x < width:
			var sway: int = int(Art.noise(x, y, band) * 3.0) - 1
			_crop(image, Vector2i(x + sway, y + 6), size)
			x += step
		Art.h_line(image, 0, y, width, P.shade(soil, 0.12))
	# 最底部的草皮
	Art.rect(image, Rect2i(0, height - 26, width, 26), P.GRASS_DARK)
	Art.scatter(image, Rect2i(0, height - 26, width, 26), P.GRASS, 0.25, 5)
	# 前景点缀：几丛花，画面底部不至于只是一条绿带。
	for i in 26:
		var x: int = int(Art.noise(i, 17, 4) * float(width))
		var y: int = height - 24 + int(Art.noise(i, 19, 6) * 22.0)
		var color: Color = [P.FLOWER_YELLOW, P.FLOWER_WHITE, P.FLOWER_PINK][i % 3]
		Art.px(image, x, y, color)
		Art.px(image, x + 1, y, color)
		Art.px(image, x, y - 1, P.LEAF_DARK)


func _crop(image: Image, ground: Vector2i, size: int) -> void:
	Art.v_line(image, ground.x, ground.y - size * 2, size * 2, P.LEAF_DARK)
	Art.px(image, ground.x - 1, ground.y - size * 2 + 1, P.LEAF)
	Art.px(image, ground.x + 1, ground.y - size * 2 + 2, P.LEAF)
	Art.px(image, ground.x, ground.y - size * 2, P.LEAF_LIGHT)
	if size > 3:
		Art.px(image, ground.x - 2, ground.y - size, P.FRUIT_RED)
		Art.px(image, ground.x + 2, ground.y - size - 1, P.FRUIT_RED)


## 四周压暗一圈，让中间的标题文字始终读得清。
func _frame(image: Image, width: int, height: int) -> void:
	for i in 60:
		var alpha: float = 0.5 * pow(1.0 - float(i) / 60.0, 1.6)
		var color := Color(0.02, 0.02, 0.06, alpha)
		Art.rect(image, Rect2i(0, i, width, 1), color)
		Art.rect(image, Rect2i(0, height - 1 - i, width, 1), color)
	for i in 44:
		var alpha: float = 0.45 * pow(1.0 - float(i) / 44.0, 1.6)
		var color := Color(0.02, 0.02, 0.06, alpha)
		Art.rect(image, Rect2i(i, 0, 1, height), color)
		Art.rect(image, Rect2i(width - 1 - i, 0, 1, height), color)


# ---------------------------------------------------------------- 飘动的云

func _cloud(width: int, height: int, variant: int) -> Image:
	var image := Art.new_image(width, height)
	var base_y: int = height / 2 + 2
	# 三层错位的椭圆，越上层越亮。
	Art.ellipse(image, Vector2i(width / 2, base_y), Vector2i(width / 2 - 2, height / 3), P.CLOUD_DARK)
	Art.ellipse(
		image,
		Vector2i(width / 2 - (6 if variant == 0 else 10), base_y - height / 3),
		Vector2i(width / 5, height / 4),
		P.CLOUD
	)
	Art.ellipse(
		image,
		Vector2i(width / 2 + (8 if variant == 0 else 12), base_y - height / 4),
		Vector2i(width / 4, height / 4),
		P.CLOUD
	)
	Art.ellipse(image, Vector2i(width / 2, base_y + 1), Vector2i(width / 2 - 2, height / 4), P.CLOUD)
	Art.h_line(image, 3, base_y - height / 3, width - 6, P.WHITE)
	# 底边打薄，云才像云而不是棉花糖。
	for x in width:
		for y in range(base_y + 1, height):
			if Art.noise(x, y, variant) < 0.5:
				Art.px(image, x, y, Color(0, 0, 0, 0))
	return image


# ---------------------------------------------------------------- 标题底板

## 标题文字背后的木质底板（九宫格）。
func _plate() -> Image:
	var size := Layout.TITLE_BANNER_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), P.WOOD_DARK.lerp(P.UI_PANEL, 0.35))
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), P.OUTLINE)
	Art.frame_rect(image, Rect2i(1, 1, size.x - 2, size.y - 2), P.WOOD)
	Art.vertical_gradient(
		image,
		Rect2i(2, 2, size.x - 4, size.y - 4),
		P.WOOD_DARK.lerp(P.UI_GOLD, 0.25),
		P.WOOD_DARK,
		4
	)
	Art.h_line(image, 2, 2, size.x - 4, P.UI_GOLD)
	for corner: Vector2i in [
		Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)
	]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image
