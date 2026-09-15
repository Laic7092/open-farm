extends "res://tools/sample/sample_base.gd"
## dialogues：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var merchant := DialogueData.new()
	merchant.id = &"merchant_greeting"
	merchant.speaker_key = &"NPC_MERCHANT"
	merchant.lines = [
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_GREETING"),
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_WEATHER"),
		_line(&"NPC_MERCHANT", &"DIALOGUE_MERCHANT_CLOSING"),
	] as Array[DialogueLine]
	_save(merchant, DIALOGUE_DIR.path_join("merchant_greeting.tres"))

	var mayor := DialogueData.new()
	mayor.id = &"mayor_greeting"
	mayor.speaker_key = &"NPC_MAYOR"
	mayor.lines = [
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_GREETING"),
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_TIP"),
		_line(&"NPC_MAYOR", &"DIALOGUE_MAYOR_SEASON"),
	] as Array[DialogueLine]
	_save(mayor, DIALOGUE_DIR.path_join("mayor_greeting.tres"))

	_add_dialogue(&"blacksmith_greeting", &"NPC_BLACKSMITH", [
		&"DIALOGUE_BLACKSMITH_GREETING",
		&"DIALOGUE_BLACKSMITH_TIP",
		&"DIALOGUE_BLACKSMITH_SEASON",
	])
	_add_dialogue(&"florist_greeting", &"NPC_FLORIST", [
		&"DIALOGUE_FLORIST_GREETING",
		&"DIALOGUE_FLORIST_TIP",
		&"DIALOGUE_FLORIST_CLOSING",
	])
	_add_dialogue(&"fisher_greeting", &"NPC_FISHER", [
		&"DIALOGUE_FISHER_GREETING",
		&"DIALOGUE_FISHER_TIP",
		&"DIALOGUE_FISHER_SEASON",
	])
	_add_dialogue(&"miner_greeting", &"NPC_MINER", [
		&"DIALOGUE_MINER_GREETING",
		&"DIALOGUE_MINER_TIP",
		&"DIALOGUE_MINER_SEASON",
	])
	_add_dialogue(&"child_greeting", &"NPC_CHILD", [
		&"DIALOGUE_CHILD_GREETING",
		&"DIALOGUE_CHILD_PLAY",
		&"DIALOGUE_CHILD_TIP",
	])
	_add_dialogue(&"librarian_greeting", &"NPC_LIBRARIAN", [
		&"DIALOGUE_LIBRARIAN_GREETING",
		&"DIALOGUE_LIBRARIAN_TIP",
		&"DIALOGUE_LIBRARIAN_SEASON",
	])

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

	# 孩子出生后才出现，跟随父母住在家门口。
	_add_dialogue(&"our_child_greeting", &"NPC_OUR_CHILD", [&"DIALOGUE_OUR_CHILD_GREETING"])

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
