extends SceneTree
## 角色图集生成器 → [code]assets/sprites/actors/*.png[/code]
##
## 玩家：4 列（走 A / 走 B / 待机 / 挥工具）× 3 行（下 / 上 / 侧），坐标见 [AtlasLayout]。
## NPC：与玩家同构的 4 列 × 3 行（走 A / 走 B / 待机 / 呼吸），
## 文件名为 [code]npc_<id>.png[/code]。
##
## 所有角色共用同一套 [method _draw_actor]，
## 靠"外观字典"换衣服 / 头发 / 肤色——新增一个 NPC 只要加一行 [constant NPC_LOOKS]，
## 不需要再画一遍像素。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_actors.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/actors"

## 玩家外观。
const PLAYER_LOOK := {
	"hair": P.HAIR,
	"hair_light": P.HAIR_LIGHT,
	"shirt": P.SHIRT,
	"shirt_dark": P.SHIRT_DARK,
	"pants": P.PANTS,
	"boot": P.BOOT,
}

## NPC 外观表：id → 外观。新增 NPC 时在这里加一条即可。
const NPC_LOOKS := {
	&"merchant": {
		"hair": P.NPC_HAIR,
		"hair_light": P.WHITE,
		"shirt": P.NPC_SHIRT,
		"shirt_dark": P.NPC_SHIRT_DARK,
		"pants": P.PANTS_DARK,
		"boot": P.BOOT,
		"hat": true,
	},
	&"mayor": {
		"hair": P.NPC_HAIR_DARK,
		"hair_light": P.STONE_LIGHT,
		"shirt": P.WOOD_DARK,
		"shirt_dark": P.OUTLINE,
		"pants": P.PANTS,
		"boot": P.BOOT,
		"apron": true,
	},
	&"blacksmith": {
		"hair": P.HAIR,
		"hair_light": P.HAIR_LIGHT,
		"shirt": P.STONE_DARK,
		"shirt_dark": P.OUTLINE,
		"pants": P.PANTS_DARK,
		"boot": P.BOOT,
		"apron": true,
		"apron_color": P.APRON_LEATHER,
		"beard": true,
	},
	&"florist": {
		"hair": P.NPC_HAIR,
		"hair_light": P.WHITE,
		"shirt": P.FLOWER_PINK,
		"shirt_dark": P.FLOWER_RED,
		"pants": P.PANTS,
		"boot": P.BOOT,
		"hat": true,
		"hat_color": P.HAY,
		"hat_dark": P.WOOD_DARK,
		"hat_light": P.FRUIT_YELLOW,
		"apron": true,
	},
	&"fisher": {
		"hair": P.NPC_HAIR_DARK,
		"hair_light": P.NPC_HAIR,
		"shirt": P.SHIRT,
		"shirt_dark": P.SHIRT_DARK,
		"pants": P.PANTS_DARK,
		"boot": P.BOOT,
		"bandana": true,
		"bandana_color": P.BANDANA_NAVY,
		"beard": true,
	},
	&"miner": {
		"hair": P.HAIR,
		"hair_light": P.HAIR_LIGHT,
		"shirt": P.DIRT,
		"shirt_dark": P.DIRT_DARK,
		"pants": P.PANTS_DARK,
		"boot": P.BOOT,
		"helmet": true,
		"beard": true,
	},
	&"child": {
		"hair": P.NPC_HAIR_BLONDE,
		"hair_light": P.FRUIT_YELLOW,
		"shirt": P.FLOWER_YELLOW,
		"shirt_dark": P.FRUIT_ORANGE,
		"pants": P.SHIRT_DARK,
		"boot": P.BOOT,
	},
	&"librarian": {
		"hair": P.HAIR,
		"hair_light": P.HAIR_LIGHT,
		"shirt": P.FRUIT_PURPLE,
		"shirt_dark": P.UI_PANEL_DARK,
		"pants": P.PANTS,
		"boot": P.BOOT,
		"glasses": true,
		"hair_long": true,
	},
	# 玩家与配偶的孩子（婚后出生才出现，见 RelationshipService）。
	&"our_child": {
		"hair": P.NPC_HAIR,
		"hair_light": P.WHITE,
		"shirt": P.FLOWER_BLUE,
		"shirt_dark": P.SHIRT_DARK,
		"pants": P.PANTS,
		"boot": P.BOOT,
	},
}


func _initialize() -> void:
	Art.save_png(_build_player(), DIR.path_join("player.png"))
	for npc_id: StringName in NPC_LOOKS:
		Art.save_png(_build_npc(NPC_LOOKS[npc_id]), DIR.path_join("npc_%s.png" % npc_id))
	print("角色图集生成完成 → ", DIR)
	quit()


# ---------------------------------------------------------------- 玩家

func _build_player() -> Image:
	var image := Art.new_image(Layout.ACTOR_SIZE.x, Layout.ACTOR_SIZE.y)
	for row: int in Layout.ACTOR_ROWS:
		# 0/1 = 走路两帧、2 = 待机、3 = 挥工具
		_draw_actor(image, Vector2i(0, row), 1, PLAYER_LOOK)
		_draw_actor(image, Vector2i(1, row), 1, PLAYER_LOOK, 1)
		_draw_actor(image, Vector2i(2, row), 0, PLAYER_LOOK)
		_draw_actor(image, Vector2i(3, row), 2, PLAYER_LOOK)
	return image


# ---------------------------------------------------------------- NPC

func _build_npc(look: Dictionary) -> Image:
	var image := Art.new_image(Layout.NPC_SIZE.x, Layout.NPC_SIZE.y)
	for row: int in Layout.ACTOR_ROWS:
		# 走 A / 走 B：迈步帧，第二帧整体上抬一像素做出起伏。
		_draw_actor(image, Vector2i(Layout.NPC_WALK_COLUMNS[0], row), 1, look)
		_draw_actor(image, Vector2i(Layout.NPC_WALK_COLUMNS[1], row), 1, look, 1)
		# 待机 / 呼吸。
		_draw_actor(image, Vector2i(Layout.NPC_IDLE_COLUMN, row), 0, look)
		_draw_actor(image, Vector2i(Layout.NPC_IDLE_BOB_COLUMN, row), 0, look, 0, 1)
	return image


# ---------------------------------------------------------------- 角色绘制

## 画一个 16×32 的角色：脚底贴着格子底边，身体往上长。
##
## [param cell] 目标格坐标（列, 行）；[param pose] 0 = 站立、1 = 迈步、2 = 挥动；
## [param bob] 整体上移像素（NPC 的呼吸帧用）。
func _draw_actor(
	image: Image,
	cell: Vector2i,
	pose: int,
	look: Dictionary,
	bob: int = 0,
	lift: int = 0
) -> void:
	var ox: int = cell.x * Layout.ACTOR_CELL.x
	var oy: int = cell.y * Layout.ACTOR_CELL.y - bob - lift
	var row: int = cell.y

	var skin: Color = P.SKIN
	var skin_dark: Color = P.SKIN_DARK
	var hair: Color = look.get("hair", P.HAIR)
	var hair_light: Color = look.get("hair_light", P.HAIR_LIGHT)
	var shirt: Color = look.get("shirt", P.SHIRT)
	var shirt_dark: Color = look.get("shirt_dark", P.SHIRT_DARK)
	var pants: Color = look.get("pants", P.PANTS)
	var boot: Color = look.get("boot", P.BOOT)
	var has_hat: bool = bool(look.get("hat", false))
	var has_apron: bool = bool(look.get("apron", false))
	var apron: Color = look.get("apron_color", P.APRON)
	var has_helmet: bool = bool(look.get("helmet", false))
	var has_bandana: bool = bool(look.get("bandana", false))
	var bandana: Color = look.get("bandana_color", P.BANDANA_NAVY)
	var has_glasses: bool = bool(look.get("glasses", false))
	var has_beard: bool = bool(look.get("beard", false))
	var long_hair: bool = bool(look.get("hair_long", false))

	# 落地阴影固定在格子底部（不跟着 bob 移动，否则人会像在飘）。
	Art.ellipse(image, Vector2i(ox + 8, oy + 29), Vector2i(6, 2), P.SHADOW)

	# 腿：长裤 6px + 靴子 2px；迈步时前后错开一像素。
	var left_leg: int = oy + 23
	var right_leg: int = oy + 23
	if pose == 1:
		left_leg = oy + 22
		right_leg = oy + 24
	Art.rect(image, Rect2i(ox + 4, left_leg, 3, 8), pants)
	Art.rect(image, Rect2i(ox + 9, right_leg, 3, 8), pants)
	Art.rect(image, Rect2i(ox + 4, left_leg + 6, 3, 2), boot)
	Art.rect(image, Rect2i(ox + 9, right_leg + 6, 3, 2), boot)

	# 身体
	Art.rect(image, Rect2i(ox + 4, oy + 12, 8, 11), shirt)
	Art.h_line(image, ox + 4, oy + 12, 8, shirt_dark)
	if has_apron:
		Art.rect(image, Rect2i(ox + 6, oy + 14, 4, 9), apron)
	else:
		Art.h_line(image, ox + 6, oy + 14, 4, shirt_dark)

	# 头
	Art.rect(image, Rect2i(ox + 4, oy + 2, 8, 10), skin)
	Art.rect(image, Rect2i(ox + 4, oy + 2, 8, 3), hair)
	Art.rect(image, Rect2i(ox + 3, oy + 3, 1, 5), hair)
	Art.rect(image, Rect2i(ox + 12, oy + 3, 1, 5), hair)
	if long_hair:
		# 披肩长发：头两侧各多垂几像素。
		Art.rect(image, Rect2i(ox + 3, oy + 8, 1, 4), hair)
		Art.rect(image, Rect2i(ox + 12, oy + 8, 1, 4), hair)

	match row:
		0:  # 朝下：两粒眼睛 + 一点腮红
			Art.px(image, ox + 6, oy + 8, P.OUTLINE)
			Art.px(image, ox + 9, oy + 8, P.OUTLINE)
			Art.px(image, ox + 5, oy + 9, skin_dark)
			Art.px(image, ox + 10, oy + 9, skin_dark)
		1:  # 朝上：后脑勺
			Art.rect(image, Rect2i(ox + 4, oy + 6, 8, 6), hair)
			Art.h_line(image, ox + 5, oy + 8, 6, hair_light)
		2:  # 朝侧面：单眼 + 侧脸轮廓
			Art.px(image, ox + 9, oy + 8, P.OUTLINE)
			Art.rect(image, Rect2i(ox + 4, oy + 6, 3, 6), hair)
			Art.px(image, ox + 11, oy + 9, skin_dark)

	# 胡子：只画在下巴，朝上时看不到。
	if has_beard and row != 1:
		Art.h_line(image, ox + 4, oy + 10, 8, hair_light)
		Art.px(image, ox + 3, oy + 10, hair_light)

	# 眼镜：横跨双眼的一片深色。
	if has_glasses and row == 0:
		Art.rect(image, Rect2i(ox + 5, oy + 8, 2, 1), P.GLASSES)
		Art.rect(image, Rect2i(ox + 9, oy + 8, 2, 1), P.GLASSES)
		Art.px(image, ox + 7, oy + 8, P.GLASSES)
	elif has_glasses and row == 2:
		Art.rect(image, Rect2i(ox + 8, oy + 8, 3, 1), P.GLASSES)

	if has_helmet:
		# 矿工：圆顶安全帽 + 帽檐 + 头灯。
		Art.rect(image, Rect2i(ox + 3, oy + 0, 10, 3), P.HELMET_YELLOW)
		Art.h_line(image, ox + 4, oy, 8, P.HELMET_DARK)
		Art.h_line(image, ox + 2, oy + 3, 12, P.HELMET_DARK)
		Art.px(image, ox + 8, oy + 4, P.LAMP_GLOW)
	elif has_hat:
		# 宽檐帽：商人 / 花匠，远远就能认出来。
		var hat: Color = look.get("hat_color", P.WOOD)
		var hat_dark: Color = look.get("hat_dark", P.WOOD_DARK)
		var hat_light: Color = look.get("hat_light", P.WOOD_LIGHT)
		Art.rect(image, Rect2i(ox + 4, oy + 0, 8, 2), hat_dark)
		Art.rect(image, Rect2i(ox + 2, oy + 2, 12, 2), hat)
		Art.h_line(image, ox + 3, oy + 2, 10, hat_light)

	if has_bandana:
		# 头巾：绕头一圈。
		Art.h_line(image, ox + 3, oy + 4, 10, bandana)
		Art.rect(image, Rect2i(ox + 12, oy + 4, 1, 3), bandana)

	# 手臂：挥动姿势抬右臂。工具本身由 [HeldToolView] 单独画，不烘进角色图集，
	# 这样每件工具才能有自己的造型，也能空挥。
	if pose == 2:
		Art.rect(image, Rect2i(ox + 11, oy + 6, 2, 5), skin)
		Art.px(image, ox + 11, oy + 5, skin)
	else:
		Art.rect(image, Rect2i(ox + 3, oy + 14, 2, 8), skin_dark)
		Art.rect(image, Rect2i(ox + 11, oy + 14, 2, 8), skin_dark)
		Art.px(image, ox + 3, oy + 21, skin)
		Art.px(image, ox + 12, oy + 21, skin)
