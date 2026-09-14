extends SceneTree
## UI 皮肤生成器 → [code]assets/ui/*.png[/code]
##
## 产出的都是"九宫格贴图"（九宫格切片边距见 [constant AtlasLayout.UI_PATCH_MARGIN]），
## 由 [code]tools/generate_resources.gd[/code] 组装成 [Theme] 里的 [StyleBoxTexture]。
## 于是"整个游戏的按钮长什么样"改的是这里的十几个像素，而不是每个场景的
## [code]theme_override[/code]。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_ui.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/ui"


func _initialize() -> void:
	Art.save_png(_panel(P.UI_PANEL, P.UI_PANEL_DARK, P.UI_PANEL_LIGHT), DIR.path_join("panel.png"))
	Art.save_png(
		_panel(P.UI_PANEL_DARK.lerp(P.UI_BORDER, 0.35), P.UI_BORDER, P.UI_PANEL),
		DIR.path_join("panel_flat.png")
	)
	Art.save_png(_button(P.UI_BUTTON, true), DIR.path_join("button_normal.png"))
	Art.save_png(_button(P.UI_BUTTON_HOVER, true), DIR.path_join("button_hover.png"))
	Art.save_png(_button(P.UI_BUTTON_PRESSED, false), DIR.path_join("button_pressed.png"))
	Art.save_png(_button_focus(), DIR.path_join("button_focus.png"))
	Art.save_png(_button(P.UI_PANEL_DARK.lerp(P.UI_BORDER, 0.6), false), DIR.path_join("button_disabled.png"))
	Art.save_png(_slot(P.UI_SLOT, P.UI_SLOT_HOVER), DIR.path_join("slot.png"))
	Art.save_png(_slot(P.UI_SLOT_HOVER, P.UI_GOLD), DIR.path_join("slot_selected.png"))
	Art.save_png(_bar(P.STAMINA_BACK), DIR.path_join("bar_back.png"))
	Art.save_png(_bar(P.STAMINA_FILL), DIR.path_join("bar_fill.png"))
	Art.save_png(_icon_coin(), DIR.path_join("icon_coin.png"))
	Art.save_png(_icon_stamina(), DIR.path_join("icon_stamina.png"))
	Art.save_png(_icon_heart(), DIR.path_join("icon_heart.png"))
	Art.save_png(_icon_clock(), DIR.path_join("icon_clock.png"))

	var weather := {
		"sunny": _weather_sunny,
		"cloudy": _weather_cloudy,
		"rainy": _weather_rainy,
		"stormy": _weather_stormy,
		"snowy": _weather_snowy,
	}
	for key: String in weather:
		var callable: Callable = weather[key]
		Art.save_png(callable.call(), DIR.path_join("weather_%s.png" % key))

	print("UI 皮肤生成完成 → ", DIR)
	quit()


# ---------------------------------------------------------------- 九宫格

## 通用面板：1 像素描边 + 内层高光 + 中心轻微竖向渐变。
func _panel(base: Color, border: Color, accent: Color) -> Image:
	var size := Layout.UI_PANEL_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), base)
	Art.vertical_gradient(image, Rect2i(1, 1, size.x - 2, size.y - 2), accent.lerp(base, 0.5), base.lerp(border, 0.35), 4)
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), border)
	Art.h_line(image, 1, 1, size.x - 2, accent)
	Art.h_line(image, 1, size.y - 2, size.x - 2, border.lerp(base, 0.5))
	# 四角收一像素，做出圆角
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image


func _button(base: Color, raised: bool) -> Image:
	var size := Layout.UI_BUTTON_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), base)
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), P.UI_BORDER)
	if raised:
		Art.h_line(image, 1, 1, size.x - 2, P.shade(base, 0.35))
		Art.v_line(image, 1, 1, size.y - 2, P.shade(base, 0.25))
		Art.h_line(image, 1, size.y - 2, size.x - 2, P.shade(base, -0.3))
		Art.v_line(image, size.x - 2, 1, size.y - 2, P.shade(base, -0.25))
	else:
		Art.h_line(image, 1, 1, size.x - 2, P.shade(base, -0.3))
		Art.h_line(image, 1, size.y - 2, size.x - 2, P.shade(base, 0.2))
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image


## 键盘焦点：明亮金边，和 hover（鼠标）区分开。
func _button_focus() -> Image:
	var size := Layout.UI_BUTTON_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), P.UI_BUTTON_HOVER)
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), P.UI_GOLD)
	Art.h_line(image, 1, 1, size.x - 2, P.shade(P.UI_BUTTON_HOVER, 0.3))
	for corner: Vector2i in [
		Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)
	]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image


func _slot(base: Color, border: Color) -> Image:
	var size := Layout.UI_SLOT_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), base)
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), P.UI_BORDER)
	Art.frame_rect(image, Rect2i(1, 1, size.x - 2, size.y - 2), border)
	Art.vertical_gradient(image, Rect2i(2, 2, size.x - 4, size.y - 4), P.shade(base, 0.18), P.shade(base, -0.18), 3)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image


## 进度条：8×8，只在纵向拉伸，因此左右各留 2 像素做端帽。
func _bar(color: Color) -> Image:
	var size := Layout.UI_BAR_SIZE
	var image := Art.new_image(size.x, size.y)
	Art.rect(image, Rect2i(0, 0, size.x, size.y), color)
	Art.frame_rect(image, Rect2i(0, 0, size.x, size.y), P.shade(color, -0.45))
	Art.h_line(image, 1, 1, size.x - 2, P.shade(color, 0.35))
	Art.h_line(image, 1, size.y - 2, size.x - 2, P.shade(color, -0.25))
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(size.x - 1, 0), Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1)]:
		Art.px(image, corner.x, corner.y, Color(0, 0, 0, 0))
	return image


# ---------------------------------------------------------------- 小图标（12×12）

func _icon_blank() -> Image:
	return Art.new_image(Layout.UI_ICON_SIZE.x, Layout.UI_ICON_SIZE.y)


func _icon_coin() -> Image:
	var image := _icon_blank()
	Art.circle(image, Vector2i(6, 6), 5, P.COIN_DARK)
	Art.circle(image, Vector2i(6, 6), 4, P.COIN)
	Art.ellipse(image, Vector2i(5, 5), Vector2i(2, 1), P.SUN_CORE)
	Art.px(image, 6, 4, P.COIN_DARK)
	Art.v_line(image, 6, 4, 5, P.COIN_DARK)
	Art.outline(image)
	return image


func _icon_stamina() -> Image:
	var image := _icon_blank()
	# 一片叶子 = 体力
	Art.ellipse(image, Vector2i(6, 6), Vector2i(4, 3), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(6, 6), Vector2i(4, 2), P.LEAF)
	Art.h_line(image, 3, 7, 6, P.LEAF_DARK)
	Art.v_line(image, 6, 3, 8, P.LEAF_LIGHT)
	Art.outline(image)
	return image


func _icon_heart() -> Image:
	var image := _icon_blank()
	Art.ellipse(image, Vector2i(4, 4), Vector2i(2, 2), P.HP_FILL)
	Art.ellipse(image, Vector2i(8, 4), Vector2i(2, 2), P.HP_FILL)
	Art.ellipse(image, Vector2i(6, 6), Vector2i(4, 3), P.HP_FILL)
	Art.px(image, 3, 8, P.HP_FILL)
	Art.px(image, 9, 8, P.HP_FILL)
	Art.px(image, 6, 9, P.HP_FILL)
	Art.px(image, 4, 3, P.FLOWER_PINK)
	Art.outline(image)
	return image


func _icon_clock() -> Image:
	var image := _icon_blank()
	Art.circle(image, Vector2i(6, 6), 5, P.WOOD_DARK)
	Art.circle(image, Vector2i(6, 6), 4, P.WHITE)
	Art.v_line(image, 6, 3, 3, P.OUTLINE)
	Art.h_line(image, 6, 6, 3, P.OUTLINE)
	Art.outline(image)
	return image


# ---------------------------------------------------------------- 天气图标（16×16）

func _weather_blank() -> Image:
	return Art.new_image(Layout.TILE, Layout.TILE)


func _weather_sunny() -> Image:
	var image := _weather_blank()
	Art.circle(image, Vector2i(8, 8), 4, P.SUN_CORE)
	Art.circle(image, Vector2i(8, 8), 3, P.SUN)
	for direction: Vector2i in [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
	]:
		Art.px(image, 8 + direction.x * 6, 8 + direction.y * 6, P.SUN)
		Art.px(image, 8 + direction.x * 5, 8 + direction.y * 5, P.SUN_CORE)
	Art.outline(image)
	return image


func _cloud(image: Image, at: Vector2i, width: int) -> void:
	Art.ellipse(image, at + Vector2i(width / 2, 0), Vector2i(width / 2, 3), P.CLOUD_DARK)
	Art.ellipse(image, at + Vector2i(width / 2, -1), Vector2i(width / 2 - 1, 2), P.CLOUD)
	Art.h_line(image, at.x + 1, at.y - 3, width - 2, P.WHITE)


func _weather_cloudy() -> Image:
	var image := _weather_blank()
	_cloud(image, Vector2i(2, 8), 12)
	Art.outline(image)
	return image


func _weather_rainy() -> Image:
	var image := _weather_blank()
	_cloud(image, Vector2i(2, 6), 12)
	for x: int in [3, 6, 9, 12]:
		Art.v_line(image, x, 10, 3, P.RAIN)
	Art.outline(image)
	return image


func _weather_stormy() -> Image:
	var image := _weather_blank()
	_cloud(image, Vector2i(2, 5), 12)
	# 闪电
	for i in 4:
		Art.px(image, 8 - i / 2, 9 + i, P.SUN)
		Art.px(image, 9 - i / 2, 9 + i, P.SUN_CORE)
	Art.h_line(image, 6, 12, 3, P.SUN)
	Art.px(image, 10, 13, P.SUN)
	Art.outline(image)
	return image


func _weather_snowy() -> Image:
	var image := _weather_blank()
	_cloud(image, Vector2i(2, 5), 12)
	for at: Vector2i in [Vector2i(3, 10), Vector2i(7, 11), Vector2i(11, 10), Vector2i(5, 13), Vector2i(9, 14)]:
		Art.px(image, at.x, at.y, P.SNOW)
		Art.px(image, at.x - 1, at.y, P.SNOW)
		Art.px(image, at.x + 1, at.y, P.SNOW)
		Art.px(image, at.x, at.y - 1, P.SNOW)
		Art.px(image, at.x, at.y + 1, P.SNOW)
	Art.outline(image)
	return image
