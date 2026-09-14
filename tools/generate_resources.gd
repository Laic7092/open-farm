extends SceneTree
## 资源组装器：把生成好的 PNG 组装成 Godot 的 [Resource]。
##
## 为什么必须分两步（PNG → --import → .tres）：
## 贴图要先进入导入管线才能被 [Resource] 引用，而导入只能由引擎启动时完成。
## [code]tools/build_assets.sh[/code] 负责编排这个顺序。
##
## 用 [ResourceSaver] 而不是手写 [code].tres[/code] 文本，
## 是为了让产出的资源格式永远与当前引擎版本一致。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/generate_resources.gd
## [/codeblock]

const Layout := preload("res://src/art/atlas_layout.gd")
const Palette := preload("res://src/art/palette.gd")

const ACTOR_DIR: String = "res://assets/sprites/actors"
const UI_DIR: String = "res://assets/ui"
const TILESET_PATH: String = "res://assets/tilesets/farm_tileset.tres"
const THEME_PATH: String = "res://assets/themes/game_theme.tres"
const PIXEL_FONT: String = "res://assets/fonts/pixel_cjk.fnt"
const SYSTEM_FONT: String = "res://assets/fonts/ui_font.tres"

## 场景里需要 SpriteFrames 的 NPC：与 [code]tools/art/generate_actors.gd[/code] 的外观表一致。
const NPC_IDS: Array[StringName] = [&"merchant", &"mayor"]

var _problems := PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/tilesets")
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/themes")
	)
	_build_tileset()
	_build_player_frames()
	for npc_id: StringName in NPC_IDS:
		_build_npc_frames(npc_id)
	_build_theme()

	if _problems.is_empty():
		print("资源组装完成")
	else:
		for problem: String in _problems:
			push_error(problem)
	quit(0 if _problems.is_empty() else 1)


# ---------------------------------------------------------------- TileSet

func _build_tileset() -> void:
	var texture := _load_texture(Layout.TILESET_PATH)
	if texture == null:
		return

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(Layout.TILE, Layout.TILE)
	for row: int in Layout.TILESET_ROWS:
		for column: int in Layout.TILESET_COLUMNS:
			source.create_tile(Vector2i(column, row))

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(Layout.TILE, Layout.TILE)
	tileset.add_source(source, 0)
	_save(tileset, TILESET_PATH)


# ---------------------------------------------------------------- SpriteFrames

func _build_player_frames() -> void:
	var texture := _load_texture(ACTOR_DIR.path_join("player.png"))
	if texture == null:
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row: int in Layout.ACTOR_ROW_NAMES.size():
		var suffix: StringName = Layout.ACTOR_ROW_NAMES[row]

		_add_animation(
			frames, texture, StringName("idle_%s" % suffix),
			[Vector2i(Layout.ACTOR_IDLE_COLUMN, row)], 1.0, false
		)
		var walk_cells: Array[Vector2i] = []
		for column: int in Layout.ACTOR_WALK_COLUMNS:
			walk_cells.append(Vector2i(column, row))
		_add_animation(
			frames, texture, StringName("walk_%s" % suffix), walk_cells, 6.0, true
		)
		_add_animation(
			frames, texture, StringName("use_%s" % suffix),
			[Vector2i(Layout.ACTOR_USE_COLUMN, row)], 1.0, false
		)
	_save(frames, ACTOR_DIR.path_join("player_frames.tres"))


func _build_npc_frames(npc_id: StringName) -> void:
	var path: String = ACTOR_DIR.path_join("npc_%s.png" % npc_id)
	var texture := _load_texture(path)
	if texture == null:
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# 两帧循环播放，做出轻微的呼吸起伏。
	_add_animation(
		frames, texture, &"idle_down",
		[Vector2i(0, 0), Vector2i(1, 0)], 1.6, true
	)
	_save(frames, ACTOR_DIR.path_join("npc_%s_frames.tres" % npc_id))


# ---------------------------------------------------------------- Theme

## UI 主题：像素中文字体 + 全部九宫格皮肤。
##
## 生成 [Theme] 而不是在每个 [code].tscn[/code] 里写 [code]theme_override[/code]，
## 是为了让"按钮长什么样"只有一处定义；场景只管结构。
func _build_theme() -> void:
	var theme := Theme.new()
	theme.default_font = _build_font()
	theme.default_font_size = Layout.TILE - 4  # 12：与像素字体字号一致

	var panel := _stylebox("panel.png", 8, 6)
	var panel_flat := _stylebox("panel_flat.png", 8, 6)
	var slot := _stylebox("slot.png", 2, 2)
	var slot_selected := _stylebox("slot_selected.png", 2, 2)

	theme.set_stylebox(&"panel", &"Panel", panel)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"PopupPanel", panel)
	theme.set_stylebox(&"panel", &"ScrollContainer", panel_flat)

	theme.set_color(&"font_color", &"Label", Palette.UI_TEXT)
	theme.set_color(&"font_color", &"RichTextLabel", Palette.UI_TEXT)

	theme.set_stylebox(&"normal", &"Button", _stylebox("button_normal.png", 8, 4))
	theme.set_stylebox(&"hover", &"Button", _stylebox("button_hover.png", 8, 4))
	theme.set_stylebox(&"pressed", &"Button", _stylebox("button_pressed.png", 8, 4))
	theme.set_stylebox(&"disabled", &"Button", _stylebox("button_disabled.png", 8, 4))
	theme.set_stylebox(&"focus", &"Button", _stylebox("button_focus.png", 8, 4))
	theme.set_color(&"font_color", &"Button", Palette.UI_TEXT)
	theme.set_color(&"font_hover_color", &"Button", Palette.UI_GOLD)
	theme.set_color(&"font_pressed_color", &"Button", Palette.UI_TEXT)
	theme.set_color(&"font_disabled_color", &"Button", Palette.UI_TEXT_DIM)
	theme.set_color(&"font_focus_color", &"Button", Palette.UI_GOLD)
	theme.set_font_size(&"font_size", &"Button", Layout.TILE - 4)

	theme.set_stylebox(&"panel", &"ItemList", panel)
	theme.set_stylebox(&"focus", &"ItemList", slot_selected)
	theme.set_stylebox(&"selected", &"ItemList", slot_selected)
	theme.set_stylebox(&"selected_focus", &"ItemList", slot_selected)
	theme.set_color(&"font_color", &"ItemList", Palette.UI_TEXT)
	theme.set_color(&"font_selected_color", &"ItemList", Palette.UI_GOLD)
	theme.set_font_size(&"font_size", &"ItemList", Layout.TILE - 4)

	theme.set_stylebox(&"background", &"ProgressBar", _stylebox("bar_back.png", 2, 2))
	theme.set_stylebox(&"fill", &"ProgressBar", _stylebox("bar_fill.png", 2, 2))
	theme.set_color(&"font_color", &"ProgressBar", Palette.UI_TEXT)

	theme.set_stylebox(&"panel", &"TooltipPanel", panel_flat)
	theme.set_color(&"font_color", &"TooltipLabel", Palette.UI_TEXT)

	_save(theme, THEME_PATH)


## 主题字体：像素字体在前，系统字体作为"子集外字符"的兜底。
func _build_font() -> Font:
	var pixel := _load_font(PIXEL_FONT)
	var system := _load_font(SYSTEM_FONT)
	if pixel == null:
		_problems.append("找不到像素字体 %s，请先运行 --import" % PIXEL_FONT)
		return system
	if system == null:
		return pixel

	var variation := FontVariation.new()
	variation.base_font = pixel
	variation.fallbacks = [system] as Array[Font]
	return variation


func _stylebox(file_name: String, margin_h: int, margin_v: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	var texture := _load_texture(UI_DIR.path_join(file_name))
	box.texture = texture
	var patch: int = Layout.UI_PATCH_MARGIN
	box.texture_margin_left = patch
	box.texture_margin_top = patch
	box.texture_margin_right = patch
	box.texture_margin_bottom = patch
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


# ---------------------------------------------------------------- 工具

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		_problems.append("找不到贴图 %s（请先生成美术并执行 --import）" % path)
		return null
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		_problems.append("%s 不是 Texture2D" % path)
	return texture


func _load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Font


func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		_problems.append("无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("  → ", path)


func _atlas(texture: Texture2D, column: int, row: int, cell: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(column * cell, row * cell, cell, cell)
	return atlas


func _add_animation(
	frames: SpriteFrames,
	texture: Texture2D,
	name: StringName,
	cells: Array[Vector2i],
	speed: float,
	loop: bool
) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, loop)
	for cell: Vector2i in cells:
		frames.add_frame(name, _atlas(texture, cell.x, cell.y, Layout.TILE))
