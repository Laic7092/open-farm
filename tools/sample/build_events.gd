extends "res://tools/sample/sample_base.gd"
## events：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

## 五个一次性事件：日结转时按条件判定，触发后打旗标 / 给钱 / 播对白。
func build() -> void:
	_event(
		&"traveler_visit", &"EVENT_TRAVELER_VISIT", &"EVENT_TRAVELER_VISIT",
		-1, 8, -1, 150
	)
	_event(
		&"mayor_subsidy", &"EVENT_MAYOR_SUBSIDY", &"EVENT_MAYOR_SUBSIDY",
		int(Season.Type.SUMMER), 1, -1, 300
	)
	_event(
		&"harvest_blessing", &"EVENT_HARVEST_BLESSING", &"EVENT_HARVEST_BLESSING",
		int(Season.Type.FALL), 28, -1, 200, &"", 0, &"harvest_blessed"
	)
	_event(
		&"first_snow", &"EVENT_FIRST_SNOW", &"EVENT_FIRST_SNOW",
		int(Season.Type.WINTER), 1, -1, 0, &"", 0, &"winter_seen"
	)
	# 好感事件：任意一天都行，但要先和书雅混熟。
	_event(
		&"librarian_visit", &"EVENT_LIBRARIAN_VISIT", &"EVENT_LIBRARIAN_VISIT",
		-1, -1, -1, 0, &"librarian", 120, &"", "librarian_visit"
	)

	# 好感度心事件：每位可攻略 NPC 在 2 心 / 4 心各有一段；第二段接第一段的旗标。
	for entry: Array in [
		[&"librarian", &"LIBRARIAN"],
		[&"florist", &"FLORIST"],
		[&"fisher", &"FISHER"],
		[&"blacksmith", &"BLACKSMITH"],
	]:
		_heart_events(entry[0], entry[1])


## 为一位 NPC 生成两段心事件：门槛分别是 2 心（100）与 4 心（200）。
##
## 第二段用 required_flag 接住第一段的 set_flag，于是好感够了也会按顺序推进，
## 不会跳过铺垫直接看到后面的剧情（与对白里的旗标链同一套约定）。
func _heart_events(npc_id: StringName, upper: StringName) -> void:
	for stage: int in [1, 2]:
		var event_id := StringName("%s_heart_%d" % [npc_id, stage])
		var flag := StringName("%s_heart_%d" % [npc_id, stage])
		var title := StringName("EVENT_%s_HEART_%d" % [upper, stage])
		_event(
			event_id, title, title, -1, -1, -1, 0,
			npc_id, 100 * stage, flag,
			"%s_heart_%d" % [npc_id, stage], true,
			StringName("%s_heart_%d" % [npc_id, stage - 1]) if stage > 1 else &"",
			_npc_dialogue_dir(npc_id)
		)


func _event(
	event_id: StringName, title_key: StringName, message_key: StringName,
	season: int, day: int, weather: int, grant_money: int,
	required_npc: StringName = &"", required_affection: int = 0,
	set_flag: StringName = &"", dialogue_id: String = "", once: bool = true,
	required_flag: StringName = &"", dialogue_dir: String = ""
) -> void:
	var event := EventData.new()
	event.id = event_id
	event.title_key = title_key
	event.message_key = message_key
	event.season = season
	event.day = day
	event.weather = weather
	event.required_npc = required_npc
	event.required_affection = required_affection
	event.required_flag = required_flag
	event.grant_money = grant_money
	event.set_flag = set_flag
	event.once = once
	if not dialogue_id.is_empty():
		var base_dir: String = dialogue_dir if not dialogue_dir.is_empty() else SHARED_DIALOGUE_DIR
		event.dialogue = _load(base_dir.path_join("%s.tres" % dialogue_id)) as DialogueData
	_save(event, EVENT_DIR.path_join("%s.tres" % event_id))
