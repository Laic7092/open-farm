@tool
class_name ToolData
extends Resource
## 工具的静态定义。
##
## 工具行为完全由数据描述（体力消耗 / 作用范围 / 作用目标），
## [FarmInteractor] 只负责"把工具数据翻译成对 [FarmGrid] 的调用"。

enum Kind {
	HOE,           ## 锄头：翻地
	WATERING_CAN,  ## 洒水壶：浇水
	SEED,          ## 种子：播种（用 item_id 指定具体作物）
	AXE,           ## 斧头：砍树桩
	PICKAXE,       ## 镐：碎石
	SICKLE,        ## 镰刀：割草 / 清除枯死作物
	FISHING,       ## 钓竿：不在地面上结算，由钓鱼状态驱动多帧时序
}

## 唯一标识。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
@export var kind: Kind = Kind.HOE
## 每次使用的体力消耗。
@export_range(0, 100) var stamina_cost: int = 2
## 作用距离（格）。
@export_range(1, 5) var reach: int = 1
## 作用范围（以目标格为中心展开的宽高）。
@export var area_size: Vector2i = Vector2i.ONE
## 是否可以被升级（骨架阶段仅保留字段）。
@export_range(0, 5) var tier: int = 0


## 该工具是否作用于农场地面格子（钓竿作用于水面，走专门的钓鱼状态）。
func targets_ground() -> bool:
	return kind != Kind.FISHING

## 该工具是否作用于水面。
func targets_water() -> bool:
	return kind == Kind.FISHING


## 该工具是否为消耗品式的播种工具。
func is_seed() -> bool:
	return kind == Kind.SEED


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if reach < 1:
		problems.append("reach 必须 >= 1")
	if area_size.x < 1 or area_size.y < 1:
		problems.append("area_size 必须 >= 1x1")
	return problems


func _to_string() -> String:
	return "ToolData(%s)" % id
