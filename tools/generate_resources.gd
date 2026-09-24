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
const SeasonPalette := preload("res://src/art/season_palette.gd")
const TileCollision := preload("res://src/world/tile_collision.gd")
const UiLayout := preload("res://src/ui/ui_layout.gd")

const ACTOR_DIR: String = "res://assets/sprites/actors"
const UI_DIR: String = "res://assets/ui"
const THEME_PATH: String = "res://assets/themes/game_theme.tres"
const PIXEL_FONT: String = "res://assets/fonts/pixel_cjk.fnt"
const SYSTEM_FONT: String = "res://assets/fonts/ui_font.tres"

var _problems := PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/tilesets")
	)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/themes")
	)
	_build_tilesets()
	_build_player_frames()
	for npc_id: StringName in _npc_ids():
		_build_npc_frames(npc_id)
	_build_theme()

	if _problems.is_empty():
		print("资源组装完成")
	else:
		for problem: String in _problems:
			push_error(problem)
	quit(0 if _problems.is_empty() else 1)


# ---------------------------------------------------------------- TileSet

## 按季节各组装一份 TileSet：图集换色、结构与碰撞完全一致。
##
## 变体不额外登记碰撞：同一个 [code]Layout[/code] 与 [code]TileCollision[/code]，所以
## "哪块地挡人"与"哪块地是雪"是两件互不影响的事。
func _build_tilesets() -> void:
	for season: Season.Type in SeasonPalette.seasons_to_build():
		_build_tileset(season)


func _build_tileset(season: Season.Type) -> void:
	# 这里用 variant_suffix_path 而不是 variant_path：这是在决定"往哪写"，
	# 变体文件此刻可能还不存在，存在性回退会把冬季写回基础路径。
	var texture_path := SeasonPalette.variant_suffix_path(Layout.TILESET_PATH, season)
	var resource_path := SeasonPalette.variant_suffix_path(
		Layout.TILESET_RESOURCE_PATH, season
	)
	var texture := _load_texture(texture_path)
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
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	tileset.add_source(source, 0)
	_apply_tile_collisions(source)
	_add_grass_edge_source(tileset, season)
	_save(tileset, resource_path)


## 深/浅草过渡在单独一张 4×4 小图集里，作为 source 1 加进同一个 TileSet。
##
## 这样场景里的 Ground 仍是一个 TileMapLayer，只是换边时写不同的 source；
## 不碰撞、不参与 [method _apply_tile_collisions] 的扫描。
func _add_grass_edge_source(tileset: TileSet, season: Season.Type) -> void:
	var texture_path := SeasonPalette.variant_suffix_path(Layout.GRASS_EDGE_PATH, season)
	var texture := _load_texture(texture_path)
	if texture == null:
		return
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(Layout.TILE, Layout.TILE)
	for row: int in Layout.GRASS_EDGE_ROWS:
		for column: int in Layout.GRASS_EDGE_COLUMNS:
			source.create_tile(Vector2i(column, row))
	tileset.add_source(source, Layout.GRASS_EDGE_SOURCE_ID)


## 给实心装饰瓦片写满格碰撞；牧草等可穿过瓦片保持无碰撞。
func _apply_tile_collisions(source: TileSetAtlasSource) -> void:
	var half := float(Layout.TILE) * 0.5
	var points := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	for row: int in Layout.TILESET_ROWS:
		for column: int in Layout.TILESET_COLUMNS:
			var atlas := Vector2i(column, row)
			if not TileCollision.is_solid(atlas):
				continue
			var data := source.get_tile_data(atlas, 0)
			if data == null:
				continue
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, points)


# ---------------------------------------------------------------- SpriteFrames

## 扫描 [code]assets/sprites/actors/npc_*.png[/code] 得到需要组装动画的 NPC id。
##
## 不再维护硬编码名单：只要 [code]generate_actors.gd[/code] 画出了图集，
## 这里就自动为它生成 [code]npc_<id>_frames.tres[/code]，
## 从结构上消灭"加了 NPC 却忘了登记"的问题。
func _npc_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file_name: String in DirAccess.get_files_at(ACTOR_DIR):
		if not file_name.begins_with("npc_") or not file_name.ends_with(".png"):
			continue
		ids.append(StringName(file_name.trim_prefix("npc_").trim_suffix(".png")))
	ids.sort()
	return ids


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
	for row: int in Layout.ACTOR_ROW_NAMES.size():
		var suffix: StringName = Layout.ACTOR_ROW_NAMES[row]
		# 待机两帧循环，做出轻微的呼吸起伏。
		_add_animation(
			frames, texture, StringName("idle_%s" % suffix),
			[
				Vector2i(Layout.NPC_IDLE_COLUMN, row),
				Vector2i(Layout.NPC_IDLE_BOB_COLUMN, row),
			], 1.6, true
		)
		var walk_cells: Array[Vector2i] = []
		for column: int in Layout.NPC_WALK_COLUMNS:
			walk_cells.append(Vector2i(column, row))
		_add_animation(
			frames, texture, StringName("walk_%s" % suffix), walk_cells, 6.0, true
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
	theme.default_font_size = UiLayout.FONT_BODY

	var panel := _stylebox("panel.png", 8, 6)
	var panel_flat := _stylebox("panel_flat.png", 8, 6)
	var slot := _stylebox("slot.png", 2, 2)
	var slot_selected := _stylebox("slot_selected.png", 2, 2)
	var hud_slot := _stylebox("slot.png", 2, 2, UiLayout.HUD_SLOT_PATCH)
	var hud_slot_selected := _stylebox("slot_selected.png", 2, 2, UiLayout.HUD_SLOT_PATCH)
	var item_slot := _stylebox("slot.png", 3, 2, 2)

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
	theme.set_font_size(&"font_size", &"Button", UiLayout.FONT_BODY)

	theme.set_stylebox(&"panel", &"ItemList", panel)
	# 焦点框只画边：ItemList 会把它盖在条目上，填色会遮住整张列表。
	theme.set_stylebox(&"focus", &"ItemList", _stylebox("list_focus.png", 2, 2))
	theme.set_stylebox(&"selected", &"ItemList", slot_selected)
	theme.set_stylebox(&"selected_focus", &"ItemList", slot_selected)
	theme.set_color(&"font_color", &"ItemList", Palette.UI_TEXT)
	theme.set_color(&"font_selected_color", &"ItemList", Palette.UI_GOLD)
	theme.set_font_size(&"font_size", &"ItemList", UiLayout.FONT_BODY)

	theme.set_stylebox(&"background", &"ProgressBar", _stylebox("bar_back.png", 2, 2))
	theme.set_stylebox(&"fill", &"ProgressBar", _stylebox("bar_fill.png", 2, 2))
	theme.set_color(&"font_color", &"ProgressBar", Palette.UI_TEXT)

	theme.set_stylebox(&"panel", &"TooltipPanel", panel_flat)
	theme.set_color(&"font_color", &"TooltipLabel", Palette.UI_TEXT)

	_build_theme_variations(theme, panel, hud_slot, hud_slot_selected, item_slot)
	_save(theme, THEME_PATH)


## 类型变体：场景只声明"我演什么角色"，尺寸与配色全在这里（[UiLayout] + [ArtPalette]）。
func _build_theme_variations(
	theme: Theme,
	panel: StyleBox,
	hud_slot: StyleBox,
	hud_slot_selected: StyleBox,
	item_slot: StyleBox
) -> void:
	# 模态外壳。
	theme.set_type_variation(&"ModalDim", &"Panel")
	theme.set_stylebox(&"panel", &"ModalDim", _flat_style(Palette.UI_DIM))
	theme.set_type_variation(&"ModalPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ModalPanel", panel)
	theme.set_type_variation(&"HudStatusPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HudStatusPanel", StyleBoxEmpty.new())
	theme.set_type_variation(&"HudDivider", &"Panel")
	theme.set_stylebox(&"panel", &"HudDivider", _flat_style(Palette.UI_DIVIDER))
	theme.set_type_variation(&"HudRowWide", &"HBoxContainer")
	theme.set_constant(&"separation", &"HudRowWide", 8)
	theme.set_type_variation(&"HudSlotRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"HudSlotRow", 2)
	theme.set_type_variation(&"HudColumn", &"VBoxContainer")
	theme.set_constant(&"separation", &"HudColumn", 3)
	theme.set_type_variation(&"ModalMargin", &"MarginContainer")
	theme.set_constant(&"margin_left", &"ModalMargin", UiLayout.MARGIN_PANEL_H)
	theme.set_constant(&"margin_top", &"ModalMargin", UiLayout.MARGIN_PANEL_V)
	theme.set_constant(&"margin_right", &"ModalMargin", UiLayout.MARGIN_PANEL_H)
	theme.set_constant(&"margin_bottom", &"ModalMargin", UiLayout.MARGIN_PANEL_V)
	theme.set_type_variation(&"ModalVBox", &"VBoxContainer")
	theme.set_constant(&"separation", &"ModalVBox", UiLayout.GAP)
	theme.set_type_variation(&"ModalVBoxTight", &"VBoxContainer")
	theme.set_constant(&"separation", &"ModalVBoxTight", UiLayout.GRID)
	theme.set_type_variation(&"DialogueMargin", &"MarginContainer")
	theme.set_constant(&"margin_left", &"DialogueMargin", 10)
	theme.set_constant(&"margin_top", &"DialogueMargin", 6)
	theme.set_constant(&"margin_right", &"DialogueMargin", 10)
	theme.set_constant(&"margin_bottom", &"DialogueMargin", 6)
	theme.set_type_variation(&"DialogueVBox", &"VBoxContainer")
	theme.set_constant(&"separation", &"DialogueVBox", 2)
	theme.set_type_variation(&"TitleFooter", &"HBoxContainer")
	theme.set_constant(&"separation", &"TitleFooter", 12)
	theme.set_type_variation(&"TitleSaveList", &"VBoxContainer")
	theme.set_constant(&"separation", &"TitleSaveList", 4)
	theme.set_type_variation(&"ModalHBox", &"HBoxContainer")
	theme.set_constant(&"separation", &"ModalHBox", UiLayout.GAP)
	theme.set_type_variation(&"ModalGrid", &"GridContainer")
	theme.set_constant(&"h_separation", &"ModalGrid", UiLayout.GRID)
	theme.set_constant(&"v_separation", &"ModalGrid", UiLayout.GRID)

	# 文字角色。
	_set_label(theme, &"TitleLabel", Palette.UI_GOLD, UiLayout.FONT_TITLE, true)
	_set_label(theme, &"TitleDisplayLabel", Palette.UI_GOLD, UiLayout.FONT_DISPLAY, true)
	_set_label(theme, &"BodyLabel", Palette.UI_TEXT, UiLayout.FONT_BODY, false)
	_set_label(theme, &"SubtleLabel", Palette.UI_TEXT_DIM, UiLayout.FONT_BODY, false)
	_set_label(theme, &"HudLabel", Palette.UI_TEXT, UiLayout.FONT_BODY, true)

	# 槽位。
	theme.set_type_variation(&"HudSlot", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HudSlot", hud_slot)
	theme.set_stylebox(&"selected", &"HudSlot", hud_slot_selected)
	theme.set_type_variation(&"HudCountLabel", &"Label")
	theme.set_color(&"font_color", &"HudCountLabel", Palette.UI_GOLD)
	theme.set_color(&"font_outline_color", &"HudCountLabel", Palette.UI_OUTLINE)
	theme.set_constant(&"outline_size", &"HudCountLabel", 3)
	theme.set_font_size(&"font_size", &"HudCountLabel", UiLayout.FONT_SMALL)
	theme.set_type_variation(&"ItemSlot", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ItemSlot", item_slot)


## 一个"文字角色"变体：颜色 + 字号 + 可选描边。
func _set_label(
	theme: Theme, type: StringName, color: Color, size: int, outlined: bool
) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_color(&"font_color", type, color)
	theme.set_font_size(&"font_size", type, size)
	if outlined:
		theme.set_color(&"font_outline_color", type, Palette.UI_OUTLINE)
		theme.set_constant(&"outline_size", type, UiLayout.OUTLINE_WIDTH)


func _flat_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


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


func _stylebox(
	file_name: String, margin_h: int, margin_v: int, patch: int = -1
) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	var texture := _load_texture(UI_DIR.path_join(file_name))
	box.texture = texture
	var resolved_patch: int = Layout.UI_PATCH_MARGIN if patch < 0 else patch
	box.texture_margin_left = resolved_patch
	box.texture_margin_top = resolved_patch
	box.texture_margin_right = resolved_patch
	box.texture_margin_bottom = resolved_patch
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


func _atlas(texture: Texture2D, column: int, row: int, cell: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(column * cell.x, row * cell.y, cell.x, cell.y)
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
		frames.add_frame(name, _atlas(texture, cell.x, cell.y, Layout.ACTOR_CELL))
