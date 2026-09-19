extends "res://tools/sample/sample_base.gd"
## commissions：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 委托板每天从这张池子里确定性挑 3 个（见 CommissionRules）。
## 报酬略高于直接出货，鼓励玩家"为委托而种"；需求覆盖四季作物与野外素材。

const COMMISSIONS: Array[Dictionary] = [
	{"id": &"ship_turnip", "item": &"turnip", "amount": 5, "reward": 150},
	{"id": &"ship_potato", "item": &"potato", "amount": 5, "reward": 250},
	{"id": &"ship_tomato", "item": &"tomato", "amount": 5, "reward": 220},
	{"id": &"ship_corn", "item": &"corn", "amount": 3, "reward": 380},
	{"id": &"ship_pumpkin", "item": &"pumpkin", "amount": 2, "reward": 420},
	{"id": &"ship_stone", "item": &"stone", "amount": 10, "reward": 140},
	{"id": &"ship_wood", "item": &"wood", "amount": 10, "reward": 160},
	{"id": &"ship_fiber", "item": &"fiber", "amount": 15, "reward": 100},
	{"id": &"ship_flower", "item": &"flower", "amount": 5, "reward": 130},
	{"id": &"ship_mushroom", "item": &"mushroom", "amount": 3, "reward": 180},
	{"id": &"ship_egg", "item": &"egg", "amount": 3, "reward": 220},
	{"id": &"ship_milk", "item": &"milk", "amount": 2, "reward": 320},
]


func build() -> void:
	for entry: Dictionary in COMMISSIONS:
		var commission := CommissionData.new()
		var commission_id: StringName = entry["id"]
		commission.id = commission_id
		commission.title_key = StringName("COMMISSION_%s_TITLE" % String(commission_id).to_upper())
		commission.item_id = entry["item"]
		commission.amount = int(entry["amount"])
		commission.reward_money = int(entry["reward"])
		_save(commission, COMMISSION_DIR.path_join("%s.tres" % commission_id))
