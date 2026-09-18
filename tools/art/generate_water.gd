extends SceneTree
## 水体贴图生成器 → [code]assets/sprites/water/<map>_<下标>.png[/code]
##
## 水面不再是地面 TileMap 里的瓦片——瓦片只能拼出 45° 台阶。
## 这里按 [WaterShape] 给的闭合折线逐像素上色，池塘因此可以是不规则的自然水塘：
## [br]- [b]俯视视角[/b]：岸线一圈浪花，往中间水越来越深（浅 → 中 → 深三档）
## [br]- [b]岸沿挡光[/b]：左上内侧压一条暗带（岸比水面高），右下内侧提一点亮
## [br]- [b]确定性[/b]：噪点用 [code]Art.noise[/code] 坐标哈希，不用随机数
##
## 形状与落位由 [WaterLayout] 声明，运行期 [WaterField] 按同一份数据建碰撞、判格。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_water.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const P := preload("res://src/art/palette.gd")
const WaterShape := preload("res://src/world/water_shape.gd")
const WaterLayout := preload("res://src/world/water_layout.gd")

## 岸沿暗带 / 受光带的平移量（像素）：光照方向与全项目的"左上受光"一致。
const SHADOW_SHIFT := Vector2(2.0, 3.0)
const LIGHT_SHIFT := Vector2(-2.0, -3.0)
## 浪花带宽度（像素）与"断断续续"的概率。
const FOAM_WIDTH: float = 1.6
const FOAM_CHANCE: float = 0.78
## 深浅分档的距离阈值（像素）。
const SHALLOW_DEPTH: float = 2.5
const MID_DEPTH: float = 8.0
const DEEP_DEPTH: float = 16.0


func _initialize() -> void:
	for world_id: StringName in WaterLayout.worlds():
		var bodies := WaterLayout.bodies_for(world_id)
		for index: int in bodies.size():
			var path := WaterLayout.sprite_path(world_id, index)
			Art.save_png(_render(bodies[index]), path)
	print("水体贴图生成完成 → ", WaterLayout.DIR)
	quit()


# ---------------------------------------------------------------- 绘制

## 把一片水烘成一张贴图；[code]body.pixel_bounds()[/code] 决定画布与落位。
func _render(body: WaterLayout.Body) -> Image:
	var bounds := body.pixel_bounds()
	var image := Art.new_image(bounds.size.x, bounds.size.y)
	var origin := Vector2(bounds.position)
	var outline := _shift(body.outline, -origin)
	var shadow := _shift(body.outline, -origin + SHADOW_SHIFT)
	var light := _shift(body.outline, -origin + LIGHT_SHIFT)
	var salt: int = bounds.position.x * 3 + bounds.position.y * 5

	for y: int in bounds.size.y:
		for x: int in bounds.size.x:
			# 像素中心判定：0.5 的偏移让"岸线正好压在像素边界"时不会两边都算。
			var point := Vector2(float(x), float(y)) + Vector2(0.5, 0.5)
			if not Geometry2D.is_point_in_polygon(point, outline):
				continue
			var depth := WaterShape.distance_to_outline(outline, point)
			var color := _depth_color(depth)
			# 岸沿挡光：落在"平移后的岸线"之外的像素，就是左上那条暗带。
			if not Geometry2D.is_point_in_polygon(point, shadow):
				color = color.lerp(P.WATER_SHADOW, 0.55)
			elif not Geometry2D.is_point_in_polygon(point, light):
				color = color.lerp(P.WATER_LIGHT, 0.30)
			# 浪花：贴着岸线的一圈白点，用噪声打断，免得像描了一圈边框。
			if depth < FOAM_WIDTH and Art.noise(x, y, salt) < FOAM_CHANCE:
				color = P.WATER_FOAM
			elif depth < FOAM_WIDTH + 2.0 and Art.noise(x, y, salt + 7) < 0.12:
				color = P.WATER_FOAM
			Art.px(image, x, y, color)
	return image


## 离岸越远水越深：浅水受光偏亮，中间回到本色，深处压暗。
func _depth_color(depth: float) -> Color:
	if depth < SHALLOW_DEPTH:
		return P.WATER_LIGHT
	if depth < MID_DEPTH:
		return P.WATER
	if depth < DEEP_DEPTH:
		return P.WATER.lerp(P.WATER_DARK, (depth - MID_DEPTH) / (DEEP_DEPTH - MID_DEPTH))
	return P.WATER_DARK


func _shift(polygon: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in polygon:
		points.append(point + delta)
	return points
