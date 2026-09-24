class_name InventoryUi
extends UiModal
## 背包界面。
##
## 槽位不是手写固定数量的节点，而是从 [ItemSlot] 场景实例化——
## 这样“背包上限”这个数字只存在于 Inventory.DEFAULT_CAPACITY 一处。
##
## 背包由组合根注入 provider 提供；provider 为 null 时界面必须清空，
## 不允许去场景树里按分组找玩家，也不允许把上一张图的旧背包留在屏幕上。

## 每行显示多少个格子。
##
## 与 [code]item_slot.tscn[/code] 的宽度、以及面板宽度三者互相约束：
## 改动其中任何一个都要同步检查另外两个，否则文字会被裁掉。
const COLUMNS: int = 4

@onready var shell: ModalShell = %Shell
@onready var grid: GridContainer = %Slots

var _slot_nodes: Array[ItemSlot] = []
## 组合根注入的“当前背包”提供者。
var _inventory_provider: Callable


func _ready() -> void:
    super._ready()
    grid.columns = COLUMNS
    shell.set_title(Text.key(&"INVENTORY_TITLE"))
    shell.set_body(grid)
    shell.set_hint(Text.key(&"INVENTORY_HINT"))
    _build_slots()
    EventBus.player.inventory_changed.connect(refresh)


## 组合根注入当前背包提供者；provider 可以返回 null（没有世界 / 玩家时）。
func bind_inventory_provider(provider: Callable) -> void:
    _inventory_provider = provider
    if is_node_ready():
        refresh()


## 打开界面并刷新内容。
func open() -> void:
    refresh()
    visible = true


func close() -> void:
    super.close()


## 按当前背包内容刷新所有格子；没有背包时全部清空。
func refresh() -> void:
    var inventory := _current_inventory()
    for index: int in _slot_nodes.size():
        if inventory == null or index >= inventory.capacity:
            _slot_nodes[index].clear()
            continue
        var slot: InventorySlot = inventory.slots[index]
        _slot_nodes[index].set_item(slot.item_id, slot.count, slot.quality)


func _current_inventory() -> Inventory:
    if not _inventory_provider.is_valid():
        return null
    return _inventory_provider.call() as Inventory


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
