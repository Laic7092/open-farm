@tool
class_name DialogueLine
extends Resource
## 一句对白。
##
## 文本只保存翻译键，实际语言由 [TranslationServer] 在 UI 层解析，
## 因此新增语言无需改动脚本或数据。
##
## 一句对白要么顺序播放（[member next_line] 为 [constant NEXT_SEQUENTIAL]），
## 要么给出玩家选项（[member choices] 非空）。分支对话由 [DialogueRules] 解析，
## UI 只负责把结果显示出来。

enum Emotion {
	NEUTRAL,
	HAPPY,
	SAD,
	ANGRY,
	SURPRISED,
}

## [member next_line] 的默认值：读完这一句后顺序播放下一句。
const NEXT_SEQUENTIAL: int = -1
## [member next_line] / [member DialogueChoice.next_line] 的结束标记。
const STOP: int = -2

## 说话人的名字翻译键；留空表示沿用 [DialogueData.speaker_key]。
@export var speaker_key: StringName = &""
## 正文翻译键。
@export var text_key: StringName = &""
@export var emotion: Emotion = Emotion.NEUTRAL
## 可选立绘。
@export var portrait: Texture2D
## 可选的玩家选项；非空时本句不再按 [member next_line] 顺序推进。
@export var choices: Array[DialogueChoice] = []
## 非选项对白的下一句：小于 0 表示结束，大于等于 0 表示跳转，默认顺序播放。
@export var next_line: int = NEXT_SEQUENTIAL


func has_choices() -> bool:
	return not choices.is_empty()


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if text_key == &"":
		problems.append("缺少 text_key")
	for choice: DialogueChoice in choices:
		if choice == null:
			problems.append("选项为空")
			continue
		for problem: String in choice.validate():
			problems.append(problem)
	return problems
