extends "res://tools/sample/sample_base.gd"
## npcs：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。
##
## 对白一律按 NPC 分目录存放（[code]data/dialogue/<npc_id>/[/code]），
## 默认问候、季节问候、恋爱对白都从各自的目录取，见 [code]build_dialogues.gd[/code]。

func build() -> void:
	_add_npc(&"merchant", &"NPC_MERCHANT", "merchant_schedule.tres", {
		"move_speed": 36.0, "shop_id": &"general_store",
	})
	_add_npc(&"mayor", &"NPC_MAYOR", "mayor_schedule.tres", {
		"move_speed": 30.0,
	})

	_add_npc(&"blacksmith", &"NPC_BLACKSMITH", "blacksmith_schedule.tres", _merge({
		"move_speed": 28.0,
	}, _romance_overrides(&"blacksmith", [&"stone"], [&"wood"], [&"flower"])))

	_add_npc(&"florist", &"NPC_FLORIST", "florist_schedule.tres", _merge({
		"move_speed": 26.0, "shop_id": &"flower_shop",
	}, _romance_overrides(&"florist", [&"flower"], [&"mushroom"], [&"wood"])))

	_add_npc(&"fisher", &"NPC_FISHER", "fisher_schedule.tres", _merge({
		"move_speed": 30.0,
	}, _romance_overrides(&"fisher", [&"mushroom", &"sea_bream", &"golden_carp"],
		[&"egg", &"sardine", &"mackerel", &"carp"], [&"fiber"])))

	_add_npc(&"librarian", &"NPC_LIBRARIAN", "librarian_schedule.tres", _merge({
		"move_speed": 26.0,
	}, _romance_overrides(&"librarian", [&"flower"], [&"egg"], [&"stone"])))

	_add_npc(&"miner", &"NPC_MINER", "miner_schedule.tres", {"move_speed": 24.0})
	_add_npc(&"child", &"NPC_CHILD", "child_schedule.tres", {"move_speed": 34.0})
	# 玩家自己的孩子：出生后才出现在农场（由 Npc.required_flag 控制），没有季节问候。
	_add_npc(&"our_child", &"NPC_OUR_CHILD", "our_child_schedule.tres", {
		"move_speed": 30.0,
	}, false)


## 建一个 NPC 并保存。
##
## [param overrides] 用于覆盖字段（速度 / 商店 id / 恋爱字段…）；
## [param seasonal] 为 true 时自动挂上夏 / 秋 / 冬三份季节问候。
func _add_npc(
	npc_id: StringName,
	name_key: StringName,
	schedule_file: String,
	overrides: Dictionary = {},
	seasonal: bool = true
) -> void:
	var npc := NpcData.new()
	npc.id = npc_id
	npc.display_name_key = name_key
	npc.default_dialogue = _load_npc_dialogue(npc_id, "%s_greeting" % npc_id)
	npc.schedule = _load(SCHEDULE_DIR.path_join(schedule_file))
	npc.frames = _npc_frames(npc_id)
	npc.move_speed = overrides.get("move_speed", 28.0)
	if seasonal:
		overrides["seasonal_dialogue"] = _seasonal_dialogues(npc_id)
	for key: String in overrides:
		if key == "move_speed":
			continue
		npc.set(key, overrides[key])
	_save(npc, NPC_DIR.path_join("%s.tres" % npc_id))


## 该 NPC 的夏 / 秋 / 冬对白（键为 [enum Season.Type] 的整数）。
##
## 春 / 默认沿用 [member NpcData.default_dialogue]，因此这里只覆盖另外三季。
func _seasonal_dialogues(npc_id: StringName) -> Dictionary:
	return {
		int(Season.Type.SUMMER): _load_npc_dialogue(npc_id, "%s_summer" % npc_id),
		int(Season.Type.FALL): _load_npc_dialogue(npc_id, "%s_fall" % npc_id),
		int(Season.Type.WINTER): _load_npc_dialogue(npc_id, "%s_winter" % npc_id),
	}


## 可攻略 NPC 的恋爱字段；[param prefix] 与对白文件名一致（[code]<prefix>_friend[/code] 等）。
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
		"friend_dialogue": _load_npc_dialogue(prefix, "%s_friend" % prefix),
		"lover_dialogue": _load_npc_dialogue(prefix, "%s_lover" % prefix),
		"married_dialogue": _load_npc_dialogue(prefix, "%s_married" % prefix),
		"confession_dialogue": _load_npc_dialogue(prefix, "%s_confession" % prefix),
		"proposal_dialogue": _load_npc_dialogue(prefix, "%s_proposal" % prefix),
	}


## 合并两个覆盖字典；[param extra] 优先。
func _merge(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate()
	merged.merge(extra, true)
	return merged


## 从 [code]data/dialogue/<npc_id>/<file_name>.tres[/code] 读一份对白。
func _load_npc_dialogue(npc_id: StringName, file_name: String) -> DialogueData:
	var path: String = _npc_dialogue_dir(npc_id).path_join("%s.tres" % file_name)
	return _load(path) as DialogueData


## 取 NPC 动画。
func _npc_frames(npc_id: StringName) -> SpriteFrames:
	var path: String = NPC_FRAMES_DIR.path_join("npc_%s_frames.tres" % npc_id)
	if not ResourceLoader.exists(path):
		push_warning("缺少 NPC 动画 %s（先跑 tools/build_assets.sh）" % path)
		return null
	return ResourceLoader.load(path) as SpriteFrames
