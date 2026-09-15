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


func _event(
	event_id: StringName, title_key: StringName, message_key: StringName,
	season: int, day: int, weather: int, grant_money: int,
	required_npc: StringName = &"", required_affection: int = 0,
	set_flag: StringName = &"", dialogue_id: String = "", once: bool = true
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
	event.grant_money = grant_money
	event.set_flag = set_flag
	event.once = once
	if not dialogue_id.is_empty():
		event.dialogue = _load(DIALOGUE_DIR.path_join("%s.tres" % dialogue_id)) as DialogueData
	_save(event, EVENT_DIR.path_join("%s.tres" % event_id))
