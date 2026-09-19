class_name CookingStand
extends Interactable
## 料理台（农舍里的灶台）：交互后打开食谱界面。
##
## 与 [MuseumStand] / [CommissionBoard] 一样只发一条 UI 请求：
## 食谱、材料与结算都在 [Cooking] 单元里，本节点不持有任何状态。

func _ready() -> void:
	prompt_key = &"PROMPT_COOK"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	EventBus.ui.cooking_requested.emit()
