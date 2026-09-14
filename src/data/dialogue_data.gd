@tool
class_name DialogueData
extends Resource
## 一段对话。
##
## NPC 交互时由 [Npc] 交给 [DialogueBox] 播放；
## 对话内容与 UI 完全解耦，因此单元测试可以直接断言对话结构。

## 唯一标识。
@export var id: StringName = &""
## 默认说话人翻译键。
@export var speaker_key: StringName = &""
## 对白列表，按顺序播放。
@export var lines: Array[DialogueLine] = []
## 播放结束后触发的事件名（例如解锁商店）；留空表示无副作用。
@export var on_finish_signal: StringName = &""


func line_count() -> int:
	return lines.size()


func is_empty() -> bool:
	return lines.is_empty()


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	for index: int in lines.size():
		var line: DialogueLine = lines[index]
		if line == null:
			problems.append("第 %d 行为空" % index)
		elif line.text_key == &"":
			problems.append("第 %d 行缺少 text_key" % index)
	return problems


func _to_string() -> String:
	return "DialogueData(%s, %d lines)" % [id, lines.size()]
