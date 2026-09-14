@tool
class_name DialogueLine
extends Resource
## 一句对白。
##
## 文本只保存翻译键，实际语言由 [TranslationServer] 在 UI 层解析，
## 因此新增语言无需改动脚本或数据。

enum Emotion {
	NEUTRAL,
	HAPPY,
	SAD,
	ANGRY,
	SURPRISED,
}

## 说话人的名字翻译键；留空表示沿用 [DialogueData.speaker_key]。
@export var speaker_key: StringName = &""
## 正文翻译键。
@export var text_key: StringName = &""
@export var emotion: Emotion = Emotion.NEUTRAL
## 可选立绘。
@export var portrait: Texture2D
## 可选的玩家选项（分支对话的最小实现留待后续里程碑）。
@export var choices: Array[StringName] = []


func has_choices() -> bool:
	return not choices.is_empty()
