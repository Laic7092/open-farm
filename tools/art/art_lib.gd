extends RefCounted
## 像素画生成基座：所有 [code]tools/art/generate_*.gd[/code] 共用的绘图原语。
##
## 为什么不直接在生成器里调 [method Image.set_pixel]：
## [br]1. [b]越界静默[/b]——手写像素画时算错一两个坐标是常态，越界必须画在画布上
##    而不是抛异常中断整个生成流程。
## [br]2. [b]确定性[/b]——[method noise] 用坐标哈希而不是 [RandomNumberGenerator]，
##    保证"同一份代码在任何机器、任何次数下都生成逐像素相同的 PNG"。
## [br]3. [b]轮廓与投影[/b]——像素风的"描边 + 落地阴影"是重复度最高的两段逻辑，
##    统一在这里实现，新素材自然风格一致。
##
## 用法：
## [codeblock]
## const Art := preload("res://tools/art/art_lib.gd")
## var img := Art.new_image(32, 32)
## Art.rect(img, Rect2i(0, 0, 8, 8), ArtPalette.LEAF)
## Art.outline(img, ArtPalette.OUTLINE)
## Art.save_png(img, "res://assets/sprites/props/tree.png")
## [/codeblock]

const Palette := preload("res://src/art/palette.gd")


# ---------------------------------------------------------------- 画布

## 新建一张全透明画布。
static func new_image(width: int, height: int, fill: Color = Color(0, 0, 0, 0)) -> Image:
	var image := Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	if fill.a > 0.0:
		image.fill(fill)
	return image


## 在 [param image] 上写入一个像素；越界时静默忽略。
static func px(image: Image, x: int, y: int, color: Color) -> void:
	if color.a <= 0.0:
		return
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)


## 读取一个像素；越界时返回透明色。
static func get_px(image: Image, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return Color(0, 0, 0, 0)
	return image.get_pixel(x, y)


## 实心矩形。
static func rect(image: Image, area: Rect2i, color: Color) -> void:
	if color.a <= 0.0:
		return
	image.fill_rect(area.intersection(Rect2i(0, 0, image.get_width(), image.get_height())), color)


## 空心矩形（1 像素描边）。
static func frame_rect(image: Image, area: Rect2i, color: Color) -> void:
	rect(image, Rect2i(area.position.x, area.position.y, area.size.x, 1), color)
	rect(image, Rect2i(area.position.x, area.end.y - 1, area.size.x, 1), color)
	rect(image, Rect2i(area.position.x, area.position.y, 1, area.size.y), color)
	rect(image, Rect2i(area.end.x - 1, area.position.y, 1, area.size.y), color)


static func h_line(image: Image, x: int, y: int, length: int, color: Color) -> void:
	rect(image, Rect2i(x, y, length, 1), color)


static func v_line(image: Image, x: int, y: int, length: int, color: Color) -> void:
	rect(image, Rect2i(x, y, 1, length), color)


## 实心椭圆（像素画的"圆"）。
static func ellipse(image: Image, center: Vector2i, radius: Vector2i, color: Color) -> void:
	if color.a <= 0.0 or radius.x <= 0 or radius.y <= 0:
		return
	for y in range(-radius.y, radius.y + 1):
		var t := float(y) / float(radius.y)
		var span := int(floor(float(radius.x) * sqrt(maxf(0.0, 1.0 - t * t))))
		if span <= 0:
			px(image, center.x, center.y + y, color)
			continue
		h_line(image, center.x - span, center.y + y, span * 2 + 1, color)


## 实心圆。
static func circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	ellipse(image, center, Vector2i(radius, radius), color)


## 两端收一个像素的"胶囊"横条，比矩形更像手绘。
static func bar(image: Image, x: int, y: int, length: int, color: Color) -> void:
	h_line(image, x + 1, y, maxi(length - 2, 1), color)
	px(image, x, y, color)
	px(image, x + length - 1, y, color)


## 从底部往上收窄的梯形（树干 / 屋顶 / 花盆都靠它）。
static func taper(image: Image, top: Vector2i, height: int, top_width: int, bottom_width: int, color: Color) -> void:
	for i in height:
		var t := float(i) / float(maxi(height - 1, 1))
		var width := int(round(lerpf(float(top_width), float(bottom_width), t)))
		h_line(image, top.x - width / 2, top.y + i, maxi(width, 1), color)


# ---------------------------------------------------------------- 质感

## 确定性伪随机：同样的坐标永远得到同样的值（0.0 ~ 1.0）。
##
## 用它而不是 RNG，是为了让"撒噪点"这类装饰在任何时候重跑都得到同一张图，
## 否则每次跑 [code]build_assets.sh[/code] 都会产生一堆无意义的二进制 diff。
static func noise(x: int, y: int, salt: int = 0) -> float:
	var h: int = x * 374761393 + y * 668265263 + salt * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0


## 按 [param chance] 的概率在矩形内撒 [param color] 噪点。
static func scatter(
	image: Image, area: Rect2i, color: Color, chance: float, salt: int = 0
) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if noise(x, y, salt) < chance:
				px(image, x, y, color)


## 交错网点（棋盘格），用于区分同色材质。
static func checker(image: Image, area: Rect2i, color: Color, salt: int = 0) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if (x + y) % 2 == 0:
				px(image, x, y, color)
			elif noise(x, y, salt) < 0.25:
				px(image, x, y, color)


## 水平纹理条（木纹 / 垄沟 / 瓦片）。
static func stripes(
	image: Image, area: Rect2i, color: Color, spacing: int, offset: int = 0
) -> void:
	var y: int = area.position.y + offset
	while y < area.end.y:
		h_line(image, area.position.x, y, area.size.x, color)
		y += maxi(spacing, 1)


## 上下渐变的底色（天空 / 水面）。
static func vertical_gradient(
	image: Image, area: Rect2i, top: Color, bottom: Color, steps: int = 0
) -> void:
	var height: int = maxi(area.size.y, 1)
	for i in height:
		var t := float(i) / float(maxi(height - 1, 1))
		var color := top.lerp(bottom, t)
		if steps > 0:
			color = color.lerp(top if t < 0.5 else bottom, 0.35)
		h_line(image, area.position.x, area.position.y + i, area.size.x, color)


# ---------------------------------------------------------------- 后期

## 给所有不透明像素的外沿补一圈描边。
##
## [param alpha_threshold] 用来忽略半透明像素（例如落地阴影）。
static func outline(
	image: Image, color: Color = Palette.OUTLINE, alpha_threshold: float = 0.6
) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var source := image.duplicate() as Image
	for y in height:
		for x in width:
			if get_px(source, x, y).a >= alpha_threshold:
				continue
			var touches := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if get_px(source, x + offset.x, y + offset.y).a >= alpha_threshold:
					touches = true
					break
			if touches:
				px(image, x, y, color)


## 在底部补一个椭圆投影（[param height] 是素材高度）。
static func ground_shadow(image: Image, width: int, height: int, inset: int = 3) -> void:
	var radius := maxi((width - inset * 2) / 2, 1)
	ellipse(image, Vector2i(width / 2, height - 2), Vector2i(radius, 1), Palette.SHADOW)


## 把 [param source] 贴到 [param target] 的 (x, y)，只覆盖不透明像素。
static func blit(target: Image, source: Image, at: Vector2i) -> void:
	var width := source.get_width()
	var height := source.get_height()
	for y in height:
		for x in width:
			var color := source.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			px(target, at.x + x, at.y + y, color)


## 把源图水平翻转后贴过去（做左向角色）。
static func blit_flipped(target: Image, source: Image, at: Vector2i) -> void:
	var flipped := source.duplicate() as Image
	flipped.flip_x()
	blit(target, flipped, at)


# ---------------------------------------------------------------- 输出

## 写 PNG，目录不存在时自动创建。返回是否成功。
static func save_png(image: Image, path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := image.save_png(path)
	if error != OK:
		push_error("ArtLib: 无法写入 %s（错误码 %d）" % [path, error])
		return false
	print("  → ", path, "  ", image.get_size())
	return true
