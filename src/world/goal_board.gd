class_name GoalBoard
extends Interactable
## 村庄目标板（镇公所旁的公告板）：交互后打开长期目标列表。
##
## 与 [CommissionBoard] 同一形态，只是目标跨年累积、由 [VillageGoals] 单元结算。

func _ready() -> void:
	prompt_key = &"PROMPT_GOALS"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	EventBus.ui.village_goals_requested.emit()
