extends SceneTree
## NPC 住宅生成器 → [code]assets/sprites/props/house_<npc_id>.png[/code]
##
## 八栋房子共用同一张 64×64 画布与同一条落地线，但**体量完全不同**：
## 杂货铺是两层带遮阳篷的商铺、镇公所是四柱门廊 + 山花 + 钟 + 旗杆的公共建筑、
## 铁匠铺是低矮敞棚 + 巨石烟囱 + 敞开的炉膛、花店是高耸的玻璃花房、
## 图书馆带一座圆塔、小女孩家是 36 宽的迷你茅草屋、渔夫家是吊脚楼、
## 矿工家是原木屋 + 井架 + 矿车。换的不只是配色，而是剪影。
##
## 每栋房子的实际占地写在各自的注释里（[code]占地[/code]），场景里
## [WorldProp] 的 [code]solid_size[/code] / [code]solid_offset[/code] 要按它填：
## 宽度对不上，玩家就会撞到"空气墙"或者站进墙里。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/art/generate_houses.gd
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const Layout := preload("res://src/art/atlas_layout.gd")
const P := preload("res://src/art/palette.gd")

const DIR: String = "res://assets/sprites/props"

## 落地线：所有房子的墙脚 / 台阶都收在这一行，投影画在它下面一行。
const GROUND: int = 60
const SHADOW_ROW: int = 61


func _initialize() -> void:
	Art.save_png(_merchant(), DIR.path_join("house_merchant.png"))
	Art.save_png(_mayor(), DIR.path_join("house_mayor.png"))
	Art.save_png(_blacksmith(), DIR.path_join("house_blacksmith.png"))
	Art.save_png(_florist(), DIR.path_join("house_florist.png"))
	Art.save_png(_librarian(), DIR.path_join("house_librarian.png"))
	Art.save_png(_child(), DIR.path_join("house_child.png"))
	Art.save_png(_fisher(), DIR.path_join("house_fisher.png"))
	Art.save_png(_miner(), DIR.path_join("house_miner.png"))
	print("NPC 住宅生成完成 → ", DIR)
	quit()

# ---------------------------------------------------------------- 商人：两层杂货铺
#
# 剪影：竖长的两层木筋楼，一层橱窗 + 门，二层两扇小窗，中间横一道条纹遮阳篷；
# 招牌吊在篷下，门口堆着货箱与木桶。
# 占地：x 2..62（宽 60）。
func _merchant() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 32, 28)

	# 一层 / 二层墙体
	var trim: Color = P.WOOD_DARK
	_timber_wall(image, Rect2i(8, 20, 48, 40), P.WALL, P.WALL_DARK, P.WALL_LIGHT, trim, 11)
	# 楼层线
	Art.rect(image, Rect2i(6, 35, 52, 3), trim)
	Art.h_line(image, 6, 35, 52, P.WOOD_LIGHT)

	# 低坡瓦顶
	_gable(image, 2, 20, 32, 24.0, 33.0, P.ROOF, P.ROOF_DARK, P.ROOF_LIGHT)
	_eave(image, 19, 0, 64, P.ROOF_DARK, P.ROOF_LIGHT)

	# 二层小窗
	_pane_square(image, Rect2i(13, 24, 10, 9), P.GLASS, trim)
	_pane_square(image, Rect2i(41, 24, 10, 9), P.GLASS, trim)

	# 一层：橱窗 + 门
	_pane_square(image, Rect2i(10, 45, 17, 12), P.GLASS, trim)
	_door(image, Rect2i(31, 44, 14, 16), P.WOOD, trim)
	# 遮阳篷压在橱窗上方
	_awning(image, Rect2i(2, 36, 60, 6), P.FLOWER_WHITE, P.ROOF, trim)

	# 店门口的货
	_crate(image, Rect2i(51, 48, 12, 12), 11)
	_barrel(image, Rect2i(0, 50, 9, 10))

	_sign(image, Rect2i(24, 38, 18, 10), &"coin", 11, trim)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 村长：镇公所
#
# 剪影：占满整幅宽度的石造公共建筑——台阶 + 四根柱子 + 檐部 + 三角山花，
# 山花上嵌一面钟，尖顶竖着旗杆。全画面最高最宽。
# 占地：x 2..62（宽 60）。
func _mayor() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 32, 28)

	# 门廊后面的深色内墙
	Art.rect(image, Rect2i(6, 28, 52, 28), P.STONE)
	Art.scatter(image, Rect2i(6, 28, 52, 28), P.STONE_DARK, 0.16, 23)
	# 大门 + 门楣
	_door(image, Rect2i(27, 40, 11, 16), P.WOOD_DARK, P.WOOD)
	Art.h_line(image, 24, 38, 17, P.STONE_LIGHT)

	# 四根柱子
	for x: int in [5, 20, 39, 54]:
		Art.rect(image, Rect2i(x, 28, 5, 24), P.WALL_LIGHT)
		Art.v_line(image, x + 4, 28, 24, P.STONE_DARK)           # 柱身暗面
		Art.v_line(image, x + 2, 29, 22, P.WHITE)                # 凹槽高光
		Art.rect(image, Rect2i(x - 1, 26, 7, 3), P.WALL_LIGHT)   # 柱头
		Art.h_line(image, x - 1, 28, 7, P.STONE)
		Art.rect(image, Rect2i(x - 1, 51, 7, 5), P.STONE_LIGHT)  # 柱础
		Art.h_line(image, x - 1, 51, 7, P.WHITE)

	# 檐部：一条横带 + 三竖线（triglyph）
	Art.rect(image, Rect2i(0, 21, 64, 6), P.WALL_LIGHT)
	Art.h_line(image, 0, 21, 64, P.WHITE)
	Art.rect(image, Rect2i(0, 26, 64, 2), P.STONE)
	for x: int in range(3, 64, 10):
		Art.v_line(image, x, 22, 3, P.STONE)

	# 三角山花
	for row: int in 12:
		var half := int(round(lerpf(4.0, 32.0, float(row) / 11.0)))
		var color: Color = P.WALL_LIGHT if (row / 4) % 2 == 0 else P.WALL
		Art.h_line(image, 32 - half, 9 + row, half * 2, color)
	Art.h_line(image, 0, 20, 64, P.STONE_DARK)

	# 山花上的钟
	Art.circle(image, Vector2i(32, 16), 5, P.WOOD_DARK)
	Art.circle(image, Vector2i(32, 16), 4, P.WHITE)
	Art.px(image, 32, 13, P.OUTLINE)
	Art.px(image, 32, 14, P.OUTLINE)
	Art.px(image, 32, 15, P.OUTLINE)
	Art.px(image, 33, 16, P.OUTLINE)
	Art.px(image, 34, 16, P.OUTLINE)
	# 旗杆 + 旗
	Art.v_line(image, 32, 1, 9, P.STONE_DARK)
	Art.rect(image, Rect2i(33, 1, 8, 5), P.FLOWER_RED)
	Art.h_line(image, 33, 3, 8, P.FLOWER_WHITE)

	# 三级台阶
	Art.rect(image, Rect2i(2, 56, 60, 2), P.STONE_LIGHT)
	Art.h_line(image, 2, 56, 60, P.WHITE)
	Art.rect(image, Rect2i(5, 58, 54, 2), P.STONE_LIGHT)
	Art.h_line(image, 5, 58, 54, P.WHITE)
	Art.h_line(image, 8, 60, 48, P.STONE_DARK)

	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 铁匠：低矮敞棚
#
# 剪影：左重右轻——左边一根顶穿屋顶的巨石烟囱，右边一个敞开的拱形炉膛口，
# 洞口里是火光与铁砧，门外摆着淬火水槽。屋顶低而宽。
# 占地：x 2..62（宽 60）。
func _blacksmith() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 32, 28)

	# 矮石墙
	_stone_wall(image, Rect2i(6, 26, 52, 34), P.STONE, P.STONE_DARK, P.STONE_LIGHT, 37)
	# 低坡铁皮顶
	_gable(image, 12, 26, 32, 26.0, 34.0, P.ROOF_IRON, P.ROOF_IRON_DARK, P.ROOF_IRON_LIGHT)
	_eave(image, 25, 0, 64, P.ROOF_IRON_DARK, P.ROOF_IRON_LIGHT)

	# 巨石烟囱（压在屋顶左侧）
	Art.rect(image, Rect2i(5, 2, 15, 26), P.STONE)
	Art.scatter(image, Rect2i(5, 2, 15, 26), P.STONE_DARK, 0.34, 37)
	Art.rect(image, Rect2i(3, 0, 19, 4), P.STONE_DARK)
	Art.h_line(image, 3, 0, 19, P.STONE_LIGHT)
	# 烟
	Art.ellipse(image, Vector2i(25, 5), Vector2i(3, 2), P.CLOUD_DARK)
	Art.ellipse(image, Vector2i(29, 1), Vector2i(3, 2), P.CLOUD)
	Art.ellipse(image, Vector2i(33, 5), Vector2i(2, 2), P.CLOUD_DARK)

	# 炉膛口：拱形暗洞
	var bay := Rect2i(37, 34, 19, 26)
	for row: int in bay.size.y:
		var inset: int = 0
		if row < 4:
			inset = (4 - row) * 2
		Art.h_line(
			image, bay.position.x + inset, bay.position.y + row,
			maxi(bay.size.x - inset * 2, 1), P.BLACK
		)
	# 洞口木框
	Art.rect(image, Rect2i(35, 32, 23, 3), P.WOOD_DARK)
	Art.v_line(image, 35, 32, 28, P.WOOD_DARK)
	Art.v_line(image, 57, 32, 28, P.WOOD_DARK)
	# 炉火
	Art.ellipse(image, Vector2i(47, 56), Vector2i(8, 5), P.FRUIT_ORANGE)
	Art.ellipse(image, Vector2i(47, 56), Vector2i(6, 4), P.LAMP_GLOW)
	Art.ellipse(image, Vector2i(47, 57), Vector2i(3, 2), P.WHITE)
	for i: int in 6:
		Art.px(image, 40 + i * 3, 44 - (i % 3) * 3, P.COIN)
	# 火光前的铁砧剪影
	Art.rect(image, Rect2i(42, 50, 10, 3), P.OUTLINE)
	Art.rect(image, Rect2i(45, 53, 4, 4), P.OUTLINE)
	Art.rect(image, Rect2i(42, 57, 10, 3), P.OUTLINE)

	# 门口淬火水槽
	Art.rect(image, Rect2i(50, 50, 14, 10), P.WOOD)
	Art.frame_rect(image, Rect2i(50, 50, 14, 10), P.WOOD_DARK)
	Art.rect(image, Rect2i(52, 52, 10, 5), P.WATER)
	Art.h_line(image, 52, 52, 10, P.WATER_LIGHT)

	_sign(image, Rect2i(8, 30, 16, 10), &"hammer", 37, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 花匠：玻璃花房
#
# 剪影：一整座高耸的玻璃山墙直接落地（白框 + 通透玻璃，能看见里面成丛的植物），
# 底部才是矮石基与门，两侧挂着花箱，门前一道藤架。
# 占地：x 6..58（宽 52）。
func _florist() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 32, 26)

	# 矮石基
	_stone_wall(image, Rect2i(6, 44, 52, 16), P.WALL_DARK, P.STONE_DARK, P.WALL_LIGHT, 41)

	# 玻璃山墙：从尖顶一路铺到石基
	for row: int in 42:
		var t := float(row) / 41.0
		var half := int(round(lerpf(4.0, 30.0, pow(t, 0.82))))
		var left := 32 - half
		Art.h_line(image, left, 2 + row, half * 2, P.GLASS)
		# 玻璃后面的植物剪影
		for plant: Vector2i in [Vector2i(22, 40), Vector2i(42, 41), Vector2i(28, 36), Vector2i(37, 43)]:
			if absi(plant.x - 32) <= half - 2 and plant.y == 2 + row:
				Art.ellipse(image, plant, Vector2i(5, 3), P.LEAF_DARK)
				Art.ellipse(image, plant, Vector2i(3, 2), P.LEAF)
		Art.h_line(image, left, 2 + row, mini(6, half), P.WATER_LIGHT)
		# 白框：横档 + 竖档
		if row % 9 == 0:
			Art.h_line(image, left, 2 + row, half * 2, P.WHITE)
		for dx: int in [-20, -10, 0, 10, 20]:
			var x := 32 + dx
			if x >= left and x < left + half * 2:
				Art.px(image, x, 2 + row, P.WHITE)
	# 屋脊
	Art.h_line(image, 28, 1, 8, P.ROOF_ROSE)
	Art.h_line(image, 30, 0, 4, P.ROOF_ROSE_DARK)

	# 门与窗（开在石基上）
	_door(image, Rect2i(27, 46, 11, 14), P.ROOF_ROSE_DARK, P.WOOD_DARK)
	_pane_square(image, Rect2i(13, 47, 11, 9), P.GLASS, P.WOOD_DARK)
	_pane_square(image, Rect2i(41, 47, 11, 9), P.GLASS, P.WOOD_DARK)
	# 花箱
	for x: int in [10, 38]:
		Art.rect(image, Rect2i(x, 56, 16, 5), P.WOOD_DARK)
		Art.h_line(image, x, 56, 16, P.WOOD)
		Art.px(image, x + 2, 55, P.FLOWER_PINK)
		Art.px(image, x + 5, 54, P.FLOWER_RED)
		Art.px(image, x + 8, 55, P.FLOWER_YELLOW)
		Art.px(image, x + 11, 54, P.FLOWER_WHITE)
		Art.px(image, x + 14, 55, P.FLOWER_BLUE)
	# 门前藤架
	Art.v_line(image, 20, 44, 12, P.WOOD_DARK)
	Art.h_line(image, 20, 44, 24, P.WOOD_DARK)
	for i: int in 5:
		Art.px(image, 22 + i * 5, 45, P.LEAF)
		Art.px(image, 24 + i * 5, 47, P.LEAF_DARK)

	_sign(image, Rect2i(24, 30, 16, 10), &"flower", 41, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 图书管理员：带塔的图书馆
#
# 剪影：右侧主楼 + 左侧一座圆塔（靛蓝锥顶高出主楼屋脊），
# 主楼两扇高拱窗，塔身一扇小拱窗，门前有台阶与一摞书。
# 占地：x 4..60（宽 56）。
func _librarian() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 34, 26)

	# 主楼
	_stone_wall(image, Rect2i(19, 24, 41, 36), P.STONE_LIGHT, P.STONE, P.WALL_LIGHT, 53)
	_gable(image, 6, 24, 40, 21.0, 32.0, P.ROOF_INDIGO, P.ROOF_INDIGO_DARK, P.ROOF_INDIGO_LIGHT)
	_eave(image, 23, 14, 64, P.ROOF_INDIGO_DARK, P.ROOF_INDIGO_LIGHT)
	# 高拱窗
	_pane_arch(image, Rect2i(25, 32, 11, 16), P.GLASS, P.STONE_DARK)
	_pane_arch(image, Rect2i(44, 32, 11, 16), P.GLASS, P.STONE_DARK)
	# 门
	_door(image, Rect2i(35, 42, 11, 18), P.WOOD_DARK, P.WOOD)
	Art.h_line(image, 33, 40, 15, P.STONE_LIGHT)

	# 圆塔：先锥顶后塔身
	for row: int in 15:
		var half := int(round(lerpf(1.0, 11.0, float(row) / 14.0)))
		var color: Color = P.ROOF_INDIGO if row % 4 < 2 else P.ROOF_INDIGO_DARK
		Art.h_line(image, 13 - half, row, half * 2, color)
	Art.h_line(image, 12, 0, 3, P.ROOF_INDIGO_LIGHT)
	_stone_wall(image, Rect2i(4, 14, 18, 46), P.STONE_LIGHT, P.STONE, P.WALL_LIGHT, 53)
	Art.rect(image, Rect2i(2, 12, 22, 3), P.STONE)          # 塔檐
	Art.h_line(image, 2, 12, 22, P.WALL_LIGHT)
	# 塔身小拱窗
	_pane_arch(image, Rect2i(9, 20, 8, 12), P.GLASS, P.STONE_DARK)
	# 塔基与书
	Art.rect(image, Rect2i(2, 56, 22, 4), P.STONE)
	Art.rect(image, Rect2i(24, 54, 9, 2), P.FRUIT_PURPLE)
	Art.rect(image, Rect2i(25, 56, 8, 2), P.FRUIT_RED)
	Art.rect(image, Rect2i(24, 58, 9, 2), P.FRUIT_GREEN)

	_sign(image, Rect2i(5, 34, 15, 9), &"book", 53, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 小女孩：迷你茅草屋
#
# 剪影：只有 36 宽的小屋，厚茅草顶向两侧探出墙外，矮篱笆围出一小块花园；
# 圆窗、红门、门上挂着花环。
# 占地：x 0..64（篱笆 + 小屋）。
func _child() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 32, 24)

	# 左右矮篱笆
	_fence(image, Rect2i(0, 50, 12, 11))
	_fence(image, Rect2i(52, 50, 12, 11))

	# 小屋墙
	_timber_wall(image, Rect2i(14, 32, 36, 28), P.WALL, P.WALL_DARK, P.WALL_LIGHT, P.WOOD_DARK, 67)
	# 厚茅草顶
	_thatch(image, 8, 34, 32, 13.0, 27.0, P.ROOF_THATCH, P.ROOF_THATCH_DARK, P.ROOF_THATCH_LIGHT, 67)
	# 小烟囱
	Art.rect(image, Rect2i(40, 6, 8, 14), P.STONE)
	Art.rect(image, Rect2i(39, 4, 10, 4), P.STONE_DARK)
	Art.ellipse(image, Vector2i(50, 3), Vector2i(3, 2), P.CLOUD_DARK)
	Art.ellipse(image, Vector2i(54, 0), Vector2i(3, 2), P.CLOUD)

	# 圆窗
	_porthole(image, Vector2i(22, 45), P.GLASS, P.WOOD_DARK)
	_porthole(image, Vector2i(42, 45), P.GLASS, P.WOOD_DARK)
	# 红门 + 花环
	_door(image, Rect2i(27, 42, 11, 18), P.FRUIT_RED, P.WOOD_DARK)
	Art.circle(image, Vector2i(32, 48), 4, P.LEAF_DARK)
	Art.circle(image, Vector2i(32, 48), 3, P.LEAF)
	Art.circle(image, Vector2i(32, 48), 1, P.FRUIT_RED)
	_sign(image, Rect2i(25, 31, 14, 9), &"heart", 67, P.WOOD_DARK)
	# 花园里的花
	for x: int in [3, 7, 55, 59]:
		Art.px(image, x, 48, P.FLOWER_PINK if x % 2 == 0 else P.FLOWER_YELLOW)
		Art.px(image, x, 49, P.LEAF)

	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 渔夫：吊脚楼
#
# 剪影：四根木桩把屋子架离地面（桩间能看见背景），圆舷窗，海风绿屋顶上
# 披着一张渔网，屋檐下挂灯，屋外晾着鱼。
# 占地：x 8..52（宽 44）。
func _fisher() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 30, 22)

	# 吊脚桩 + 平台
	for x: int in [12, 22, 36, 46]:
		Art.rect(image, Rect2i(x, 47, 3, 14), P.WOOD_DARK)
		Art.px(image, x, 47, P.WOOD_LIGHT)
	Art.rect(image, Rect2i(8, 43, 44, 5), P.PLANK)
	Art.h_line(image, 8, 43, 44, P.WOOD_LIGHT)
	Art.h_line(image, 8, 47, 44, P.WOOD_DARK)

	# 木板墙
	_plank_wall(image, Rect2i(10, 22, 40, 21), P.PLANK, P.WOOD_DARK, P.WOOD_LIGHT)
	# 舷窗
	_porthole(image, Vector2i(19, 30), P.GLASS, P.WOOD_DARK)
	_porthole(image, Vector2i(41, 30), P.GLASS, P.WOOD_DARK)
	_door(image, Rect2i(27, 28, 11, 15), P.WOOD_DARK, P.WOOD)

	# 海风绿屋顶
	_gable(image, 6, 22, 30, 15.0, 25.0, P.ROOF_TEAL, P.ROOF_TEAL_DARK, P.ROOF_TEAL_LIGHT)
	Art.rect(image, Rect2i(4, 21, 57, 4), P.ROOF_TEAL_DARK)
	Art.h_line(image, 4, 21, 57, P.ROOF_TEAL_LIGHT)
	# 屋顶上披的渔网
	_net(image, Rect2i(28, 8, 22, 15))
	# 檐下挂灯
	Art.v_line(image, 44, 25, 3, P.WOOD_DARK)
	Art.rect(image, Rect2i(42, 28, 5, 6), P.WOOD_DARK)
	Art.rect(image, Rect2i(43, 29, 3, 4), P.LAMP_GLOW)
	# 晾着的鱼
	Art.ellipse(image, Vector2i(16, 50), Vector2i(5, 2), P.GLASS)
	Art.px(image, 12, 49, P.OUTLINE)
	Art.h_line(image, 20, 50, 3, P.GLASS)

	_sign(image, Rect2i(10, 34, 14, 9), &"fish", 71, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 矿工：原木屋 + 井架
#
# 剪影：左侧一座 A 字井架顶着滑轮，比屋子还高；屋身是两端露出断面的原木墙，
# 顶上是长苔的单坡木顶，右下角停着一辆装矿石的矿车与轨道。
# 占地：x 0..64（井架 + 矿车）。
func _miner() -> Image:
	var image := Art.new_image(Layout.HOUSE_SIZE.x, Layout.HOUSE_SIZE.y)
	_shadow(image, 34, 26)

	# 石头地基
	_stone_wall(image, Rect2i(16, 52, 38, 8), P.STONE, P.STONE_DARK, P.STONE_LIGHT, 89)
	# 原木墙
	_log_wall(image, Rect2i(18, 24, 34, 28), P.TRUNK, P.TRUNK_DARK, P.WOOD_LIGHT)
	# 长苔单坡顶
	_shed(image, 12, 58, 6, 18, 26, P.ROOF_MOSS, P.ROOF_MOSS_DARK, P.ROOF_MOSS_LIGHT, 89)
	# 门 / 窗
	_door(image, Rect2i(24, 38, 11, 16), P.WOOD, P.WOOD_DARK)
	_pane_square(image, Rect2i(42, 32, 9, 9), P.GLASS, P.WOOD_DARK)

	# A 字井架 + 滑轮
	_beam(image, Vector2i(3, 60), Vector2i(11, 14), P.WOOD_DARK, 2)
	_beam(image, Vector2i(19, 60), Vector2i(11, 14), P.WOOD_DARK, 2)
	_beam(image, Vector2i(6, 42), Vector2i(16, 42), P.WOOD_DARK, 2)
	_beam(image, Vector2i(7, 52), Vector2i(15, 52), P.WOOD_DARK, 2)
	Art.circle(image, Vector2i(11, 11), 5, P.WOOD_DARK)
	Art.circle(image, Vector2i(11, 11), 4, P.WOOD)
	_beam(image, Vector2i(7, 11), Vector2i(15, 11), P.WOOD_DARK, 1)
	_beam(image, Vector2i(11, 7), Vector2i(11, 15), P.WOOD_DARK, 1)
	Art.circle(image, Vector2i(11, 11), 1, P.STONE_DARK)
	# 矿车 + 轨道
	Art.rect(image, Rect2i(48, 48, 15, 10), P.WOOD_DARK)
	Art.rect(image, Rect2i(49, 49, 13, 8), P.PLANK)
	Art.rect(image, Rect2i(50, 47, 11, 3), P.STONE)
	Art.px(image, 52, 48, P.COIN)
	Art.px(image, 56, 48, P.STONE_LIGHT)
	Art.circle(image, Vector2i(51, 59), 2, P.STONE_DARK)
	Art.circle(image, Vector2i(60, 59), 2, P.STONE_DARK)
	Art.h_line(image, 44, 60, 20, P.STONE_DARK)

	_sign(image, Rect2i(20, 26, 14, 9), &"pickaxe", 89, P.WOOD_DARK)
	Art.outline(image, P.OUTLINE)
	return image


# ---------------------------------------------------------------- 墙体

func _timber_wall(
	image: Image, area: Rect2i, base: Color, dark: Color, light: Color, trim: Color, salt: int
) -> void:
	Art.rect(image, area, base)
	Art.scatter(image, area, dark, 0.09, salt)
	Art.rect(image, Rect2i(area.position.x, area.position.y, area.size.x, 2), trim)
	Art.rect(image, Rect2i(area.position.x, area.end.y - 3, area.size.x, 3), trim)
	Art.v_line(image, area.position.x + 1, area.position.y + 2, area.size.y - 2, trim)
	Art.v_line(image, area.end.x - 2, area.position.y + 2, area.size.y - 2, trim)
	Art.h_line(image, area.position.x, area.position.y, area.size.x, light)
	Art.v_line(image, area.position.x, area.position.y, area.size.y, dark)


## 错缝料石 + 每块左上角的高光。
func _stone_wall(
	image: Image, area: Rect2i, base: Color, dark: Color, light: Color, salt: int
) -> void:
	Art.rect(image, area, base)
	Art.scatter(image, area, dark, 0.14, salt)
	Art.scatter(image, area, light, 0.04, salt + 1)
	var course: int = 6
	var row: int = 0
	var y: int = area.position.y
	while y < area.end.y:
		Art.h_line(image, area.position.x, y, area.size.x, dark)
		var x: int = area.position.x + (3 if row % 2 == 0 else 9)
		while x < area.end.x:
			Art.v_line(image, x, y, course, dark)
			var block: int = mini(9, area.end.x - x - 2)
			if block > 0:
				Art.h_line(image, x + 1, y + 1, block, light)
				Art.v_line(image, x + 1, y + 1, 2, light)
			x += 12
		y += course
		row += 1


func _plank_wall(image: Image, area: Rect2i, base: Color, dark: Color, light: Color) -> void:
	Art.rect(image, area, base)
	Art.stripes(image, area, dark, 6)
	Art.stripes(image, area, light, 6, 1)
	Art.v_line(image, area.position.x + 3, area.position.y + 2, area.size.y - 2, dark)
	Art.v_line(image, area.end.x - 4, area.position.y + 2, area.size.y - 2, dark)


## 原木墙：一层层圆木，两端伸出墙面露出断面。
func _log_wall(image: Image, area: Rect2i, base: Color, dark: Color, light: Color) -> void:
	var height: int = 6
	var row: int = 0
	var y: int = area.position.y
	while y < area.end.y:
		var h: int = mini(height, area.end.y - y)
		var color: Color = base if row % 2 == 0 else base.lerp(dark, 0.22)
		Art.rect(image, Rect2i(area.position.x, y, area.size.x, h), color)
		Art.h_line(image, area.position.x, y, area.size.x, dark)
		Art.h_line(image, area.position.x, y + 1, area.size.x, light)
		# 两端露出的原木断面
		Art.rect(image, Rect2i(area.position.x - 2, y + 1, 3, h - 2), dark)
		Art.rect(image, Rect2i(area.end.x - 1, y + 1, 3, h - 2), dark)
		Art.px(image, area.position.x - 1, y + 2, light)
		Art.px(image, area.end.x + 1, y + 2, light)
		y += height
		row += 1


# ---------------------------------------------------------------- 屋顶

## 人字顶：[param top] 是屋脊行，[param eave] 是檐口行。
func _gable(
	image: Image, top: int, eave: int, center: int,
	half_top: float, half_bottom: float, base: Color, dark: Color, light: Color
) -> void:
	var rows: int = eave - top
	for row: int in rows:
		var t := float(row) / float(maxi(rows - 1, 1))
		var half := int(round(lerpf(half_top, half_bottom, t)))
		var color: Color = base if (row / 4) % 2 == 0 else base.lerp(dark, 0.35)
		Art.h_line(image, center - half, top + row, half * 2, color)
	Art.h_line(image, center - 3, top, 7, light)


## 厚茅草顶：轮廓更鼓，一根根草茎，屋脊压一道。
func _thatch(
	image: Image, top: int, eave: int, center: int,
	half_top: float, half_bottom: float, base: Color, dark: Color, light: Color, salt: int
) -> void:
	var rows: int = eave - top
	for row: int in rows:
		var t := float(row) / float(maxi(rows - 1, 1))
		var half := int(round(lerpf(half_top, half_bottom, sqrt(t))))
		var fallback: Color = base if (row / 3) % 2 == 0 else base.lerp(dark, 0.25)
		for x in range(center - half, center + half):
			var n := Art.noise(x, row, salt)
			if n < 0.18:
				Art.px(image, x, top + row, dark)
			elif n < 0.30:
				Art.px(image, x, top + row, light)
			else:
				Art.px(image, x, top + row, fallback)
	Art.h_line(image, center - 4, top, 9, light)
	Art.h_line(image, center - 6, top + 1, 13, light)
	_eave(image, eave, center - 34, center + 34, dark, light)


## 单坡顶：在 [param x0]..[param x1] 之间由左高 [param top_a] 斜到右低 [param top_b]，
## 全部收在檐口行 [param eave]，屋面上长着苔。
func _shed(
	image: Image, x0: int, x1: int, top_a: int, top_b: int, eave: int,
	base: Color, dark: Color, light: Color, salt: int
) -> void:
	var span: int = maxi(x1 - x0 - 1, 1)
	for x in range(x0, x1):
		var t := float(x - x0) / float(span)
		var top := int(round(lerpf(float(top_a), float(top_b), t)))
		var fallback: Color = base if ((x / 8) % 2) == 0 else base.lerp(dark, 0.35)
		for y in range(top, eave + 4):
			var n := Art.noise(x, y, salt)
			if n < 0.10:
				Art.px(image, x, y, light)
			elif n < 0.16:
				Art.px(image, x, y, dark)
			else:
				Art.px(image, x, y, fallback)
		Art.px(image, x, top, light)
	# 椽子
	for x in range(x0 + 6, x1, 12):
		var t := float(x - x0) / float(span)
		var top := int(round(lerpf(float(top_a), float(top_b), t)))
		Art.v_line(image, x, top + 1, eave - top + 2, dark)
	Art.h_line(image, x0, eave, x1 - x0, dark)
	Art.h_line(image, x0, eave + 3, x1 - x0, dark)


## 出檐板：下沿压深、上沿提亮。
func _eave(image: Image, y: int, x0: int, x1: int, dark: Color, light: Color) -> void:
	Art.rect(image, Rect2i(x0, y, x1 - x0, 4), dark)
	Art.h_line(image, x0, y, x1 - x0, light)
	Art.h_line(image, x0, y + 3, x1 - x0, dark)


## 条纹遮阳篷，下沿做扇贝。
func _awning(image: Image, area: Rect2i, light: Color, stripe: Color, trim: Color) -> void:
	Art.rect(image, area, light)
	for x in range(area.position.x, area.end.x, 6):
		Art.rect(image, Rect2i(x, area.position.y, 3, area.size.y), stripe)
		Art.h_line(image, x, area.end.y, 3, stripe)
	Art.h_line(image, area.position.x, area.position.y, area.size.x, trim)


# ---------------------------------------------------------------- 门窗

func _window_glass(glow: bool = false) -> Color:
	return P.LAMP_GLOW if glow else P.GLASS


func _pane_square(image: Image, area: Rect2i, glass: Color, trim: Color) -> void:
	Art.rect(image, area, P.GLASS_DARK)
	Art.rect(image, Rect2i(area.position.x + 1, area.position.y + 1, area.size.x - 2, area.size.y - 2), glass)
	Art.h_line(image, area.position.x + 1, area.position.y + 1, area.size.x - 2, P.WATER_FOAM)
	Art.frame_rect(image, area, trim)
	Art.v_line(image, area.position.x + area.size.x / 2, area.position.y, area.size.y, trim)
	Art.h_line(image, area.position.x, area.position.y + area.size.y / 2, area.size.x, trim)
	Art.h_line(image, area.position.x - 1, area.end.y, area.size.x + 2, trim)


func _pane_arch(image: Image, area: Rect2i, glass: Color, trim: Color) -> void:
	var x := area.position.x
	var y := area.position.y
	Art.rect(image, area, trim)
	Art.rect(image, Rect2i(x + 1, y + 3, area.size.x - 2, area.size.y - 4), glass)
	Art.rect(image, Rect2i(x + 3, y + 1, area.size.x - 6, 2), glass)
	Art.rect(image, Rect2i(x + 2, y + 2, area.size.x - 4, 1), glass)
	Art.h_line(image, x + 3, y + 1, area.size.x - 6, P.WATER_FOAM)
	Art.v_line(image, x + area.size.x / 2, y + 1, area.size.y - 1, trim)
	Art.h_line(image, x - 1, area.end.y, area.size.x + 2, trim)


## 圆窗 / 舷窗。
func _porthole(image: Image, center: Vector2i, glass: Color, trim: Color) -> void:
	Art.circle(image, center, 5, trim)
	Art.circle(image, center, 4, P.GLASS_DARK)
	Art.circle(image, center, 3, glass)
	Art.px(image, center.x - 1, center.y - 1, P.WATER_FOAM)
	Art.px(image, center.x + 1, center.y + 1, P.WATER_FOAM)


func _door(image: Image, area: Rect2i, color: Color, trim: Color) -> void:
	Art.h_line(image, area.position.x - 2, area.position.y - 2, area.size.x + 4, trim)
	Art.rect(image, area, color)
	Art.frame_rect(image, area, trim)
	Art.v_line(image, area.position.x + area.size.x / 2, area.position.y + 1, area.size.y - 1, trim)
	Art.h_line(image, area.position.x + 1, area.position.y + 2, area.size.x - 2, color.lerp(P.WHITE, 0.28))
	Art.px(image, area.position.x + 3, area.end.y - 9, P.COIN)
	Art.px(image, area.position.x + area.size.x - 4, area.end.y - 9, P.COIN)


# ---------------------------------------------------------------- 摆件

func _shadow(image: Image, center_x: int, half: int) -> void:
	Art.ellipse(image, Vector2i(center_x, SHADOW_ROW), Vector2i(half, 2), P.SHADOW)


func _crate(image: Image, area: Rect2i, salt: int) -> void:
	Art.rect(image, area, P.PLANK)
	Art.frame_rect(image, area, P.WOOD_DARK)
	Art.h_line(image, area.position.x + 1, area.position.y + 1, area.size.x - 2, P.WOOD_LIGHT)
	Art.v_line(image, area.position.x + area.size.x / 2, area.position.y + 1, area.size.y - 2, P.WOOD_DARK)
	Art.h_line(image, area.position.x + 1, area.position.y + area.size.y / 2, area.size.x - 2, P.WOOD_DARK)
	Art.px(image, area.position.x + 2, area.position.y + 2, P.HAY)
	Art.px(image, area.position.x + 3, area.position.y + 2, P.HAY)
	Art.px(image, area.position.x + 7, area.position.y + 3, P.FRUIT_GREEN)


func _barrel(image: Image, area: Rect2i) -> void:
	Art.rect(image, area, P.WOOD)
	Art.v_line(image, area.position.x, area.position.y + 1, area.size.y - 2, P.WOOD_DARK)
	Art.v_line(image, area.end.x - 1, area.position.y + 1, area.size.y - 2, P.WOOD_DARK)
	Art.h_line(image, area.position.x, area.position.y, area.size.x, P.WOOD_LIGHT)
	Art.h_line(image, area.position.x, area.position.y + 3, area.size.x, P.STONE_DARK)
	Art.h_line(image, area.position.x, area.position.y + 7, area.size.x, P.STONE_DARK)


func _fence(image: Image, area: Rect2i) -> void:
	Art.h_line(image, area.position.x, area.position.y + 2, area.size.x, P.WOOD_LIGHT)
	Art.h_line(image, area.position.x, area.position.y + 6, area.size.x, P.WOOD_LIGHT)
	for x in range(area.position.x, area.end.x, 4):
		Art.rect(image, Rect2i(x, area.position.y, 2, area.size.y), P.WOOD)
		Art.px(image, x, area.position.y, P.WOOD_DARK)
		Art.px(image, x + 1, area.position.y, P.WOOD_DARK)


## 披在屋顶上的渔网：只画在已经不透明的像素上，天然贴合屋面。
func _net(image: Image, area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if Art.get_px(image, x, y).a <= 0.0:
				continue
			if (x + y) % 5 == 0 or (x - y) % 5 == 0:
				Art.px(image, x, y, P.HAY)
	for x in range(area.position.x, area.end.x, 4):
		if Art.get_px(image, x, area.end.y - 1).a > 0.0:
			Art.px(image, x, area.end.y, P.WOOD_LIGHT)


## 两点之间的粗线（井架 / 斜撑）。
func _beam(image: Image, from: Vector2i, to: Vector2i, color: Color, thickness: int = 2) -> void:
	var delta := to - from
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		var x := int(round(lerpf(float(from.x), float(to.x), t)))
		var y := int(round(lerpf(float(from.y), float(to.y), t)))
		Art.rect(image, Rect2i(x, y, thickness, thickness), color)


# ---------------------------------------------------------------- 招牌

## 吊在门头上的职业招牌。[param board] 尺寸为 0 表示这栋房子不挂招牌。
func _sign(image: Image, board: Rect2i, kind: StringName, salt: int, trim: Color) -> void:
	if board.size.x <= 0 or kind == &"none":
		return
	Art.v_line(image, board.position.x + 3, board.position.y - 2, 2, trim)
	Art.v_line(image, board.end.x - 4, board.position.y - 2, 2, trim)
	Art.rect(image, board, P.WOOD_LIGHT)
	Art.scatter(image, board, P.WOOD_DARK, 0.12, salt)
	Art.frame_rect(image, board, trim)
	_emblem(image, Vector2i(board.position.x + board.size.x / 2, board.position.y + board.size.y / 2), kind)


## 招牌上的职业图案。
func _emblem(image: Image, center: Vector2i, kind: StringName) -> void:
	match kind:
		&"coin":
			Art.circle(image, center, 3, P.COIN_DARK)
			Art.circle(image, center, 2, P.COIN)
			Art.px(image, center.x, center.y - 1, P.COIN_DARK)
		&"clock":
			Art.circle(image, center, 3, P.OUTLINE)
			Art.circle(image, center, 2, P.WHITE)
			Art.px(image, center.x, center.y - 1, P.OUTLINE)
			Art.px(image, center.x + 1, center.y, P.OUTLINE)
		&"hammer":
			Art.rect(image, Rect2i(center.x - 4, center.y - 3, 8, 3), P.STONE_LIGHT)
			Art.h_line(image, center.x - 4, center.y - 3, 8, P.STONE)
			Art.v_line(image, center.x, center.y, 4, P.WOOD_LIGHT)
		&"flower":
			Art.px(image, center.x, center.y - 2, P.FLOWER_PINK)
			Art.px(image, center.x - 2, center.y, P.FLOWER_PINK)
			Art.px(image, center.x + 2, center.y, P.FLOWER_PINK)
			Art.px(image, center.x, center.y + 2, P.FLOWER_RED)
			Art.px(image, center.x, center.y, P.COIN)
			Art.v_line(image, center.x, center.y + 3, 2, P.LEAF)
		&"book":
			Art.rect(image, Rect2i(center.x - 5, center.y - 2, 10, 2), P.FRUIT_PURPLE)
			Art.rect(image, Rect2i(center.x - 4, center.y, 8, 2), P.FRUIT_RED)
			Art.h_line(image, center.x - 5, center.y - 1, 10, P.UI_TEXT)
			Art.h_line(image, center.x - 4, center.y + 1, 8, P.UI_TEXT)
		&"heart":
			Art.h_line(image, center.x - 3, center.y - 2, 2, P.FLOWER_RED)
			Art.h_line(image, center.x + 2, center.y - 2, 2, P.FLOWER_RED)
			Art.h_line(image, center.x - 4, center.y - 1, 8, P.FLOWER_RED)
			Art.h_line(image, center.x - 3, center.y, 6, P.FLOWER_RED)
			Art.h_line(image, center.x - 2, center.y + 1, 4, P.FLOWER_RED)
			Art.h_line(image, center.x - 1, center.y + 2, 2, P.FLOWER_RED)
		&"fish":
			Art.ellipse(image, Vector2i(center.x - 1, center.y), Vector2i(5, 2), P.GLASS)
			Art.ellipse(image, Vector2i(center.x - 1, center.y), Vector2i(3, 1), P.WATER_LIGHT)
			Art.px(image, center.x - 4, center.y - 1, P.OUTLINE)
			for i: int in 3:
				Art.v_line(image, center.x + 4 + i, center.y - 2 + i, 5 - i * 2, P.GLASS)
		&"pickaxe":
			Art.h_line(image, center.x - 5, center.y - 2, 10, P.STONE_LIGHT)
			Art.px(image, center.x - 5, center.y - 1, P.STONE_LIGHT)
			Art.px(image, center.x + 5, center.y - 1, P.STONE_LIGHT)
			Art.v_line(image, center.x, center.y - 1, 4, P.WOOD_LIGHT)
