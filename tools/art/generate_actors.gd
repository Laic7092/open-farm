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

## 画一个 16×16 的角色。
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
	var ox: int = cell.x * Layout.TILE
	var oy: int = cell.y * Layout.TILE - bob - lift
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

	# 落地阴影始终画在格子底部，不跟着 bob 移动，否则人会像在飘。
	Art.ellipse(image, Vector2i(ox + 8, oy + 15), Vector2i(5, 2), P.SHADOW)

	# 腿：迈步时前后错开一像素。
	var left_leg: int = oy + 11
	var right_leg: int = oy + 11
	if pose == 1:
		left_leg = oy + 10
		right_leg = oy + 12
	Art.rect(image, Rect2i(ox + 4, left_leg, 3, 3), pants)
	Art.rect(image, Rect2i(ox + 9, right_leg, 3, 3), pants)
	Art.h_line(image, ox + 4, left_leg + 3, 3, boot)
	Art.h_line(image, ox + 9, right_leg + 3, 3, boot)

	# 身体
	Art.rect(image, Rect2i(ox + 4, oy + 6, 8, 6), shirt)
	Art.h_line(image, ox + 4, oy + 6, 8, shirt_dark)
	if has_apron:
		Art.rect(image, Rect2i(ox + 6, oy + 7, 4, 5), P.APRON)
	else:
		Art.h_line(image, ox + 6, oy + 7, 4, shirt_dark)

	# 头
	Art.rect(image, Rect2i(ox + 5, oy + 1, 6, 5), skin)
	Art.rect(image, Rect2i(ox + 5, oy + 1, 6, 2), hair)
	Art.rect(image, Rect2i(ox + 4, oy + 2, 1, 3), hair)
	Art.rect(image, Rect2i(ox + 11, oy + 2, 1, 3), hair)

	match row:
		0:  # 朝下：两粒眼睛 + 一点腮红
			Art.px(image, ox + 6, oy + 4, P.OUTLINE)
			Art.px(image, ox + 9, oy + 4, P.OUTLINE)
			Art.px(image, ox + 5, oy + 5, skin_dark)
			Art.px(image, ox + 10, oy + 5, skin_dark)
		1:  # 朝上：后脑勺
			Art.rect(image, Rect2i(ox + 5, oy + 3, 6, 4), hair)
			Art.h_line(image, ox + 6, oy + 4, 4, hair_light)
		2:  # 朝侧面：单眼 + 侧脸轮廓
			Art.px(image, ox + 9, oy + 4, P.OUTLINE)
			Art.rect(image, Rect2i(ox + 4, oy + 3, 2, 4), hair)
			Art.px(image, ox + 11, oy + 5, skin_dark)

	if has_hat:
		# 商人：一顶宽檐帽，远远就能认出来。
		Art.rect(image, Rect2i(ox + 3, oy + 1, 10, 2), P.WOOD)
		Art.rect(image, Rect2i(ox + 5, oy - 1, 6, 2), P.WOOD_DARK)
		Art.h_line(image, ox + 4, oy + 1, 8, P.WOOD_LIGHT)

	# 手臂 / 手持工具
	if pose == 2:
		Art.rect(image, Rect2i(ox + 11, oy + 3, 2, 3), skin)
		Art.rect(image, Rect2i(ox + 12, oy + 0, 2, 4), P.WOOD)
		Art.px(image, ox + 13, oy - 1, P.STONE_LIGHT)
	else:
		Art.rect(image, Rect2i(ox + 3, oy + 7, 2, 4), skin_dark)
		Art.rect(image, Rect2i(ox + 11, oy + 7, 2, 4), skin_dark)
		Art.px(image, ox + 3, oy + 11, skin)
		Art.px(image, ox + 12, oy + 11, skin)
