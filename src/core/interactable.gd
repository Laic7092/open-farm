class_name Interactable
extends Area2D
## 可交互物基类（NPC、告示牌、床、出货箱……）。
##
## 通过 [Area2D] 让玩家在自己的"交互检测区"内发现目标，
## 玩家只依赖本基类的 [method interact]，不依赖具体子类。

## 交互发生时发出；[param actor] 是发起交互的角色。
signal interacted(actor: Node2D)

## 是否可交互；临时关闭（例如 NPC 在睡觉）时可置为 false。
@export var enabled: bool = true

## 交互提示文案的翻译键，HUD 会用它显示"按 E 交谈"之类提示。
@export var prompt_key: StringName = &"PROMPT_INTERACT"


## 是否当前可交互。
func can_interact() -> bool:
	return enabled


## 由玩家调用；子类覆写以实现具体行为，务必先调用 [code]super.interact(actor)[/code]。
func interact(actor: Node2D) -> void:
	interacted.emit(actor)
