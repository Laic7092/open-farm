extends "res://tools/sample/sample_base.gd"
## npcs：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

func build() -> void:
	var merchant := NpcData.new()
	merchant.id = &"merchant"
	merchant.display_name_key = &"NPC_MERCHANT"
	merchant.default_dialogue = _load(DIALOGUE_DIR.path_join("merchant_greeting.tres"))
	merchant.shop_id = &"general_store"
	merchant.frames = _npc_frames(&"merchant")
	merchant.move_speed = 36.0
	merchant.schedule = _load(SCHEDULE_DIR.path_join("merchant_schedule.tres"))
	_save(merchant, NPC_DIR.path_join("merchant.tres"))

	var mayor := NpcData.new()
	mayor.id = &"mayor"
	mayor.display_name_key = &"NPC_MAYOR"
	mayor.default_dialogue = _load(DIALOGUE_DIR.path_join("mayor_greeting.tres"))
	mayor.frames = _npc_frames(&"mayor")
	mayor.move_speed = 30.0
	mayor.schedule = _load(SCHEDULE_DIR.path_join("mayor_schedule.tres"))
	_save(mayor, NPC_DIR.path_join("mayor.tres"))

	var blacksmith := {"move_speed": 28.0}
	blacksmith.merge(_romance_overrides(
		&"blacksmith", [&"stone"], [&"wood"], [&"flower"]
	))
	_add_npc(&"blacksmith", &"NPC_BLACKSMITH", "blacksmith_greeting.tres", "blacksmith_schedule.tres", blacksmith)

	var florist := {"move_speed": 26.0, "shop_id": &"flower_shop"}
	florist.merge(_romance_overrides(
		&"florist", [&"flower"], [&"mushroom"], [&"wood"]
	))
	_add_npc(&"florist", &"NPC_FLORIST", "florist_greeting.tres", "florist_schedule.tres", florist)

	var fisher := {"move_speed": 30.0}
	fisher.merge(_romance_overrides(
		&"fisher", [&"mushroom", &"sea_bream", &"golden_carp"],
		[&"egg", &"sardine", &"mackerel", &"carp"], [&"fiber"]
	))
	_add_npc(&"fisher", &"NPC_FISHER", "fisher_greeting.tres", "fisher_schedule.tres", fisher)

	var librarian := {"move_speed": 26.0}
	librarian.merge(_romance_overrides(
		&"librarian", [&"flower"], [&"egg"], [&"stone"]
	))
	_add_npc(&"librarian", &"NPC_LIBRARIAN", "librarian_greeting.tres", "librarian_schedule.tres", librarian)

	_add_npc(&"miner", &"NPC_MINER", "miner_greeting.tres", "miner_schedule.tres", {
		"move_speed": 24.0,
	})
	_add_npc(&"child", &"NPC_CHILD", "child_greeting.tres", "child_schedule.tres", {
		"move_speed": 34.0,
	})
	# 玩家自己的孩子：出生后才出现在农场（由 Npc.required_flag 控制）。
	_add_npc(&"our_child", &"NPC_OUR_CHILD", "our_child_greeting.tres", "our_child_schedule.tres", {
		"move_speed": 30.0,
	})


## 批量建一个 NPC 并保存；[param overrides] 用于覆盖字段（速度 / 商店 id …）。
func _add_npc(
	npc_id: StringName,
	name_key: StringName,
	dialogue_file: String,
	schedule_file: String,
	overrides: Dictionary = {}
) -> void:
	var npc := NpcData.new()
	npc.id = npc_id
	npc.display_name_key = name_key
	npc.default_dialogue = _load(DIALOGUE_DIR.path_join(dialogue_file))
	npc.schedule = _load(SCHEDULE_DIR.path_join(schedule_file))
	npc.frames = _npc_frames(npc_id)
	npc.move_speed = overrides.get("move_speed", 28.0)
	for key: String in overrides:
		if key == "move_speed":
			continue
		npc.set(key, overrides[key])
	_save(npc, NPC_DIR.path_join("%s.tres" % npc_id))


## 可攻略 NPC 的恋爱字段；[param prefix] 对应 [code]<prefix>_friend.tres[/code] 等对白。
func _romance_overrides(
	prefix: StringName,
	loved: Array,
	liked: Array,
	disliked: Array
) -> Dictionary:
	return {
		"romanceable": true,
		"confession_affection": 200,
		"marriage_affection": 250,
		"loved_gifts": _str_array(loved),
		"liked_gifts": _str_array(liked),
		"disliked_gifts": _str_array(disliked),
		"friend_dialogue": _load(DIALOGUE_DIR.path_join("%s_friend.tres" % prefix)),
		"lover_dialogue": _load(DIALOGUE_DIR.path_join("%s_lover.tres" % prefix)),
		"married_dialogue": _load(DIALOGUE_DIR.path_join("%s_married.tres" % prefix)),
		"confession_dialogue": _load(DIALOGUE_DIR.path_join("%s_confession.tres" % prefix)),
		"proposal_dialogue": _load(DIALOGUE_DIR.path_join("%s_proposal.tres" % prefix)),
	}


## 取 NPC 动画。
func _npc_frames(npc_id: StringName) -> SpriteFrames:
	var path: String = NPC_FRAMES_DIR.path_join("npc_%s_frames.tres" % npc_id)
	if not ResourceLoader.exists(path):
		push_warning("缺少 NPC 动画 %s（先跑 tools/build_assets.sh）" % path)
		return null
	return ResourceLoader.load(path) as SpriteFrames
