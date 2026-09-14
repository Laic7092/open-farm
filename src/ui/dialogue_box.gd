class_name DialogueBox
extends Control
## 对话框：逐字显示 + 按键推进。
##
## 只负责"把 [DialogueData] 演出来"，不理解对话内容、也不决定何时开商店——
## 那是 [Npc] 监听 [signal EventBus.dialogue_finished] 之后的事。

## 播放结束（无论是正常读完还是被跳过）。
signal finished(dialogue: DialogueData)

## 每秒显示多少个字。
const CHARS_PER_SECOND: float = 45.0

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var hint_label: Label = %HintLabel

var _dialogue: DialogueData
var _line_index: int = -1
var _typing: bool = false
var _type_tween: Tween


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_tool"):
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
	EventBus.dialogue_started.emit(dialogue)
	_show_next_line()


## 推进：正在打字则立刻显示完整，否则进入下一句。
func advance() -> void:
	if _typing:
		_finish_typing()
		return
	_show_next_line()


# ---------------------------------------------------------------- 内部

func _show_next_line() -> void:
	_line_index += 1
	if _dialogue == null or _line_index >= _dialogue.line_count():
		_close()
		return

	var line: DialogueLine = _dialogue.lines[_line_index]
	var speaker_key: StringName = (
		line.speaker_key if line.speaker_key != &"" else _dialogue.speaker_key
	)
	speaker_label.text = Text.key(speaker_key)
	text_label.text = Text.key(line.text_key)
	hint_label.text = Text.key(&"DIALOGUE_ADVANCE_HINT")
	EventBus.dialogue_line_shown.emit()
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


func _finish_typing() -> void:
	_typing = false
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	text_label.visible_ratio = 1.0


func _close() -> void:
	var dialogue: DialogueData = _dialogue
	_dialogue = null
	visible = false
	EventBus.dialogue_finished.emit(dialogue)
	finished.emit(dialogue)
