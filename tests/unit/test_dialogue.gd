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

func test_sample_merchant_greeting_is_branching() -> void:
	var dialogue := Database.get_dialogue(&"merchant_greeting")
	assert_object(dialogue).is_not_null()
	if dialogue == null:
		return
	assert_bool(dialogue.lines[0].has_choices()).is_true()
	for choice: DialogueChoice in dialogue.lines[0].choices:
		assert_int(DialogueRules.choice_target(choice, dialogue.line_count())).is_greater_equal(0)


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

func test_npc_applies_choice_effects_only_for_its_own_dialogue() -> void:
	var profile := PlayerProfile.new()
	var service := RelationshipService.new()
	service.set_state(RelationshipStore.new())

	var npc: Npc = auto_free(
		load("res://scenes/npc/npc.tscn").instantiate()
	) as Npc
	npc.npc_id = &"blacksmith"
	npc.bind_dependencies(profile, null)
	npc.bind_services(null, service, null)
	add_child(npc)

	var dialogue := Database.get_dialogue(&"blacksmith_greeting")
	npc.set(&"_active_dialogue", dialogue)
	var choice := DialogueRules.available_choices(dialogue.lines[0], null)[0]
	EventBus.ui.dialogue_choice_made.emit(dialogue, choice)
	assert_int(service.affection(&"blacksmith")).is_equal(choice.affection_delta)

	# 别人的对话不应被本 NPC 结算。
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
