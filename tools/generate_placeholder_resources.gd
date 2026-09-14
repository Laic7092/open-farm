extends SceneTree
## 占位资源生成器（第二阶段：把 PNG 组装成 TileSet / SpriteFrames）。
##
## 为什么分成两步：Godot 的贴图必须先进导入管线才能被 [Resource] 引用，
## 而导入只能在引擎启动时完成。所以流程是
## [code]生成 PNG → --import → 生成 .tres → --import[/code]，
## 由 [code]tools/build_assets.sh[/code] 统一编排。
##
## 用 [ResourceSaver] 而不是手写 [code].tres[/code] 文本，
## 是为了让产出的资源格式永远与当前引擎版本一致。

const SPRITE_DIR: String = "res://assets/sprites"
const TILESET_PATH: String = "res://assets/tilesets/farm_tileset.tres"

const TILE: int = 16
## tileset_farm.png 的排版。
const ATLAS_COLUMNS: int = 8
const ATLAS_ROWS: int = 2

## 玩家贴图：4 列（走 A / 走 B / 待机 / 挥动）× 3 行（下 / 上 / 侧）。
const PLAYER_COLUMNS: int = 4
const PLAYER_ROWS: Array[StringName] = [&"down", &"up", &"side"]
const PLAYER_IDLE_COLUMN: int = 2
const PLAYER_USE_COLUMN: int = 3
const PLAYER_WALK_COLUMNS: Array[int] = [0, 1]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/tilesets")
	)
	var problems := PackedStringArray()
	problems.append_array(_build_tileset())
	problems.append_array(_build_player_frames())
	problems.append_array(_build_npc_frames())
	if problems.is_empty():
		print("占位资源生成完成")
	else:
		for problem: String in problems:
			push_error(problem)
	quit()


# ---------------------------------------------------------------- TileSet

func _build_tileset() -> PackedStringArray:
	var problems := PackedStringArray()
	var texture := _load_texture(SPRITE_DIR.path_join("tileset_farm.png"), problems)
	if texture == null:
		return problems

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for row: int in ATLAS_ROWS:
		for column: int in ATLAS_COLUMNS:
			source.create_tile(Vector2i(column, row))

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)

	var error: Error = ResourceSaver.save(tileset, TILESET_PATH)
	if error != OK:
		problems.append("无法写入 %s（错误码 %d）" % [TILESET_PATH, error])
	else:
		print("  → ", TILESET_PATH)
	return problems


# ---------------------------------------------------------------- SpriteFrames

func _build_player_frames() -> PackedStringArray:
	var problems := PackedStringArray()
	var texture := _load_texture(SPRITE_DIR.path_join("player.png"), problems)
	if texture == null:
		return problems

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	for row: int in PLAYER_ROWS.size():
		var suffix: StringName = PLAYER_ROWS[row]

		_add_animation(
			frames, texture, StringName("idle_%s" % suffix),
			[Vector2i(PLAYER_IDLE_COLUMN, row)], 1.0, false
		)
		var walk_cells: Array[Vector2i] = []
		for column: int in PLAYER_WALK_COLUMNS:
			walk_cells.append(Vector2i(column, row))
		_add_animation(
			frames, texture, StringName("walk_%s" % suffix), walk_cells, 6.0, true
		)
		_add_animation(
			frames, texture, StringName("use_%s" % suffix),
			[Vector2i(PLAYER_USE_COLUMN, row)], 1.0, false
		)

	var path: String = SPRITE_DIR.path_join("player_frames.tres")
	var error: Error = ResourceSaver.save(frames, path)
	if error != OK:
		problems.append("无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("  → ", path)
	return problems


func _build_npc_frames() -> PackedStringArray:
	var problems := PackedStringArray()
	var texture := _load_texture(SPRITE_DIR.path_join("npc.png"), problems)
	if texture == null:
		return problems

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(
		frames, texture, &"idle_down",
		[Vector2i(0, 0), Vector2i(1, 0)], 1.6, true
	)

	var path: String = SPRITE_DIR.path_join("npc_frames.tres")
	var error: Error = ResourceSaver.save(frames, path)
	if error != OK:
		problems.append("无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("  → ", path)
	return problems


# ---------------------------------------------------------------- 工具

func _load_texture(path: String, problems: PackedStringArray) -> Texture2D:
	if not ResourceLoader.exists(path):
		problems.append("找不到贴图 %s，请先运行 generate_placeholder_art.gd 并执行 --import" % path)
		return null
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		problems.append("%s 不是 Texture2D" % path)
	return texture


func _atlas(texture: Texture2D, column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(column * TILE, row * TILE, TILE, TILE)
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
		frames.add_frame(name, _atlas(texture, cell.x, cell.y))