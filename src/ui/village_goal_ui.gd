class_name VillageGoalUi
extends Control
## 长期村庄目标板：看进度、达标领奖。
##
## 目标本身不产生行为，只汇总玩家自由玩出来的数字；判定与发奖都在
## [VillageGoals] 单元里，界面只展示与发请求。
##
## [b]操作[/b]：WASD / 方向键选择，[code]E[/code] / 回车领奖，[code]Esc[/code] 离开。

@onready var title_label: Label = %TitleLabel
@onready var progress_label: Label = %ProgressLabel
@onready var list: ItemList = %List
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

## 组合根注入的目标单元。
var _goals: VillageGoals
## 本界面自己的音效播放器。
var sfx: SfxPlayer
## 当前列表里的目标 id，与 [member list] 的行一一对应。
var _entries: Array[StringName] = []


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	visible = false
	hint_label.text = Text.key(&"GOAL_HINT")
	list.item_selected.connect(func(_index: int) -> void: _refresh_info())


## 组合根注入目标单元。
func bind_goals(goals: VillageGoals) -> void:
	_goals = goals


func open() -> void:
	if _goals == null:
		push_error("VillageGoalUi: 依赖未注入")
		return
	_rebuild()
	visible = true


func close() -> void:
	visible = false


# ---------------------------------------------------------------- 列表

func _rebuild() -> void:
	list.clear()
	_entries.clear()
	title_label.text = Text.key(&"GOAL_TITLE")

	var claimed: int = 0
	for goal: VillageGoalData in _goals.goals():
		_entries.append(goal.id)
		var done: bool = _goals.state.is_claimed(goal.id)
		if done:
			claimed += 1
		list.add_item(_row_text(goal, done))
		# 没解锁的条目只透出"尚未开启"，不泄漏后面目标的内容。
		var hidden: bool = not _goals.is_unlocked(goal)
		list.set_item_disabled(list.item_count - 1, hidden or done)
	progress_label.text = Text.format(&"GOAL_PROGRESS", {
		"done": claimed,
		"total": _entries.size(),
	})
	if not _entries.is_empty():
		list.select(0)
	_refresh_info()


func _row_text(goal: VillageGoalData, done: bool) -> String:
	if not _goals.is_unlocked(goal):
		return "%s  %s" % [Text.key(&"GOAL_LOCKED"), Text.key(&"MUSEUM_UNKNOWN")]
	var mark := "✓ " if done else ""
	return "%s%s  %d / %d" % [
		mark,
		Text.key(goal.title_key),
		mini(_goals.progress(goal), goal.target),
		goal.target,
	]


func _refresh_info() -> void:
	var goal := _selected_goal()
	if goal == null or not _goals.is_unlocked(goal):
		info_label.text = Text.key(&"GOAL_LOCKED")
		return
	var lines := PackedStringArray()
	lines.append(Text.key(goal.description_key))
	if _goals.state.is_claimed(goal.id):
		lines.append(Text.key(&"GOAL_CLAIMED"))
	else:
		lines.append(Text.format(&"GOAL_REWARD", {
			"money": goal.reward_money,
		}))
	info_label.text = "\n".join(lines)


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
	elif event.is_action_pressed(&"ui_accept"):
		_claim()
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


# ---------------------------------------------------------------- 领奖

func _claim() -> void:
	var goal := _selected_goal()
	if goal == null:
		return
	match _goals.claim(goal.id):
		VillageGoals.Result.CLAIMED:
			EventBus.ui.notification_requested.emit(&"NOTIFY_GOAL_CLAIMED", {
				"title": Text.key(goal.title_key),
				"money": goal.reward_money,
			})
			sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -2.0)
			_rebuild()
		VillageGoals.Result.NOT_READY:
			EventBus.ui.notification_requested.emit(&"NOTIFY_GOAL_NOT_READY", {})
		VillageGoals.Result.ALREADY:
			EventBus.ui.notification_requested.emit(&"GOAL_CLAIMED", {})
		VillageGoals.Result.LOCKED:
			EventBus.ui.notification_requested.emit(&"GOAL_LOCKED", {})
		_:
			EventBus.ui.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})


func _selected_goal() -> VillageGoalData:
	var index := _selected_index()
	if index < 0 or index >= _entries.size():
		return null
	return Database.get_village_goal(_entries[index])


func _selected_index() -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1
