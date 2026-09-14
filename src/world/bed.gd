class_name Bed
extends Interactable
## 床：交互后直接睡到第二天早上。
##
## 睡觉会走完整的日结转流水线（天气 → 作物生长 → 体力恢复），
## 因此这里只需要调用 [method GameClock.sleep_until_morning]，
## 不需要知道任何系统细节。

func _ready() -> void:
	prompt_key = &"PROMPT_BED"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	if GameClock.paused:
		return
	EventBus.notification_requested.emit(&"NOTIFY_SLEEPING", {})
	GameClock.sleep_until_morning()
