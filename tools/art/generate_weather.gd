extends SceneTree
## 天气特效贴图生成器 → [code]assets/sprites/weather/*.png[/code]
##
## 供 [code]src/world/weather_fx.gd[/code] 的粒子系统使用。
## 粒子贴图必须小（几个像素）且 [b]可平铺[/b]：
## 放大到几百个粒子时，任何一点规律都会被看出来。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_weather.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/weather"


func _initialize() -> void:
	Art.save_png(_rain_drop(), DIR.path_join("rain_drop.png"))
	Art.save_png(_snow_flake(), DIR.path_join("snow_flake.png"))
	Art.save_png(_leaf(), DIR.path_join("leaf.png"))
	Art.save_png(_sunburst(), DIR.path_join("sunburst.png"))
	print("天气特效贴图生成完成 → ", DIR)
	quit()


## 雨丝：上淡下浓的一道斜线。
func _rain_drop() -> Image:
	var image := Art.new_image(3, 10)
	for i in 10:
		var alpha: float = 0.35 + 0.65 * float(i) / 9.0
		var color := Color(P.RAIN.r, P.RAIN.g, P.RAIN.b, alpha)
		Art.px(image, 1, i, color)
		if i > 3:
			Art.px(image, 0, i - 1, Color(P.RAIN.r, P.RAIN.g, P.RAIN.b, alpha * 0.5))
	return image


## 雪花：十字 + 中心点。
func _snow_flake() -> Image:
	var image := Art.new_image(5, 5)
	Art.h_line(image, 0, 2, 5, P.SNOW)
	Art.v_line(image, 2, 0, 5, P.SNOW)
	Art.px(image, 1, 1, Color(P.SNOW.r, P.SNOW.g, P.SNOW.b, 0.7))
	Art.px(image, 3, 3, Color(P.SNOW.r, P.SNOW.g, P.SNOW.b, 0.7))
	Art.px(image, 2, 2, P.WHITE)
	return image


## 落叶：暴风雨里的琐碎飘落物。
func _leaf() -> Image:
	var image := Art.new_image(6, 6)
	Art.ellipse(image, Vector2i(3, 3), Vector2i(2, 1), P.LEAF_DARK)
	Art.ellipse(image, Vector2i(2, 3), Vector2i(1, 1), P.LEAF_LIGHT)
	Art.px(image, 5, 3, P.TRUNK_DARK)
	return image


## 阳光：一圈放射状光晕，晴天叠加在画面上。
func _sunburst() -> Image:
	var image := Art.new_image(32, 32)
	for ring: int in 3:
		var radius: int = 16 - ring * 3
		for step: int in 12:
			var angle := TAU * float(step) / 12.0 + ring * 0.26
			var at := Vector2i(16, 16) + Vector2i(int(round(cos(angle) * radius)), int(round(sin(angle) * radius)))
			Art.px(image, at.x, at.y, Color(P.SUN.r, P.SUN.g, P.SUN.b, 0.28 - ring * 0.06))
	return image
