class_name MuseumUi
extends Control
## 博物馆图鉴界面。
##
## 只读展示 [MuseumState]：已发现的条目标出图标与名字，未发现的显示 ???。
## 图鉴的记录发生在 [Main] 侧（背包一有变化就补录），本界面不参与玩法结算。
##
## [b]操作[/b]：WASD / 方向键选择，[code]A[/code] / [code]D[/code] 左右切换分类，
## [code]Esc[/code] 关闭（由 [UiRoot] 统一处理）。

## 分类页：显示名翻译键 + 过滤的 [enum ItemData.Category]（-1 = 全部）。
const CATEGORIES: Array[Dictionary] = [
	{"key": &"MUSEUM_CAT_ALL", "filter": -1},
	{"key": &"MUSEUM_CAT_CROP", "filter": ItemData.Category.CROP},
	{"key": &"MUSEUM_CAT_SEED", "filter": ItemData.Category.SEED},
	{"key": &"MUSEUM_CAT_FOOD", "filter": ItemData.Category.FOOD},
	{"key": &"MUSEUM_CAT_MATERIAL", "filter": ItemData.Category.MATERIAL},
]

@onready var title_label: Label = %TitleLabel
@onready var progress_label: Label = %ProgressLabel
@onready var category_label: Label = %CategoryLabel
@onready var list: ItemList = %List
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

var _state: MuseumState
var _category: int = 0
## 当前列表里的道具 id，与 [member list] 的行一一对应。
var _entries: Array[StringName] = []


func _ready() -> void:
	visible = false
	hint_label.text = Text.key(&"MUSEUM_HINT")
	list.item_selected.connect(func(_index: int) -> void: _refresh_info())


## 组合根注入图鉴状态；[UiRoot] 会把同一个回调下发给各界面。
func bind_progress(museum: MuseumState, _commissions: CommissionState) -> void:
	_state = museum


func open() -> void:
	if _state == null:
		push_error("MuseumUi: 未注入 MuseumState")
		return
	_category = 0
	_rebuild()
	visible = true


func close() -> void:
	visible = false


## 重建列表：按分类过滤 + 按 id 排序，保证每次打开顺序稳定。
func _rebuild() -> void:
	list.clear()
	_entries.clear()
	title_label.text = Text.key(&"MUSEUM_TITLE")
	_refresh_category_label()
	_refresh_progress()

	var filter: int = int(CATEGORIES[_category]["filter"])
	var ids: Array[StringName] = []
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		if filter >= 0 and item.category != filter:
			continue
		ids.append(item_id)
	ids.sort()

	for item_id: StringName in ids:
		_entries.append(item_id)
		var item := Database.get_item(item_id)
		var known: bool = _state.is_discovered(item_id)
		list.add_item(_row_text(item, known))
		if known and item.icon != null:
			list.set_item_icon(list.item_count - 1, item.icon)
		list.set_item_disabled(list.item_count - 1, not known)
	if not _entries.is_empty():
		list.select(0)
	_refresh_info()


func _row_text(item: ItemData, known: bool) -> String:
	if not known:
		return Text.key(&"MUSEUM_UNKNOWN")
	return Text.item_name(item)


func _refresh_category_label() -> void:
	category_label.text = "◀ %s ▶" % Text.key(CATEGORIES[_category]["key"])


func _refresh_progress() -> void:
	var total := Database.items().size()
	progress_label.text = Text.format(
		&"MUSEUM_PROGRESS",
		{"found": _state.discovered_count(), "total": total}
	)


func _refresh_info() -> void:
	var index := _selected_index()
	if index < 0 or index >= _entries.size():
		info_label.text = ""
		return
	var item := Database.get_item(_entries[index])
	if not _state.is_discovered(_entries[index]):
		info_label.text = Text.key(&"MUSEUM_UNKNOWN")
		return
	var description := Text.key(item.description_key)
	info_label.text = description if not description.is_empty() else Text.item_name(item)


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
	elif event.is_action_pressed(&"ui_left", true):
		_switch_category(-1)
	elif event.is_action_pressed(&"ui_right", true):
		_switch_category(1)
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
	EventBus.ui.ui_sound_requested.emit(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)


func _switch_category(step: int) -> void:
	_category = wrapi(_category + step, 0, CATEGORIES.size())
	_rebuild()
	EventBus.ui.ui_sound_requested.emit(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)


func _selected_index() -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1
