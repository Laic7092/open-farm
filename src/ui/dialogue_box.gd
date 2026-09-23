class_name DialogueBox
extends Control
## 对话框：逐字显示 + 按键推进 + 分支选项。
##
## 只负责"把 [DialogueData] 演出来"：
## [br]- 跳转规则全部委托给纯静态的 [DialogueRules]；
## [br]- 好感 / 旗标等副作用只发出 [signal choice_selected]，由发起对话的 [Npc] 结算，
##   因此本节点既不理解对话内容、也不决定何时开商店。

## 播放结束（正常读完或跳过）。
signal finished(dialogue: DialogueData)
## 玩家做出了一个选项；[param choice] 是选中的那条，供副作用结算使用。
signal choice_selected(dialogue: DialogueData, choice: DialogueChoice)

## 每秒显示多少个字。
const CHARS_PER_SECOND: float = 45.0

## 情绪 → 正文颜色。只做轻微染色，保证在各种主题下都读得清。
const EMOTION_COLORS: Dictionary = {
	DialogueLine.Emotion.NEUTRAL: Color(1.0, 1.0, 1.0),
	DialogueLine.Emotion.HAPPY: Color(1.0, 0.93, 0.62),
	DialogueLine.Emotion.SAD: Color(0.72, 0.82, 1.0),
	DialogueLine.Emotion.ANGRY: Color(1.0, 0.66, 0.6),
	DialogueLine.Emotion.SURPRISED: Color(0.82, 1.0, 0.82),
}

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var hint_label: Label = %HintLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
## 组合根注入的玩家档案；选项的旗标条件靠它判定。
var _profile: PlayerProfile

var _dialogue: DialogueData
var _line_index: int = -1
var _typing: bool = false
var _type_tween: Tween
## 当前正在等待玩家选择的选项（已过滤掉条件不满足的）。
var _choices: Array[DialogueChoice] = []
var _choice_index: int = 0
var _awaiting_choice: bool = false
## 触控控件占用的左右宽度（由 [EventBus.ui] 广播）；非触控 / 世界模式为零。
## 模态里摇杆保持可见，正文与选项必须让开这两块。
var _touch_insets: Vector2 = Vector2.ZERO
## 当前 UI 缩放；对话框贴底，绕底边中点放大。
var _ui_scale: float = 1.0
## 实际生效的面板缩放：被内容最小尺寸与屏幕夹取后的值。
var _panel_scale: float = 1.0
## 显示安全区换算后的四周内边距（虚拟画布单位）。
var _safe: Vector4 = Vector4.ZERO


## 由 [UiRoot] 转发组合根依赖；只用到玩家档案。
func bind_dependencies(profile: PlayerProfile, _clock: GameDateClock) -> void:
	_profile = profile


## 本界面自己的音效播放器（翻页声）。
var sfx: SfxPlayer


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	visible = false
	choices_box.visible = false
	text_label.custom_minimum_size = Vector2(0.0, UiLayout.DIALOGUE_TEXT_MIN_HEIGHT)
	_layout_panel()
	EventBus.ui.touch_insets_changed.connect(_on_touch_insets_changed)
	EventBus.ui.safe_insets_changed.connect(_on_safe_insets_changed)
	EventBus.ui.ui_scale_changed.connect(apply_ui_scale)
	resized.connect(_layout_panel)
	panel.resized.connect(_refresh_scale)
	apply_ui_scale.call_deferred(UiSettings.scale())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_choice:
		if event.is_action_pressed(&"ui_up"):
			_move_choice(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_down"):
			_move_choice(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			choose(_choice_index)
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


## 开始播放一段对话。
func open(dialogue: DialogueData) -> void:
	if dialogue == null or dialogue.is_empty():
		finished.emit(dialogue)
		return
	_dialogue = dialogue
	_line_index = -1
	visible = true
	EventBus.ui.dialogue_started.emit(dialogue)
	_show_line(0)


## 推进：正在打字则立刻显示完整，否则进入下一句。
func advance() -> void:
	if _awaiting_choice:
		return
	if _typing:
		_finish_typing()
		return
	_step()


# ---------------------------------------------------------------- 内部

## 顺序推进一句；跳转规则交给 [DialogueRules]。
func _step() -> void:
	var line := _current_line()
	var next := DialogueRules.next_sequential(line, _line_index, _line_count())
	if next == DialogueRules.END:
		_close()
	else:
		_show_line(next)


## 显示第 [param index] 句；越界即结束。
func _show_line(index: int) -> void:
	if _dialogue == null or index < 0 or index >= _line_count():
		_close()
		return
	_line_index = index
	_reset_choices()

	var line: DialogueLine = _dialogue.lines[index]
	var speaker_key: StringName = (
		line.speaker_key if line.speaker_key != &"" else _dialogue.speaker_key
	)
	speaker_label.text = Text.key(speaker_key)
	text_label.text = Text.key(line.text_key)
	_apply_emotion(line.emotion)
	hint_label.text = Text.key(&"DIALOGUE_ADVANCE_HINT")
	EventBus.ui.dialogue_line_shown.emit()
	if sfx != null:
		sfx.play(AudioCatalog.SFX_DIALOGUE, 1.0, -3.0)
	_start_typing()


func _start_typing() -> void:
	_typing = true
	text_label.visible_ratio = 0.0
	var duration: float = maxf(float(text_label.text.length()) / CHARS_PER_SECOND, 0.05)
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_finish_typing)


## 打字结束（自然结束或玩家跳过）；随后按需弹出选项。
func _finish_typing() -> void:
	_typing = false
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	text_label.visible_ratio = 1.0
	_reveal_choices()


## 情绪染色；未知情绪退回白色。
func _apply_emotion(emotion: DialogueLine.Emotion) -> void:
	var color: Color = EMOTION_COLORS.get(emotion, Color.WHITE)
	text_label.add_theme_color_override(&"font_color", color)


# ---------------------------------------------------------------- 触控让位

func _on_touch_insets_changed(insets: Vector2) -> void:
	_touch_insets = insets
	_layout_panel()


func _on_safe_insets_changed(insets: Vector4) -> void:
	_safe = insets
	_layout_panel()


## 按令牌摆好贴底面板：宽度落在摇杆与 ABXY 之间的安全带里，
## 底部留 [constant UiLayout.DIALOGUE_BOTTOM] + 安全区；整体缩放后也不会出屏。
##
## [b]为什么要夹缩放[/b]：面板用 [code]Control.scale[/code] 整体放大，内容最小尺寸
## 会被一起放大；先把缩放夹到内容放得下，面板才不会在放大后顶出屏幕或压到触控键。
func _layout_panel() -> void:
	var viewport := size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		viewport = get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return
	var screen := UiLayout.safe_rect(viewport, _safe)
	var side := UiLayout.DIALOGUE_SIDE
	var band := UiLayout.usable_rect(viewport, _safe, _touch_insets)
	var content_min := panel.get_combined_minimum_size()
	# 缩放先夹到“安全带放得下”：触控占位会把可用宽度压窄，只按整屏夹会让
	# 内容顶着摇杆 / ABXY。安全带太窄时 [method UiLayout.fitted_scale] 会自然缩小。
	var available := Vector2(
		maxf(band.size.x - side * 2.0, 0.0),
		maxf(screen.size.y - UiLayout.DIALOGUE_BOTTOM, 0.0)
	)
	_panel_scale = UiLayout.fitted_scale(available, content_min, _ui_scale)
	# 视觉宽度优先取安全带；装不下时退回内容最小宽度，但都夹在屏内。
	var widest := maxf(screen.size.x - side * 2.0, 0.0)
	var visual := maxf(minf(band.size.x - side * 2.0, widest), content_min.x * _panel_scale)
	visual = clampf(visual, 0.0, widest)
	var left := band.position.x + band.size.x * 0.5 - visual * 0.5
	left = clampf(
		left, screen.position.x + side, maxf(screen.end.x - side - visual, screen.position.x + side)
	)
	var center_x := left + visual * 0.5
	var width := visual / _panel_scale
	panel.offset_left = center_x - width * 0.5
	panel.offset_right = center_x + width * 0.5 - viewport.x
	var bottom := -(UiLayout.DIALOGUE_BOTTOM + _safe.w)
	# 先给零高度，让 PanelContainer 的最小尺寸把它向上撑：选项多也不会顶出屏幕。
	panel.offset_bottom = bottom
	panel.offset_top = bottom
	panel.custom_minimum_size = Vector2(0.0, UiLayout.DIALOGUE_MIN_HEIGHT)
	_refresh_scale()


## 贴底长大：pivot 放底边中点，放大只朝上 / 朝内。
func apply_ui_scale(value: float) -> void:
	_ui_scale = value
	_layout_panel()


func _refresh_scale() -> void:
	panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y)
	panel.scale = Vector2(_panel_scale, _panel_scale)


# ---------------------------------------------------------------- 选项

## 若当前句带选项，则把它们显示出来并进入等待状态。
func _reveal_choices() -> void:
	if _dialogue == null or _awaiting_choice:
		return
	var line := _current_line()
	if line == null or not line.has_choices():
		return
	_choices = DialogueRules.available_choices(line, _profile)
	if _choices.is_empty():
		# 条件选项全被过滤掉时，直接当作普通对白继续，避免卡死。
		return
	_awaiting_choice = true
	_choice_index = 0
	hint_label.text = Text.key(&"DIALOGUE_CHOOSE_HINT")
	_build_choice_buttons()


func _build_choice_buttons() -> void:
	_clear_choice_buttons()
	for index: int in _choices.size():
		var button := Button.new()
		button.text = Text.key(_choices[index].text_key)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(choose.bind(index))
		choices_box.add_child(button)
	choices_box.visible = true
	_highlight_choice(0)
	# 选项出现会改内容最小尺寸，重排一次，缩放才不会把它顶出屏幕。
	_layout_panel.call_deferred()


## 清空选项状态（按钮 + 数据 + 等待标记）。
func _reset_choices() -> void:
	_awaiting_choice = false
	_choices = []
	_clear_choice_buttons()


## 只清空按钮节点，保留选项数据。
func _clear_choice_buttons() -> void:
	if choices_box == null:
		return
	for child: Node in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	choices_box.visible = false
	_layout_panel.call_deferred()


func _move_choice(step: int) -> void:
	if _choices.is_empty():
		return
	_choice_index = wrapi(_choice_index + step, 0, _choices.size())
	_highlight_choice(_choice_index)


func _highlight_choice(index: int) -> void:
	for i: int in choices_box.get_child_count():
		var button := choices_box.get_child(i) as Button
		if button == null:
			continue
		var color := Color(1.0, 0.9, 0.5) if i == index else Color(0.85, 0.86, 0.9)
		button.add_theme_color_override(&"font_color", color)


## 玩家确认了第 [param index] 个可见选项；越界或非等待状态会被忽略。
##
## 既供键盘 / 鼠标输入调用，也允许自动化脚本直接驱动（单元测试用）。
func choose(index: int) -> void:
	if not _awaiting_choice or index < 0 or index >= _choices.size():
		return
	var choice: DialogueChoice = _choices[index]
	var dialogue: DialogueData = _dialogue
	_reset_choices()
	choice_selected.emit(dialogue, choice)

	var target := DialogueRules.choice_target(choice, _line_count())
	if target == DialogueRules.END:
		_close()
	else:
		_show_line(target)


# ---------------------------------------------------------------- 收尾

func _close() -> void:
	var dialogue: DialogueData = _dialogue
	_dialogue = null
	_line_index = -1
	_reset_choices()
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	visible = false
	EventBus.ui.dialogue_finished.emit(dialogue)
	finished.emit(dialogue)


func _current_line() -> DialogueLine:
	if _dialogue == null or _line_index < 0 or _line_index >= _line_count():
		return null
	return _dialogue.lines[_line_index]


## 当前是否正在等待玩家选择选项。
func is_awaiting_choice() -> bool:
	return _awaiting_choice


## 当前显示到第几句；未在播放时为 -1。
func current_line_index() -> int:
	return _line_index


func _line_count() -> int:
	return _dialogue.line_count() if _dialogue != null else 0
