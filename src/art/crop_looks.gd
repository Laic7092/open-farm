extends RefCounted
## 作物外观表——[code]assets/sprites/crops/<id>.png[/code] 与道具图标的唯一事实来源。
##
## 形状只有三种（球根 / 丛生 / 藤架），足够覆盖全部作物；新增作物时先挑一个形状，
## 再调颜色即可。这里同时被 [code]tools/art/generate_crops.gd[/code]（生长图）与
## [code]tools/art/generate_items.gd[/code]（收获物 / 种子袋图标）读取，
## 因此"同一作物在田里和背包里长得像"是结构上保证的。
##
## [b]为什么单独成文件[/b]：两个生成器都是 [SceneTree] 脚本，互相 preload 会连
## [method SceneTree._initialize] 一起带进来；把纯数据抽到 [RefCounted] 里两边共用。

const P := preload("res://src/art/palette.gd")

const LOOKS := {
	# ------------------------------------------------------------ 春
	&"turnip": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FLOWER_WHITE, "fruit_dark": P.APRON,
	},
	&"potato": {
		"shape": "bush", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.SOIL_LIGHT, "fruit_dark": P.SOIL_DARK,
	},
	&"strawberry": {
		"shape": "bush", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_RED, "fruit_dark": P.ROOF_DARK,
	},
	&"cabbage": {
		"shape": "bush", "leaf": P.LEAF_LIGHT, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_GREEN, "fruit_dark": P.LEAF_DARK,
	},
	&"onion": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
	&"tulip": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FLOWER_PINK, "fruit_dark": P.ROOF_ROSE_DARK,
	},
	# ------------------------------------------------------------ 夏
	&"tomato": {
		"shape": "vine", "leaf": P.LEAF_DARK, "leaf_dark": P.LEAF,
		"fruit": P.FRUIT_RED, "fruit_dark": P.ROOF_DARK,
	},
	&"corn": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
	&"melon": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_GREEN, "fruit_dark": P.LEAF_DARK,
	},
	&"eggplant": {
		"shape": "bush", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_PURPLE, "fruit_dark": P.ROOF_INDIGO_DARK,
	},
	&"sunflower": {
		"shape": "vine", "leaf": P.LEAF_DARK, "leaf_dark": P.LEAF,
		"fruit": P.FLOWER_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
	&"pineapple": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
	# ------------------------------------------------------------ 秋
	&"pumpkin": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_ORANGE, "fruit_dark": P.ROOF_DARK,
	},
	&"carrot": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_ORANGE, "fruit_dark": P.FRUIT_RED,
	},
	&"spinach": {
		"shape": "bush", "leaf": P.LEAF_DARK, "leaf_dark": P.LEAF,
		"fruit": P.LEAF, "fruit_dark": P.LEAF_DARK,
	},
	&"sweet_potato": {
		"shape": "bush", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_PURPLE, "fruit_dark": P.SOIL_DARK,
	},
	&"grape": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_PURPLE, "fruit_dark": P.ROOF_INDIGO_DARK,
	},
	&"chrysanthemum": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FLOWER_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
	# ------------------------------------------------------------ 冬
	&"bok_choy": {
		"shape": "bush", "leaf": P.LEAF_LIGHT, "leaf_dark": P.LEAF_DARK,
		"fruit": P.LEAF, "fruit_dark": P.LEAF_DARK,
	},
	&"broccoli": {
		"shape": "bush", "leaf": P.LEAF_DARK, "leaf_dark": P.LEAF,
		"fruit": P.FRUIT_GREEN, "fruit_dark": P.LEAF_DARK,
	},
	&"snow_pea": {
		"shape": "vine", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.FRUIT_GREEN, "fruit_dark": P.LEAF_DARK,
	},
	&"white_radish": {
		"shape": "bulb", "leaf": P.LEAF, "leaf_dark": P.LEAF_DARK,
		"fruit": P.WHITE, "fruit_dark": P.WALL_DARK,
	},
	&"kale": {
		"shape": "bush", "leaf": P.LEAF_LIGHT, "leaf_dark": P.LEAF_DARK,
		"fruit": P.LEAF_LIGHT, "fruit_dark": P.LEAF_DARK,
	},
	&"wintersweet": {
		"shape": "vine", "leaf": P.LEAF_DARK, "leaf_dark": P.LEAF,
		"fruit": P.FLOWER_YELLOW, "fruit_dark": P.FRUIT_ORANGE,
	},
}
