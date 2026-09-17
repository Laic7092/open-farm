extends GdUnitTestSuite
## 野生植被生长 / 扩散规则测试。
##
## 这是"世界会自己变化"的核心数值逻辑，也是最容易被调坏的地方，
## 因此把阶段换算、季节休眠、雨天加成、权重抽取、产出概率都钉死。

var _tree: FloraData
var _weed: FloraData
var _rock: FloraData


func before_test() -> void:
	_tree = FloraData.new()
	_tree.id = &"test_tree"
	_tree.kind = FloraData.Kind.TREE
	_tree.days_per_stage = [1, 2, 3]
	_tree.spawn_weight = [5, 5, 3, 0]
	_tree.rain_bonus = 2
	_tree.grow_seasons = [
		Season.Type.SPRING, Season.Type.SUMMER, Season.Type.FALL
	] as Array[Season.Type]
	_tree.solid_from_stage = 2
	_tree.drop_item_id = &"wood"
	_tree.drop_amount = Vector2i(2, 3)

	_weed = FloraData.new()
	_weed.id = &"test_weed"
	_weed.kind = FloraData.Kind.WEED
	_weed.days_per_stage = [1]
	_weed.spawn_weight = [7, 8, 5, 0]
	_weed.rain_bonus = 3
	_weed.grow_seasons = [
		Season.Type.SPRING, Season.Type.SUMMER, Season.Type.FALL
	] as Array[Season.Type]

	_rock = FloraData.new()
	_rock.id = &"test_rock"
	_rock.kind = FloraData.Kind.ROCK
	_rock.days_per_stage = []
	_rock.spawn_weight = [3, 3, 3, 1]
	_rock.grow_seasons = Season.all()
	_rock.solid_from_stage = 0


func _state(days: int = 0) -> FloraState:
	var state := FloraState.new(_tree.id)
	state.days_grown = days
	return state


# ---------------------------------------------------------------- 阶段

func test_stage_of_boundaries() -> void:
	assert_int(FloraGrowth.stage_of(_tree, 0)).is_equal(0)
	assert_int(FloraGrowth.stage_of(_tree, 1)).is_equal(1)
	assert_int(FloraGrowth.stage_of(_tree, 2)).is_equal(1)
	assert_int(FloraGrowth.stage_of(_tree, 3)).is_equal(2)
	assert_int(FloraGrowth.stage_of(_tree, 6)).is_equal(3)


func test_mature_and_total_days() -> void:
	assert_int(FloraGrowth.mature_days(_tree)).is_equal(6)
	assert_bool(FloraGrowth.is_mature(_tree, 5)).is_false()
	assert_bool(FloraGrowth.is_mature(_tree, 6)).is_true()


## 石头这种没有阶段的物种永远停在 0 阶段。
func test_rock_never_changes_stage() -> void:
	assert_int(FloraGrowth.stage_of(_rock, 0)).is_equal(0)
	assert_int(FloraGrowth.stage_of(_rock, 999)).is_equal(0)
	assert_bool(FloraGrowth.can_grow(_rock, Season.Type.SPRING)).is_false()
	assert_bool(_rock.can_grow()).is_false()


func test_solidity_starts_at_declared_stage() -> void:
	# days_per_stage = [1, 2, 3]：阶段 0 是第 0 天，阶段 1 是第 1~2 天，
	# 阶段 2（solid_from_stage）从第 3 天开始。
	assert_bool(FloraGrowth.is_solid(_tree, 0)).is_false()
	assert_bool(FloraGrowth.is_solid(_tree, 2)).is_false()
	assert_bool(FloraGrowth.is_solid(_tree, 3)).is_true()
	assert_bool(FloraGrowth.is_solid(_tree, 6)).is_true()
	# 石头一落地就挡路。
	assert_bool(FloraGrowth.is_solid(_rock, 0)).is_true()


# ---------------------------------------------------------------- 季节与天气

func test_winter_is_dormant_but_not_fatal() -> void:
	assert_bool(FloraGrowth.can_grow(_tree, Season.Type.WINTER)).is_false()
	var state := _state(4)
	var result := FloraGrowth.advance(_tree, state, Season.Type.WINTER)
	assert_int(state.days_grown).is_equal(4)
	assert_bool(state.dead).is_false()
	assert_bool(result[FloraGrowth.KEY_STAGE_CHANGED]).is_false()


func test_advance_grows_and_reports_stage_change() -> void:
	var state := _state(0)
	var result := FloraGrowth.advance(_tree, state, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(1)
	assert_bool(result[FloraGrowth.KEY_STAGE_CHANGED]).is_true()
	assert_bool(result[FloraGrowth.KEY_MATURED]).is_false()


## 长到"挡路"的那一天要单独报出来，[FloraField] 靠它决定何时做连通性守卫。
func test_advance_reports_becoming_solid() -> void:
	var state := _state(2)  # 阶段 1：能穿过去
	var result := FloraGrowth.advance(_tree, state, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(3)
	assert_bool(result[FloraGrowth.KEY_BECAME_SOLID]).is_true()
	assert_bool(result[FloraGrowth.KEY_MATURED]).is_false()

	result = FloraGrowth.advance(_tree, state, Season.Type.SPRING)
	assert_int(state.days_grown).is_equal(4)
	assert_bool(result[FloraGrowth.KEY_BECAME_SOLID]).is_false()


func test_spawn_weight_follows_season_and_weather() -> void:
	assert_int(FloraGrowth.spawn_weight(_tree, Season.Type.SPRING, Weather.Type.SUNNY)).is_equal(5)
	assert_int(FloraGrowth.spawn_weight(_tree, Season.Type.FALL, Weather.Type.SUNNY)).is_equal(3)
	# 冬季权重为 0。
	assert_int(FloraGrowth.spawn_weight(_tree, Season.Type.WINTER, Weather.Type.SUNNY)).is_equal(0)
	# 雨天在季节权重上加成。
	assert_int(FloraGrowth.spawn_weight(_tree, Season.Type.SPRING, Weather.Type.RAINY)).is_equal(7)
	# 雪天一颗种子都不落。
	assert_int(FloraGrowth.spawn_weight(_rock, Season.Type.WINTER, Weather.Type.SNOWY)).is_equal(0)


func test_pick_spawn_only_returns_offered_species() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240914
	var weights := {&"a": 1, &"b": 0, &"c": 3}
	for _i: int in 50:
		var picked: StringName = FloraGrowth.pick_spawn(weights, rng)
		assert_bool(picked == &"a" or picked == &"c").is_true()


func test_pick_spawn_returns_empty_without_weights() -> void:
	var rng := RandomNumberGenerator.new()
	assert_str(String(FloraGrowth.pick_spawn({}, rng))).is_empty()
	assert_str(String(FloraGrowth.pick_spawn({&"a": 0}, rng))).is_empty()


# ---------------------------------------------------------------- 产出

func test_removal_drops_within_declared_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := _state(6)
	for _i: int in 20:
		var outcome := FloraGrowth.apply_removal(_tree, state, rng)
		assert_str(String(outcome["item_id"])).is_equal("wood")
		assert_int(int(outcome["amount"])).is_between(2, 3)


func test_removal_respects_drop_chance() -> void:
	_tree.drop_chance = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var outcome := FloraGrowth.apply_removal(_tree, _state(6), rng)
	assert_int(int(outcome["amount"])).is_equal(0)


# ---------------------------------------------------------------- 地表白名单

func test_only_natural_ground_can_grow() -> void:
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS_ALT)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS_LUSH)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS_DRY)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS_DAPPLED)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.GRASS_MEADOW)).is_true()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.TALL_GRASS)).is_true()
	# 沙地 / 裸土的过渡格基底仍是自然地表，也要能长东西。
	assert_bool(
		FloraGrowth.is_natural_ground(FarmAtlas.transition_atlas(FarmAtlas.Surface.SAND, 5))
	).is_true()
	assert_bool(
		FloraGrowth.is_natural_ground(FarmAtlas.transition_atlas(FarmAtlas.Surface.DIRT, 9))
	).is_true()
	# 人摆过的地方不长东西。
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.PATH)).is_false()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.PATH_STONE)).is_false()
	assert_bool(
		FloraGrowth.is_natural_ground(FarmAtlas.transition_atlas(FarmAtlas.Surface.PATH, 5))
	).is_false()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.WATER)).is_false()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.FENCE)).is_false()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.FLOWER_BED)).is_false()
	assert_bool(FloraGrowth.is_natural_ground(FarmAtlas.SOIL_DRY)).is_false()
