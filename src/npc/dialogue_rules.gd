class_name DialogueRules
extends RefCounted
## 对话推进规则的[b]纯静态[/b]实现。
##
## 只回答"这句之后演哪句、哪些选项可见"，不碰场景树 / UI / 存档，
## 因此 [code]tests/unit/test_dialogue.gd[/code] 可以脱离引擎逐条断言
## （与 [AffectionRules] / [MarriageRules] 同一套做法）。
##
## 运行时节点 [DialogueBox] 只负责把这里算出的索引显示出来，
## 自身不包含任何跳转判断。

## 表示"对话到此结束"的索引（[DialogueRules] 的返回值，不是数据里的值）。
const END: int = -1


## 顺序推进时的下一句；[param line] 上的显式 [member DialogueLine.next_line] 优先。
##
## [param line] 为 null 或 [param index] 越界都视为结束，调用方不必先做检查。
static func next_sequential(line: DialogueLine, index: int, line_count: int) -> int:
	if line == null or index < 0 or index >= line_count:
		return END
	if line.next_line == DialogueLine.STOP:
		return END
	if line.next_line >= 0:
		return _clamp_target(line.next_line, line_count)
	var following: int = index + 1
	return following if following < line_count else END


## 选项的跳转目标；空选项、负数目标、越界目标一律视为结束。
static func choice_target(choice: DialogueChoice, line_count: int) -> int:
	if choice == null or choice.next_line < 0:
		return END
	return _clamp_target(choice.next_line, line_count)


## 当前可见的选项：带 [member DialogueChoice.required_flag] 的选项需要玩家持有旗标。
##
## [param profile] 为 null 时只保留无条件的选项，避免把"看不见的条件"当成满足。
static func available_choices(
	line: DialogueLine, profile: PlayerProfile
) -> Array[DialogueChoice]:
	var result: Array[DialogueChoice] = []
	if line == null:
		return result
	for choice: DialogueChoice in line.choices:
		if choice == null:
			continue
		if choice.required_flag != &"":
			if profile == null or not profile.has_flag(choice.required_flag):
				continue
		result.append(choice)
	return result


static func _clamp_target(target: int, line_count: int) -> int:
	if target < 0 or target >= line_count:
		return END
	return target
