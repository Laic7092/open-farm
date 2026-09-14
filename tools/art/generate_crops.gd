extends SceneTree
## 作物图集生成器 → [code]assets/sprites/crops/<crop_id>.png[/code]
##
## 每种作物一张 5 帧图（4 个生长阶段 + 1 个枯死形态），
## 帧号与 [CropGrowth.stage_of] 一一对应，坐标见 [AtlasLayout]。
##
## 与地表 / 角色不同，作物[b]按 id 一图一文件[/b]：
## 这样"新增一种作物"= 往目录里丢一个 `.tres` + 跑一次生成器，
## 而不是所有作物挤在一张图集里互相牵连。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_crops.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/crops"

## 作物外观表：id → 形状 + 颜色。
## 形状只有三种（球根 / 丛生 / 藤架），足够覆盖当前作物；
## 新增作物时先挑一个形状，再调颜色即可。
const CROPS := {
	&"turnip": {
		"shape": "bulb",
		"leaf": P.LEAF,
		"leaf_dark": P.LEAF_DARK,
		"fruit": P.FLOWER_WHITE,
		"fruit_dark": P.APRON,
	},
	&"potato": {
		"shape": "bush",
		"leaf": P.LEAF,
		"leaf_dark": P.LEAF_DARK,
		"fruit": P.SOIL_LIGHT,
		"fruit_dark": P.SOIL_DARK,
	},
	&"tomato": {
		"shape": "vine",
		"leaf": P.LEAF_DARK,
		"leaf_dark": P.LEAF,
		"fruit": P.FRUIT_RED,
		"fruit_dark": P.ROOF_DARK,
	},
}


func _initialize() -> void:
	for crop_id: StringName in CROPS:
		var config: Dictionary = CROPS[crop_id]
		Art.save_png(_build_crop(config), DIR.path_join("%s.png" % crop_id))
	print("作物图集生成完成（%d 种）→ %s" % [CROPS.size(), DIR])
	quit()


func _build_crop(config: Dictionary) -> Image:
	var image := Art.new_image(Layout.CROP_SIZE.x, Layout.CROP_SIZE.y)
	var shape: String = config.get("shape", "bush")
	for column: int in 4:
		match shape:
			"bulb":
				_bulb_stage(image, column, config)
			"vine":
				_vine_stage(image, column, config)
			_:
				_bush_stage(image, column, config)
	_withered(image, Layout.CROP_WITHERED_COLUMN)
	return image


# ---------------------------------------------------------------- 形状

## 球根类（萝卜）：地上只有叶，成熟时露出圆球根。
func _bulb_stage(image: Image, column: int, config: Dictionary) -> void:
	var origin := _origin(column)
	var leaf: Color = config["leaf"]
	var leaf_dark: Color = config["leaf_dark"]
	var fruit: Color = config["fruit"]
	var fruit_dark: Color = config["fruit_dark"]
	var ground: int = origin.y + 13

	match column:
		0:
			_sprout(image, origin, leaf, leaf_dark)
		1:
			_leaves(image, origin + Vector2i(8, ground), 3, 4, leaf, leaf_dark)
		2:
			_leaves(image, origin + Vector2i(8, ground), 4, 6, leaf, leaf_dark)
		_:
			# 成熟：土里冒出一个带横纹的白球根。
			Art.ellipse(image, origin + Vector2i(8, ground - 2), Vector2i(4, 4), fruit_dark)
			Art.ellipse(image, origin + Vector2i(8, ground - 3), Vector2i(4, 3), fruit)
			Art.h_line(image, origin.x + 5, origin.y + 11, 7, fruit_dark)
			Art.px(image, origin.x + 6, origin.y + 13, fruit_dark)
			_leaves(image, origin + Vector2i(8, ground), 5, 8, leaf, leaf_dark)


## 丛生类（土豆）：矮而密的叶子，成熟时土面露出块茎。
func _bush_stage(image: Image, column: int, config: Dictionary) -> void:
	var origin := _origin(column)
	var leaf: Color = config["leaf"]
	var leaf_dark: Color = config["leaf_dark"]
	var fruit: Color = config["fruit"]
	var fruit_dark: Color = config["fruit_dark"]
	var ground: int = origin.y + 13

	match column:
		0:
			_sprout(image, origin, leaf, leaf_dark)
		1:
			_bush(image, origin + Vector2i(8, ground), 4, leaf, leaf_dark)
		2:
			_bush(image, origin + Vector2i(8, ground), 6, leaf, leaf_dark)
		_:
			_bush(image, origin + Vector2i(8, ground), 7, leaf, leaf_dark)
			# 露出地面的块茎
			Art.ellipse(image, origin + Vector2i(5, ground - 1), Vector2i(2, 1), fruit_dark)
			Art.ellipse(image, origin + Vector2i(5, ground - 1), Vector2i(1, 1), fruit)
			Art.ellipse(image, origin + Vector2i(11, ground), Vector2i(2, 1), fruit_dark)


## 藤架类（番茄）：一根立茎 + 侧枝，成熟时挂上红果。
func _vine_stage(image: Image, column: int, config: Dictionary) -> void:
	var origin := _origin(column)
	var leaf: Color = config["leaf"]
	var leaf_dark: Color = config["leaf_dark"]
	var fruit: Color = config["fruit"]
	var fruit_dark: Color = config["fruit_dark"]
	var ground: int = origin.y + 14
	var stem_x: int = origin.x + 8
	var stem: int = [1, 5, 8, 10][column]

	match column:
		0:
			_sprout(image, origin, leaf, leaf_dark)
		_:
			Art.v_line(image, stem_x, ground - stem, stem, leaf_dark)
			_vine_pairs(image, Vector2i(stem_x, ground), int(stem / 3) + 1, leaf, leaf_dark)
			Art.px(image, stem_x, ground - stem, P.LEAF_LIGHT)

	if column == 3:
		for at: Vector2i in [Vector2i(-3, -4), Vector2i(2, -6), Vector2i(-1, -9)]:
			var p := Vector2i(stem_x + at.x, ground + at.y)
			Art.ellipse(image, p, Vector2i(2, 2), fruit_dark)
			Art.ellipse(image, p, Vector2i(1, 1), fruit)
			Art.px(image, p.x - 1, p.y - 1, P.FRUIT_ORANGE)


# ---------------------------------------------------------------- 零件

func _origin(column: int) -> Vector2i:
	return Vector2i(column * Layout.TILE, 0)


## 刚破土：两片小叶。
func _sprout(image: Image, origin: Vector2i, leaf: Color, leaf_dark: Color) -> void:
	var at := origin + Vector2i(8, 13)
	Art.v_line(image, at.x, at.y - 2, 3, leaf_dark)
	Art.px(image, at.x - 1, at.y - 3, leaf)
	Art.px(image, at.x - 2, at.y - 4, leaf)
	Art.px(image, at.x + 1, at.y - 3, leaf)
	Art.px(image, at.x + 2, at.y - 4, leaf)


## 从地面长出的斜向对生叶——比横条更像植物。
##
## 叶片沿茎的高度均匀分布（而不是每层固定 2 像素），
## 这样"矮壮的萝卜叶"和"高挑的番茄"可以共用同一个函数。
func _leaves(
	image: Image, ground: Vector2i, pairs: int, height: int, leaf: Color, leaf_dark: Color
) -> void:
	Art.v_line(image, ground.x, ground.y - height, height, leaf_dark)
	var step: float = float(maxi(height, 1)) / float(maxi(pairs, 1))
	for index: int in pairs:
		var y: int = ground.y - 1 - int(round(float(index) * step))
		Art.px(image, ground.x - 1, y, leaf)
		Art.px(image, ground.x - 2, y - 1, leaf)
		Art.px(image, ground.x - 3, y - 1, leaf_dark)
		Art.px(image, ground.x + 1, y, leaf)
		Art.px(image, ground.x + 2, y - 1, leaf)
		Art.px(image, ground.x + 3, y - 1, leaf_dark)
	Art.px(image, ground.x, ground.y - height - 1, P.LEAF_LIGHT)


## 藤架类：主茎 + 左右交替的侧枝。
func _vine_pairs(
	image: Image, ground: Vector2i, levels: int, leaf: Color, leaf_dark: Color
) -> void:
	for level: int in levels:
		var y: int = ground.y - 3 - level * 3
		var direction: int = -1 if level % 2 == 0 else 1
		Art.px(image, ground.x + direction, y, leaf_dark)
		Art.px(image, ground.x + direction * 2, y - 1, leaf)
		Art.px(image, ground.x + direction * 2, y - 2, leaf)
		Art.px(image, ground.x + direction * 3, y - 2, leaf_dark)
		Art.px(image, ground.x + direction * 3, y - 3, leaf)


## 一丛矮叶。
func _bush(
	image: Image, ground: Vector2i, radius: int, leaf: Color, leaf_dark: Color
) -> void:
	Art.ellipse(image, Vector2i(ground.x, ground.y - radius / 2), Vector2i(radius, radius - 1), leaf_dark)
	Art.ellipse(image, Vector2i(ground.x, ground.y - radius / 2 - 1), Vector2i(radius - 1, radius - 2), leaf)
	Art.h_line(image, ground.x - radius + 2, ground.y - radius + 1, maxi(radius - 1, 1), P.LEAF_LIGHT)


## 枯死形态：统一用枯黄，与 [Crop.WITHERED_FRAME] 对应。
func _withered(image: Image, column: int) -> void:
	var origin := _origin(column)
	var ground: int = origin.y + 14
	Art.v_line(image, origin.x + 8, ground - 8, 8, P.WITHER_DARK)
	Art.h_line(image, origin.x + 3, ground - 9, 4, P.WITHER)
	Art.h_line(image, origin.x + 9, ground - 6, 4, P.WITHER)
	Art.h_line(image, origin.x + 5, ground - 3, 6, P.WITHER_DARK)
	Art.px(image, origin.x + 6, ground - 10, P.WITHER)
	Art.px(image, origin.x + 11, ground - 8, P.WITHER_DARK)
