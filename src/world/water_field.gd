class_name WaterField
extends Node2D
## 一张地图上的水面标记。
##
## 水本身已经由 [GroundPainter.water] 画进了地面 [TileMapLayer]；
## 这个节点只回答"某个格子是不是水、是哪一种水"，
## 钓鱼因此不必认识地图脚本，也不必再存一份水面数据。
##
## 与 [FloraField] 同一套做法：按分组被查询，
## [FarmInteractor] 用 [method Node.get_first_node_in_group] 找到当前地图的水域。

## 加入该分组后，玩家与工具可以找到当前场景的水面。
const GROUP: StringName = &"water_field"

## 波光动画速度（弧度/秒）。
const WAVE_SPEED: float = 1.35
## 波光 crest / 暗光两层透明度，避免动态水面喧宾夺主。
const WAVE_CREST_ALPHA: float = 0.30
const WAVE_GLOW_ALPHA: float = 0.16
## 水面覆盖层：位于地面（-20）之上、土壤（-10）与摆件（0）之下。
const WATER_Z_INDEX: int = -15

## 地面图层；"这一格是不是水"靠读它的瓦片实现。
@export var ground_layer: TileMapLayer
## 这片水的类型；见 [enum WaterKind.Kind]。
@export var water_kind: WaterKind.Kind = WaterKind.Kind.POND

## 当前地图的全部水格，[method _draw] 只遍历这一份缓存。
var _water_cells: Array[Vector2i] = []
## 全局波光相位。
var _phase: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	z_index = WATER_Z_INDEX
	_scan_water()
	if _water_cells.is_empty():
		set_process(false)


## 水面动态：按时间推进相位，然后重绘水格上的波光高光。
func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * WAVE_SPEED, TAU)
	queue_redraw()


## 扫描地面层，缓存所有水格。只在地图第一次 ready 时跑一次。
func _scan_water() -> void:
	_water_cells.clear()
	if ground_layer == null:
		return
	var used := ground_layer.get_used_rect()
	for cell: Vector2i in GridUtils.cells_in_area(used.position, used.size):
		if is_water(cell):
			_water_cells.append(cell)


func _draw() -> void:
	if _water_cells.is_empty():
		return
	var crest := ArtPalette.WATER_FOAM
	crest.a = WAVE_CREST_ALPHA
	var glow := ArtPalette.WATER_LIGHT
	glow.a = WAVE_GLOW_ALPHA
	for cell: Vector2i in _water_cells:
		var base := Vector2(cell.x * AtlasLayout.TILE, cell.y * AtlasLayout.TILE)
		# 每个格子的相位由坐标错开；sway 让高光在 1px 内上下呼吸。
		var phase := _phase + float(cell.x) * 0.41 + float(cell.y) * 0.67
		var sway := int(round(sin(phase) * 1.5))
		var seed: int = absi(cell.x * 19 + cell.y * 31)
		var x: int = 2 + seed % 9
		draw_rect(
			Rect2(base + Vector2(float(x), float(4 + sway)), Vector2(4.0, 1.0)), crest
		)
		draw_rect(
			Rect2(
				base + Vector2(float(15 - x), float(10 - sway)), Vector2(3.0, 1.0)
			),
			glow
		)


## 这一格是否是水。地面缺失时一律返回 false。
func is_water(cell: Vector2i) -> bool:
	if ground_layer == null:
		return false
	return FarmAtlas.is_water(ground_layer.get_cell_atlas_coords(cell))


## 这一格的水域类型；不是水返回 -1。
func kind_at(cell: Vector2i) -> int:
	return int(water_kind) if is_water(cell) else -1
