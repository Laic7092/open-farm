extends SceneTree
## 手持工具生成器 → [code]assets/sprites/tools/<tool_id>.png[/code]
##
## 角色挥动时手里那件工具的[b]大图[/b]（16×24，宽 1 格、长 1.5 格），
## 竖直摆放：工具头朝上、握柄在底部中心。[code]HeldToolView[/code] 以握柄为轴心
## 旋转，挥动因此是"转出来"的，不需要每件工具一套逐帧图。
##
## 与 [code]generate_items.gd[/code] 的 16×16 背包图标分工不同：
## 图标是斜握的小图，这里是竖握、有辨识度的大图。两者共享调色板。
##
## 形状按 [enum ToolData.Kind] 分（锄 / 斧 / 镐 / 壶 / 镰 / 竿），
## 铜 / 铁升级只换工具头的金属色——与 [code]data/tools/*.tres[/code] 的 id 一一对应。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_tools.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

## 每种金属一套「基底 / 暗部 / 亮部」。基础工具是铁灰色，铜 / 铁升级换色。
const METALS := {
	"steel": [P.STONE, P.STONE_DARK, P.STONE_LIGHT],
	"copper": [P.COPPER, P.COPPER_DARK, P.COPPER_LIGHT],
	"iron": [P.IRON, P.IRON_DARK, P.IRON_LIGHT],
}

## 工具 id → [形状, 金属]；新增工具时在这里加一条。
const TOOL_LOOKS := {
	&"hoe": ["hoe", "steel"],
	&"hoe_copper": ["hoe", "copper"],
	&"hoe_iron": ["hoe", "iron"],
	&"axe": ["axe", "steel"],
	&"axe_copper": ["axe", "copper"],
	&"axe_iron": ["axe", "iron"],
	&"pickaxe": ["pickaxe", "steel"],
	&"pickaxe_copper": ["pickaxe", "copper"],
	&"pickaxe_iron": ["pickaxe", "iron"],
	&"watering_can": ["watering_can", "steel"],
	&"watering_can_copper": ["watering_can", "copper"],
	&"watering_can_iron": ["watering_can", "iron"],
	&"sickle": ["sickle", "steel"],
	&"fishing_rod": ["fishing_rod", "steel"],
}

## 工具头的中心列；握柄绕它摆动。
const GRIP_X: int = 8
## 贴图最底一行（握柄末端）。
const GRIP_Y: int = 23


func _initialize() -> void:
	for tool_id: StringName in TOOL_LOOKS:
		var look: Array = TOOL_LOOKS[tool_id]
		var metal: Array = METALS[look[1]]
		var image: Image = _shape(look[0], metal[0], metal[1], metal[2])
		Art.save_png(image, Layout.TOOL_DIR.path_join("%s.png" % tool_id))
	print("手持工具生成完成 → ", Layout.TOOL_DIR)
	quit()


func _blank() -> Image:
	return Art.new_image(Layout.TOOL_SPRITE_SIZE.x, Layout.TOOL_SPRITE_SIZE.y)


func _shape(shape: String, metal: Color, dark: Color, light: Color) -> Image:
	var image := _blank()
	match shape:
		"hoe":
			_hoe(image, metal, dark, light)
		"axe":
			_axe(image, metal, dark, light)
		"pickaxe":
			_pickaxe(image, metal, dark, light)
		"watering_can":
			_watering_can(image, metal, dark, light)
		"sickle":
			_sickle(image, metal, dark, light)
		"fishing_rod":
			_fishing_rod(image)
	Art.outline(image)
	return image


## 从 [param top_y] 往下到握柄末端的木柄。
func _handle(image: Image, top_y: int) -> void:
	var height: int = GRIP_Y + 1 - top_y
	Art.rect(image, Rect2i(GRIP_X - 1, top_y, 2, height), P.WOOD)
	Art.v_line(image, GRIP_X, top_y, height, P.WOOD_DARK)
	# 掌心一段包一层深色握把。
	Art.rect(image, Rect2i(GRIP_X - 1, 18, 2, 5), P.WOOD_DARK)
	Art.px(image, GRIP_X - 1, 18, P.WOOD)


# ---------------------------------------------------------------- 各种工具

## 锄：木柄顶端一块横向金属板，末端向下折出刃口。
func _hoe(image: Image, metal: Color, dark: Color, light: Color) -> void:
	_handle(image, 9)
	Art.rect(image, Rect2i(3, 5, 10, 3), metal)
	Art.h_line(image, 3, 5, 10, light)
	Art.h_line(image, 3, 7, 10, dark)
	Art.rect(image, Rect2i(11, 8, 3, 4), metal)
	Art.rect(image, Rect2i(11, 10, 3, 2), dark)


## 斧：木柄右侧一块楔形斧刃，刃口在外弧。
func _axe(image: Image, metal: Color, dark: Color, light: Color) -> void:
	_handle(image, 9)
	Art.quad(image, Vector2(7, 4), Vector2(14, 7), Vector2(14, 12), Vector2(7, 15), metal)
	Art.quad(image, Vector2(7, 4), Vector2(11, 6), Vector2(11, 13), Vector2(7, 15), dark)
	Art.quad(image, Vector2(10, 5), Vector2(14, 7), Vector2(14, 8), Vector2(10, 7), light)
	Art.v_line(image, 13, 8, 4, light)
	Art.px(image, 14, 9, light)
	Art.px(image, 14, 10, light)


## 镐：木柄顶端一根两头翘起的横镐，两端收尖。
func _pickaxe(image: Image, metal: Color, dark: Color, light: Color) -> void:
	_handle(image, 9)
	Art.rect(image, Rect2i(2, 7, 12, 2), metal)
	Art.h_line(image, 3, 7, 10, light)
	Art.h_line(image, 2, 8, 12, dark)
	Art.px(image, 1, 6, light)
	Art.px(image, 0, 5, metal)
	Art.px(image, 14, 6, light)
	Art.px(image, 15, 5, metal)


## 洒水壶：壶身 + 左上壶嘴 + 顶部提手；握在壶底。
func _watering_can(image: Image, metal: Color, dark: Color, light: Color) -> void:
	# 壶身
	Art.rect(image, Rect2i(4, 9, 9, 11), P.WATER_DARK)
	Art.rect(image, Rect2i(5, 10, 7, 9), P.WATER)
	Art.h_line(image, 5, 10, 7, P.WATER_LIGHT)
	Art.rect(image, Rect2i(5, 18, 7, 1), dark)
	# 壶嘴
	Art.rect(image, Rect2i(1, 7, 4, 3), P.WATER_DARK)
	Art.px(image, 0, 6, P.WATER_LIGHT)
	Art.px(image, 1, 6, P.WATER)
	# 提手
	Art.h_line(image, 5, 6, 8, P.WOOD_DARK)
	Art.v_line(image, 5, 7, 2, P.WOOD_DARK)
	Art.v_line(image, 12, 7, 2, P.WOOD_DARK)
	# 底部握把
	Art.rect(image, Rect2i(6, 20, 5, 3), P.WOOD_DARK)
	Art.h_line(image, 6, 20, 5, P.WOOD)


## 镰：短木柄顶端一弯新月刃，刃口朝外。
func _sickle(image: Image, metal: Color, dark: Color, light: Color) -> void:
	_handle(image, 15)
	var arc: Array[Vector2i] = [
		Vector2i(7, 13), Vector2i(5, 12), Vector2i(4, 10), Vector2i(4, 8),
		Vector2i(6, 6), Vector2i(9, 5), Vector2i(12, 5), Vector2i(14, 6),
	]
	for i: int in arc.size() - 1:
		var from := Vector2(arc[i])
		var to := Vector2(arc[i + 1])
		Art.line(image, from, to, light)
		Art.line(image, from + Vector2(0, 1), to + Vector2(0, 1), metal)
	Art.px(image, 14, 7, dark)
	Art.px(image, 13, 5, light)


## 钓竿：细长竿身微微倾斜，近手处一个卷线器。
func _fishing_rod(image: Image) -> void:
	for i: int in GRIP_Y:
		var x: int = GRIP_X - i / 6
		Art.px(image, x, GRIP_Y - i, P.WOOD)
		Art.px(image, x + 1, GRIP_Y - i, P.WOOD_DARK)
	# 卷线器
	Art.ellipse(image, Vector2i(GRIP_X + 1, 17), Vector2i(2, 1), P.STONE_DARK)
	Art.px(image, GRIP_X, 16, P.STONE_LIGHT)
	# 竿尖
	Art.px(image, GRIP_X - 3, 0, P.STONE_LIGHT)
