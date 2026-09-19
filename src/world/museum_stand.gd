class_name MuseumStand
extends Interactable
## 博物馆展台：交互后打开图鉴 UI。
##
## 交互逻辑只发一条 UI 请求，图鉴数据与界面都在 UI 层，展台本身不持有状态。

func _ready() -> void:
	prompt_key = &"PROMPT_MUSEUM"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	EventBus.ui.museum_requested.emit()
