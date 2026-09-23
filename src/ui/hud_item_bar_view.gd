class_name HudItemBarView
extends Node
## HUD 底部的物品栏快捷栏。
##
## [b]物品栏自己的小视图[/b]：订阅手持 / 背包变化，只读物品栏与它背后的背包。
## 物品栏不存放任何道具，所以这里也只做"读背包 + 标出当前手持格"。
##
## 物品栏由组合根注入的提供者给出：地图与世界是换来换去的，物品栏跟着玩家走，
## 所以这里不自己去场景树里找玩家（见 `AGENTS.md` 的"归属"一节）。

## 物品栏格子场景。
const HUD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/hud_slot.tscn")

@onready var inventory_bar: HBoxContainer = %InventoryBar

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


## 重画整条物品栏并标出当前手持格。
func refresh() -> void:
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

	for index: int in ItemBar.SIZE:
		var slot := HUD_SLOT_SCENE.instantiate() as HudSlot
		inventory_bar.add_child(slot)
		# 点某格 → 请求把它设为手持（不可用道具由 [method ItemBar.select] 忽略）。
		slot.pressed.connect(_on_slot_pressed.bind(index))
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


func _on_hand_changed(_item_id: StringName, _index: int) -> void:
	refresh()


## 点按物品栏某一格：把它对应的背包格设为手持。
func _on_slot_pressed(bar_index: int) -> void:
	var item_bar := _item_bar()
	if item_bar == null:
		return
	var backpack_index := item_bar.slot_index(bar_index)
	if backpack_index >= 0:
		item_bar.select(backpack_index)
