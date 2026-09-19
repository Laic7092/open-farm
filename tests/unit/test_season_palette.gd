extends GdUnitTestSuite
## [SeasonPalette] 的映射表与路径规则。
##
## 这张表是"冬季长什么样"的唯一事实来源，所以测试盯三件事：
## [br]1. 冬季覆盖了画法取过的每一个材质，且三档颜色都真的与基础色不同
##    （漏一个就会在生成图里残留绿色）；
## [br]2. 没有覆盖的季节是"占位"：与基础色逐值相同、不产生变体文件；
## [br]3. 变体路径由 [method Season.to_key] 派生，不写死字面量。

const Layout := preload("res://src/art/atlas_layout.gd")
const SeasonPalette := preload("res://src/art/season_palette.gd")

const TREE_PROP: String = "res://assets/sprites/props/tree.png"
const HOUSE_PROP: String = "res://assets/sprites/props/house.png"
const TILESET: String = "res://assets/tilesets/farm_tileset.tres"


## 冬季必须覆盖全部材质，且每一档都不能等于基础色——否则生成图会残留基础色。
func test_winter_overrides_every_material_with_different_colors() -> void:
	var winter: Dictionary = SeasonPalette.OVERRIDES[Season.Type.WINTER]
	for name: StringName in SeasonPalette.material_names():
		assert_bool(winter.has(name)).override_failure_message(
			"冬季缺少材质 %s 的覆盖：生成图会残留基础色" % name
		).is_true()
		if not winter.has(name):
			continue
		var base := SeasonPalette.material(SeasonPalette.BASE_SEASON, name)
		var variant := SeasonPalette.material(Season.Type.WINTER, name)
		assert_int(variant.size()).override_failure_message(
			"材质 %s 的冬季颜色不是三档" % name
		).is_equal(3)
		for index: int in base.size():
			assert_bool(variant[index] != base[index]).override_failure_message(
				"材质 %s 第 %d 档冬季色与基础色相同（%s）" % [name, index, base[index]]
			).is_true()


## 春 / 夏 / 秋是占位季：不回退到基础色以外的任何东西，也不产生变体。
func test_uncovered_seasons_are_placeholders() -> void:
	for season: Season.Type in [
		Season.Type.SPRING, Season.Type.SUMMER, Season.Type.FALL
	]:
		assert_bool(SeasonPalette.has_variant(season)).override_failure_message(
			"季节 %s 不该有变体（本轮只做冬季）" % Season.to_key(season)
		).is_false()
		for name: StringName in SeasonPalette.material_names():
			var fallback := SeasonPalette.material(season, name)
			var base := SeasonPalette.material(SeasonPalette.BASE_SEASON, name)
			assert_bool(fallback == base).override_failure_message(
				"季节 %s 的材质 %s 应当逐值回退基础色" % [Season.to_key(season), name]
			).is_true()
	assert_bool(SeasonPalette.has_variant(Season.Type.WINTER)).is_true()


## 基础季自己不算"有变体"，否则基础一遍会被当成变体写两份。
func test_base_season_has_no_variant_even_if_overridden() -> void:
	assert_bool(SeasonPalette.has_variant(SeasonPalette.BASE_SEASON)).is_false()
	var order := SeasonPalette.seasons_to_build()
	assert_int(order.size()).is_equal(2)
	assert_bool(order[0] == SeasonPalette.BASE_SEASON).is_true()
	assert_bool(order[1] == Season.Type.WINTER).is_true()


## 后缀只由 [method Season.to_key] 派生，四个季节都不能手写。
func test_file_suffix_comes_from_season_key() -> void:
	for season: Season.Type in Season.all():
		var suffix := SeasonPalette.file_suffix(season)
		if season == Season.Type.WINTER:
			assert_str(suffix).is_equal("_winter")
		else:
			assert_str(suffix).override_failure_message(
				"季节 %s 目前不该有后缀" % Season.to_key(season)
			).is_empty()


func test_variant_path_falls_back_when_the_file_is_missing() -> void:
	var winter := Season.Type.WINTER
	# 有变体：返回 _winter 路径。
	assert_str(SeasonPalette.variant_path(TREE_PROP, winter)).is_equal(
		"res://assets/sprites/props/tree_winter.png"
	)
	# 没变体：回落基础路径，运行时因此可以无脑取 variant_path。
	assert_str(SeasonPalette.variant_path(HOUSE_PROP, winter)).is_equal(HOUSE_PROP)
	# 基础季永远返回基础路径。
	assert_str(SeasonPalette.variant_path(TREE_PROP, SeasonPalette.BASE_SEASON)).is_equal(
		TREE_PROP
	)
	assert_str(SeasonPalette.variant_suffix_path(TILESET, winter)).is_equal(
		"res://assets/tilesets/farm_tileset_winter.tres"
	)


## 无扩展名 / 点号在目录里的路径也不能被切坏。
func test_variant_suffix_path_handles_paths_without_extension() -> void:
	assert_str(SeasonPalette.variant_suffix_path("res://data/no_ext", Season.Type.WINTER)).is_equal(
		"res://data/no_ext_winter"
	)
	assert_str(
		SeasonPalette.variant_suffix_path("res://a.b/c", Season.Type.WINTER)
	).is_equal("res://a.b/c_winter")


## 变体贴图取不到时回退基础贴图，而不是返回 null。
func test_variant_texture_falls_back_to_base() -> void:
	var tree := load(TREE_PROP) as Texture2D
	var variant := SeasonPalette.variant_texture(tree, Season.Type.WINTER)
	assert_object(variant).is_not_null()
	assert_str(variant.resource_path).is_equal("res://assets/sprites/props/tree_winter.png")
	var house := load(HOUSE_PROP) as Texture2D
	assert_bool(SeasonPalette.variant_texture(house, Season.Type.WINTER) == house).is_true()
	assert_object(SeasonPalette.variant_texture(null, Season.Type.WINTER)).is_null()


## [code]Layout.TILESET_RESOURCE_PATH[/code] 必须真的能取到冬季表，否则运行时换图会静默失败。
func test_tileset_variant_exists() -> void:
	var path := SeasonPalette.variant_path(Layout.TILESET_RESOURCE_PATH, Season.Type.WINTER)
	assert_str(path).is_equal("res://assets/tilesets/farm_tileset_winter.tres")
	assert_bool(ResourceLoader.exists(path)).is_true()
