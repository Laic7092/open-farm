extends GdUnitTestSuite
## 世界摆件尺度契约的可执行版本。
##
## [code]AtlasLayout.PROPS[/code] 是摆件尺寸的唯一事实来源：
## 生成器按 [code]visual[/code] 出图，[WorldProp] 按 [code]solid[/code] / [code]solid_offset[/code]
## 建碰撞，测试在这里把"表 ↔ 生成物 ↔ 玩家基准"三者钉死。
##
## 只测数据与几何，不把节点挂进场景树。

const Layout := preload("res://src/art/atlas_layout.gd")
const PROP_DIR: String = "res://assets/sprites/props"


## 玩家是全表的唯一参照：占地 1 格、视觉 2 格高。
func test_player_is_the_reference() -> void:
	assert_that(Layout.PLAYER_FOOTPRINT).is_equal(Vector2i(1, 1))
	assert_that(Layout.PLAYER_VISUAL).is_equal(Vector2i(1, 2))


## 每条目都必须有对应的 PNG，且像素尺寸与 visual 完全一致（改表没重跑生成器会红）。
func test_every_prop_art_matches_table() -> void:
	for prop_id: StringName in Layout.PROPS:
		var spec: Dictionary = Layout.PROPS[prop_id]
		var visual: Vector2i = spec["visual"]
		var path := "%s/%s.png" % [PROP_DIR, prop_id]
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message("缺少 %s" % path).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).override_failure_message(
			"%s 宽度应为 %d" % [path, visual.x]
		).is_equal(visual.x)
		assert_int(texture.get_height()).override_failure_message(
			"%s 高度应为 %d" % [path, visual.y]
		).is_equal(visual.y)


## 逻辑占地必须是正整数格，且不超过贴图能覆盖的格数：
## 允许"视觉大于占地"（树冠、灯头），不允许"占地比画还大"。
func test_footprint_fits_visual() -> void:
	for prop_id: StringName in Layout.PROPS:
		var spec: Dictionary = Layout.PROPS[prop_id]
		var visual: Vector2i = spec["visual"]
		var footprint: Vector2i = spec["footprint"]
		var max_cells := Vector2i(
			ceili(float(visual.x) / Layout.TILE), ceili(float(visual.y) / Layout.TILE)
		)
		assert_bool(footprint.x >= 1 and footprint.y >= 1).override_failure_message(
			"%s 的 footprint 必须至少 1×1，实际 %s" % [prop_id, footprint]
		).is_true()
		assert_bool(
			footprint.x <= max_cells.x and footprint.y <= max_cells.y
		).override_failure_message(
			"%s 的 footprint %s 超出视觉 %s 覆盖的 %s 格" % [prop_id, footprint, visual, max_cells]
		).is_true()


## 不可穿过的摆件必须有实际阻挡盒；可穿过的（如地毯）不参与碰撞。
func test_solid_box_or_passable() -> void:
	for prop_id: StringName in Layout.PROPS:
		var spec: Dictionary = Layout.PROPS[prop_id]
		if bool(spec["passable"]):
			continue
		var solid: Vector2 = spec["solid"]
		assert_bool(solid.x > 0.0 and solid.y > 0.0).override_failure_message(
			"%s 不可穿过，但 solid 为 %s" % [prop_id, solid]
		).is_true()


## [WorldProp] 能从贴图文件名推断 prop id，并直接吃到表里的碰撞盒。
func test_world_prop_resolves_spec_from_texture() -> void:
	var prop := WorldProp.new()
	prop.texture = load("%s/lamp.png" % PROP_DIR)
	assert_that(prop.resolve_prop_id()).is_equal(&"lamp")
	assert_that(prop._effective_solid_size()).is_equal(Layout.prop_spec(&"lamp")["solid"])
	prop.free()


## 未知 id 一律回退：空条目、零视觉、零占地、按实心处理。
func test_unknown_prop_falls_back_safely() -> void:
	assert_bool(Layout.prop_spec(&"no_such_prop").is_empty()).is_true()
	assert_that(Layout.prop_visual(&"no_such_prop")).is_equal(Vector2i.ZERO)
	assert_that(Layout.prop_footprint(&"no_such_prop")).is_equal(Vector2i.ZERO)
	assert_bool(Layout.prop_passable(&"no_such_prop")).is_false()


## 住宅由 [code]generate_houses.gd[/code] 生成、场景碰撞按 [constant AtlasLayout.HOUSE_SIZE]
## 标定：表里所有住宅的 visual 必须与它一致，否则换图会同时挪碰撞。
func test_house_variants_match_house_size() -> void:
	for prop_id: StringName in Layout.PROPS:
		if prop_id == &"house" or String(prop_id).begins_with("house_"):
			assert_that(Layout.prop_visual(prop_id)).override_failure_message(
				"%s 的 visual 必须等于 HOUSE_SIZE" % prop_id
			).is_equal(Layout.HOUSE_SIZE)


## 本批定稿的三类轮廓：大石占地 4 格、路灯高于玩家、树 2×4。
func test_silhouette_targets() -> void:
	assert_that(Layout.prop_footprint(&"rock_big")).is_equal(Vector2i(2, 2))
	var player_height: int = Layout.PLAYER_VISUAL.y * Layout.TILE
	assert_int(Layout.prop_visual(&"lamp").y).override_failure_message(
		"路灯应高于 2 格玩家"
	).is_greater(player_height)
	assert_that(Layout.prop_visual(&"tree")).is_equal(Vector2i(32, 64))
	assert_that(Layout.prop_visual(&"tree_pine")).is_equal(Vector2i(32, 64))
