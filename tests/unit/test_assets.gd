extends GdUnitTestSuite
## 美术资源规范的可执行版本。
##
## [code]docs/art_pipeline.md[/code] 里写的规则如果只停留在文档里就没人遵守，
## 所以这里把每一条都变成断言：
## [br]- 生成物存在、尺寸与 [AtlasLayout] 一致（改了排版忘了重新生成会红）
## [br]- 像素中文字体覆盖了翻译表里的每一个字（新文案变成方块会红）
## [br]- 数据资源挂上了贴图（背包/田地不显示图标会红）

const Layout := preload("res://src/art/atlas_layout.gd")
const Palette := preload("res://src/art/palette.gd")

const STRINGS_CSV: String = "res://assets/i18n/strings.csv"
const PIXEL_FONT: String = "res://assets/fonts/pixel_cjk.fnt"
const THEME_PATH: String = "res://assets/themes/game_theme.tres"
const TILESET_PATH: String = "res://assets/tilesets/farm_tileset.tres"

## 所有生成器都必须产出的文件。
const REQUIRED_ASSETS: Array[String] = [
	"res://assets/sprites/tileset_farm.png",
	"res://assets/sprites/actors/player.png",
	"res://assets/sprites/actors/npc_merchant.png",
	"res://assets/sprites/actors/npc_mayor.png",
	"res://assets/sprites/actors/npc_blacksmith.png",
	"res://assets/sprites/actors/npc_florist.png",
	"res://assets/sprites/actors/npc_fisher.png",
	"res://assets/sprites/actors/npc_miner.png",
	"res://assets/sprites/actors/npc_child.png",
	"res://assets/sprites/actors/npc_librarian.png",
	"res://assets/sprites/props/house.png",
	"res://assets/sprites/props/barn.png",
	"res://assets/sprites/props/tree.png",
	"res://assets/sprites/props/bed.png",
	"res://assets/sprites/props/shipping_bin.png",
	"res://assets/sprites/props/dock.png",
	"res://assets/sprites/props/boat.png",
	"res://assets/sprites/props/cave.png",
	"res://assets/sprites/props/bookshelf.png",
	"res://assets/sprites/props/counter.png",
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
	"res://assets/sprites/weather/rain_drop.png",
	"res://assets/sprites/weather/snow_flake.png",
	"res://assets/ui/panel.png",
	"res://assets/ui/button_normal.png",
	"res://assets/ui/slot.png",
	"res://assets/ui/weather_sunny.png",
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


## 六张世界地图都要在，否则 [SceneDoor] 的 target_scene 会指向空气。
func test_world_scenes_exist() -> void:
	for path: String in [
		"res://scenes/world/farm.tscn",
		"res://scenes/world/town.tscn",
		"res://scenes/world/twon.tscn",
		"res://scenes/world/beach.tscn",
		"res://scenes/world/mine.tscn",
		"res://scenes/world/library.tscn",
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


func test_actor_png_matches_atlas_layout() -> void:
	var texture := load("res://assets/sprites/actors/player.png") as Texture2D
	assert_object(texture).is_not_null()
	if texture == null:
		return
	assert_int(texture.get_width()).is_equal(Layout.ACTOR_SIZE.x)
	assert_int(texture.get_height()).is_equal(Layout.ACTOR_SIZE.y)


## NPC 图集必须和玩家同构，否则走路动画会取到空帧。
func test_npc_png_matches_atlas_layout() -> void:
	for npc_id: StringName in Database.npcs:
		var path: String = "res://assets/sprites/actors/npc_%s.png" % npc_id
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message(
			"NPC %s 没有图集 %s" % [npc_id, path]
		).is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()).is_equal(Layout.NPC_SIZE.x)
		assert_int(texture.get_height()).is_equal(Layout.NPC_SIZE.y)


func test_crop_png_matches_atlas_layout() -> void:
	for crop_id: StringName in Database.crops:
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
	for flora_id: StringName in Database.floras:
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
	for animal_id: StringName in Database.animals:
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


## 图集排版表声明的格子必须都在 TileSet 里——否则脚本铺地时会画到空处。
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
		Layout.WATER, Layout.STONE, Layout.WOOD, Layout.FLOWERS, Layout.FENCE,
		Layout.BUSH, Layout.SIGN, Layout.TALL_GRASS, Layout.DIRT, Layout.GRAVEL,
		Layout.SAND, Layout.WATER_EDGE, Layout.PATH_STONE, Layout.ROOF, Layout.WALL,
		Layout.WINDOW, Layout.DOORWAY, Layout.FENCE_GATE, Layout.FLOWER_BED,
		Layout.FLOWER_RED, Layout.FLOWER_BLUE, Layout.MUSHROOM, Layout.PEBBLE,
		Layout.STUMP_TILE, Layout.HAY, Layout.CRATE, Layout.WELL_TOP,
	]
	for cell: Vector2i in declared:
		assert_bool(source.has_tile(cell)).override_failure_message(
			"TileSet 缺少瓦片 %s" % cell
		).is_true()


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
	for item_id: StringName in Database.items:
		var item := Database.get_item(item_id)
		assert_object(item.icon).override_failure_message(
			"道具 %s 没有图标" % item_id
		).is_not_null()


func test_every_npc_has_animation_frames() -> void:
	for npc_id: StringName in Database.npcs:
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


# ---------------------------------------------------------------- 内部

## 翻译表里出现过的所有字符（去掉表头、逗号与换行）。
func _characters_in_strings() -> Array[int]:
	var seen: Dictionary[int, bool] = {}
	var file := FileAccess.open(STRINGS_CSV, FileAccess.READ)
	if file == null:
		return []
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
