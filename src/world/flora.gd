class_name Flora
extends Sprite2D
## 一株野生植被的可视化节点。
##
## 和 [Crop] 一样只是 [FloraState] 的"视图"：自己不保存任何游戏状态，
## 由 [FloraField] 在状态变化后调用 [method refresh] 同步画面。
##
## [b]碰撞体是动态加挂的[/b]：默认一落地就挡人；牧草这类
## 显式 `passable` 的低矮地被才允许穿过去。

## 变成实心时用的碰撞层级，与 [WorldProp] / [WorldBounds] 一致。
const SOLID_LAYER: int = 1

var state: FloraState
var data: FloraData

var _body: StaticBody2D


## 绑定数据并立即刷新画面。
func setup(p_state: FloraState, p_data: FloraData) -> void:
	state = p_state
	data = p_data
	# 贴图跟着数据走：场景里不硬编码图集，新增一种植物不需要改任何代码。
	if data != null and data.sprite_sheet != null:
		texture = data.sprite_sheet
		hframes = AtlasLayout.FLORA_COLUMNS
		_align_bottom_to_cell()
	refresh()


## 让贴图的"底部"对齐格子的下边缘。
##
## 树有 48 像素高、石头只有 16 像素，如果都按中心摆在格子中心，
## 树看起来会站在自己格子下方一格半的位置——玩家砍的格子和他看到的树就对不上了。
## 统一按"脚踩格底"摆放之后，视觉、目标格、碰撞体三者才对得上。
func _align_bottom_to_cell() -> void:
	if texture == null or vframes <= 0:
		return
	var cell_height: float = float(texture.get_height()) / float(vframes)
	offset = Vector2(0.0, float(GridUtils.TILE_SIZE) * 0.5 - cell_height * 0.5)


## 按当前状态更新帧号与碰撞体。
func refresh() -> void:
	if state == null or data == null:
		return
	frame = clampi(
		FloraGrowth.stage_of(data, state.days_grown), 0, AtlasLayout.FLORA_COLUMNS - 1
	)
	# 枯死的东西偏黄，玩家一眼能看出"这株报废了"。
	modulate = Color(0.86, 0.8, 0.66, 1.0) if state.dead else Color(1, 1, 1, 1)
	_sync_body()


## 当前阶段是否挡路。
func is_solid() -> bool:
	if state == null or data == null:
		return false
	return FloraGrowth.is_solid(data, state.days_grown)


func _sync_body() -> void:
	var want: bool = is_solid()
	if want and _body == null:
		_body = _build_body()
	elif not want and _body != null:
		_body.queue_free()
		_body = null


func _build_body() -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Solid"
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	body.position = data.solid_offset

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = data.solid_size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)
	return body
