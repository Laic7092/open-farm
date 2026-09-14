@tool
class_name FloraData
extends Resource
## 野生植被的静态定义（数据驱动）。
##
## 树、杂草、石头这些东西"长什么样、长多快、什么时候冒出来、怎么清掉"
## 全部写在 [Resource] 里，而不是散落在 [FloraField] 的 if 分支里：
## 新增一种野生植物 = 往 [code]data/flora/[/code] 丢一个 [code].tres[/code]。
##
## 与 [CropData] 一样，这里只有[b]不变[/b]的数据；会变的（长了几天）
## 放在 [FloraState] 里，规则放在 [FloraGrowth] 的纯静态函数里。

enum Kind {
	TREE,      ## 树：会长大，成熟后挡路，砍掉出木材
	WEED,      ## 杂草：长得快，割掉出纤维，会侵占农田
	ROCK,      ## 石头：不生长，砸掉出石材
	FLOWER,    ## 野花：可徒手采
	MUSHROOM,  ## 蘑菇：雨后冒出来，可徒手采
}

## 唯一标识，存档里保存的就是它。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
@export var kind: Kind = Kind.WEED

## 每个生长阶段需要的天数；数组长度 = 阶段数。
##
## 空数组表示[b]不生长[/b]（石头这类一成不变的东西），
## 于是"石头不会变"这件事是数据决定的，不是代码里的特例。
@export var days_per_stage: Array[int] = []

## 四个季节的每日扩散权重，下标即 [enum Season.Type]；0 表示这个季节不长新的。
@export var spawn_weight: Array[int] = [0, 0, 0, 0]
## 雨 / 暴风雨天的额外扩散权重（"下过雨之后一地蘑菇"）。
@export_range(0, 50) var rain_bonus: int = 0
## 允许生长的季节；不在列表里的季节只是停滞，不会枯死。
@export var grow_seasons: Array[Season.Type] = [
	Season.Type.SPRING, Season.Type.SUMMER, Season.Type.FALL
]

## 单张地图里的数量上限（防止长期游玩后长满整张图）。
@export_range(0, 999) var max_per_world: int = 20
## 与同类之间的最小切比雪夫间距（格）；0 表示可以挨着长。
@export_range(0, 10) var min_spacing: int = 0
## 新地图开局"播种"时的权重；0 表示不参与初始植被。
##
## 和 [member spawn_weight] 分开，是为了让"开局这片林子长什么样"和
## "之后每天还会冒出什么"可以分别调：树在开局该多一点，而杂草该天天冒。
@export_range(0, 50) var initial_weight: int = 0

## 从第几个阶段开始有碰撞体；-1 表示永远可以穿过去。
@export_range(-1, 8) var solid_from_stage: int = -1
@export var solid_size: Vector2 = Vector2(10, 8)
@export var solid_offset: Vector2 = Vector2(0, 20)

## 清除它需要的工具；[FarmInteractor] 用这个字段做工具路由。
@export var tool_kind: ToolData.Kind = ToolData.Kind.SICKLE
## 清除一次消耗的体力。
@export_range(0, 100) var stamina_cost: int = 1
## 是否允许长在农田（没翻耕的空地）上——杂草为 true，这就是"田里会长草"。
@export var grows_on_farmland: bool = false
## 是否可以徒手采摘（野花、蘑菇）。
@export var pickable_by_hand: bool = false

## 清除后的产出。
@export var drop_item_id: StringName = &""
@export var drop_amount: Vector2i = Vector2i(1, 1)
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0

## 阶段图：[code]assets/sprites/flora/<id>.png[/code]，固定 4 列。
##
## 由 [code]tools/generate_sample_data.gd[/code] 按 id 自动填好，
## 因此"新增一种野生植物"只要在美术生成器里加一行外观，场景与代码都不用动。
@export var sprite_sheet: Texture2D


## 生长阶段总数（不含成熟的最后一段，含义与 [method CropData.stage_count] 一致）。
func stage_count() -> int:
	return days_per_stage.size()


## 这种东西是否会长大。
func can_grow() -> bool:
	return not days_per_stage.is_empty()


## 从种子到成熟需要的总天数。
func total_growth_days() -> int:
	var total: int = 0
	for days: int in days_per_stage:
		total += maxi(days, 0)
	return total


## 某个季节的每日扩散权重。
func spawn_weight_for_season(season: Season.Type) -> int:
	if spawn_weight.size() != Season.COUNT:
		return 0
	return maxi(spawn_weight[int(season)], 0)


## 该物种四个季节里最高的扩散权重；用于"不管什么季节，新地图都不该是光秃秃的"。
func peak_spawn_weight() -> int:
	var peak: int = 0
	for weight: int in spawn_weight:
		peak = maxi(peak, weight)
	return peak


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if spawn_weight.size() != Season.COUNT:
		problems.append("spawn_weight 必须正好有 %d 项（每个季节一项）" % Season.COUNT)
	if !days_per_stage.is_empty():
		for stage_days: int in days_per_stage:
			if stage_days < 1:
				problems.append("days_per_stage 每一项都必须 >= 1")
				break
		if solid_from_stage > days_per_stage.size():
			problems.append("solid_from_stage 超过了阶段数")
	if drop_amount.x < 0 or drop_amount.y < drop_amount.x:
		problems.append("drop_amount 不能为负，且上限不小于下限")
	return problems


func _to_string() -> String:
	return "FloraData(%s)" % id
