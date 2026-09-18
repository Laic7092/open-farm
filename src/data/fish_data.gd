@tool
class_name FishData
extends Resource
## 鱼的静态定义（数据驱动）。
##
## 一条鱼"出没在哪片水、哪个季节、什么天气、几点到几点、多稀有、多难钓"
## 全部写在这里；[FishingRules] 只负责按这些字段筛选与加权抽取。
## 因此新增鱼种 = 往 [code]data/fish/[/code] 丢一个 [code].tres[/code] + 画一张道具图标。
##
## 与 [CropData] / [FloraData] 一致：这里只有[b]不变[/b]的数据，
## 会变的（背包里有没有、钓过多大）不在这里。

## 唯一标识。
@export var id: StringName = &""
## 钓上来后放进背包的道具 id。
@export var item_id: StringName = &""

## 出没的水域；见 [enum WaterKind.Kind]。
@export var water: Array[int] = []
## 出没的季节；空数组表示四季皆可。
@export var seasons: Array[Season.Type] = []
## 需要的天气；空数组表示不看天气。
@export var weathers: Array[Weather.Type] = []
## 出没时段（小时，含端点）。[code]min_hour > max_hour[/code] 表示跨午夜。
@export_range(0, 23) var min_hour: int = 0
@export_range(0, 23) var max_hour: int = 23

## 抽取权重：越大越常见；0 表示不会出现。
@export_range(0, 999) var weight: int = 10
## 搏斗难度 1~5：拉扯小游戏里鱼游得更快、判定区更窄。
@export_range(1, 5) var difficulty: int = 1
## 体长范围（厘米），仅用于展示。
@export var size_cm: Vector2i = Vector2i(20, 40)


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if item_id == &"":
		problems.append("item_id 不能为空")
	if water.is_empty():
		problems.append("water 至少要有一片水域")
	for value: int in water:
		if not WaterKind.is_valid(value):
			problems.append("water 含有未知水域 %d" % value)
	if weight <= 0:
		problems.append("weight 必须 >= 1")
	if size_cm.x < 1 or size_cm.y < size_cm.x:
		problems.append("size_cm 必须为正，且上限不小于下限")
	for value: int in weathers:
		if not Weather.is_valid(value):
			problems.append("weathers 含有未知天气 %d" % value)
	for value: int in seasons:
		if not Season.is_valid(value):
			problems.append("seasons 含有未知季节 %d" % value)
	return problems


func _to_string() -> String:
	return "FishData(%s)" % id
