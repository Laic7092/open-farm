class_name FestivalGameUi
extends Control
## 节日小游戏界面：挑一件自家产物参赛，按价值评奖。
##
## 评分、收走参赛品与发奖都在 [FestivalGame] 单元里；界面只列候选与发请求。
## 一场节日每年只能参加一次，所以提交后列表会变空、只留历史最好成绩。
##
## [b]操作[/b]：WASD / 方向键选择，[code]E[/code] / 回车提交，[code]Esc[/code] 离开。

@onready var title_label: Label = %TitleLabel
@onready var best_label: Label = %BestLabel
@onready var list: ItemList = %List
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

## 组合根注入的小游戏单元。
var _game: FestivalGame
## 本界面自己的音效播放器。
var sfx: SfxPlayer
## 正在参加哪一场节日。
var _festival_id: StringName = &""
## 当前列表里的候选（与 [member list] 的行一一对应）。
var _entries: Array[Dictionary] = []


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	visible = false
	hint_label.text = Text.key(&"FESTIVAL_GAME_HINT")
	list.item_selected.connect(func(_index: int) -> void: _refresh_info())


## 组合根注入小游戏单元。
func bind_festival_game(game: FestivalGame) -> void:
	_game = game


func open(festival_id: StringName) -> void:
	if _game == null:
		push_error("FestivalGameUi: 依赖未注入")
		return
	_festival_id = festival_id
	_rebuild()
	visible = true


func close() -> void:
	visible = false


# ---------------------------------------------------------------- 列表

func _rebuild() -> void:
	list.clear()
	_entries.clear()
	var game := _game.game_for(_festival_id)
	title_label.text = Text.key(&"FESTIVAL_GAME_TITLE")
	if game != null:
		title_label.text = Text.key(game.display_name_key)
	best_label.text = Text.format(&"FESTIVAL_GAME_BEST", {
		"score": _game.state.best_score(_festival_id),
		"target": game.min_score if game != null else 0,
	})

	for entry: Dictionary in _game.candidates(_festival_id):
		_entries.append(entry)
		var item := Database.get_item(entry["item_id"])
		list.add_item(_row_text(item, entry))
		if item != null and item.icon != null:
			list.set_item_icon(list.item_count - 1, item.icon)
	if not _entries.is_empty():
		list.select(0)
	_refresh_info()


func _row_text(item: ItemData, entry: Dictionary) -> String:
	var quality: String = Text.key(QualityRules.label_key(entry["quality"]))
	return "%s（%s）×%d  %s %d" % [
		Text.item_name(item),
		quality,
		entry["count"],
		Text.key(&"FESTIVAL_GAME_SCORE"),
		entry["score"],
	]


func _refresh_info() -> void:
	if _entries.is_empty():
		info_label.text = Text.key(&"FESTIVAL_GAME_DONE")
		return
	var entry: Dictionary = _entries[_selected_index()]
	info_label.text = "%s：%d" % [
		Text.key(&"FESTIVAL_GAME_SCORE"), entry["score"]
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
		_submit()
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


# ---------------------------------------------------------------- 提交

func _submit() -> void:
	if _festival_id == &"" or _entries.is_empty():
		return
	var entry: Dictionary = _entries[_selected_index()]
	var item := Database.get_item(entry["item_id"])
	match _game.play(_festival_id, entry["item_id"], entry["quality"]):
		FestivalGame.Result.WON:
			EventBus.ui.notification_requested.emit(&"NOTIFY_CONTEST_WON", {
				"item": Text.item_name(item),
				"score": entry["score"],
			})
			sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -2.0)
			_rebuild()
		FestivalGame.Result.PARTICIPATED:
			EventBus.ui.notification_requested.emit(&"NOTIFY_CONTEST_LOST", {
				"item": Text.item_name(item),
				"score": entry["score"],
			})
			sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -4.0)
			_rebuild()
		FestivalGame.Result.ALREADY_PLAYED:
			EventBus.ui.notification_requested.emit(&"NOTIFY_CONTEST_ALREADY", {})
		FestivalGame.Result.NOT_ACCEPTED:
			EventBus.ui.notification_requested.emit(&"NOTIFY_CONTEST_NOT_ACCEPTED", {})
		FestivalGame.Result.NOT_ACTIVE, FestivalGame.Result.NO_GAME:
			EventBus.ui.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
		_:
			EventBus.ui.notification_requested.emit(&"NOTIFY_CONTEST_MISSING", {})


func _selected_index() -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else 0
