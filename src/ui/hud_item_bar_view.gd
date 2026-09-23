class_name HudItemBarView
extends Node
## HUD 底部的物品栏快捷栏。
##
## [b]物品栏自己的小视图[/b]：订阅手持 / 背包变化，只读物品栏与它背后的背包。
## 物品栏不存放任何道具，所以这里也只做"读背包 + 标出当前手持格"。
##
## [b]自己管缩放[/b]：空闲 [constant SHRINK_DELAY] 秒后缩到
## [constant UiLayout.HUD_BAR_SHRINK_SCALE]，点格子 / 换手持 / 背包变动这些
## "激活"会立刻恢复并把计时重置。因此 [Hud] 不再统一设置本条的
## [member Control.scale] / pivot，也不再为它做安全区偏移与触控让位。
##
## 物品栏由组合根注入的提供者给出：地图与世界是换来换去的，物品栏跟着玩家走，
## 所以这里不自己去场景树里找玩家（见 `AGENTS.md` 的"归属"一节）。

## 物品栏格子场景。
const HUD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/hud_slot.tscn")
## 空闲多久后自动缩小（秒）。
const SHRINK_DELAY: float = 6.0
## 缩小 / 恢复的过渡时长（秒）。
const SHRINK_DURATION: float = 0.25

@onready var inventory_bar: HBoxContainer = %InventoryBar

## 组合根注入的"当前物品栏"提供者；没有玩家时返回 null。
var _provider: Callable
## 物品栏格子，按从左到右排列。
var _slots: Array[HudSlot] = []
## 当前 UI 缩放（正常档）；缩小档是它再乘 [constant UiLayout.HUD_BAR_SHRINK_SCALE]。
var _ui_scale: float = 1.0
## 是否已自动缩小。
var _shrunk: bool = false
## 空闲计时；到时缩小。
var _shrink_timer: Timer
## 当前缩放过渡；重设时先杀掉旧 tween，避免两个同时写 scale。
var _scale_tween: Tween


func bind_item_bar(provider: Callable) -> void:
	_provider = provider
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.player.hand_changed.connect(_on_hand_changed)
	EventBus.player.inventory_changed.connect(_on_inventory_changed)
	EventBus.ui.ui_scale_changed.connect(_apply_ui_scale)
	inventory_bar.resized.connect(_refresh_pivot)
	_build()
	refresh()
	_shrink_timer = Timer.new()
	_shrink_timer.one_shot = true
	_shrink_timer.wait_time = SHRINK_DELAY
	_shrink_timer.timeout.connect(_set_shrunk.bind(true))
	add_child(_shrink_timer)
	_shrink_timer.start()
	# pivot 要等布局拿到 size 才能算，延后一帧再套用存盘值。
	_apply_ui_scale.call_deferred(UiSettings.scale())


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
	_activate()


func _on_inventory_changed() -> void:
	refresh()
	_activate()


## UI 缩放变化：正常档跟着变，缩小状态不变。
func _apply_ui_scale(value: float) -> void:
	_ui_scale = value
	_apply_scale(false)


## 绕底边中点缩放（缩小只朝屏幕内侧收，不会脱离底边）。
func _refresh_pivot() -> void:
	inventory_bar.pivot_offset = Vector2(inventory_bar.size.x * 0.5, inventory_bar.size.y)


## 缩放到当前档位；[param animate] 为 true 时用过渡动画。
func _apply_scale(animate: bool) -> void:
	_refresh_pivot()
	var factor: float = _ui_scale * (UiLayout.HUD_BAR_SHRINK_SCALE if _shrunk else 1.0)
	var target := Vector2(factor, factor)
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	if not animate:
		inventory_bar.scale = target
		return
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(inventory_bar, "scale", target, SHRINK_DURATION)


## 激活（点格子 / 换手持 / 背包变动）：恢复正常并重新计时。
func _activate() -> void:
	_set_shrunk(false)
	if _shrink_timer != null:
		_shrink_timer.start()


func _set_shrunk(value: bool) -> void:
	if _shrunk == value:
		return
	_shrunk = value
	_apply_scale(true)


## 点按物品栏某一格：把它对应的背包格设为手持。
func _on_slot_pressed(bar_index: int) -> void:
	_activate()
	var item_bar := _item_bar()
	if item_bar == null:
		return
	var backpack_index := item_bar.slot_index(bar_index)
	if backpack_index >= 0:
		item_bar.select(backpack_index)
