class_name CommissionBoard
extends Interactable
## 委托板：交互后打开今日委托列表。
##
## 委托状态由 [CommissionState] 持有并在 UI 层结算；委托板只负责发请求。

func _ready() -> void:
	prompt_key = &"PROMPT_COMMISSION"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	EventBus.ui.commission_requested.emit()
