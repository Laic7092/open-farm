class_name CommissionUi
extends Control
## 委托板界面：展示今日委托、交付道具换报酬。
##
## 委托的"出题、刷新、结算"都在 [Commission] 单元里；界面只做展示与发请求，
## 不碰背包与金钱——交付结果由单元返回，界面翻译成提示与音效。
##
## [b]操作[/b]：WASD / 方向键选择，[code]E[/code] / 回车交付，[code]Esc[/code] 关闭。

@onready var title_label: Label = %TitleLabel
@onready var date_label: Label = %DateLabel
@onready var list: ItemList = %List
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

## 组合根注入的委托单元。
var _commission: Commission
## 本界面自己的音效播放器。
var sfx: SfxPlayer
var _clock: GameDateClock
## 当前列表里的委托 id，与 [member list] 的行一一对应。
var _entries: Array[StringName] = []


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	visible = false
	hint_label.text = Text.key(&"COMMISSION_HINT")
	list.item_selected.connect(func(_index: int) -> void: _refresh_info())


## 组合根注入时钟（用于显示日期）；委托逻辑由 [method bind_commission] 注入。
func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


## 组合根注入委托单元。
func bind_commission(commission: Commission) -> void:
	_commission = commission


func open() -> void:
	if _commission == null or _clock == null:
		push_error("CommissionUi: 依赖未注入")
		return
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func _rebuild() -> void:
	list.clear()
	_entries.clear()
	title_label.text = Text.key(&"COMMISSION_TITLE")
	date_label.text = Text.date_text(_clock.date)

	for commission_id: StringName in _commission.offers():
		var data := Database.get_commission(commission_id)
		if data == null:
			continue
		_entries.append(commission_id)
		var done: bool = _commission.is_completed(commission_id)
		list.add_item(_row_text(data, done))
		var item := Database.get_item(data.item_id)
		if item != null and item.icon != null:
			list.set_item_icon(list.item_count - 1, item.icon)
		list.set_item_disabled(list.item_count - 1, done)
	if not _entries.is_empty():
		list.select(0)
	_refresh_info()


func _row_text(data: CommissionData, done: bool) -> String:
	var item := Database.get_item(data.item_id)
	var mark := "✓ " if done else ""
	return "%s%s  %s ×%d  +%s" % [
		mark,
		Text.key(data.title_key),
		Text.item_name(item),
		data.amount,
		Text.format(&"HUD_MONEY", {"value": CommissionRules.reward_of(data)}),
	]


func _refresh_info() -> void:
	var index := _selected_index()
	if index < 0 or index >= _entries.size():
		info_label.text = ""
		return
	var data := Database.get_commission(_entries[index])
	if data == null:
		info_label.text = ""
		return
	var item := Database.get_item(data.item_id)
	info_label.text = "%s ×%d → %s" % [
		Text.item_name(item),
		data.amount,
		Text.format(&"HUD_MONEY", {"value": CommissionRules.reward_of(data)}),
	]


# ---------------------------------------------------------------- 键盘导航

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _navigate(event):
		get_viewport().set_input_as_handled()


func _navigate(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_up", true):
		_move(-1)
	elif event.is_action_pressed(&"ui_down", true):
		_move(1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool"):
		_deliver()
	else:
		return false
	return true


func _move(step: int) -> void:
	if list.item_count <= 0:
		return
	var current := _selected_index()
	var next: int = clampi(current + step, 0, list.item_count - 1)
	if next == current:
		return
	list.select(next)
	list.ensure_current_is_visible()
	_refresh_info()
	sfx.play(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)


# ---------------------------------------------------------------- 交付

func _deliver() -> void:
	var index := _selected_index()
	if index < 0 or index >= _entries.size():
		return
	var commission_id: StringName = _entries[index]
	var data := Database.get_commission(commission_id)
	match _commission.deliver(commission_id):
		Commission.Result.DELIVERED:
			if data != null:
				EventBus.ui.notification_requested.emit(
					&"NOTIFY_COMMISSION_DELIVERED",
					{
						"title": Text.key(data.title_key),
						"reward": CommissionRules.reward_of(data),
					}
				)
			sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
			_rebuild()
		Commission.Result.ALREADY_DONE:
			EventBus.ui.notification_requested.emit(&"NOTIFY_COMMISSION_ALREADY", {})
		Commission.Result.INSUFFICIENT:
			EventBus.ui.notification_requested.emit(&"NOTIFY_COMMISSION_INCOMPLETE", {})


func _selected_index() -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1
