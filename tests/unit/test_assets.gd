extends GdUnitTestSuite
## 美术资源规范的可执行版本。
##
## [code]AGENTS.md[/code] 里写的规则如果只停留在文档里就没人遵守，
## 所以这里把每一条都变成断言：
## [br]- 生成物存在、尺寸与 [AtlasLayout] 一致（改了排版忘了重新生成会红）
## [br]- 像素中文字体覆盖了翻译表里的每一个字（新文案变成方块会红）
## [br]- 数据资源挂上了贴图（背包/田地不显示图标会红）

const Layout := preload("res://src/art/atlas_layout.gd")
const Palette := preload("res://src/art/palette.gd")
const SeasonPalette := preload("res://src/art/season_palette.gd")
const TileCollision := preload("res://src/world/tile_collision.gd")
const Decor := preload("res://src/world/decor_painter.gd")
const Interior := preload("res://src/world/interior_walls.gd")
const WaterLayout := preload("res://src/world/water_layout.gd")

const I18N_DIR: String = "res://assets/i18n"
const PIXEL_FONT: String = "res://assets/fonts/pixel_cjk.fnt"
const THEME_PATH: String = "res://assets/themes/game_theme.tres"
const TILESET_PATH: String = "res://assets/tilesets/farm_tileset.tres"

## 两栋住宅的剪影至少要有多少行不同，才算"两栋不同的房子"（半幅以上）。
## 阈值定得松：要挡的是"换个配色就算新建筑"，不是禁止两栋房子有相似的坡顶。
const SILHOUETTE_MIN_DIFFERENT_ROWS: int = 32

## 季节性变体的基础贴图清单；新增带叶物件时同步在这里登记，
## 否则"冬季没换色"只能等玩家看见冬天才发现。
const SEASONAL_BASES: Array[String] = [
	"res://assets/sprites/tileset_farm.png",
	"res://assets/sprites/flora/tree_oak.png",
	"res://assets/sprites/flora/tree_pine.png",
	"res://assets/sprites/flora/weed.png",
	"res://assets/sprites/props/tree.png",
	"res://assets/sprites/props/tree_pine.png",
]

## 变体命名检查：目录 → 该目录里的"基础名"清单。
## 带 [code]_<key>[/code] 后缀的文件里，key 必须是合法季节 key（防手写 [code]_winter2[/code]）。
const SEASONAL_DIRS: Dictionary = {
	"res://assets/sprites": ["tileset_farm"],
	"res://assets/sprites/flora": ["tree_oak", "tree_pine", "weed"],
	"res://assets/sprites/props": ["tree", "tree_pine"],
}

## 所有生成器都必须产出的文件。
const REQUIRED_ASSETS: Array[String] = [
	"res://assets/sprites/tileset_farm.png",
	"res://assets/sprites/water/town_0.png",
	"res://assets/sprites/water/twon_0.png",
	"res://assets/sprites/water/beach_0.png",
	"res://assets/sprites/actors/player.png",
	"res://assets/sprites/actors/npc_merchant.png",
	"res://assets/sprites/actors/npc_mayor.png",
	"res://assets/sprites/actors/npc_blacksmith.png",
	"res://assets/sprites/actors/npc_florist.png",
	"res://assets/sprites/actors/npc_fisher.png",
	"res://assets/sprites/actors/npc_miner.png",
	"res://assets/sprites/actors/npc_child.png",
	"res://assets/sprites/actors/npc_librarian.png",
	"res://assets/sprites/actors/npc_our_child.png",
	"res://assets/sprites/items/blue_feather.png",
	"res://assets/sprites/props/house.png",
	"res://assets/sprites/props/house_merchant.png",
	"res://assets/sprites/props/house_mayor.png",
	"res://assets/sprites/props/house_blacksmith.png",
	"res://assets/sprites/props/house_florist.png",
	"res://assets/sprites/props/house_librarian.png",
	"res://assets/sprites/props/house_child.png",
	"res://assets/sprites/props/house_fisher.png",
	"res://assets/sprites/props/house_miner.png",
	"res://assets/sprites/props/barn.png",
	"res://assets/sprites/props/tree.png",
	"res://assets/sprites/props/bed.png",
	"res://assets/sprites/props/shipping_bin.png",
	"res://assets/sprites/props/dock.png",
	"res://assets/sprites/props/boat.png",
	"res://assets/sprites/props/cave.png",
	"res://assets/sprites/props/bookshelf.png",
	"res://assets/sprites/props/counter.png",
	"res://assets/sprites/props/museum_stand.png",
	"res://assets/sprites/props/notice_board.png",
	"res://assets/sprites/props/forge.png",
	"res://assets/sprites/props/flower_stand.png",
	"res://assets/sprites/flora/tree_oak.png",
	"res://assets/sprites/flora/tree_pine.png",
	"res://assets/sprites/flora/weed.png",
	"res://assets/sprites/flora/rock.png",
	"res://assets/sprites/flora/boulder.png",
	"res://assets/sprites/flora/flower.png",
	"res://assets/sprites/flora/mushroom.png",
	"res://assets/sprites/animals/chicken.png",
	"res://assets/sprites/animals/cow.png",
	"res://assets/sprites/props/coop.png",
	"res://assets/sprites/props/trough.png",
	"res://assets/sprites/props/tv.png",
	"res://assets/sprites/props/table.png",
	"res://assets/sprites/props/chair.png",
	"res://assets/sprites/props/stove.png",
	"res://assets/sprites/props/wardrobe.png",
	"res://assets/sprites/props/rug.png",
	"res://assets/sprites/weather/rain_drop.png",
	"res://assets/sprites/weather/snow_flake.png",
	"res://assets/sprites/props/bobber.png",
	"res://assets/sprites/props/ripple.png",
	"res://assets/ui/panel.png",
	"res://assets/ui/button_normal.png",
	"res://assets/ui/slot.png",
	"res://assets/ui/weather_sunny.png",
	"res://assets/ui/fish_track.png",
	"res://assets/ui/fish_zone.png",
	"res://assets/ui/fish_marker.png",
	"res://assets/ui/hook_marker.png",
	"res://assets/ui/bar_tension.png",
	"res://assets/title/backdrop.png",
	"res://assets/title/cloud_a.png",
	"res://assets/title/plate.png",
	"res://assets/fonts/pixel_cjk.fnt",
	"res://assets/fonts/pixel_cjk.png",
	"res://assets/tilesets/farm_tileset.tres",
	"res://assets/themes/game_theme.tres",
]


# ---------------------------------------------------------------- 文件存在性

func test_all_generated_assets_exist() -> void:
	for path: String in REQUIRED_ASSETS:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"缺少生成物 %s（跑一次 ./tools/build_assets.sh）" % path
		).is_true()


## 全部世界地图都要在，否则 [SceneDoor] 的 target_scene 会指向空气。
func test_world_scenes_exist() -> void:
	for path: String in [
		"res://scenes/world/farm.tscn",
		"res://scenes/world/town.tscn",
		"res://scenes/world/twon.tscn",
		"res://scenes/world/beach.tscn",
		"res://scenes/world/mine.tscn",
		"res://scenes/world/library.tscn",
		"res://scenes/world/home.tscn",
		"res://scenes/world/north_woods.tscn",
		"res://scenes/world/south_pasture.tscn",
	]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"缺少世界场景 %s" % path
		).is_true()


# ---------------------------------------------------------------- 尺寸与排版

func test_tileset_png_matches_atlas_layout() -> void:
	var texture := load(Layout.TILESET_PATH) as Texture2D
	assert_object(texture).is_not_null()
	if texture == null:
		return
	assert_int(texture.get_width()).is_equal(Layout.TILESET_SIZE.x)
	assert_int(texture.get_height()).is_equal(Layout.TILESET_SIZE.y)


## 每片水体的贴图尺寸必须与 [WaterLayout] 声明的一致：运行期按同一份
## [method WaterLayout.Body.pixel_bounds] 摆放贴图，尺寸差一像素就会错位。
func test_water_textures_match_layout() -> void:
	for world_id: StringName in WaterLayout.worlds():
		var bodies := WaterLayout.bodies_for(world_id)
		assert_bool(bodies.size() > 0).override_failure_message(
			"%s 登记为有水面，却没有任何水体" % world_id
		).is_true()
		for index: int in bodies.size():
			var path: String = WaterLayout.sprite_path(world_id, index)
			var texture := load(path) as Texture2D
			assert_object(texture).override_failure_message(
				"缺少水面贴图 %s" % path
			).is_not_null()
			if texture == null:
				continue
			var expected: Vector2i = bodies[index].pixel_bounds().size
			assert_int(texture.get_width()).override_failure_message(
				"%s 宽度应为 %d" % [path, expected.x]
			).is_equal(expected.x)
			assert_int(texture.get_height()).override_failure_message(
				"%s 高度应为 %d" % [path, expected.y]
			).is_equal(expected.y)


func test_actor_png_matches_atlas_layout() -> void:
	var texture := load("res://assets/sprites/actors/player.png") as Texture2D
	assert_object(texture).is_not_null()
	if texture == null:
		return
	assert_int(texture.get_width()).is_equal(Layout.ACTOR_SIZE.x)
	assert_int(texture.get_height()).is_equal(Layout.ACTOR_SIZE.y)


## NPC 图集必须和玩家同构，否则走路动画会取到空帧。
func test_npc_png_matches_atlas_layout() -> void:
	for npc_id: StringName in Database.npcs():
		var path: String = "res://assets/sprites/actors/npc_%s.png" % npc_id
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message(
			"NPC %s 没有图集 %s" % [npc_id, path]
		).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).is_equal(Layout.NPC_SIZE.x)
		assert_int(texture.get_height()).is_equal(Layout.NPC_SIZE.y)


## 每件工具都要有一张能拿在手里的大图（16×24），否则挥动时手里是空的。
func test_every_tool_has_a_held_sprite() -> void:
	for tool_id: StringName in Database.tools():
		var path: String = "res://assets/sprites/tools/%s.png" % tool_id
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message(
			"工具 %s 没有手持贴图 %s（跑一次 ./tools/build_assets.sh）" % [tool_id, path]
		).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).override_failure_message(
			"%s 宽度应为 %d" % [path, Layout.TOOL_SPRITE_SIZE.x]
		).is_equal(Layout.TOOL_SPRITE_SIZE.x)
		assert_int(texture.get_height()).override_failure_message(
			"%s 高度应为 %d" % [path, Layout.TOOL_SPRITE_SIZE.y]
		).is_equal(Layout.TOOL_SPRITE_SIZE.y)


## 每栋住宅都必须是 64×64（场景里的落地碰撞盒按这个尺寸标定），
## 而且**剪影**必须各成一栋——只换配色不算换了房子。
func test_npc_houses_are_distinct() -> void:
	var dir := DirAccess.open("res://assets/sprites/props")
	assert_object(dir).override_failure_message("打不开道具目录").is_not_null()
	if dir == null:
		return
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name == "house.png" or (name.begins_with("house_") and name.ends_with(".png")):
			names.append(name)
	names.sort()
	# 农舍 + 8 位有房子的 NPC；少一张说明生成器没跑或场景指向了不存在的贴图。
	assert_int(names.size()).override_failure_message(
		"住宅贴图数量不对（只找到 %s）" % str(names)
	).is_greater_equal(9)
	var pixels: Dictionary = {}
	var profiles: Dictionary = {}
	for name: String in names:
		var texture := load("res://assets/sprites/props/%s" % name) as Texture2D
		assert_object(texture).override_failure_message("缺少 %s" % name).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).override_failure_message(
			"%s 必须与农舍同宽，否则场景里的碰撞盒会错位" % name
		).is_equal(Layout.HOUSE_SIZE.x)
		assert_int(texture.get_height()).is_equal(Layout.HOUSE_SIZE.y)
		var image := texture.get_image()
		pixels[name] = image.get_data()
		profiles[name] = _silhouette_rows(image)
	var keys: Array = pixels.keys()
	keys.sort()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			assert_bool(pixels[keys[i]] == pixels[keys[j]]).override_failure_message(
				"%s 与 %s 是同一张图：房子要跟角色走" % [keys[i], keys[j]]
			).is_false()
			var different: int = 0
			var left: Array = profiles[keys[i]]
			var right: Array = profiles[keys[j]]
			for row: int in left.size():
				if left[row] != right[row]:
					different += 1
			assert_int(different).override_failure_message(
				"%s 与 %s 的剪影雷同（只有 %d/%d 行不同）：房子要换体量，不只是换配色"
				% [keys[i], keys[j], different, left.size()]
			).is_greater_equal(SILHOUETTE_MIN_DIFFERENT_ROWS)


## 剪影指纹：每行的 (最左, 最右, 不透明像素数)。
## 外形相同、只是换了颜色时，两栋房子的指纹会逐行相同。
func _silhouette_rows(image: Image) -> Array:
	var rows: Array = []
	for y: int in image.get_height():
		var farthest_left := image.get_width()
		var farthest_right := -1
		var count := 0
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				farthest_left = mini(farthest_left, x)
				farthest_right = maxi(farthest_right, x)
				count += 1
		rows.append(Vector3i(farthest_left, farthest_right, count))
	return rows


func test_crop_png_matches_atlas_layout() -> void:
	for crop_id: StringName in Database.crops():
		var crop := Database.get_crop(crop_id)
		assert_object(crop.sprite_sheet).override_failure_message(
			"作物 %s 没有挂生长图" % crop_id
		).is_not_null()
		if crop.sprite_sheet == null:
			continue
		assert_int(crop.sprite_sheet.get_width()).is_equal(Layout.CROP_SIZE.x)
		assert_int(crop.sprite_sheet.get_height()).is_equal(Layout.CROP_SIZE.y)


## 野生植被的阶段表必须挂上、且放得下"成熟"那一列。
##
## 列数对不上时 [Flora] 会画出空帧（植株凭空消失），所以这条检查不能省。
func test_flora_stage_sheets_match_layout() -> void:
	for flora_id: StringName in Database.floras():
		var data := Database.get_flora(flora_id)
		assert_object(data.sprite_sheet).override_failure_message(
			"野生植被 %s 没有挂阶段图" % flora_id
		).is_not_null()
		if data.sprite_sheet == null:
			continue
		assert_int(data.sprite_sheet.get_width() % Layout.FLORA_COLUMNS).override_failure_message(
			"野生植被 %s 的贴图宽度不是 %d 列的整数倍" % [flora_id, Layout.FLORA_COLUMNS]
		).is_equal(0)
		var needed_columns: int = data.stage_count() + 1
		assert_bool(needed_columns <= Layout.FLORA_COLUMNS).override_failure_message(
			"野生植被 %s 需要 %d 列，图集只有 %d 列"
				% [flora_id, needed_columns, Layout.FLORA_COLUMNS]
		).is_true()


## 牲畜贴图必须挂上、且宽度是固定列数的整数倍。
func test_animal_sheets_match_layout() -> void:
	for animal_id: StringName in Database.animals():
		var animal := Database.get_animal(animal_id)
		assert_object(animal.sprite_sheet).override_failure_message(
			"动物 %s 没有挂贴图" % animal_id
		).is_not_null()
		if animal.sprite_sheet == null:
			continue
		assert_int(
			animal.sprite_sheet.get_width() % Layout.ANIMAL_COLUMNS
		).override_failure_message(
			"动物 %s 的贴图宽度不是 %d 列的整数倍" % [animal_id, Layout.ANIMAL_COLUMNS]
		).is_equal(0)
		assert_int(animal.sprite_sheet.get_height()).is_equal(Layout.ANIMAL_CELL)


func test_title_backdrop_matches_viewport() -> void:
	var texture := load(Layout.TITLE_BACKDROP_PATH) as Texture2D
	assert_object(texture).is_not_null()
	if texture == null:
		return
	assert_int(texture.get_width()).is_equal(Layout.TITLE_VIEWPORT.x)
	assert_int(texture.get_height()).is_equal(Layout.TITLE_VIEWPORT.y)


## Ground 不再画装饰；每个装饰 id 都应有 16×16 透明贴图，且被 DecorPainter 登记。
func test_decor_sprites_match_layout() -> void:
	assert_int(Decor.TEXTURES.size()).override_failure_message(
		"DecorPainter 的贴图表与 AtlasLayout.DECOR_SPRITES 数量不一致"
	).is_equal(Layout.DECOR_SPRITES.size())
	for name: String in Layout.DECOR_SPRITES:
		var id := StringName(name)
		assert_bool(Decor.TEXTURES.has(id)).override_failure_message(
			"DecorPainter 缺少装饰 id %s" % name
		).is_true()
		var path: String = Layout.DECOR_DIR.path_join("%s.png" % name)
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message("缺少装饰贴图 %s" % path).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).override_failure_message(
			"装饰贴图 %s 宽度应为一格" % path
		).is_equal(Layout.DECOR_SPRITE_SIZE.x)
		assert_int(texture.get_height()).override_failure_message(
			"装饰贴图 %s 高度应为一格" % path
		).is_equal(Layout.DECOR_SPRITE_SIZE.y)


## 图集里只有崖壁带碰撞：装饰与墙面已改由 [WorldProp] / [InteriorWalls] 自己挡人。
func test_only_solid_ground_tiles_have_collision() -> void:
	var tileset := load(TILESET_PATH) as TileSet
	assert_object(tileset).is_not_null()
	if tileset == null:
		return
	assert_int(tileset.get_physics_layers_count()).is_equal(1)
	assert_int(tileset.get_physics_layer_collision_layer(0)).is_equal(1)
	var source := tileset.get_source(0) as TileSetAtlasSource
	assert_object(source).is_not_null()
	if source == null:
		return
	for index: int in source.get_tiles_count():
		var atlas: Vector2i = source.get_tile_id(index)
		var data := source.get_tile_data(atlas, 0)
		assert_object(data).override_failure_message("瓦片 %s 没有 TileData" % atlas).is_not_null()
		if data == null:
			continue
		if TileCollision.is_solid(atlas):
			assert_int(data.get_collision_polygons_count(0)).override_failure_message(
				"实心地形 %s 没有碰撞多边形" % atlas
			).is_greater(0)
		else:
			assert_int(data.get_collision_polygons_count(0)).override_failure_message(
				"地板瓦片 %s 不该有碰撞" % atlas
			).is_equal(0)


## 图集的每一格都必须是真地面：声明的地面格都在，且没有全透明占位格。
func test_tileset_contains_every_declared_tile() -> void:
	var tileset := load(TILESET_PATH) as TileSet
	assert_object(tileset).is_not_null()
	if tileset == null:
		return
	assert_int(tileset.get_source_count()).is_equal(1)
	var source := tileset.get_source(0) as TileSetAtlasSource
	assert_object(source).is_not_null()
	if source == null:
		return
	var declared: Array[Vector2i] = [
		Layout.GRASS, Layout.GRASS_ALT, Layout.PATH, Layout.SOIL_DRY, Layout.SOIL_WET,
		Layout.STONE, Layout.WOOD, Layout.CLIFF, Layout.DIRT, Layout.GRAVEL,
		Layout.SAND, Layout.PATH_STONE, Layout.PATH_STONE_ALT,
		Layout.GRASS_LUSH, Layout.GRASS_DRY, Layout.GRASS_DAPPLED, Layout.GRASS_MEADOW,
	]
	for block: Vector2i in [
		Layout.PATH_TRANSITION_BLOCK, Layout.STONE_TRANSITION_BLOCK,
		Layout.SAND_TRANSITION_BLOCK, Layout.DIRT_TRANSITION_BLOCK,
	]:
		for mask: int in 16:
			declared.append(Layout.transition_cell(block, mask))
	for cell: Vector2i in declared:
		assert_bool(source.has_tile(cell)).override_failure_message(
			"TileSet 缺少瓦片 %s" % cell
		).is_true()
	assert_int(source.get_tiles_count()).is_equal(Layout.TILESET_COLUMNS * Layout.TILESET_ROWS)
	_assert_tileset_has_no_placeholder_cell()


## 占位格（整格透明）是旧布局的残留；图集应当正好被地面瓦片填满。
func _assert_tileset_has_no_placeholder_cell() -> void:
	var texture := load(Layout.TILESET_PATH) as Texture2D
	assert_object(texture).is_not_null()
	if texture == null:
		return
	var image := texture.get_image()
	assert_object(image).is_not_null()
	if image == null:
		return
	for row: int in Layout.TILESET_ROWS:
		for column: int in Layout.TILESET_COLUMNS:
			assert_bool(_has_opaque_pixel(image, Vector2i(column, row))).override_failure_message(
				"图集第 %s 格是空的：地面图集不该留占位格" % Vector2i(column, row)
			).is_true()


func _has_opaque_pixel(image: Image, cell: Vector2i) -> bool:
	for y: int in Layout.TILE:
		for x: int in Layout.TILE:
			var at := Vector2i(cell.x * Layout.TILE + x, cell.y * Layout.TILE + y)
			if image.get_pixelv(at).a > 0.0:
				return true
	return false


## 室内墙面构件同样不占图集格子：每张一张，被 [InteriorWalls] 登记。
func test_interior_sprites_match_layout() -> void:
	assert_int(Interior.TEXTURES.size()).override_failure_message(
		"InteriorWalls 的贴图表与 AtlasLayout.INTERIOR_SPRITES 数量不一致"
	).is_equal(Layout.INTERIOR_SPRITES.size())
	for name: String in Layout.INTERIOR_SPRITES:
		var id := StringName(name)
		assert_bool(Interior.TEXTURES.has(id)).override_failure_message(
			"InteriorWalls 缺少构件 id %s" % name
		).is_true()
		var path: String = Layout.INTERIOR_DIR.path_join("%s.png" % name)
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message("缺少墙面贴图 %s" % path).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).override_failure_message(
			"墙面贴图 %s 宽度应为一格" % path
		).is_equal(Layout.TILE)
		assert_int(texture.get_height()).override_failure_message(
			"墙面贴图 %s 高度应为一格" % path
		).is_equal(Layout.TILE)


# ---------------------------------------------------------------- 像素中文字体

## 翻译表里的每一个字符都必须能由像素字体画出，否则玩家会看到方块。
func test_pixel_font_covers_every_translated_character() -> void:
	var font := load(PIXEL_FONT) as FontFile
	assert_object(font).is_not_null()
	if font == null:
		return

	var missing := PackedStringArray()
	for code: int in _characters_in_strings():
		if not font.has_char(code):
			missing.append(char(code))
	assert_array(missing).override_failure_message(
		"像素字体缺少 %d 个字符：%s（重跑 ./tools/build_assets.sh）"
			% [missing.size(), "".join(missing)]
	).is_empty()


## 字体必须自带中文字形，而不是靠系统字体兜底。
func test_pixel_font_is_not_a_system_font() -> void:
	var font := load(PIXEL_FONT) as FontFile
	assert_object(font).is_not_null()
	if font == null:
		return
	assert_bool(font.has_char(0x7267)).is_true()  # "牧"
	assert_int(font.fixed_size).is_equal(12)


## 项目主题必须真的用上像素字体，否则上面两条检查没有意义。
func test_project_theme_uses_the_pixel_font() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_object(theme).is_not_null()
	if theme == null:
		return
	assert_int(theme.default_font_size).is_equal(Layout.TILE - 4)
	var font := theme.default_font
	assert_bool(_font_chain_contains_pixel(font)).override_failure_message(
		"主题默认字体链里没有像素字体"
	).is_true()


# ---------------------------------------------------------------- 数据与贴图

func test_every_item_has_an_icon() -> void:
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		assert_object(item.icon).override_failure_message(
			"道具 %s 没有图标" % item_id
		).is_not_null()


func test_every_npc_has_animation_frames() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		assert_object(npc.frames).override_failure_message(
			"NPC %s 没有动画" % npc_id
		).is_not_null()
		if npc.frames != null:
			assert_bool(npc.frames.has_animation(&"idle_down")).is_true()
			assert_bool(npc.frames.has_animation(&"walk_down")).override_failure_message(
				"NPC %s 缺少走路动画（日程寻路会变成滑行）" % npc_id
			).is_true()


# ---------------------------------------------------------------- 调色板

## 调色板是唯一颜色来源，至少要有内容，且不能被写坏。
func test_palette_is_usable() -> void:
	assert_float(Palette.GRASS.a).is_equal(1.0)
	assert_bool(Palette.GRASS != Palette.GRASS_DARK).is_true()
	# shade() 是生成器做明暗档唯一的工具，压暗/提亮方向不能反。
	assert_bool(Palette.shade(Palette.GRASS, -0.5).get_luminance() < Palette.GRASS.get_luminance()).is_true()
	assert_bool(Palette.shade(Palette.GRASS, 0.5).get_luminance() > Palette.GRASS.get_luminance()).is_true()


# ---------------------------------------------------------------- 季节变体

## 冬季变体与基础图同尺寸、同 alpha 掩码，而且不能残留任何基础材质色。
##
## 最后一条专抓"某个取色函数忘了走 [code]SeasonPalette[/code]"：
## 漏掉的地方会原样保留基础色，而形状仍然对得上。
func test_season_variants_keep_shape_and_drop_base_colors() -> void:
	var base_lookup := _base_material_lookup()
	for base_path: String in SEASONAL_BASES:
		var variant_path := SeasonPalette.variant_suffix_path(base_path, Season.Type.WINTER)
		assert_bool(ResourceLoader.exists(variant_path)).override_failure_message(
			"缺少冬季变体 %s（跑一次 ./tools/build_assets.sh）" % variant_path
		).is_true()
		if not ResourceLoader.exists(variant_path):
			continue
		var base_texture := load(base_path) as Texture2D
		var variant_texture := load(variant_path) as Texture2D
		assert_object(variant_texture).is_not_null()
		if base_texture == null or variant_texture == null:
			continue
		var base_image := base_texture.get_image()
		var variant_image := variant_texture.get_image()
		assert_int(variant_image.get_width()).override_failure_message(
			"%s 与基础图宽度不一致" % variant_path
		).is_equal(base_image.get_width())
		assert_int(variant_image.get_height()).is_equal(base_image.get_height())
		_assert_same_alpha_mask(base_image, variant_image, variant_path)
		_assert_no_base_material_color(variant_image, base_lookup, variant_path)


## 每个 [code]_<key>[/code] 后缀都必须是合法季节 key。
func test_season_variant_suffixes_are_valid_season_keys() -> void:
	var valid: Array[String] = []
	for season: Season.Type in Season.all():
		valid.append(String(Season.to_key(season)))
	for dir_path: String in SEASONAL_DIRS:
		var bases: Array = SEASONAL_DIRS[dir_path]
		for file_name: String in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".png"):
				continue
			var stem := file_name.trim_suffix(".png")
			# tree_pine 这类"另一个基础名"不是 tree 的变体，跳过。
			if bases.has(stem):
				continue
			# 取最长的匹配基础名：tree_pine_winter 应按 tree_pine 拆，而不是 tree。
			var matched := ""
			for base: String in bases:
				if stem.begins_with("%s_" % base) and base.length() > matched.length():
					matched = base
			if matched.is_empty():
				continue
			var suffix := stem.substr(matched.length() + 1)
			assert_bool(valid.has(suffix)).override_failure_message(
				"%s/%s 的后缀 '%s' 不是合法季节 key" % [dir_path, file_name, suffix]
			).is_true()


## 冬季 TileSet 的瓦片数、坐标与碰撞必须与基础表一致：
## 换季只该换图，不该把碰撞一起换掉。
func test_winter_tileset_matches_base_structure() -> void:
	var winter_path := SeasonPalette.variant_path(
		Layout.TILESET_RESOURCE_PATH, Season.Type.WINTER
	)
	var base := load(Layout.TILESET_RESOURCE_PATH) as TileSet
	var winter := load(winter_path) as TileSet
	assert_object(winter).override_failure_message(
		"缺少冬季 TileSet %s" % winter_path
	).is_not_null()
	if base == null or winter == null:
		return
	assert_int(winter.get_physics_layers_count()).is_equal(base.get_physics_layers_count())
	var base_source := base.get_source(0) as TileSetAtlasSource
	var winter_source := winter.get_source(0) as TileSetAtlasSource
	assert_object(winter_source).is_not_null()
	if base_source == null or winter_source == null:
		return
	assert_int(winter_source.get_tiles_count()).is_equal(base_source.get_tiles_count())
	for index: int in base_source.get_tiles_count():
		var atlas: Vector2i = base_source.get_tile_id(index)
		assert_bool(winter_source.has_tile(atlas)).override_failure_message(
			"冬季 TileSet 缺少瓦片 %s" % atlas
		).is_true()
		var base_data := base_source.get_tile_data(atlas, 0)
		var winter_data := winter_source.get_tile_data(atlas, 0)
		if base_data == null or winter_data == null:
			continue
		assert_int(winter_data.get_collision_polygons_count(0)).override_failure_message(
			"瓦片 %s 的碰撞与基础表不一致" % atlas
		).is_equal(base_data.get_collision_polygons_count(0))


func _assert_same_alpha_mask(base_image: Image, variant_image: Image, path: String) -> void:
	var base_data := base_image.get_data()
	var variant_data := variant_image.get_data()
	assert_int(variant_data.size()).is_equal(base_data.size())
	if variant_data.size() != base_data.size():
		return
	var mismatch := -1
	for index: int in range(3, base_data.size(), 4):
		if (base_data[index] > 127) != (variant_data[index] > 127):
			mismatch = index >> 2
			break
	assert_int(mismatch).override_failure_message(
		"%s 的形状变了：第 %d 像素的透明度与基础图不同" % [path, mismatch]
	).is_equal(-1)


func _base_material_lookup() -> Dictionary:
	var lookup: Dictionary = {}
	for color: Color in SeasonPalette.base_colors():
		lookup[_rgb_key(color)] = true
	return lookup


func _rgb_key(color: Color) -> int:
	return (
		(int(round(color.r * 255.0)) << 16)
		| (int(round(color.g * 255.0)) << 8)
		| int(round(color.b * 255.0))
	)


func _assert_no_base_material_color(image: Image, lookup: Dictionary, path: String) -> void:
	var data := image.get_data()
	var hit := -1
	for index: int in range(0, data.size(), 4):
		if data[index + 3] <= 127:
			continue
		var key := (
			(int(data[index]) << 16) | (int(data[index + 1]) << 8) | int(data[index + 2])
		)
		if lookup.has(key):
			hit = key
			break
	assert_int(hit).override_failure_message(
		"%s 残留基础材质色 #%06x：某个取色没走 SeasonPalette" % [path, hit]
	).is_equal(-1)


# ---------------------------------------------------------------- 内部

## 翻译表里出现过的所有字符（去掉表头、引号、逗号与换行）。
##
## 文案按域拆成多个 CSV（[code]ui / content / dialogue[/code]），这里遍历整个目录，
## 拆分不影响字形子集的收集。
func _characters_in_strings() -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	var dir := DirAccess.open(I18N_DIR)
	if dir == null:
		return []
	for file_name: String in dir.get_files():
		if file_name.get_extension().to_lower() != "csv":
			continue
		var file := FileAccess.open(I18N_DIR.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var text := file.get_as_text()
		file.close()
		for index: int in text.length():
			var code: int = text.unicode_at(index)
			if code < 0x20:
				continue
			seen[code] = true
	var codes: Array[int] = []
	for code: int in seen:
		codes.append(code)
	codes.sort()
	return codes


func _font_chain_contains_pixel(font: Font) -> bool:
	if font == null:
		return false
	if font.resource_path == PIXEL_FONT:
		return true
	if font is FontVariation:
		var variation := font as FontVariation
		if _font_chain_contains_pixel(variation.base_font):
			return true
	for fallback: Font in font.fallbacks:
		if fallback != null and fallback.resource_path == PIXEL_FONT:
			return true
	return false


## 钓鱼的 UI 与浮标尺寸必须与 [AtlasLayout] 一致：
## [code]FishingUi[/code] 按这些尺寸摆放判定区与标记，[code]FishingBobber[/code] 直接贴图。
func test_fishing_art_matches_atlas_layout() -> void:
	var expected := {
		"res://assets/ui/fish_track.png": Layout.UI_FISH_TRACK_SIZE,
		"res://assets/ui/fish_zone.png": Layout.UI_FISH_ZONE_SIZE,
		"res://assets/ui/fish_marker.png": Layout.UI_FISH_MARK_SIZE,
		"res://assets/ui/hook_marker.png": Layout.UI_HOOK_MARK_SIZE,
		"res://assets/sprites/props/bobber.png": Layout.BOBBER_SIZE,
		"res://assets/sprites/props/ripple.png": Layout.RIPPLE_SIZE,
	}
	for path: String in expected:
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message("缺少 %s" % path).is_not_null()
		if texture == null:
			continue
		var size: Vector2i = expected[path]
		assert_int(texture.get_width()).override_failure_message(
			"%s 宽度应为 %d" % [path, size.x]
		).is_equal(size.x)
		assert_int(texture.get_height()).override_failure_message(
			"%s 高度应为 %d" % [path, size.y]
		).is_equal(size.y)
