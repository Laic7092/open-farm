@tool
class_name CropData
extends Resource
## 一种作物的静态定义（数据驱动）。
##
## 作物的一切数值都放在 [Resource] 里，而不是写死在代码或场景中：
## 新增一种作物 = 新建一个 [code].tres[/code]，无需改动任何脚本。
## 运行时状态（长了几天、是否浇水）放在 [CropState] 中，两者严格分离。

## 唯一标识，存档中保存的就是它。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
## 播种时消耗的种子道具 id。
@export var seed_item_id: StringName = &""
## 收获产出的道具 id。
@export var harvest_item_id: StringName = &""
## 每次收获的数量。
@export_range(1, 99) var harvest_amount: int = 1
## 每个生长阶段需要的"有效生长天数"，数组长度 = 阶段数。
@export var days_per_stage: Array[int] = [1, 1, 1, 1]
## 可种植的季节；不在此列表中的季节里种下会直接枯死。
@export var seasons: Array[Season.Type] = [Season.Type.SPRING]
## 收获后重新结果所需天数；0 表示一次性作物（收获后消失）。
@export_range(0, 30) var regrow_days: int = 0
## 连续多少天没浇水会枯死；0 表示永不枯死。
@export_range(0, 10) var days_without_water_tolerance: int = 2
## 种子售价（商店买入价）。
@export_range(0, 99999) var seed_price: int = 0
## 作物基础售价（商店卖出价）。
@export_range(0, 99999) var base_sell_price: int = 0
## 每次收获额外产出 1 个的概率。
@export_range(0.0, 1.0, 0.01) var bonus_yield_chance: float = 0.0
## 生长图：[code]assets/sprites/crops/<id>.png[/code]，5 列 = 4 个生长阶段 + 枯死形态。
##
## 由 [code]tools/generate_sample_data.gd[/code] 按 id 自动填好，
## 因此"新增一种作物"只要在美术生成器里加一行外观，场景与代码都不用动。
@export var sprite_sheet: Texture2D


## 从播种到成熟需要的总有效生长天数。
func total_growth_days() -> int:
	var total: int = 0
	for days: int in days_per_stage:
		total += maxi(days, 0)
	return total


## 生长阶段总数（不含枯死）。
func stage_count() -> int:
	return maxi(days_per_stage.size(), 1)


## 该作物是否能在 [param season] 种植 / 存活。
func is_plantable_in(season: Season.Type) -> bool:
	return seasons.is_empty() or seasons.has(season)


## 是否属于多次收获作物。
func is_regrowable() -> bool:
	return regrow_days > 0


## 数据自检；返回空数组表示通过。供单元测试与编辑器工具调用。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if seed_item_id == &"":
		problems.append("seed_item_id 不能为空")
	if harvest_item_id == &"":
		problems.append("harvest_item_id 不能为空")
	if days_per_stage.is_empty():
		problems.append("days_per_stage 不能为空")
	for stage_days: int in days_per_stage:
		if stage_days < 1:
			problems.append("days_per_stage 每一项都必须 >= 1")
			break
	if seasons.is_empty():
		problems.append("seasons 不能为空")
	return problems


func _to_string() -> String:
	return "CropData(%s)" % id
