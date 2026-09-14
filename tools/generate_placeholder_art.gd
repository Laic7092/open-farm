extends SceneTree
## 占位美术生成器（第一阶段：只产出 PNG）。
##
## 骨架阶段没有任何美术资源，但 [TileMapLayer] / [AnimatedSprite2D] 都需要真实贴图。
## 与其手工塞一堆二进制文件，不如把"像素长什么样"写成代码：
## [br]- 可复现：任何人 clone 之后跑一次脚本就能得到完全相同的图集
## [br]- 可读：改颜色 / 改尺寸直接改这个文件，不需要打开图像编辑器
## [br]- 可替换：真正的美术到位后，删掉本脚本、换成同名 PNG 即可，代码零改动
##
## 用法（必须先用 --import 让 PNG 进入导入管线，再跑 resources 脚本）：
## [codeblock]
## godot --headless --path . -s res://tools/generate_placeholder_art.gd
## [/codeblock]

const TILE: int = 16

const SPRITE_DIR: String = "res://assets/sprites"

# ---------------------------------------------------------------- 调色板
const C_GRASS := Color8(74, 138, 58)
const C_GRASS_DARK := Color8(62, 120, 48)
const C_PATH := Color8(168, 134, 90)
const C_PATH_DARK := Color8(142, 110, 72)
const C_SOIL := Color8(126, 88, 56)
const C_SOIL_DARK := Color8(92, 62, 38)
const C_SOIL_LIGHT := Color8(150, 108, 72)
const C_SOIL_WET := Color8(72, 50, 34)
const C_SOIL_WET_DARK := Color8(50, 32, 20)
const C_SOIL_WET_LIGHT := Color8(92, 68, 48)
const C_WATER := Color8(47, 111, 176)
const C_WATER_LIGHT := Color8(92, 156, 216)
const C_STONE := Color8(140, 140, 146)
const C_STONE_DARK := Color8(104, 104, 112)
const C_WOOD := Color8(152, 108, 64)
const C_WOOD_DARK := Color8(112, 76, 42)
const C_FLOWER_PINK := Color8(226, 96, 118)
const C_FLOWER_YELLOW := Color8(240, 208, 96)
const C_FLOWER_WHITE := Color8(242, 242, 236)
const C_SKIN := Color8(240, 200, 160)
const C_SKIN_DARK := Color8(206, 162, 124)
const C_HAIR := Color8(96, 62, 40)
const C_SHIRT := Color8(60, 96, 176)
const C_SHIRT_DARK := Color8(44, 72, 140)
const C_PANTS := Color8(70, 70, 96)
const C_BOOT := Color8(72, 48, 32)
const C_LEAF := Color8(84, 158, 66)
const C_LEAF_DARK := Color8(56, 116, 46)
const C_FRUIT := Color8(226, 92, 76)
const C_WITHER := Color8(146, 126, 92)
const C_WITHER_DARK := Color8(112, 96, 68)
const C_OUTLINE := Color8(38, 30, 26)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPRITE_DIR))
	_write(_build_tileset(), SPRITE_DIR.path_join("tileset_farm.png"))
	_write(_build_crops(), SPRITE_DIR.path_join("crops.png"))
	_write(_build_player(), SPRITE_DIR.path_join("player.png"))
	_write(_build_npc(), SPRITE_DIR.path_join("npc.png"))
	print("占位美术生成完成 → ", SPRITE_DIR)
	quit()


# ---------------------------------------------------------------- 图集：地形

## 8 列 × 2 行，每格 16×16。排版必须与 [FarmAtlas] 的常量一致。
func _build_tileset() -> Image:
	var image := _new_image(TILE * 8, TILE * 2)
	_draw_grass(image, 0, 0, false)
	_draw_grass(image, 1, 0, true)
	_draw_path(image, 2, 0)
	_draw_soil(image, 3, 0, false)
	_draw_soil(image, 4, 0, true)
	_draw_water(image, 5, 0)
	_draw_stone(image, 6, 0)
	_draw_wood(image, 7, 0)
	_draw_flowers(image, 0, 1)
	_draw_fence(image, 1, 1)
	_draw_bush(image, 2, 1)
	_draw_sign(image, 3, 1)
	return image


func _draw_grass(image: Image, column: int, row: int, alternate: bool) -> void:
	_fill_cell(image, column, row, C_GRASS)
	var points: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(11, 4), Vector2i(4, 9), Vector2i(13, 12), Vector2i(8, 6)
	]
	if alternate:
		points = [
			Vector2i(2, 3), Vector2i(9, 5), Vector2i(5, 11), Vector2i(12, 13), Vector2i(6, 7)
		]
	for offset: Vector2i in points:
		_px(image, column * TILE + offset.x, row * TILE + offset.y, C_GRASS_DARK)


func _draw_path(image: Image, column: int, row: int) -> void:
	_fill_cell(image, column, row, C_PATH)
	for offset: Vector2i in [
		Vector2i(1, 4), Vector2i(6, 2), Vector2i(10, 7), Vector2i(3, 12), Vector2i(13, 11)
	]:
		_px(image, column * TILE + offset.x, row * TILE + offset.y, C_PATH_DARK)


func _draw_soil(image: Image, column: int, row: int, watered: bool) -> void:
	var base: Color = C_SOIL_WET if watered else C_SOIL
	var dark: Color = C_SOIL_WET_DARK if watered else C_SOIL_DARK
	var light: Color = C_SOIL_WET_LIGHT if watered else C_SOIL_LIGHT
	_fill_cell(image, column, row, base)
	var origin := Vector2i(column * TILE, row * TILE)
	# 边框 + 断续垄沟：一眼区分"翻过的地"和普通泥地，湿土整体更深。
	_fill(image, Rect2i(origin.x, origin.y, TILE, 1), dark)
	_fill(image, Rect2i(origin.x, origin.y + TILE - 1, TILE, 1), dark)
	for line: int in [4, 9, 14]:
		_h_line(image, origin.x + 1, origin.y + line, 5, dark)
		_h_line(image, origin.x + 8, origin.y + line, 5, dark)
	# 上沿高光，让土块有体积感。
	_h_line(image, origin.x + 2, origin.y + 2, TILE - 4, light)


func _draw_water(image: Image, column: int, row: int) -> void:
	_fill_cell(image, column, row, C_WATER)
	for offset: Vector2i in [Vector2i(2, 4), Vector2i(9, 6), Vector2i(4, 11), Vector2i(11, 13)]:
		_h_line(image, column * TILE + offset.x, row * TILE + offset.y, 3, C_WATER_LIGHT)


func _draw_stone(image: Image, column: int, row: int) -> void:
	_fill_cell(image, column, row, C_STONE)
	_fill(image, Rect2i(column * TILE + 2, row * TILE + 2, 5, 4), C_STONE_DARK)
	_fill(image, Rect2i(column * TILE + 9, row * TILE + 8, 4, 5), C_STONE_DARK)


func _draw_wood(image: Image, column: int, row: int) -> void:
	_fill_cell(image, column, row, C_WOOD)
	for line: int in [0, 5, 10, 15]:
		_h_line(image, column * TILE, row * TILE + line, TILE, C_WOOD_DARK)


func _draw_flowers(image: Image, column: int, row: int) -> void:
	_draw_grass(image, column, row, false)
	var origin := Vector2i(column * TILE, row * TILE)
	_flower(image, origin + Vector2i(3, 4), C_FLOWER_PINK)
	_flower(image, origin + Vector2i(10, 3), C_FLOWER_YELLOW)
	_flower(image, origin + Vector2i(7, 10), C_FLOWER_WHITE)


func _flower(image: Image, at: Vector2i, color: Color) -> void:
	_px(image, at.x, at.y, color)
	_px(image, at.x + 1, at.y, color)
	_px(image, at.x, at.y + 1, color)
	_px(image, at.x + 1, at.y + 1, C_FLOWER_YELLOW)


func _draw_fence(image: Image, column: int, row: int) -> void:
	_draw_grass(image, column, row, true)
	var origin := Vector2i(column * TILE, row * TILE)
	_fill(image, Rect2i(origin.x + 1, origin.y + 4, 14, 2), C_WOOD)
	_fill(image, Rect2i(origin.x + 1, origin.y + 9, 14, 2), C_WOOD)
	_fill(image, Rect2i(origin.x + 3, origin.y + 2, 3, 12), C_WOOD_DARK)
	_fill(image, Rect2i(origin.x + 10, origin.y + 2, 3, 12), C_WOOD_DARK)


func _draw_bush(image: Image, column: int, row: int) -> void:
	_draw_grass(image, column, row, false)
	var origin := Vector2i(column * TILE, row * TILE)
	# 用三块错位的圆角矩形拼出灌木轮廓，比一整块方形自然。
	_fill(image, Rect2i(origin.x + 3, origin.y + 6, 8, 8), C_LEAF_DARK)
	_fill(image, Rect2i(origin.x + 6, origin.y + 5, 8, 8), C_LEAF_DARK)
	_fill(image, Rect2i(origin.x + 4, origin.y + 7, 7, 6), C_LEAF)
	_fill(image, Rect2i(origin.x + 7, origin.y + 6, 6, 6), C_LEAF)
	_px(image, origin.x + 5, origin.y + 8, C_FLOWER_WHITE)
	_px(image, origin.x + 10, origin.y + 9, C_FLOWER_WHITE)


func _draw_sign(image: Image, column: int, row: int) -> void:
	_draw_grass(image, column, row, true)
	var origin := Vector2i(column * TILE, row * TILE)
	_fill(image, Rect2i(origin.x + 7, origin.y + 8, 2, 6), C_WOOD_DARK)
	_fill(image, Rect2i(origin.x + 2, origin.y + 3, 12, 7), C_WOOD)
	_h_line(image, origin.x + 4, origin.y + 6, 8, C_WOOD_DARK)


# ---------------------------------------------------------------- 图集：作物

## 5 帧：4 个生长阶段 + 1 个枯死形态。帧号与 [Crop] 的逻辑对应。
func _build_crops() -> Image:
	var image := _new_image(TILE * 5, TILE)
	_draw_crop_stage(image, 0, 2, 1, false)
	_draw_crop_stage(image, 1, 3, 3, false)
	_draw_crop_stage(image, 2, 4, 6, false)
	_draw_crop_stage(image, 3, 6, 9, true)
	_draw_withered(image, 4)
	return image


func _draw_crop_stage(
	image: Image, frame: int, stem_height: int, leaf_pairs: int, fruited: bool
) -> void:
	var origin := Vector2i(frame * TILE, 0)
	var ground: int = origin.y + 14
	var stem_x: int = origin.x + 7
	# 茎
	_fill(image, Rect2i(stem_x, ground - stem_height, 2, stem_height), C_LEAF_DARK)
	# 叶
	for index: int in leaf_pairs:
		var y: int = ground - 2 - index * 3
		_fill(image, Rect2i(stem_x - 3, y, 3, 2), C_LEAF)
		_fill(image, Rect2i(stem_x + 2, y, 3, 2), C_LEAF)
	# 成熟后果实
	if fruited:
		_fill(image, Rect2i(stem_x - 3, ground - stem_height - 2, 3, 3), C_FRUIT)
		_fill(image, Rect2i(stem_x + 1, ground - stem_height - 1, 3, 3), C_FRUIT)
		_fill(image, Rect2i(stem_x - 1, ground - stem_height + 2, 3, 3), C_FRUIT)


func _draw_withered(image: Image, frame: int) -> void:
	var origin := Vector2i(frame * TILE, 0)
	var ground: int = origin.y + 14
	_fill(image, Rect2i(origin.x + 7, ground - 7, 2, 7), C_WITHER_DARK)
	_fill(image, Rect2i(origin.x + 3, ground - 8, 4, 2), C_WITHER)
	_fill(image, Rect2i(origin.x + 9, ground - 6, 4, 2), C_WITHER)
	_fill(image, Rect2i(origin.x + 5, ground - 3, 6, 2), C_WITHER_DARK)


# ---------------------------------------------------------------- 图集：玩家

## 4 列 × 3 行，每格 16×16。
## 行：0=朝下、1=朝上、2=朝侧面（左用 flip_h 复用）
## 列：0/1=走路两帧、2=待机、3=挥工具
func _build_player() -> Image:
	var image := _new_image(TILE * 4, TILE * 3)
	for row: int in 3:
		_draw_character(image, 4, row, 0, 0)
		_draw_character(image, 4, row, 1, 1)
		_draw_character(image, 4, row, 2, 0)
		_draw_character(image, 4, row, 3, 2)
	return image


## [param columns] 固定为 4；[param row] 决定朝向，[param pose] 0=站立 1=迈步 2=挥动。
func _draw_character(image: Image, columns: int, row: int, column: int, pose: int) -> void:
	var ox: int = column * TILE
	var oy: int = row * TILE

	# 影子
	_fill(image, Rect2i(ox + 4, oy + 14, 8, 2), Color(0, 0, 0, 0.22))

	# 腿
	var left_leg: int = oy + 11
	var right_leg: int = oy + 11
	if pose == 1:
		left_leg = oy + 10
		right_leg = oy + 12
	_fill(image, Rect2i(ox + 4, left_leg, 3, 3), C_PANTS)
	_fill(image, Rect2i(ox + 9, right_leg, 3, 3), C_PANTS)
	_fill(image, Rect2i(ox + 4, left_leg + 3, 3, 1), C_BOOT)
	_fill(image, Rect2i(ox + 9, right_leg + 3, 3, 1), C_BOOT)

	# 身体
	_fill(image, Rect2i(ox + 4, oy + 6, 8, 6), C_SHIRT)
	_fill(image, Rect2i(ox + 4, oy + 6, 8, 2), C_SHIRT_DARK)

	# 头
	_fill(image, Rect2i(ox + 5, oy + 1, 6, 5), C_SKIN)
	_fill(image, Rect2i(ox + 5, oy + 1, 6, 3), C_HAIR)
	_fill(image, Rect2i(ox + 4, oy + 2, 1, 3), C_HAIR)
	_fill(image, Rect2i(ox + 11, oy + 2, 1, 3), C_HAIR)

	match row:
		0:  # 朝下：画眼睛
			_px(image, ox + 6, oy + 4, C_OUTLINE)
			_px(image, ox + 9, oy + 4, C_OUTLINE)
		1:  # 朝上：后脑勺，没有五官
			_fill(image, Rect2i(ox + 5, oy + 3, 6, 4), C_HAIR)
		2:  # 朝侧面：单只眼睛 + 侧脸
			_px(image, ox + 9, oy + 4, C_OUTLINE)
			_fill(image, Rect2i(ox + 4, oy + 3, 2, 4), C_HAIR)

	# 手臂 / 手持工具
	if pose == 2:
		# 抬手挥动
		_fill(image, Rect2i(ox + 11, oy + 2, 2, 4), C_SKIN)
		_fill(image, Rect2i(ox + 12, oy + 0, 2, 3), C_WOOD)
	else:
		_fill(image, Rect2i(ox + 3, oy + 7, 2, 4), C_SKIN_DARK)
		_fill(image, Rect2i(ox + 11, oy + 7, 2, 4), C_SKIN_DARK)


# ---------------------------------------------------------------- 图集：NPC

## 2 帧 × 1 行：0=站立、1=交替帧（用于轻微的呼吸感）。
func _build_npc() -> Image:
	var image := _new_image(TILE * 2, TILE)
	_draw_npc_frame(image, 0, 0)
	_draw_npc_frame(image, 1, 1)
	return image


func _draw_npc_frame(image: Image, column: int, bob: int) -> void:
	var ox: int = column * TILE
	var oy: int = 0
	_fill(image, Rect2i(ox + 4, oy + 14, 8, 2), Color(0, 0, 0, 0.22))
	_fill(image, Rect2i(ox + 4, oy + 11 + bob, 3, 3), C_PANTS)
	_fill(image, Rect2i(ox + 9, oy + 11 + bob, 3, 3), C_PANTS)
	_fill(image, Rect2i(ox + 4, oy + 6 + bob, 8, 6), C_SHIRT_DARK)
	_fill(image, Rect2i(ox + 5, oy + 1 + bob, 6, 5), C_SKIN)
	_fill(image, Rect2i(ox + 5, oy + 1 + bob, 6, 3), C_WITHER_DARK)
	_px(image, ox + 6, oy + 4 + bob, C_OUTLINE)
	_px(image, ox + 9, oy + 4 + bob, C_OUTLINE)


# ---------------------------------------------------------------- 绘图原语

func _new_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)


func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _h_line(image: Image, x: int, y: int, length: int, color: Color) -> void:
	_fill(image, Rect2i(x, y, length, 1), color)


func _fill_cell(image: Image, column: int, row: int, color: Color) -> void:
	_fill(image, Rect2i(column * TILE, row * TILE, TILE, TILE), color)


func _write(image: Image, path: String) -> void:
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("无法写入 %s（错误码 %d）" % [path, error])
