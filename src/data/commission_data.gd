@tool
class_name CommissionData
extends Resource
## 委托板上的一个委托（静态定义）。
##
## 委托只描述"要什么、给多少报酬"，能不能交付、怎么扣道具在
## [CommissionRules] / [CommissionState] 与 UI 里结算。
## 与作物 / 道具一样，新增委托 = 往 [code]res://data/commissions/[/code] 丢一个
## [code].tres[/code]，代码不用动。

## 唯一标识。
@export var id: StringName = &""
## 标题翻译键。
@export var title_key: StringName = &""
## 需要的道具 id。
@export var item_id: StringName = &""
## 需要几件。
@export_range(1, 99) var amount: int = 1
## 完成后的金钱报酬。
@export_range(0, 99999) var reward_money: int = 0


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if title_key == &"":
		problems.append("title_key 不能为空")
	if item_id == &"":
		problems.append("item_id 不能为空")
	if amount < 1:
		problems.append("amount 必须 >= 1")
	return problems


func _to_string() -> String:
	return "CommissionData(%s, %d x %s)" % [id, amount, item_id]
