class_name Npc
extends Interactable
## NPC：可以对话，商人还会在对话结束后打开商店。
##
## NPC 的行为数据来自 [NpcData]，本脚本只负责"把数据变成一次交互"。

const GROUP: StringName = &"npc"

## 好感度变化。
signal affection_changed(value: int)

## 对应的 [NpcData.id]。
@export var npc_id: StringName = &""
## 存档标识（同一场景里多个 NPC 必须各不相同）。
@export var persistence_id: StringName = &""
## 是否在站立时播放轻微起伏动画。
@export var idle_bob: bool = true

## 静态数据。
var data: NpcData
## 好感度。
var affection: int = 0

var _pending_shop_id: StringName = &""

@onready var sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	add_to_group(GROUP)
	data = Database.get_npc(npc_id)
	if data != null:
		prompt_key = &"PROMPT_TALK"
		if data.is_merchant():
			prompt_key = &"PROMPT_SHOP"
		if persistence_id == &"":
			persistence_id = StringName("npc_%s" % npc_id)
	else:
		push_warning("Npc: 找不到 NpcData '%s'" % npc_id)

	if persistence_id != &"":
		Persistence.register(self, persistence_id)

	if idle_bob:
		sprite.play(&"idle_down")

	EventBus.dialogue_finished.connect(_on_dialogue_finished)


func _exit_tree() -> void:
	if EventBus.dialogue_finished.is_connected(_on_dialogue_finished):
		EventBus.dialogue_finished.disconnect(_on_dialogue_finished)


## 当前季节应该说的话。
func current_dialogue() -> DialogueData:
	if data == null:
		return null
	return data.dialogue_for_season(GameClock.date.season)


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	super.interact(actor)

	var dialogue := current_dialogue()
	if dialogue == null or dialogue.is_empty():
		EventBus.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
		return

	# 商人：先把招呼打完，再打开商店（由 dialogue_finished 触发）。
	_pending_shop_id = data.shop_id if data.is_merchant() else &""
	EventBus.dialogue_requested.emit(dialogue)


## 增加好感度。
func add_affection(amount: int) -> void:
	if data == null or amount == 0:
		return
	affection = clampi(affection + amount, 0, data.max_affection)
	affection_changed.emit(affection)


func to_dict() -> Dictionary:
	return {"affection": affection}


func from_dict(data_dict: Dictionary) -> void:
	affection = maxi(int(data_dict.get("affection", 0)), 0)
	affection_changed.emit(affection)


func _on_dialogue_finished(_dialogue: DialogueData) -> void:
	if _pending_shop_id == &"":
		return
	var shop_id: StringName = _pending_shop_id
	_pending_shop_id = &""
	EventBus.shop_requested.emit(shop_id)
