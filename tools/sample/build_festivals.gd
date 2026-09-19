extends "res://tools/sample/sample_base.gd"
## festivals：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

## 五个节日：每个季节一场，村民按 [member FestivalData.npc_ids] 到会场集合。
func build() -> void:
	_festival(
		&"new_year", &"FESTIVAL_NEW_YEAR", Season.Type.SPRING, 1, 8, 17,
		&"plaza", [&"mayor", &"merchant", &"blacksmith", &"florist", &"child"],
		4, "festival_new_year"
	)
	_festival(
		&"flower_festival", &"FESTIVAL_FLOWER", Season.Type.SPRING, 14, 9, 16,
		&"garden", [&"florist", &"child", &"mayor"],
		4, "festival_flower", &"flower_festival_joined", &"flower_exhibit"
	)
	_festival(
		&"fireworks", &"FESTIVAL_FIREWORKS", Season.Type.SUMMER, 24, 18, 23,
		&"plaza", [&"mayor", &"merchant", &"blacksmith", &"florist", &"child", &"librarian"],
		5, "festival_fireworks", &"", &"fishing_derby"
	)
	_festival(
		&"harvest_festival", &"FESTIVAL_HARVEST", Season.Type.FALL, 15, 9, 17,
		&"plaza", [&"mayor", &"merchant", &"blacksmith", &"florist", &"child"],
		5, "festival_harvest", &"harvest_festival_joined", &"harvest_contest"
	)
	_festival(
		&"starry_night", &"FESTIVAL_STARRY_NIGHT", Season.Type.WINTER, 25, 18, 22,
		&"plaza", [&"mayor", &"florist", &"child", &"librarian"],
		6, "festival_starry_night"
	)


func _festival(
	festival_id: StringName, name_key: StringName, season: Season.Type, day: int,
	start_hour: int, end_hour: int, gather_point: StringName, npc_ids: Array,
	affection: int, dialogue_id: String, attendance_flag: StringName = &"",
	game_id: StringName = &""
) -> void:
	var festival := FestivalData.new()
	festival.id = festival_id
	festival.display_name_key = name_key
	festival.season = season
	festival.day = day
	festival.start_hour = start_hour
	festival.end_hour = end_hour
	festival.world_path = TWON_SCENE
	festival.gather_point = gather_point
	festival.npc_ids = _str_array(npc_ids)
	festival.attendance_affection = affection
	festival.attendance_flag = attendance_flag
	festival.game_id = game_id
	festival.intro_dialogue = (
		_load(SHARED_DIALOGUE_DIR.path_join("%s.tres" % dialogue_id)) as DialogueData
	)
	_save(festival, FESTIVAL_DIR.path_join("%s.tres" % festival_id))
