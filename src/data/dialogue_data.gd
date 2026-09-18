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
			continue
		for problem: String in line.validate():
			problems.append("第 %d 行：%s" % [index, problem])
		_check_jump(problems, index, line.next_line, false)
		for choice: DialogueChoice in line.choices:
			if choice == null:
				continue
			_check_jump(problems, index, choice.next_line, true)
	return problems


## 校验一处跳转目标。
##
## 普通对白：[constant DialogueLine.NEXT_SEQUENTIAL]（顺序）与
## [constant DialogueLine.STOP]（结束）都合法，其余负数报错，正数越界报错。
## 选项：[param from_choice] 为 true，必须明确给出 [constant DialogueLine.STOP]
## 或有效索引，“顺序播放”语义对选项不成立。
func _check_jump(
	problems: PackedStringArray, index: int, target: int, from_choice: bool
) -> void:
	if target == DialogueLine.STOP:
		return
	if target == DialogueLine.NEXT_SEQUENTIAL:
		if from_choice:
			problems.append("第 %d 行：选项缺少跳转目标" % index)
		return
	if target < 0:
		problems.append("第 %d 行：无效的跳转目标 %d" % [index, target])
		return
	if target >= lines.size():
		problems.append("第 %d 行：跳转越界 %d" % [index, target])


func _to_string() -> String:
	return "DialogueData(%s, %d lines)" % [id, lines.size()]
