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

## 地面图层；"这一格是不是水"靠读它的瓦片实现。
@export var ground_layer: TileMapLayer
## 这片水的类型；见 [enum WaterKind.Kind]。
@export var water_kind: WaterKind.Kind = WaterKind.Kind.POND


func _enter_tree() -> void:
	add_to_group(GROUP)


## 这一格是否是水。地面缺失时一律返回 false。
func is_water(cell: Vector2i) -> bool:
	if ground_layer == null:
		return false
	return FarmAtlas.is_water(ground_layer.get_cell_atlas_coords(cell))


## 这一格的水域类型；不是水返回 -1。
func kind_at(cell: Vector2i) -> int:
	return int(water_kind) if is_water(cell) else -1
