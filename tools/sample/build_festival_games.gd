extends "res://tools/sample/sample_base.gd"
## festival_games：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 三场品评会：花祭比花、烟花大会比钓上来的鱼、收获祭比作物。
## 参赛品显式列出（而不是按类别过滤），生成时能顺着清单核对 id 是否存在；
## 评分规则在 [FestivalGameRules]，这里只管数值与名单。

## (id, 参赛道具清单, 夺冠门槛, 奖金, 安慰奖)
const GAMES: Array = [
	[
		&"flower_exhibit",
		[&"flower", &"tulip", &"sunflower", &"chrysanthemum", &"wintersweet"],
		150, 600, 100,
	],
	[
		&"fishing_derby",
		[
			&"sardine", &"mackerel", &"sea_bream", &"squid", &"octopus",
			&"tuna", &"crucian", &"carp", &"catfish", &"golden_carp",
		],
		250, 800, 150,
	],
	[
		&"harvest_contest",
		[
			&"turnip", &"potato", &"tomato", &"corn", &"pumpkin", &"melon",
			&"cabbage", &"carrot", &"eggplant", &"strawberry", &"grape", &"pineapple",
		],
		200, 700, 120,
	],
]


func build() -> void:
	for entry: Array in GAMES:
		_game(entry[0], entry[1], int(entry[2]), int(entry[3]), int(entry[4]))


func _game(
	game_id: StringName, item_ids: Array, min_score: int, reward: int, consolation: int
) -> void:
	var game := FestivalGameData.new()
	game.id = game_id
	game.display_name_key = StringName("FESTIVAL_GAME_%s" % String(game_id).to_upper())
	game.item_ids = _str_array(item_ids)
	game.min_score = min_score
	game.reward_money = reward
	game.consolation_money = consolation
	_save(game, FESTIVAL_GAME_DIR.path_join("%s.tres" % game_id))
