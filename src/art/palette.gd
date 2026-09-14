class_name ArtPalette
extends RefCounted
## 全局调色板——[b]美术资源颜色的唯一事实来源[/b]。
##
## 生成脚本（[code]tools/art/*.gd[/code]）与游戏运行时代码都从这里取色，
## 因此"整体色调"是一个可以在一处调整的参数，而不是散落在几百个
## [code]Color8(...)[/code] 里的魔法数字。
##
## [b]规范[/b]：任何新的美术生成器都不得写死颜色字面量；
## 确实需要新颜色时，先在本文件里起一个有意义的名字。
##
## 配色取向：明度分层（每个材质给出 base / dark / light 三档），
## 保证 16×16 的小图在整数缩放后依然有体积感。

# ---------------------------------------------------------------- 通用

const OUTLINE := Color8(36, 28, 32)
const SHADOW := Color(0.0, 0.0, 0.0, 0.22)
const SHADOW_STRONG := Color(0.0, 0.0, 0.0, 0.35)
const WHITE := Color8(248, 248, 240)
const BLACK := Color8(24, 20, 28)

# ---------------------------------------------------------------- 草地

const GRASS := Color8(96, 160, 72)
const GRASS_DARK := Color8(72, 132, 56)
const GRASS_LIGHT := Color8(126, 186, 92)

# ---------------------------------------------------------------- 土地

const PATH := Color8(186, 152, 104)
const PATH_DARK := Color8(150, 118, 78)
const PATH_LIGHT := Color8(210, 180, 132)
const DIRT := Color8(152, 116, 78)
const DIRT_DARK := Color8(120, 88, 58)
const SOIL := Color8(126, 88, 56)
const SOIL_DARK := Color8(92, 62, 38)
const SOIL_LIGHT := Color8(154, 112, 74)
const SOIL_WET := Color8(78, 54, 36)
const SOIL_WET_DARK := Color8(54, 36, 24)
const SOIL_WET_LIGHT := Color8(100, 72, 50)
const GRAVEL := Color8(168, 164, 156)
const GRAVEL_DARK := Color8(132, 128, 122)
const SAND := Color8(226, 206, 148)
const SAND_DARK := Color8(196, 174, 120)

# ---------------------------------------------------------------- 水

const WATER := Color8(58, 122, 186)
const WATER_DARK := Color8(40, 92, 152)
const WATER_LIGHT := Color8(112, 176, 226)
const WATER_FOAM := Color8(226, 240, 248)

# ---------------------------------------------------------------- 石 / 木

const STONE := Color8(150, 150, 156)
const STONE_DARK := Color8(108, 108, 116)
const STONE_LIGHT := Color8(186, 186, 192)
const WOOD := Color8(166, 118, 70)
const WOOD_DARK := Color8(118, 80, 46)
const WOOD_LIGHT := Color8(198, 152, 100)
const PLANK := Color8(186, 142, 92)

# ---------------------------------------------------------------- 植被

const LEAF := Color8(88, 164, 74)
const LEAF_DARK := Color8(56, 116, 52)
const LEAF_LIGHT := Color8(126, 196, 96)
const TRUNK := Color8(120, 82, 50)
const TRUNK_DARK := Color8(86, 58, 36)
const FLOWER_PINK := Color8(230, 106, 138)
const FLOWER_RED := Color8(214, 78, 78)
const FLOWER_YELLOW := Color8(244, 212, 104)
const FLOWER_WHITE := Color8(246, 246, 238)
const FLOWER_BLUE := Color8(112, 148, 224)
const WITHER := Color8(150, 130, 96)
const WITHER_DARK := Color8(112, 96, 68)
const MUSHROOM_CAP := Color8(206, 82, 74)
const MUSHROOM_STEM := Color8(240, 232, 214)

# ---------------------------------------------------------------- 建筑

const ROOF := Color8(186, 84, 72)
const ROOF_DARK := Color8(140, 58, 52)
const ROOF_LIGHT := Color8(218, 118, 100)
const WALL := Color8(232, 214, 182)
const WALL_DARK := Color8(194, 172, 138)
const WALL_LIGHT := Color8(248, 238, 214)
const GLASS := Color8(122, 178, 208)
const GLASS_DARK := Color8(84, 132, 166)

## 各角色住宅的屋顶材质。每栋房子按"角色职业"换一种瓦色，
## 于是"谁住在哪"在画面上就能认出来，而不用读牌子。
## 三档明暗的用法见 [code]tools/art/generate_houses.gd[/code]。
const ROOF_SLATE := Color8(104, 112, 146)       # 村公所：青石板
const ROOF_SLATE_DARK := Color8(72, 78, 110)
const ROOF_SLATE_LIGHT := Color8(146, 156, 190)
const ROOF_IRON := Color8(92, 88, 100)          # 铁匠铺：铁皮顶
const ROOF_IRON_DARK := Color8(62, 58, 72)
const ROOF_IRON_LIGHT := Color8(132, 128, 142)
const ROOF_ROSE := Color8(216, 132, 152)        # 花店：玫瑰色瓦
const ROOF_ROSE_DARK := Color8(168, 92, 116)
const ROOF_ROSE_LIGHT := Color8(242, 178, 194)
const ROOF_INDIGO := Color8(96, 100, 172)       # 图书馆：靛蓝瓦
const ROOF_INDIGO_DARK := Color8(64, 68, 132)
const ROOF_INDIGO_LIGHT := Color8(136, 142, 212)
const ROOF_THATCH := Color8(202, 164, 92)       # 小女孩家：茅草顶
const ROOF_THATCH_DARK := Color8(156, 122, 62)
const ROOF_THATCH_LIGHT := Color8(232, 200, 130)
const ROOF_TEAL := Color8(78, 134, 130)         # 渔夫小屋：海风绿
const ROOF_TEAL_DARK := Color8(52, 98, 96)
const ROOF_TEAL_LIGHT := Color8(112, 174, 166)
const ROOF_MOSS := Color8(98, 138, 84)          # 矿工木屋：长苔的木顶
const ROOF_MOSS_DARK := Color8(68, 102, 60)
const ROOF_MOSS_LIGHT := Color8(132, 174, 108)

# ---------------------------------------------------------------- 角色

const SKIN := Color8(242, 202, 164)
const SKIN_DARK := Color8(206, 162, 124)
const HAIR := Color8(96, 62, 40)
const HAIR_LIGHT := Color8(132, 90, 56)
const SHIRT := Color8(66, 108, 186)
const SHIRT_DARK := Color8(46, 78, 142)
const PANTS := Color8(78, 78, 106)
const PANTS_DARK := Color8(56, 56, 78)
const BOOT := Color8(76, 52, 36)
const APRON := Color8(238, 232, 218)

const NPC_SHIRT := Color8(178, 92, 108)
const NPC_SHIRT_DARK := Color8(136, 66, 82)
const NPC_HAIR := Color8(196, 190, 182)
const NPC_HAIR_DARK := Color8(150, 144, 138)
## 角色外观补充色：金发 / 皮革围裙 / 头巾 / 安全帽 / 眼镜。
const NPC_HAIR_BLONDE := Color8(212, 176, 96)
const APRON_LEATHER := Color8(150, 104, 62)
const BANDANA_NAVY := Color8(52, 74, 120)
const HELMET_YELLOW := Color8(240, 200, 72)
const HELMET_DARK := Color8(186, 146, 44)
const GLASSES := Color8(58, 60, 78)

# ---------------------------------------------------------------- 牲畜

const ANIMAL_HIDE := Color8(240, 234, 224)   # 奶牛 / 鸡的浅色毛
const ANIMAL_SPOT := Color8(62, 52, 58)      # 奶牛黑斑
const ANIMAL_SNOUT := Color8(232, 166, 166)  # 粉色口鼻
const ANIMAL_CHICK := Color8(246, 214, 118)  # 幼鸡黄
const ANIMAL_HOOF := Color8(84, 66, 58)      # 蹄
const HAY := Color8(214, 178, 96)            # 干草

# ---------------------------------------------------------------- 果实

const FRUIT_RED := Color8(226, 92, 76)
const FRUIT_ORANGE := Color8(236, 148, 62)
const FRUIT_YELLOW := Color8(240, 210, 96)
const FRUIT_GREEN := Color8(140, 194, 88)
const FRUIT_PURPLE := Color8(150, 106, 190)
const SEED_BROWN := Color8(178, 146, 96)

# ---------------------------------------------------------------- UI

const UI_PANEL := Color8(84, 60, 92)
const UI_PANEL_DARK := Color8(52, 36, 60)
const UI_PANEL_LIGHT := Color8(122, 90, 128)
const UI_BORDER := Color8(38, 26, 44)
const UI_TEXT := Color8(248, 244, 226)
const UI_TEXT_DIM := Color8(178, 172, 190)
const UI_GOLD := Color8(250, 214, 118)
const UI_BUTTON := Color8(96, 74, 108)
const UI_BUTTON_HOVER := Color8(132, 102, 146)
const UI_BUTTON_PRESSED := Color8(72, 54, 82)
const UI_SLOT := Color8(62, 46, 72)
const UI_SLOT_HOVER := Color8(104, 82, 118)

const STAMINA_FILL := Color8(122, 200, 108)
const STAMINA_BACK := Color8(46, 44, 62)
const COIN := Color8(250, 206, 96)
const COIN_DARK := Color8(206, 154, 56)

# ---------------------------------------------------------------- 天气 / 天空

const SKY_DAWN := Color8(96, 122, 190)
const SKY_DAY := Color8(126, 186, 232)
const SKY_DUSK := Color8(240, 158, 118)
const SKY_NIGHT := Color8(42, 48, 92)
const CLOUD := Color8(246, 248, 250)
const CLOUD_DARK := Color8(206, 214, 226)
const SUN := Color8(252, 226, 120)
const SUN_CORE := Color8(255, 248, 200)
const MOON := Color8(238, 238, 210)
const RAIN := Color8(168, 200, 236)
const SNOW := Color8(244, 248, 252)
const HILL_FAR := Color8(122, 156, 118)
const HILL_NEAR := Color8(96, 138, 92)

# ---------------------------------------------------------------- 昼夜环境光

## [CanvasModulate] 的全局环境光：白天纯白（不改变原色），越晚越冷、越暗。
## 关键帧与插值规则见 [code]src/world/day_night.gd[/code]；
## 这里只定义"颜色本身"，是调夜景色调的唯一入口。
const AMBIENT_DAY := Color(1.0, 1.0, 1.0)
const AMBIENT_DAWN := Color(0.62, 0.68, 0.92)
const AMBIENT_MORNING := Color(1.0, 0.94, 0.84)
const AMBIENT_EVENING := Color(1.0, 0.84, 0.66)
const AMBIENT_DUSK := Color(0.70, 0.58, 0.74)
const AMBIENT_NIGHT := Color(0.45, 0.50, 0.76)

## 点光源（路灯 / 窗灯）的颜色；半径由场景里的 [code]WorldProp.light_radius[/code] 指定。
const LAMP_GLOW := Color8(255, 214, 150)

## 天气对画面的染色，由 [code]WorldLighting[/code] 与昼夜环境光相乘。
const WEATHER_SUNNY := Color(1.0, 1.0, 1.0)
const WEATHER_CLOUDY := Color(0.88, 0.9, 0.95)
const WEATHER_RAINY := Color(0.7, 0.76, 0.88)
const WEATHER_STORMY := Color(0.54, 0.6, 0.76)
const WEATHER_SNOWY := Color(0.93, 0.95, 1.0)


## 按 [param amount]（-1..1）把颜色压暗或提亮，用于快速生成明暗档。
static func shade(color: Color, amount: float) -> Color:
	if amount >= 0.0:
		return color.lerp(WHITE, amount)
	return color.lerp(BLACK, -amount)


## 把颜色转成"网点"用的两种颜色（像素画里做质感）。
static func checker_pair(color: Color) -> Array[Color]:
	return [color, shade(color, -0.12)]


## 调色板里 [param index] 个颜色，供"按 id 稳定取色"用。
static func accent(index: int) -> Color:
	var wheel: Array[Color] = [
		FRUIT_RED, FRUIT_ORANGE, FRUIT_YELLOW, FRUIT_GREEN, FRUIT_PURPLE,
		FLOWER_PINK, FLOWER_BLUE, COIN,
	]
	return wheel[posmod(index, wheel.size())]
