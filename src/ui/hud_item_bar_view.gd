class_name HudItemBarView
extends Node
## HUD 底部的物品栏与手持道具。
##
## [b]物品栏自己的小视图[/b]：订阅手持 / 背包变化，只读物品栏与它背后的背包。
## 物品栏不存放任何道具，所以这里也只做"读背包 + 标出当前手持格"。
##
## 物品栏由组合根注入的提供者给出：地图与世界是换来换去的，物品栏跟着玩家走，
## 所以这里不自己去场景树里找玩家（见 `AGENTS.md` 的"归属"一节）。

## 物品栏格子场景。
const HUD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/hud_slot.tscn")

@onready var inventory_bar: HBoxContainer = %InventoryBar
@onready var tool_icon: TextureRect = %ToolIcon
@onready var tool_label: Label = %ToolLabel

## 组合根注入的"当前物品栏"提供者；没有玩家时返回 null。
var _provider: Callable
## 物品栏格子，按从左到右排列。
var _slots: Array[HudSlot] = []


func bind_item_bar(provider: Callable) -> void:
	_provider = provider
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.player.hand_changed.connect(_on_hand_changed)
	EventBus.player.inventory_changed.connect(refresh)
	_build()
	refresh()


## 重画手持图标与整条物品栏。
func refresh() -> void:
	_refresh_hand()
	_refresh_bar()


func _item_bar() -> ItemBar:
	if not _provider.is_valid():
		return null
	return _provider.call() as ItemBar


func _build() -> void:
	for slot: HudSlot in _slots:
		slot.queue_free()
	_slots.clear()

	if HUD_SLOT_SCENE == null:
		push_error("HudItemBarView: 找不到 hud_slot.tscn")
		return

	for _index: int in ItemBar.SIZE:
		var slot := HUD_SLOT_SCENE.instantiate() as HudSlot
		inventory_bar.add_child(slot)
		_slots.append(slot)


## 刷新底部物品栏：直接映射背包的前几格，并标出当前手持格。
func _refresh_bar() -> void:
	if _slots.is_empty():
		return

	var item_bar := _item_bar()
	if item_bar == null or item_bar.backpack == null:
		for slot: HudSlot in _slots:
			slot.clear()
		return

	var selected := item_bar.hand_index()
	for bar_index: int in _slots.size():
		var backpack_index := item_bar.slot_index(bar_index)
		if backpack_index < 0:
			_slots[bar_index].clear()
			continue
		var slot: InventorySlot = item_bar.backpack.slots[backpack_index]
		_slots[bar_index].set_item(
			slot.item_id, slot.count, backpack_index == selected, slot.quality
		)


## 左手边的持物图标。旧的手持文字行已经隐藏，但保留节点以便兼容外部查找；
## 真正的手持道具由底部物品栏高亮显示。
func _refresh_hand() -> void:
	var item_bar := _item_bar()
	var item_id: StringName = item_bar.selected_item_id() if item_bar != null else &""
	var item := Database.get_item(item_id)
	tool_label.text = Text.item_name(item)
	tool_icon.texture = item.icon if item != null else null


func _on_hand_changed(_item_id: StringName, _index: int) -> void:
	refresh()
