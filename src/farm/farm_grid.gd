class_name FarmGrid
extends Node2D
## 农田网格：整片农场的[b]唯一权威状态[/b]。
##
## 负责：
## [br]- 保存每块地的翻耕 / 浇水 / 作物状态（纯数据，可整体序列化）
## [br]- 按需生成作物的可视化节点
## [br]- 在日结转时推进所有作物的生长
##
## [b]设计取舍[/b]：格子状态放在 [Dictionary] 而不是散落在场景节点上，
## 于是"农场存档"就是一次 [method to_dict]，不需要遍历整棵场景树；
## 而 TileMapLayer 只承担绘制职责，随时可以丢弃重建。

## 加入该分组后，玩家与工具可以找到当前场景的农田。
const GROUP: StringName = &"farm_grid"

## 未指定格子。
const NO_CELL: Vector2i = Vector2i(-1, -1)


## 某块地的可见状态发生变化。
signal tile_state_changed(cell: Vector2i)

## 地面图层（草地 / 小路）。
@export var ground_layer: TileMapLayer

## 土壤图层（已翻耕 / 已浇水）。
@export var soil_layer: TileMapLayer

## 作物节点的父节点。
@export var crops_root: Node2D

## 作物场景 [Crop]。
@export var crop_scene: PackedScene

## 可翻耕的矩形区域（格子坐标）。
@export var farmable_area: Rect2i = Rect2i(0, 0, 16, 12)

## 地面绘制区域（格子坐标），仅视觉用途。
@export var ground_area: Rect2i = Rect2i(-1, -1, 22, 16)

## 进入场景时是否自动铺地面（骨架阶段用代码铺，避免手写 TileMap 二进制数据）。
@export var paint_ground_on_ready: bool = true

## 进入场景时是否自动撒装饰（栅栏 / 花丛 / 灌木），纯观感。
@export var decorate_on_ready: bool = true

## 存档标识。
@export var persistence_id: StringName = &"farm_grid"

## 格子状态表：只保存"非空白"的格子，空字典代表一块干净的荒地。
var tiles: Dictionary[Vector2i, FarmTile] = {}

var _crop_nodes: Dictionary[Vector2i, Crop] = {}
var _rng := RandomNumberGenerator.new()


## 注册在 [code]_enter_tree()[/code] 而不是 [code]_ready()[/code]：
## 世界场景会被 [SceneRouter] 缓存复用，节点可能多次进出场景树，
## 而 [code]_ready()[/code] 一个节点一生只跑一次——放在 _ready 里的话，
## 第一次离开地图后日结转钩子就再也不会被注册回来了。
func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	GameClock.register_day_hook(_on_day_rollover)


func _exit_tree() -> void:
	GameClock.unregister_day_hook(_on_day_rollover)


func _ready() -> void:
	_rng.randomize()
	if paint_ground_on_ready:
		paint_ground()
	if decorate_on_ready:
		paint_decorations()
	_rebuild_soil_visuals()


# ---------------------------------------------------------------- 查询

## 该格子是否属于可耕种区域。
func is_farmable(cell: Vector2i) -> bool:
	return farmable_area.has_point(cell)


## 取格子状态；不存在时按需创建。
func get_tile(cell: Vector2i) -> FarmTile:
	if not tiles.has(cell):
		tiles[cell] = FarmTile.new(cell)
	return tiles[cell]


## 取格子状态；不存在时返回 null（只读查询用，不会产生副作用）。
func peek_tile(cell: Vector2i) -> FarmTile:
	return tiles.get(cell) as FarmTile


## 该格子是否有内容。
func has_content(cell: Vector2i) -> bool:
	var tile: FarmTile = peek_tile(cell)
	return tile != null and not tile.is_pristine()


func is_tilled(cell: Vector2i) -> bool:
	var tile: FarmTile = peek_tile(cell)
	return tile != null and tile.tilled


func is_watered(cell: Vector2i) -> bool:
	var tile: FarmTile = peek_tile(cell)
	return tile != null and tile.watered


## 该格子上的作物状态；没有则返回 null。
func get_crop(cell: Vector2i) -> CropState:
	var tile: FarmTile = peek_tile(cell)
	return tile.crop if tile != null else null


## 已耕种（翻过地）的格子数量。
func tilled_count() -> int:
	var total: int = 0
	for tile: FarmTile in tiles.values():
		if tile.tilled:
			total += 1
	return total


# ---------------------------------------------------------------- 操作

## 翻地。
func till(cell: Vector2i) -> bool:
	if not is_farmable(cell):
		return false
	# 田里先得把野草清掉，否则草下面那层土翻不动。
	if flora_blocks(cell):
		return false
	var tile := get_tile(cell)
	if tile.tilled or tile.has_crop():
		return false
	tile.tilled = true
	_refresh_soil(cell)
	EventBus.tile_tilled.emit(cell)
	return true


## 浇水。只有翻过的地才能浇水。
func water(cell: Vector2i) -> bool:
	if not is_farmable(cell):
		return false
	var tile := get_tile(cell)
	if not tile.tilled or tile.watered:
		return false
	tile.watered = true
	_refresh_soil(cell)
	EventBus.tile_watered.emit(cell)
	return true


## 播种。[param season] 由调用方传入，保证本方法不依赖全局时钟、可单测。
func plant(cell: Vector2i, seed_item_id: StringName, season: Season.Type) -> bool:
	if not is_farmable(cell) or flora_blocks(cell):
		return false
	var tile := get_tile(cell)
	if not tile.tilled or tile.has_crop():
		return false

	var seed := Database.get_item(seed_item_id)
	if seed == null or seed.crop_id == &"":
		return false
	var data := Database.get_crop(seed.crop_id)
	if data == null or not data.is_plantable_in(season):
		return false

	tile.crop = CropState.new(data.id)
	_spawn_crop_node(cell)
	EventBus.crop_planted.emit(cell, data.id)
	return true


## 收获。
##
## 返回 [code]{ "item_id": StringName, "amount": int, "removed": bool }[/code]，
## 空字典表示这块地现在没东西可收。
func harvest(cell: Vector2i) -> Dictionary:
	var tile: FarmTile = peek_tile(cell)
	if tile == null or not tile.has_crop():
		return {}
	var data := Database.get_crop(tile.crop.crop_id)
	if data == null:
		return {}

	var outcome := CropGrowth.apply_harvest(data, tile.crop, _rng)
	var amount: int = int(outcome.get("amount", 0))
	if amount <= 0:
		return {}

	EventBus.crop_harvested.emit(cell, outcome["item_id"], amount)
	if bool(outcome.get("removed", false)):
		_remove_crop_node(cell)
		tile.clear_crop()
	else:
		_refresh_crop(cell)
	_prune_tile(cell)
	return outcome


## 清除作物（镰刀）：枯死的作物和长歪的作物都能清掉。
func clear_crop(cell: Vector2i) -> bool:
	var tile: FarmTile = peek_tile(cell)
	if tile == null or not tile.has_crop():
		return false
	tile.clear_crop()
	_remove_crop_node(cell)
	_prune_tile(cell)
	return true


## 把翻好的地恢复成草地（镐 / 锄头对空地的二次使用）。
func revert_soil(cell: Vector2i) -> bool:
	var tile: FarmTile = peek_tile(cell)
	if tile == null or not tile.tilled or tile.has_crop():
		return false
	tile.tilled = false
	tile.watered = false
	_refresh_soil(cell)
	return true


# ---------------------------------------------------------------- 日结转

## 推进一天：所有作物结算生长，土壤湿度重置。
##
## [param weather_waters] 为 true 时（雨天）视为全部作物自动浇水。
func advance_day(date: GameDate, weather_waters: bool) -> void:
	for cell: Vector2i in tiles.keys():
		var tile: FarmTile = tiles[cell]
		if tile.has_crop():
			_advance_crop(cell, tile, date, weather_waters)
		tile.watered = weather_waters
		_refresh_soil(cell)
		_prune_tile(cell)


# ---------------------------------------------------------------- 地面绘制

## 用代码铺地面。不用 TileMap 手绘数据而是脚本铺，是为了让"农场多大"
## 只由 [member ground_area] 一个数字决定（改大小不用重画地图）。
##
## 布局：左下两条小路交汇，农舍门前一小段石板路，其余是带深浅变化的草地，
## 边角点缀荒草与碎石。所有图案都由坐标算出，因此每次进游戏完全一致。
func paint_ground() -> void:
	if ground_layer == null:
		return
	ground_layer.clear()
	var path_row: int = ground_area.position.y + ground_area.size.y - 1
	var path_column: int = ground_area.position.x

	for cell: Vector2i in GridUtils.cells_in_area(ground_area.position, ground_area.size):
		var atlas: Vector2i = _grass_variant(cell)
		# 最下两行 + 最左两列是通路，正好把农舍与农田连起来。
		if cell.y >= path_row - 1 or cell.x <= path_column + 1:
			atlas = FarmAtlas.PATH
		# 右下的荒地：视觉上把"可耕种区"和"地图边缘"区分开。
		elif cell.x > farmable_area.end.x + 3 and cell.y > farmable_area.end.y + 3:
			atlas = _wild_variant(cell)
		ground_layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)

	# 农舍门前的石板路（房子在左上，路通向农场大门）。
	for y: int in range(2, farmable_area.position.y - 1):
		ground_layer.set_cell(Vector2i(6, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)
		ground_layer.set_cell(Vector2i(7, y), FarmAtlas.SOURCE_ID, FarmAtlas.PATH_STONE)


## 草地明暗：两种草皮按坐标交错，避免一整块纯色看起来像贴图没加载。
func _grass_variant(cell: Vector2i) -> Vector2i:
	if (cell.x * 3 + cell.y * 5) % 7 < 3:
		return FarmAtlas.GRASS_ALT
	return FarmAtlas.GRASS


## 荒地：杂草 + 偶尔一块碎石。
func _wild_variant(cell: Vector2i) -> Vector2i:
	var roll: int = (cell.x * 7 + cell.y * 11) % 13
	if roll == 0:
		return FarmAtlas.PEBBLE
	if roll < 5:
		return FarmAtlas.TALL_GRASS
	return FarmAtlas.GRASS_ALT


## 撒装饰：农田上方一排栅栏（中间留门）、四周点缀花丛、灌木与杂物。
##
## 刻意不用随机数——地图每次生成都应当一模一样，否则每次进场景画面都在跳。
func paint_decorations() -> void:
	if ground_layer == null:
		return

	var fence_row: int = farmable_area.position.y - 1
	var gate_x: int = farmable_area.position.x + farmable_area.size.x / 2
	for column: int in farmable_area.size.x:
		var cell := Vector2i(farmable_area.position.x + column, fence_row)
		if cell.x == gate_x:
			continue
		ground_layer.set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.FENCE)
	# 栅栏门两侧的门柱
	ground_layer.set_cell(Vector2i(gate_x - 1, fence_row), FarmAtlas.SOURCE_ID, FarmAtlas.FENCE_GATE)
	ground_layer.set_cell(Vector2i(gate_x + 1, fence_row), FarmAtlas.SOURCE_ID, FarmAtlas.FENCE_GATE)

	var decorations := {
		Vector2i(farmable_area.position.x - 2, fence_row): FarmAtlas.BUSH,
		Vector2i(farmable_area.position.x + farmable_area.size.x + 1, fence_row): FarmAtlas.BUSH,
		Vector2i(farmable_area.position.x - 2, farmable_area.position.y + 2): FarmAtlas.FLOWERS,
		Vector2i(farmable_area.position.x + farmable_area.size.x + 1, farmable_area.position.y + 3):
			FarmAtlas.FLOWERS,
		Vector2i(farmable_area.position.x + 3, farmable_area.end.y + 2): FarmAtlas.SIGN,
		Vector2i(farmable_area.position.x + 8, farmable_area.end.y + 2): FarmAtlas.FLOWERS,
		Vector2i(farmable_area.position.x + 14, farmable_area.end.y + 3): FarmAtlas.BUSH,
		# 新增：一边一片花圃，田边几个草垛与木箱，让农场看起来"在用"。
		Vector2i(farmable_area.position.x + 2, fence_row - 1): FarmAtlas.FLOWER_BED,
		Vector2i(farmable_area.position.x + 3, fence_row - 1): FarmAtlas.FLOWER_BED,
		Vector2i(farmable_area.end.x - 2, fence_row - 1): FarmAtlas.FLOWER_BED,
		Vector2i(farmable_area.end.x - 1, fence_row - 1): FarmAtlas.FLOWER_BED,
		Vector2i(farmable_area.end.x + 2, farmable_area.position.y + 6): FarmAtlas.HAY,
		Vector2i(farmable_area.end.x + 3, farmable_area.position.y + 7): FarmAtlas.HAY,
		Vector2i(farmable_area.end.x + 2, farmable_area.position.y + 9): FarmAtlas.CRATE,
		Vector2i(farmable_area.end.x + 2, farmable_area.end.y + 4): FarmAtlas.MUSHROOM,
		Vector2i(farmable_area.position.x - 1, farmable_area.end.y + 3): FarmAtlas.FLOWER_BLUE,
		Vector2i(farmable_area.position.x + 20, farmable_area.end.y + 4): FarmAtlas.FLOWER_RED,
		Vector2i(farmable_area.position.x + 24, farmable_area.end.y + 2): FarmAtlas.STUMP_TILE,
		Vector2i(farmable_area.position.x + 26, farmable_area.end.y + 5): FarmAtlas.WELL_TOP,
		Vector2i(farmable_area.position.x + 31, farmable_area.position.y + 2): FarmAtlas.MUSHROOM,
		Vector2i(farmable_area.position.x + 33, farmable_area.position.y + 8): FarmAtlas.PEBBLE,
		Vector2i(farmable_area.position.x + 30, farmable_area.end.y + 6): FarmAtlas.TALL_GRASS,
	}
	for cell: Vector2i in decorations:
		if ground_area.has_point(cell):
			ground_layer.set_cell(cell, FarmAtlas.SOURCE_ID, decorations[cell])


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	var entries: Array = []
	for cell: Vector2i in tiles:
		var tile: FarmTile = tiles[cell]
		if tile.is_pristine():
			continue
		entries.append(tile.to_dict())
	# 排序保证存档内容稳定，便于 diff 与测试。
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Array = a.get("cell", [0, 0])
		var cb: Array = b.get("cell", [0, 0])
		if int(ca[1]) != int(cb[1]):
			return int(ca[1]) < int(cb[1])
		return int(ca[0]) < int(cb[0])
	)
	return {"tiles": entries}


func from_dict(data: Dictionary) -> void:
	for node: Crop in _crop_nodes.values():
		node.queue_free()
	_crop_nodes.clear()
	tiles.clear()

	var raw: Variant = data.get("tiles", [])
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary:
				continue
			var tile := FarmTile.new()
			tile.from_dict(entry)
			tiles[tile.cell] = tile

	_rebuild_soil_visuals()
	_rebuild_crop_visuals()


# ---------------------------------------------------------------- 内部

func _advance_crop(
	cell: Vector2i, tile: FarmTile, date: GameDate, weather_waters: bool
) -> void:
	var data := Database.get_crop(tile.crop.crop_id)
	if data == null:
		return
	var watered: bool = tile.watered or weather_waters
	var change := CropGrowth.advance(data, tile.crop, watered, date.season)
	if bool(change.get(CropGrowth.KEY_DIED, false)):
		EventBus.crop_died.emit(cell)
		_refresh_crop(cell)
		return
	if bool(change.get(CropGrowth.KEY_STAGE_CHANGED, false)):
		EventBus.crop_stage_changed.emit(
			cell, CropGrowth.stage_of(data, tile.crop.days_grown)
		)
		_refresh_crop(cell)


func _spawn_crop_node(cell: Vector2i) -> void:
	_remove_crop_node(cell)
	if crop_scene == null or crops_root == null:
		return
	var node := crop_scene.instantiate() as Crop
	if node == null:
		push_error("FarmGrid: crop_scene 的根节点必须是 Crop")
		return
	crops_root.add_child(node)
	node.position = GridUtils.cell_to_world(cell)
	node.y_sort_enabled = false
	var tile: FarmTile = tiles[cell]
	node.setup(tile.crop, Database.get_crop(tile.crop.crop_id))
	_crop_nodes[cell] = node


func _remove_crop_node(cell: Vector2i) -> void:
	if not _crop_nodes.has(cell):
		return
	var node: Crop = _crop_nodes[cell]
	_crop_nodes.erase(cell)
	if is_instance_valid(node):
		node.queue_free()


func _refresh_crop(cell: Vector2i) -> void:
	var node: Crop = _crop_nodes.get(cell) as Crop
	if is_instance_valid(node):
		node.refresh()


func _refresh_soil(cell: Vector2i) -> void:
	if soil_layer == null:
		return
	var tile: FarmTile = peek_tile(cell)
	if tile == null or not tile.tilled:
		soil_layer.erase_cell(cell)
	else:
		var atlas: Vector2i = FarmAtlas.SOIL_WET if tile.watered else FarmAtlas.SOIL_DRY
		soil_layer.set_cell(cell, FarmAtlas.SOURCE_ID, atlas)
	tile_state_changed.emit(cell)


func _rebuild_soil_visuals() -> void:
	if soil_layer == null:
		return
	soil_layer.clear()
	for cell: Vector2i in tiles:
		_refresh_soil(cell)


func _rebuild_crop_visuals() -> void:
	for cell: Vector2i in tiles:
		if tiles[cell].has_crop():
			_spawn_crop_node(cell)


## 丢掉"什么都没有"的格子，避免长期游玩后字典无限膨胀。
func _prune_tile(cell: Vector2i) -> void:
	var tile: FarmTile = tiles.get(cell) as FarmTile
	if tile != null and tile.is_pristine():
		tiles.erase(cell)


## 这一格上是不是长着野生植被（杂草会侵占农田，必须先清掉才能翻地 / 播种）。
##
## 唯一的反向依赖（农田 → 植被）就这一处：用分组软查询而不是成员引用，
## 于是没有植被系统的场景（比如纯农田测试）完全不受影响。
func flora_blocks(cell: Vector2i) -> bool:
	if not is_inside_tree():
		return false
	var field := get_tree().get_first_node_in_group(FloraField.GROUP) as FloraField
	return field != null and field.occupied(cell)


func _on_day_rollover(date: GameDate) -> void:
	advance_day(date, WeatherSystem.waters_crops())
