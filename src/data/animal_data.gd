@tool
class_name AnimalData
extends Resource
## 一种可畜养动物的静态定义（数据驱动）。
##
## 和 [CropData] 同构：数值全部放在 [Resource] 里，新增一种动物 =
## 新建一个 [code].tres[/code]，脚本无需改动。运行期状态放在 [AnimalState]。
##
## [b]为什么动物不按季节枯死[/b]：牲畜是"资产"而不是"一季的投入"，
## 牧场物语里牛不会因为入冬就消失。季节只影响世界，不影响畜舍。

## 唯一标识，存档中保存的就是它。
@export var id: StringName = &""
## 显示名翻译键。
@export var display_name_key: StringName = &""
## 物种标签；[BuildingData.allowed_species] 用它决定"这种畜舍能养什么"。
@export var species: StringName = &""
## 从幼崽长到成年所需的喂养天数。
@export_range(1, 60) var mature_days: int = 3
## 成年后每隔多少天产出一次。
@export_range(1, 30) var produce_days: int = 1
## 产出的道具 id。
@export var product_item_id: StringName = &""
## 每次产出的数量。
@export_range(1, 99) var product_amount: int = 1
## 每天消耗的饲料道具 id。
@export var feed_item_id: StringName = &"hay"
## 好感度上限。
@export_range(0, 999) var max_affection: int = 100
## 每天第一次抚摸增加的好感度。
@export_range(0, 99) var affection_per_pet: int = 4
## 一天没喂食下降的好感度。
@export_range(0, 99) var affection_decay_per_day: int = 2
## 好感度达到该值后，产出有概率额外 +1。
@export_range(0, 999) var bonus_affection_threshold: int = 80
## 高好感时的额外产出概率。
@export_range(0.0, 1.0, 0.01) var bonus_product_chance: float = 0.25
## 产出时至少抽出银品质的概率（见 [QualityRules]）。
@export_range(0.0, 1.0, 0.01) var quality_silver_chance: float = 0.0
## 产出时抽出金品质的概率。
@export_range(0.0, 1.0, 0.01) var quality_gold_chance: float = 0.0
## 成年且好感达标的同类两两配对后，多少天产下一只幼崽；0 表示不繁殖。
@export_range(0, 60) var breed_days: int = 0
## 参与繁殖所需的最低好感度。
@export_range(0, 999) var breed_affection: int = 60
## 动物贴图：[code]assets/sprites/animals/<id>.png[/code]，固定 3 列。
##
## 列 0 = 幼崽、列 1 = 成年、列 2 = 成年且有产出可收。
@export var sprite_sheet: Texture2D


## 给定已喂养天数，是否已成年。
func is_mature(days_grown: int) -> bool:
	return days_grown >= mature_days


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if species == &"":
		problems.append("species 不能为空")
	if product_item_id == &"":
		problems.append("product_item_id 不能为空")
	if feed_item_id == &"":
		problems.append("feed_item_id 不能为空")
	if mature_days < 1:
		problems.append("mature_days 必须 >= 1")
	if produce_days < 1:
		problems.append("produce_days 必须 >= 1")
	if breed_days < 0:
		problems.append("breed_days 不能为负")
	if breed_affection < 0:
		problems.append("breed_affection 不能为负。")
	return problems


func _to_string() -> String:
	return "AnimalData(%s)" % id
