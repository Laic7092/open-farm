class_name CookingUi
extends Control
## 料理台界面：挑一道食谱、看材料够不够、按 E 下锅。
##
## "能不能做、扣哪些材料、放不放得下"都在 [Cooking] 单元里；界面只展示与发请求，
## 不碰背包——结果由单元返回，界面翻译成提示与音效。
##
## [b]操作[/b]：WASD / 方向键选择，[code]E[/code] / 回车下锅，[code]Esc[/code] 离开。

@onready var title_label: Label = %TitleLabel
@onready var count_label: Label = %CountLabel
@onready var list: ItemList = %List
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

## 组合根注入的料理单元。
var _cooking: Cooking
## 本界面自己的音效播放器。
var sfx: SfxPlayer
## 当前列表里的食谱 id，与 [member list] 的行一一对应。
var _entries: Array[StringName] = []


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	visible = false
	hint_label.text = Text.key(&"COOKING_HINT")
	list.item_selected.connect(func(_index: int) -> void: _refresh_info())


## 组合根注入料理单元。
func bind_cooking(cooking: Cooking) -> void:
	_cooking = cooking


func open() -> void:
	if _cooking == null:
		push_error("CookingUi: 依赖未注入")
		return
	_rebuild()
	visible = true


func close() -> void:
	visible = false


# ---------------------------------------------------------------- 列表

func _rebuild() -> void:
	list.clear()
	_entries.clear()
	title_label.text = Text.key(&"COOKING_TITLE")
	count_label.text = Text.format(&"COOKING_KNOWN", {
		"known": _cooking.state.known_count(),
		"total": Database.recipes().size(),
	})

	for recipe: RecipeData in _cooking.recipes():
		_entries.append(recipe.id)
		var unlocked: bool = _cooking.is_unlocked(recipe)
		list.add_item(_row_text(recipe, unlocked))
		var output := Database.get_item(recipe.output_item_id)
		if output != null and output.icon != null:
			list.set_item_icon(list.item_count - 1, output.icon)
		# 未解锁的菜不能下锅，直接置灰；做过的菜在行首打星。
		list.set_item_disabled(list.item_count - 1, not unlocked)
	if not _entries.is_empty():
		list.select(0)
	_refresh_info()


func _row_text(recipe: RecipeData, unlocked: bool) -> String:
	if not unlocked:
		return "%s  %s" % [Text.key(&"COOKING_LOCKED"), Text.key(&"MUSEUM_UNKNOWN")]
	var mark := "★ " if _cooking.state.is_known(recipe.id) else "· "
	return "%s%s  ×%d" % [
		mark, Text.key(recipe.display_name_key), recipe.output_amount
	]


func _refresh_info() -> void:
	var recipe := _selected_recipe()
	if recipe == null:
		info_label.text = ""
		return
	if not _cooking.is_unlocked(recipe):
		info_label.text = Text.key(&"COOKING_LOCKED")
		return
	var lines := PackedStringArray()
	for ingredient: RecipeIngredient in recipe.ingredients:
		var item := Database.get_item(ingredient.item_id)
		var have: int = _count_of(ingredient.item_id)
		var missing: bool = have < ingredient.amount
		lines.append("%s %s ×%d（%s %d）" % [
			"✗" if missing else "✓",
			Text.item_name(item),
			ingredient.amount,
			Text.key(&"COOKING_HAVE"),
			have,
		])
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
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool"):
		_cook()
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


# ---------------------------------------------------------------- 下锅

func _cook() -> void:
	var recipe := _selected_recipe()
	if recipe == null:
		return
	match _cooking.cook(recipe.id):
		Cooking.Result.COOKED:
			EventBus.ui.notification_requested.emit(&"NOTIFY_COOKED", {
				"item": Text.key(recipe.display_name_key),
				"count": recipe.output_amount,
			})
			sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
			_rebuild()
		Cooking.Result.MISSING:
			EventBus.ui.notification_requested.emit(&"NOTIFY_COOK_MATERIALS", {})
		Cooking.Result.FULL:
			EventBus.ui.notification_requested.emit(&"NOTIFY_INVENTORY_FULL", {})
		Cooking.Result.LOCKED:
			EventBus.ui.notification_requested.emit(&"COOKING_LOCKED", {})
		_:
			EventBus.ui.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})


func _selected_recipe() -> RecipeData:
	var index := _selected_index()
	if index < 0 or index >= _entries.size():
		return null
	return Database.get_recipe(_entries[index])


func _count_of(item_id: StringName) -> int:
	return _cooking.count_of(item_id) if _cooking != null else 0


func _selected_index() -> int:
	var selected := list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1
