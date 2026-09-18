@tool
class_name DialogueChoice
extends Resource
## 对话中的一个玩家选项。
##
## 选项只描述"显示什么、跳到哪一句、产生什么副作用"，
## 真正的 UI 由 [DialogueBox] 负责、好感 / 旗标结算由发起对话的 [Npc] 负责，
## 因此对话数据仍然与场景树、服务完全解耦，单元测试可以直接断言结构。

## 选项按钮上的翻译键。
@export var text_key: StringName = &""
## 选中后跳到 [member DialogueData.lines] 的哪一句。
##
## 约定与 [member DialogueLine.next_line] 一致：小于 0 表示结束对话，
## 大于等于 0 表示跳转，越界按结束处理。
@export var next_line: int = DialogueLine.STOP
## 选中后立刻结算的好感度变化（可正可负，0 表示不变）。
@export var affection_delta: int = 0
## 选中后写入的剧情旗标；留空表示不写。
@export var set_flag: StringName = &""
## 仅当玩家拥有该旗标时该选项才出现；留空表示始终可见。
@export var required_flag: StringName = &""


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if text_key == &"":
		problems.append("选项缺少 text_key")
	return problems


func _to_string() -> String:
	return "DialogueChoice(%s → %d)" % [text_key, next_line]
