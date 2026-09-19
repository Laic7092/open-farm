extends GdUnitTestSuite
## 季节外观的运行时行为：换贴图、换图集、刷新时机。
##
## 这一层测的是"[SeasonLook] 有没有把季节推到该推的地方"，而不是颜色本身
## （颜色由 [code]tests/unit/test_season_palette.gd[/code] 与素材测试守）。
## 关键点：[code]TileMapLayer.tile_set[/code] 换掉后瓦片数据必须原样保留，
## 否则换季会把整张地图铲平。

const Layout := preload("res://src/art/atlas_layout.gd")
const SeasonPalette := preload("res://src/art/season_palette.gd")

const TREE_FLORA: StringName = &"tree_oak"
const TREE_FLORA_PATH: String = "res://assets/sprites/flora/tree_oak.png"
const TREE_WINTER_PATH: String = "res://assets/sprites/flora/tree_oak_winter.png"
const TREE_PROP: String = "res://assets/sprites/props/tree.png"
const TREE_PROP_WINTER: String = "res://assets/sprites/props/tree_winter.png"
const HOUSE_PROP: String = "res://assets/sprites/props/house.png"


## [Flora] 只换贴图：冬季换到变体，基础季回退，且不碰 [code]modulate[/code]。
func test_flora_set_season_swaps_texture_and_falls_back() -> void:
	var flora := auto_free(Flora.new()) as Flora
	flora.setup(FloraState.new(TREE_FLORA), Database.get_flora(TREE_FLORA))
	assert_str(flora.texture.resource_path).is_equal(TREE_FLORA_PATH)

	flora.set_season(Season.Type.WINTER)
	assert_str(flora.texture.resource_path).is_equal(TREE_WINTER_PATH)
	# 季节不能写进 modulate：那是"枯死偏黄"的语义。
	assert_bool(flora.modulate == Color(1, 1, 1, 1)).is_true()

	flora.set_season(SeasonPalette.BASE_SEASON)
	assert_str(flora.texture.resource_path).is_equal(TREE_FLORA_PATH)


## 跨季时 [FloraField] 要遍历所有节点，而不是只刷状态变了的格子。
func test_flora_field_apply_season_reaches_every_node() -> void:
	var field := auto_free(FloraField.new()) as FloraField
	var flora := Flora.new() as Flora
	field.add_child(flora)
	flora.setup(FloraState.new(TREE_FLORA), Database.get_flora(TREE_FLORA))
	field._nodes[Vector2i.ZERO] = flora

	field.apply_season(Season.Type.WINTER)
	assert_str(flora.texture.resource_path).is_equal(TREE_WINTER_PATH)
	field.apply_season(SeasonPalette.BASE_SEASON)
	assert_str(flora.texture.resource_path).is_equal(TREE_FLORA_PATH)


## [WorldProp] 换季幂等：同一季节反复调用不会反复替换贴图对象。
func test_world_prop_apply_season_is_idempotent() -> void:
	var prop := auto_free(WorldProp.new()) as WorldProp
	prop.texture = load(TREE_PROP) as Texture2D

	prop.apply_season(Season.Type.WINTER)
	var winter := prop.texture
	assert_str(winter.resource_path).is_equal(TREE_PROP_WINTER)
	prop.apply_season(Season.Type.WINTER)
	assert_bool(prop.texture == winter).is_true()

	prop.apply_season(SeasonPalette.BASE_SEASON)
	assert_str(prop.texture.resource_path).is_equal(TREE_PROP)


## 没有变体的摆件（房子）原样保留，运行时才能无脑遍历所有 WorldProp。
func test_world_prop_without_variant_keeps_texture() -> void:
	var prop := auto_free(WorldProp.new()) as WorldProp
	var house := load(HOUSE_PROP) as Texture2D
	prop.texture = house
	prop.apply_season(Season.Type.WINTER)
	assert_bool(prop.texture == house).is_true()


## 换图集不能丢瓦片数据，否则换季会把整张地图铲平。
func test_refresh_swaps_tileset_without_losing_cells() -> void:
	var clock := GameDateClock.new()
	clock.set_date(GameDate.new(1, Season.Type.WINTER, 1))
	var root := auto_free(Node2D.new()) as Node2D
	add_child(root)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = load(Layout.TILESET_RESOURCE_PATH) as TileSet
	root.add_child(layer)
	layer.set_cell(Vector2i.ZERO, 0, Vector2i(8, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(8, 0))

	var look := auto_free(SeasonLook.new()) as SeasonLook
	look.bind_dependencies(null, clock)
	root.add_child(look)
	look.refresh()

	assert_str(layer.tile_set.resource_path).is_equal(
		SeasonPalette.variant_path(Layout.TILESET_RESOURCE_PATH, Season.Type.WINTER)
	)
	assert_int(layer.get_used_cells().size()).is_equal(2)
	assert_bool(layer.get_cell_atlas_coords(Vector2i.ZERO) == Vector2i(8, 0)).is_true()


## 日结转只在季节真的变了才刷；回到基础季时图集也要回退。
func test_rollover_only_refreshes_on_real_season_change() -> void:
	var clock := GameDateClock.new()
	clock.set_date(GameDate.new(1, Season.Type.SPRING, 1))
	var root := auto_free(Node2D.new()) as Node2D
	add_child(root)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = load(Layout.TILESET_RESOURCE_PATH) as TileSet
	root.add_child(layer)
	var look := auto_free(SeasonLook.new()) as SeasonLook
	look.bind_dependencies(null, clock)
	root.add_child(look)

	look.refresh()
	var count := look.refresh_count
	look._on_day_rollover(GameDate.new(1, Season.Type.SPRING, 2))
	assert_int(look.refresh_count).override_failure_message("同一季节内不该重复刷新").is_equal(count)

	clock.set_date(GameDate.new(1, Season.Type.WINTER, 1))
	look._on_day_rollover(clock.date)
	assert_int(look.refresh_count).is_equal(count + 1)
	assert_str(layer.tile_set.resource_path).is_equal(
		SeasonPalette.variant_path(Layout.TILESET_RESOURCE_PATH, Season.Type.WINTER)
	)

	clock.set_date(GameDate.new(1, Season.Type.SPRING, 1))
	look._on_day_rollover(clock.date)
	assert_str(layer.tile_set.resource_path).is_equal(Layout.TILESET_RESOURCE_PATH)


## 没有注入时钟时按基础季处理（单独跑节点、编辑器预览都不该崩）。
func test_refresh_without_clock_uses_base_season() -> void:
	var look := auto_free(SeasonLook.new()) as SeasonLook
	add_child(look)
	look.refresh()
	assert_bool(look.season() == SeasonPalette.BASE_SEASON).is_true()


## 退出场景树要注销日结转钩子，否则缓存复用会重复注册。
func test_exit_tree_unregisters_day_hook() -> void:
	var clock := GameDateClock.new()
	var look := SeasonLook.new()
	look.bind_dependencies(null, clock)
	add_child(look)
	assert_int(clock.day_pipeline.size()).is_equal(1)
	remove_child(look)
	assert_int(clock.day_pipeline.size()).is_equal(0)
	look.free()
