class_name InventoryUi
extends Control
## 背包界面。
##
## 槽位不是手写 24 个节点，而是从 [ItemSlot] 场景实例化——
## 这样"背包上限"这个数字只存在于 [constant Inventory.DEFAULT_CAPACITY] 一处。

## 每行显示多少个格子。
##
## 与 [code]item_slot.tscn[/code] 的宽度、以及面板宽度三者互相约束：
## 改动其中任何一个都要同步检查另外两个，否则文字会被裁掉。
const COLUMNS: int = 5

@onready var grid: GridContainer = %Slots
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel

var _slot_nodes: Array[ItemSlot] = []


func _ready() -> void:
	visible = false
	grid.columns = COLUMNS
	title_label.text = Text.key(&"INVENTORY_TITLE")
	hint_label.text = Text.key(&"INVENTORY_HINT")
	_build_slots()
	EventBus.inventory_changed.connect(refresh)


## 打开界面并刷新内容。
func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false


## 按当前背包内容刷新所有格子。
func refresh() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return
	var inventory: Inventory = player.inventory
	for index: int in _slot_nodes.size():
		if index >= inventory.capacity:
			_slot_nodes[index].clear()
			continue
		var slot: InventorySlot = inventory.slots[index]
		_slot_nodes[index].set_item(slot.item_id, slot.count)


func _build_slots() -> void:
	for node: ItemSlot in _slot_nodes:
		node.queue_free()
	_slot_nodes.clear()

	var scene: PackedScene = load("res://scenes/ui/item_slot.tscn")
	if scene == null:
		push_error("InventoryUi: 找不到 item_slot.tscn")
		return
	for _index: int in Inventory.DEFAULT_CAPACITY:
		var node := scene.instantiate() as ItemSlot
		grid.add_child(node)
		_slot_nodes.append(node)
