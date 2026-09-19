extends GdUnitTestSuite
## 对话系统测试：跳转规则、选项过滤与数据自检。
##
## 跳转判断全在纯静态的 [DialogueRules] 里，因此这里无需场景树即可逐条断言；
## 末尾再用真实生成的 .tres 验证"示例数据确实是分支的"。


# ---------------------------------------------------------------- 顺序推进

func test_sequential_line_advances_by_one() -> void:
	var line := DialogueLine.new()
	line.text_key = &"A"
	assert_int(DialogueRules.next_sequential(line, 0, 3)).is_equal(1)


func test_last_line_without_override_ends() -> void:
	var line := DialogueLine.new()
	line.text_key = &"A"
	assert_int(DialogueRules.next_sequential(line, 2, 3)).is_equal(DialogueRules.END)


func test_explicit_stop_ends_even_in_the_middle() -> void:
	var line := DialogueLine.new()
	line.text_key = &"A"
	line.next_line = DialogueLine.STOP
	assert_int(DialogueRules.next_sequential(line, 0, 3)).is_equal(DialogueRules.END)


func test_explicit_jump_is_honored() -> void:
	var line := DialogueLine.new()
	line.text_key = &"A"
	line.next_line = 2
	assert_int(DialogueRules.next_sequential(line, 0, 3)).is_equal(2)


func test_out_of_range_jump_ends() -> void:
	var line := DialogueLine.new()
	line.text_key = &"A"
	line.next_line = 99
	assert_int(DialogueRules.next_sequential(line, 0, 3)).is_equal(DialogueRules.END)


func test_null_line_and_bad_index_end() -> void:
	assert_int(DialogueRules.next_sequential(null, 0, 3)).is_equal(DialogueRules.END)
	var line := DialogueLine.new()
	assert_int(DialogueRules.next_sequential(line, -1, 3)).is_equal(DialogueRules.END)
	assert_int(DialogueRules.next_sequential(line, 3, 3)).is_equal(DialogueRules.END)


# ---------------------------------------------------------------- 选项

func test_choice_target_resolution() -> void:
	var choice := DialogueChoice.new()
	choice.next_line = 1
	assert_int(DialogueRules.choice_target(choice, 3)).is_equal(1)
	choice.next_line = DialogueLine.STOP
	assert_int(DialogueRules.choice_target(choice, 3)).is_equal(DialogueRules.END)
	choice.next_line = 99
	assert_int(DialogueRules.choice_target(choice, 3)).is_equal(DialogueRules.END)
	choice.next_line = 1
	assert_int(DialogueRules.choice_target(null, 3)).is_equal(DialogueRules.END)


func test_available_choices_filters_by_required_flag() -> void:
	var profile := PlayerProfile.new()
	var open := DialogueChoice.new()
	open.text_key = &"OPEN"
	var locked := DialogueChoice.new()
	locked.text_key = &"LOCKED"
	locked.required_flag = &"child_born"
	var line := DialogueLine.new()
	line.text_key = &"A"
	line.choices = [open, locked] as Array[DialogueChoice]

	assert_int(DialogueRules.available_choices(line, profile).size()).is_equal(1)
	profile.set_flag(&"child_born")
	assert_int(DialogueRules.available_choices(line, profile).size()).is_equal(2)
	# 没有玩家档案时，条件选项不应被误判为可见。
	assert_int(DialogueRules.available_choices(line, null).size()).is_equal(1)


# ---------------------------------------------------------------- 数据自检

func test_valid_branching_dialogue_passes_validation() -> void:
	var dialogue := _branching_dialogue()
	assert_array(dialogue.validate()).is_empty()


func test_choice_missing_text_is_reported() -> void:
	var dialogue := _branching_dialogue()
	dialogue.lines[0].choices[0].text_key = &""
	assert_array(dialogue.validate()).is_not_empty()


func test_choice_without_explicit_target_is_reported() -> void:
	var dialogue := _branching_dialogue()
	dialogue.lines[0].choices[0].next_line = DialogueLine.NEXT_SEQUENTIAL
	assert_array(dialogue.validate()).is_not_empty()


func test_choice_target_out_of_range_is_reported() -> void:
	var dialogue := _branching_dialogue()
	dialogue.lines[0].choices[0].next_line = 99
	assert_array(dialogue.validate()).is_not_empty()


func test_sequential_line_still_valid() -> void:
	var dialogue := DialogueData.new()
	dialogue.id = &"plain"
	dialogue.lines = [_line(&"A"), _line(&"B")] as Array[DialogueLine]
	assert_array(dialogue.validate()).is_empty()


# ---------------------------------------------------------------- 示例数据

## 每位村民的开场都应当是分支的（示例内容的验收）。
func test_every_sample_greeting_is_branching() -> void:
	for dialogue_id: StringName in [
		&"merchant_greeting", &"mayor_greeting", &"blacksmith_greeting",
		&"florist_greeting", &"fisher_greeting", &"miner_greeting",
		&"child_greeting", &"librarian_greeting", &"our_child_greeting",
	]:
		var dialogue := Database.get_dialogue(dialogue_id)
		assert_object(dialogue).override_failure_message(
			"缺少对白 %s" % dialogue_id
		).is_not_null()
		if dialogue == null:
			continue
		assert_bool(dialogue.lines[0].has_choices()).override_failure_message(
			"%s 的开场没有分支" % dialogue_id
		).is_true()
		for choice: DialogueChoice in dialogue.lines[0].choices:
			assert_int(
				DialogueRules.choice_target(choice, dialogue.line_count())
			).override_failure_message(
				"%s 的选项 %s 跳转越界" % [dialogue_id, choice.text_key]
			).is_greater_equal(0)


## 所有生成出来的对白都要通过自检：跳转不越界、选项都有目标。
func test_every_sample_dialogue_validates() -> void:
	var problems := PackedStringArray()
	for dialogue_id: StringName in Database.dialogues():
		var dialogue := Database.get_dialogue(dialogue_id)
		for problem: String in dialogue.validate():
			problems.append("%s：%s" % [dialogue_id, problem])
	assert_array(problems).override_failure_message(
		"有 %d 条对白没通过自检：%s" % [problems.size(), ", ".join(problems)]
	).is_empty()


## 每位村民（自家孩子除外）都要有夏 / 秋 / 冬三份专属问候，且开局就是分支。
##
## 春季沿用 [member NpcData.default_dialogue]，所以这里只检查另外三季确实是覆盖值。
func test_every_villager_has_seasonal_greetings() -> void:
	for npc_id: StringName in [
		&"merchant", &"mayor", &"blacksmith", &"florist",
		&"fisher", &"miner", &"child", &"librarian",
	]:
		var npc := Database.get_npc(npc_id)
		assert_object(npc).override_failure_message("缺少 NPC %s" % npc_id).is_not_null()
		if npc == null:
			continue
		for season: Season.Type in [
			Season.Type.SUMMER, Season.Type.FALL, Season.Type.WINTER
		]:
			var dialogue := npc.dialogue_for_season(season)
			assert_object(dialogue).override_failure_message(
				"%s 缺少 %s 的季节对白" % [npc_id, Season.to_key(season)]
			).is_not_null()
			if dialogue == null:
				continue
			assert_str(String(dialogue.id)).override_failure_message(
				"%s 的 %s 对白没有覆盖默认问候" % [npc_id, Season.to_key(season)]
			).is_not_equal(String(npc.default_dialogue.id))
			assert_bool(dialogue.lines[0].has_choices()).override_failure_message(
				"%s 的季节问候 %s 没有分支" % [npc_id, dialogue.id]
			).is_true()


## 语言无关：季节对白应当按季节换到不同的资源，而不是四季同一份。
func test_seasonal_dialogues_are_not_shared_between_seasons() -> void:
	for npc_id: StringName in Database.npcs():
		var npc := Database.get_npc(npc_id)
		if npc.seasonal_dialogue.is_empty():
			continue
		var seen: Dictionary[StringName, bool] = {}
		for season: Season.Type in Season.all():
			var dialogue := npc.dialogue_for_season(season)
			assert_bool(seen.has(dialogue.id)).override_failure_message(
				"%s 的 %s 与上一季共用同一份对白 %s"
				% [npc_id, Season.to_key(season), dialogue.id]
			).is_false()
			seen[dialogue.id] = true


## 书雅问矿洞的选项受矿工写下的旗标门控。
func test_librarian_cave_choice_is_gated_by_miner_rumor() -> void:
	var dialogue := Database.get_dialogue(&"librarian_greeting")
	assert_object(dialogue).is_not_null()
	if dialogue == null:
		return
	var profile := PlayerProfile.new()
	var before := DialogueRules.available_choices(dialogue.lines[0], profile).size()
	profile.set_flag(&"heard_cave_rumor")
	var after := DialogueRules.available_choices(dialogue.lines[0], profile).size()
	assert_int(after).override_failure_message(
		"听过矿洞传闻后，书雅应该多出一个选项"
	).is_equal(before + 1)


## 选项的 [member DialogueChoice.set_flag] 必须真的被某个 NPC 写下来。
##
## 允许一份“外部旗标”白名单（关系 / 节日等系统写的），否则对话里引用它们会被误报。
func test_required_flags_are_produced_somewhere() -> void:
	var external_flags: Array[StringName] = [&"child_born"]
	var produced: Dictionary[StringName, bool] = {}
	var required: Dictionary[StringName, StringName] = {}
	for dialogue_id: StringName in Database.dialogues():
		var dialogue := Database.get_dialogue(dialogue_id)
		for line: DialogueLine in dialogue.lines:
			for choice: DialogueChoice in line.choices:
				if choice.set_flag != &"":
					produced[choice.set_flag] = true
				if choice.required_flag != &"" and not external_flags.has(choice.required_flag):
					required[choice.required_flag] = dialogue_id
	for flag: StringName in required:
		assert_bool(produced.has(flag)).override_failure_message(
			"对白 %s 的选项要求旗标 %s，但没有任何选项会写下它（条件永远不成立）"
			% [required[flag], flag]
		).is_true()


func test_sample_blacksmith_flirt_raises_affection() -> void:
	var dialogue := Database.get_dialogue(&"blacksmith_greeting")
	assert_object(dialogue).is_not_null()
	if dialogue == null:
		return
	var choices := DialogueRules.available_choices(dialogue.lines[0], null)
	assert_int(choices.size()).is_equal(2)
	assert_int(choices[0].affection_delta).is_greater(0)


# ---------------------------------------------------------------- 界面接线

func test_dialogue_box_branch_reaches_target_and_finishes() -> void:
	var box: DialogueBox = auto_free(
		load("res://scenes/ui/dialogue_box.tscn").instantiate()
	) as DialogueBox
	add_child(box)
	box.open(_branching_dialogue())
	assert_int(box.current_line_index()).is_equal(0)

	box.advance()  # 跳过打字，弹出选项
	assert_bool(box.is_awaiting_choice()).is_true()
	box.choose(0)  # YES → 第 1 句
	assert_int(box.current_line_index()).is_equal(1)

	box.advance()  # 跳过第 1 句打字
	box.advance()  # 最后一句 → 结束
	assert_int(box.current_line_index()).is_equal(-1)
	assert_bool(box.visible).is_false()


func test_dialogue_box_stop_choice_closes_immediately() -> void:
	var box: DialogueBox = auto_free(
		load("res://scenes/ui/dialogue_box.tscn").instantiate()
	) as DialogueBox
	add_child(box)
	box.open(_branching_dialogue())
	box.advance()
	box.choose(1)  # NO → STOP
	assert_int(box.current_line_index()).is_equal(-1)
	assert_bool(box.visible).is_false()


# ---------------------------------------------------------------- 副作用

## NPC 不再自己订阅全局信号：这类连接全部收口在本图协作根。
func test_npc_does_not_subscribe_to_global_signals() -> void:
	var service := RelationshipService.new()
	service.set_state(RelationshipStore.new())
	var npc: Npc = auto_free(
		load("res://scenes/npc/npc.tscn").instantiate()
	) as Npc
	npc.npc_id = &"blacksmith"
	npc.bind_dependencies(PlayerProfile.new(), null)
	npc.bind_services(null, service, null)
	add_child(npc)

	var watched: Array[Signal] = [
		EventBus.minute_changed,
		EventBus.day_changed,
		EventBus.player.npc_affection_changed,
		EventBus.player.child_born,
		EventBus.ui.dialogue_finished,
		EventBus.ui.dialogue_choice_made,
	]
	for signal_ref: Signal in watched:
		for connection: Dictionary in signal_ref.get_connections():
			var callable: Callable = connection.get("callable")
			assert_bool(callable.get_object() == npc).override_failure_message(
				"NPC 不应订阅全局信号"
			).is_false()

	remove_child(npc)
	service.free()


## 选项副作用只结算给发起这一段对白的人。
func test_field_routes_choice_effects_only_to_the_speaker() -> void:
	var profile := PlayerProfile.new()
	var service := RelationshipService.new()
	service.set_state(RelationshipStore.new())

	var field: NpcField = auto_free(NpcField.new()) as NpcField
	add_child(field)
	var npc: Npc = auto_free(
		load("res://scenes/npc/npc.tscn").instantiate()
	) as Npc
	npc.npc_id = &"blacksmith"
	npc.bind_dependencies(profile, null)
	npc.bind_services(null, service, null)
	npc.bind_npc_field(field)
	add_child(npc)

	var dialogue := Database.get_dialogue(&"blacksmith_greeting")
	field.open_dialogue(npc, dialogue)
	var choice := DialogueRules.available_choices(dialogue.lines[0], null)[0]
	EventBus.ui.dialogue_choice_made.emit(dialogue, choice)
	assert_int(service.affection(&"blacksmith")).is_equal(choice.affection_delta)

	# 不是当前这段对白，无论内容如何都不结算。
	var other := Database.get_dialogue(&"merchant_greeting")
	EventBus.ui.dialogue_choice_made.emit(other, other.lines[0].choices[0])
	assert_int(service.affection(&"blacksmith")).is_equal(choice.affection_delta)

	remove_child(npc)
	service.free()


# ---------------------------------------------------------------- 工具

func _line(text_key: StringName) -> DialogueLine:
	var line := DialogueLine.new()
	line.text_key = text_key
	return line


func _branching_dialogue() -> DialogueData:
	var dialogue := DialogueData.new()
	dialogue.id = &"branch_test"
	var greeting := _line(&"GREETING")
	var yes := DialogueChoice.new()
	yes.text_key = &"YES"
	yes.next_line = 1
	var no := DialogueChoice.new()
	no.text_key = &"NO"
	no.next_line = DialogueLine.STOP
	greeting.choices = [yes, no] as Array[DialogueChoice]
	dialogue.lines = [greeting, _line(&"REPLY")] as Array[DialogueLine]
	return dialogue
