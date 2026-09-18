extends "res://tools/sample/sample_base.gd"
## dialogues：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 带分支的日常问候用 [method _authored] 描述：先用标签（[code]id[/code] / [code]next[/code]）
## 写清跳转，再统一映射成行号。这样调整行序 / 插行不会把跳转接错，也比手写索引好审。
## 只有顺序播放的恋爱与节日对白继续用 [method _add_dialogue]。


func build() -> void:
	_build_greetings()
	_build_romance()
	_build_festivals()


# ---------------------------------------------------------------- 日常问候（带分支）

func _build_greetings() -> void:
	# 商人：选项 → 分支 → 汇合（最早的分支示例）。
	_save_authored(&"merchant_greeting", &"NPC_MERCHANT", [
		{"key": &"DIALOGUE_MERCHANT_GREETING", "choices": [
			{"key": &"DIALOGUE_MERCHANT_CHOICE_BUY", "next": &"BUY"},
			{"key": &"DIALOGUE_MERCHANT_CHOICE_BROWSE", "next": &"BROWSE"},
		]},
		{"id": &"BUY", "key": &"DIALOGUE_MERCHANT_BUY_REPLY", "next": &"CLOSING"},
		{"id": &"BROWSE", "key": &"DIALOGUE_MERCHANT_WEATHER", "next": &"CLOSING"},
		{"id": &"CLOSING", "key": &"DIALOGUE_MERCHANT_CLOSING", "next": &"stop"},
	])

	# 村长：问农事给一点好感，问近况埋下"矿洞"旗标（铁匠 / 矿工 / 书雅会引用）。
	_save_authored(&"mayor_greeting", &"NPC_MAYOR", [
		{"key": &"DIALOGUE_MAYOR_GREETING", "choices": [
			{"key": &"DIALOGUE_MAYOR_CHOICE_ADVICE", "next": &"TIP", "affection": 1},
			{"key": &"DIALOGUE_MAYOR_CHOICE_NEWS", "next": &"NEWS", "set_flag": &"heard_village_news"},
		]},
		{"id": &"TIP", "key": &"DIALOGUE_MAYOR_TIP", "next": &"SEASON"},
		{"id": &"NEWS", "key": &"DIALOGUE_MAYOR_NEWS_REPLY", "emotion": DialogueLine.Emotion.SURPRISED, "next": &"SEASON"},
		{"id": &"SEASON", "key": &"DIALOGUE_MAYOR_SEASON", "next": &"stop"},
	])

	# 铁匠：夸他会 +2 好感，两条支线最后都回到提示 → 季节（情绪染色示例）。
	_save_authored(&"blacksmith_greeting", &"NPC_BLACKSMITH", [
		{"key": &"DIALOGUE_BLACKSMITH_GREETING", "choices": [
			{"key": &"DIALOGUE_BLACKSMITH_CHOICE_FLIRT", "next": &"FLIRT", "affection": 2},
			{"key": &"DIALOGUE_BLACKSMITH_CHOICE_WORK", "next": &"WORK"},
		]},
		{"id": &"FLIRT", "key": &"DIALOGUE_BLACKSMITH_FLIRT_REPLY", "emotion": DialogueLine.Emotion.HAPPY, "next": &"TIP"},
		{"id": &"WORK", "key": &"DIALOGUE_BLACKSMITH_WORK_REPLY", "next": &"TIP"},
		{"id": &"TIP", "key": &"DIALOGUE_BLACKSMITH_TIP", "next": &"SEASON"},
		{"id": &"SEASON", "key": &"DIALOGUE_BLACKSMITH_SEASON", "next": &"stop"},
	])

	_save_authored(&"florist_greeting", &"NPC_FLORIST", [
		{"key": &"DIALOGUE_FLORIST_GREETING", "choices": [
			{"key": &"DIALOGUE_FLORIST_CHOICE_PRAISE", "next": &"PRAISE", "affection": 2},
			{"key": &"DIALOGUE_FLORIST_CHOICE_KINDS", "next": &"KINDS"},
		]},
		{"id": &"PRAISE", "key": &"DIALOGUE_FLORIST_PRAISE_REPLY", "emotion": DialogueLine.Emotion.HAPPY, "next": &"CLOSING"},
		{"id": &"KINDS", "key": &"DIALOGUE_FLORIST_KINDS_REPLY", "next": &"CLOSING"},
		{"id": &"CLOSING", "key": &"DIALOGUE_FLORIST_CLOSING", "next": &"stop"},
	])

	_save_authored(&"fisher_greeting", &"NPC_FISHER", [
		{"key": &"DIALOGUE_FISHER_GREETING", "choices": [
			{"key": &"DIALOGUE_FISHER_CHOICE_CATCH", "next": &"CATCH"},
			{"key": &"DIALOGUE_FISHER_CHOICE_STORY", "next": &"STORY"},
		]},
		{"id": &"CATCH", "key": &"DIALOGUE_FISHER_CATCH_REPLY", "next": &"SEASON"},
		{"id": &"STORY", "key": &"DIALOGUE_FISHER_STORY_REPLY", "emotion": DialogueLine.Emotion.SURPRISED, "next": &"SEASON"},
		{"id": &"SEASON", "key": &"DIALOGUE_FISHER_SEASON", "next": &"stop"},
	])

	# 矿工：问深处会写下"听到矿洞传闻"旗标，书雅那边的隐藏选项才出现。
	_save_authored(&"miner_greeting", &"NPC_MINER", [
		{"key": &"DIALOGUE_MINER_GREETING", "choices": [
			{"key": &"DIALOGUE_MINER_CHOICE_CAVE", "next": &"CAVE", "set_flag": &"heard_cave_rumor"},
			{"key": &"DIALOGUE_MINER_CHOICE_SMALLTALK", "next": &"TIP"},
		]},
		{"id": &"CAVE", "key": &"DIALOGUE_MINER_CAVE_REPLY", "emotion": DialogueLine.Emotion.SURPRISED, "next": &"SEASON"},
		{"id": &"TIP", "key": &"DIALOGUE_MINER_TIP", "next": &"SEASON"},
		{"id": &"SEASON", "key": &"DIALOGUE_MINER_SEASON", "next": &"stop"},
	])

	_save_authored(&"child_greeting", &"NPC_CHILD", [
		{"key": &"DIALOGUE_CHILD_GREETING", "choices": [
			{"key": &"DIALOGUE_CHILD_CHOICE_PLAY", "next": &"PLAY", "affection": 1},
			{"key": &"DIALOGUE_CHILD_CHOICE_TIP", "next": &"TIP"},
		]},
		{"id": &"PLAY", "key": &"DIALOGUE_CHILD_PLAY", "emotion": DialogueLine.Emotion.HAPPY, "next": &"stop"},
		{"id": &"TIP", "key": &"DIALOGUE_CHILD_TIP", "next": &"stop"},
	])

	# 书雅：第三个选项带 required_flag，只有从矿工那儿听过传闻才会出现，选中后写下新旗标。
	_save_authored(&"librarian_greeting", &"NPC_LIBRARIAN", [
		{"key": &"DIALOGUE_LIBRARIAN_GREETING", "choices": [
			{"key": &"DIALOGUE_LIBRARIAN_CHOICE_BOOK", "next": &"SEASON", "affection": 1},
			{"key": &"DIALOGUE_LIBRARIAN_CHOICE_CAVE", "next": &"CAVE", "required_flag": &"heard_cave_rumor", "set_flag": &"knows_cave_map"},
			{"key": &"DIALOGUE_LIBRARIAN_CHOICE_BROWSE", "next": &"TIP"},
		]},
		{"id": &"SEASON", "key": &"DIALOGUE_LIBRARIAN_SEASON", "next": &"stop"},
		{"id": &"CAVE", "key": &"DIALOGUE_LIBRARIAN_CAVE_REPLY", "emotion": DialogueLine.Emotion.HAPPY, "next": &"stop"},
		{"id": &"TIP", "key": &"DIALOGUE_LIBRARIAN_TIP", "next": &"stop"},
	])

	_save_authored(&"our_child_greeting", &"NPC_OUR_CHILD", [
		{"key": &"DIALOGUE_OUR_CHILD_GREETING", "next": &"stop"},
	])


# ---------------------------------------------------------------- 恋爱 / 婚姻

func _build_romance() -> void:
	# 恋爱 / 婚姻对白：每位可攻略 NPC 五段（朋友 / 恋人 / 婚后 / 表白 / 求婚）。
	for entry: Array in [
		[&"librarian", &"NPC_LIBRARIAN"],
		[&"florist", &"NPC_FLORIST"],
		[&"fisher", &"NPC_FISHER"],
		[&"blacksmith", &"NPC_BLACKSMITH"],
	]:
		var prefix: StringName = entry[0]
		var speaker: StringName = entry[1]
		var upper := String(prefix).to_upper()
		_add_dialogue(
			StringName("%s_friend" % prefix), speaker,
			[StringName("DIALOGUE_%s_FRIEND" % upper)]
		)
		_add_dialogue(
			StringName("%s_lover" % prefix), speaker,
			[StringName("DIALOGUE_%s_LOVER" % upper)]
		)
		_add_dialogue(
			StringName("%s_married" % prefix), speaker,
			[StringName("DIALOGUE_%s_MARRIED" % upper)]
		)
		_add_dialogue(
			StringName("%s_confession" % prefix), speaker,
			[
				StringName("DIALOGUE_%s_CONFESSION_1" % upper),
				StringName("DIALOGUE_%s_CONFESSION_2" % upper),
			]
		)
		_add_dialogue(
			StringName("%s_proposal" % prefix), speaker,
			[
				StringName("DIALOGUE_%s_PROPOSAL_1" % upper),
				StringName("DIALOGUE_%s_PROPOSAL_2" % upper),
			]
		)


# ---------------------------------------------------------------- 节日

func _build_festivals() -> void:
	# 节日开场对白：第一次进会场时播放。
	_add_dialogue(&"festival_new_year", &"NPC_MAYOR", [
		&"DIALOGUE_FESTIVAL_NEW_YEAR_1", &"DIALOGUE_FESTIVAL_NEW_YEAR_2",
	])
	_add_dialogue(&"festival_flower", &"NPC_FLORIST", [
		&"DIALOGUE_FESTIVAL_FLOWER_1", &"DIALOGUE_FESTIVAL_FLOWER_2",
	])
	_add_dialogue(&"festival_fireworks", &"NPC_CHILD", [
		&"DIALOGUE_FESTIVAL_FIREWORKS_1", &"DIALOGUE_FESTIVAL_FIREWORKS_2",
	])
	_add_dialogue(&"festival_harvest", &"NPC_MERCHANT", [
		&"DIALOGUE_FESTIVAL_HARVEST_1", &"DIALOGUE_FESTIVAL_HARVEST_2",
	])
	_add_dialogue(&"festival_starry_night", &"NPC_LIBRARIAN", [
		&"DIALOGUE_FESTIVAL_STARRY_1", &"DIALOGUE_FESTIVAL_STARRY_2",
	])
	_add_dialogue(&"librarian_visit", &"NPC_LIBRARIAN", [&"EVENT_LIBRARIAN_VISIT"])


# ---------------------------------------------------------------- 作者友好构造器

## 用标签描述一段带分支的对白并保存（见文件头说明）。
##
## [param spec] 是行数组，每行支持这些键：
## [br]- [code]key[/code]：正文翻译键（必填）
## [br]- [code]id[/code]：本行标签，供 [code]next[/code] / 选项引用
## [br]- [code]speaker[/code]：覆盖说话人（默认用段落 speaker_key）
## [br]- [code]emotion[/code]：[enum DialogueLine.Emotion]
## [br]- [code]next[/code]：下一行标签；[code]&"stop"[/code] 结束，省略则顺序播放
## [br]- [code]choices[/code]：选项数组，每项支持
##   [code]key[/code] / [code]next[/code] / [code]affection[/code] /
##   [code]set_flag[/code] / [code]required_flag[/code]
func _save_authored(dialogue_id: StringName, speaker_key: StringName, spec: Array) -> void:
	var index_of: Dictionary[StringName, int] = {}
	for index: int in spec.size():
		var label: StringName = spec[index].get("id", &"")
		if label != &"":
			index_of[label] = index

	var dialogue := DialogueData.new()
	dialogue.id = dialogue_id
	dialogue.speaker_key = speaker_key
	var lines: Array[DialogueLine] = []
	for index: int in spec.size():
		lines.append(_authored_line(spec[index], index_of, dialogue_id))
	dialogue.lines = lines
	_save(dialogue, DIALOGUE_DIR.path_join("%s.tres" % dialogue_id))


## 建一行（含它的选项）；标签解析失败时用 push_error 报出来，并退化成"结束"保证生成不中断。
func _authored_line(entry: Dictionary, index_of: Dictionary, context: StringName) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_key = entry.get("speaker", &"")
	line.text_key = entry["key"]
	line.emotion = entry.get("emotion", DialogueLine.Emotion.NEUTRAL)

	line.next_line = DialogueLine.NEXT_SEQUENTIAL
	var next_label: StringName = entry.get("next", &"")
	if next_label != &"":
		line.next_line = _label_index(next_label, index_of, context)

	var choices: Array[DialogueChoice] = []
	for choice_spec: Dictionary in entry.get("choices", []):
		var choice := DialogueChoice.new()
		choice.text_key = choice_spec["key"]
		choice.next_line = _choice_target(choice_spec, index_of, context)
		choice.affection_delta = choice_spec.get("affection", 0)
		choice.set_flag = choice_spec.get("set_flag", &"")
		choice.required_flag = choice_spec.get("required_flag", &"")
		choices.append(choice)
	line.choices = choices
	return line


func _choice_target(choice_spec: Dictionary, index_of: Dictionary, context: StringName) -> int:
	var label: StringName = choice_spec.get("next", &"")
	if label == &"":
		push_error("%s：选项 %s 缺少跳转目标" % [context, choice_spec.get("key", &"")])
		return DialogueLine.STOP
	return _label_index(label, index_of, context)


func _label_index(label: StringName, index_of: Dictionary, context: StringName) -> int:
	if label == &"stop":
		return DialogueLine.STOP
	if index_of.has(label):
		return index_of[label]
	push_error("%s：对白标签 %s 不存在" % [context, label])
	return DialogueLine.STOP


# ---------------------------------------------------------------- 顺序对白

## 批量建一段"每句一个翻译键"的对白并保存。
func _add_dialogue(
	dialogue_id: StringName, speaker_key: StringName, text_keys: Array
) -> void:
	var dialogue := DialogueData.new()
	dialogue.id = dialogue_id
	dialogue.speaker_key = speaker_key
	var lines: Array[DialogueLine] = []
	for text_key: StringName in text_keys:
		lines.append(_line(speaker_key, text_key))
	dialogue.lines = lines
	_save(dialogue, DIALOGUE_DIR.path_join("%s.tres" % dialogue_id))


func _line(speaker_key: StringName, text_key: StringName) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_key = speaker_key
	line.text_key = text_key
	return line
