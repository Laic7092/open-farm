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

## 两栋住宅的剪影至少要有多少行不同，才算"两栋不同的房子"（半幅以上）。
## 阈值定得松：要挡的是"换个配色就算新建筑"，不是禁止两栋房子有相似的坡顶。
const SILHOUETTE_MIN_DIFFERENT_ROWS: int = 32

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


## 走前景 overlay 的窄件（树冠）必须有同尺寸的 [code]fg_<名字>.png[/code]，
## [WorldProp] 才能按约定自动挂上去；尺寸不一致会在场景里错位。
## 建筑 / 柜台改走"身后淡出"，不再拆 overlay，所以不在此列。
func test_foreground_overlays_match_their_base() -> void:
	var names: Array[String] = ["tree", "tree_pine"]
	for name: String in names:
		var base := load("res://assets/sprites/props/%s.png" % name) as Texture2D
		var overlay := load("res://assets/sprites/props/fg_%s.png" % name) as Texture2D
		assert_object(base).is_not_null()
		assert_object(overlay).override_failure_message(
			"%s 缺少前景 overlay fg_%s.png" % [name, name]
		).is_not_null()
		if base == null or overlay == null:
			continue
		assert_int(overlay.get_width()).override_failure_message(
			"fg_%s.png 宽度与底图不一致" % name
		).is_equal(base.get_width())
		assert_int(overlay.get_height()).override_failure_message(
			"fg_%s.png 高度与底图不一致" % name
		).is_equal(base.get_height())

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
