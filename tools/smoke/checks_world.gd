extends "res://tools/smoke/smoke_base.gd"
## 世界 / 时间 / 数据 的冒烟检查；公共断言 / 取用器见 smoke_base.gd。

## 节日与事件：数据装载、今日播报、会场开放时间、参加奖励与存档往返。
func _check_calendar() -> void:
	_check(Database.get_festival(&"new_year") != null, "应当有新年祭数据")
	_check(Database.get_event(&"traveler_visit") != null, "应当有旅人事件数据")
	_check(_calendar.has_festival_today(), "春 1 日应当是新年祭")
	_check_eq(_calendar.today_text(), Text.key(&"FESTIVAL_NEW_YEAR"), "今日节日文本应当是新年祭")

	var hud := get_tree().root.find_child("Hud", true, false)
	if hud != null:
		var label := hud.find_child("FestivalLabel", true, false) as Label
		_check(label != null and label.visible, "HUD 应当显示今日节日横幅")

	# 会场 08:00 才开门。
	_check(not _calendar.is_active(&"new_year"), "06:00 新年祭还没开门")
	_clock.set_time(9, 0)
	_check(_calendar.is_active(&"new_year"), "09:00 新年祭应当开放")

	var before := _relationships.affection(&"mayor")
	_check(_calendar.attend(&"new_year"), "应当能参加新年祭")
	_check_eq(_relationships.affection(&"mayor"), before + 4, "参加节日应当给在场 NPC 加好感")
	_check(not _calendar.attend(&"new_year"), "同一年不能重复参加")

	# 参加记录要能跟着存档走。
	var snapshot := _calendar.to_dict()
	_calendar.reset()
	_calendar.from_dict(snapshot)
	_check(_calendar.has_attended(&"new_year"), "读档后应当记得参加过新年祭")

	# 还原到开局状态：后面的时钟检查依赖"春 1 日 06:00"。
	_calendar.reset()
	_relationships.set_affection(&"mayor", before)
	_clock.set_time(GameDateClock.DAY_START_HOUR, 0)


func _check_database() -> void:
	_check(Database.crops().size() >= 3, "作物数据应当至少有 3 种")
	_check(Database.floras().size() >= 7, "野生植被数据应当至少有 7 种")
	_check(Database.items().size() >= 10, "道具数据应当至少有 10 种")
	_check(Database.tools().size() >= 6, "工具数据应当至少有 6 种")
	_check(Database.shops().has(&"general_store"), "应当存在 general_store 商店")
	_check(Database.npcs().has(&"merchant"), "应当存在 merchant NPC")
	var problems := Database.validate_all()
	_check(problems.is_empty(), "数据自检不应有问题：%s" % ", ".join(problems))


func _check_world() -> void:
	var world := _world()
	_check(world != null, "世界场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "farm", "开局世界应当是农场")
	_check(_farm_grid() != null, "农场场景应当包含 FarmGrid")
	_check(_player() != null, "农场场景应当包含玩家")
	# 农场的东口通向村庄——世界的起点就是这条路。
	_check_door_target(world, "ToTwon", "res://scenes/world/twon.tscn", &"from_farm")

	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(ground != null, "应当存在 Ground 图层")
	if ground != null:
		_check(ground.get_used_cells().size() > 0, "地面图层应当已绘制瓦片")


func _check_spawn() -> void:
	var player := _player()
	if player == null:
		return
	var expected := _find_spawn(&"start")
	_check(expected != null, "农场应当有 start 出生点")
	if expected != null:
		_check(
			player.global_position.distance_to(expected.global_position) < 1.0,
			"玩家应当被放置在 start 出生点（实际 %s，期望 %s）"
				% [player.global_position, expected.global_position]
		)


func _check_clock() -> void:
	_check_eq(_clock.hour(), GameDateClock.DAY_START_HOUR, "开局时间应当是 06:00")
	var day_before: int = _clock.date.day

	# 刚好跨过 02:00 这个分界点：应当同时推进日期并停在 02:00。
	_clock.set_time(GameDateClock.DAY_ROLLOVER_HOUR - 1, 59)
	_clock.advance_minutes(1)
	_check_eq(_clock.date.day, day_before + 1, "跨过 02:00 后日期应当 +1")
	_check_eq(_clock.hour(), GameDateClock.DAY_ROLLOVER_HOUR, "跨天后应当停在 02:00")
	_check(_clock.minutes_since_day_start() >= 0, "当天已过分钟数不应为负")

	# 睡到早上：应当回到 06:00。
	_clock.sleep_until_morning()
	_check_eq(_clock.hour(), GameDateClock.DAY_START_HOUR, "睡醒后应当回到 06:00")
	_check_eq(_clock.date.day, day_before + 2, "睡觉应当再推进一天")


func _check_day_night() -> void:
	var world := _world()
	if world == null:
		return
	var lighting := world.find_child("WorldLighting", true, false) as WorldLighting
	_check(lighting != null, "农场场景应当自动挂载 WorldLighting")
	if lighting == null:
		return

	var lights := world.find_children("*", "PointLight2D", true, false)
	_check(not lights.is_empty(), "带 light_radius 的路灯应当生成 PointLight2D")

	_clock.set_time(12, 0)
	var noon_tint := lighting.tint_color()
	var noon_energy := _max_light_energy(world)
	_check(noon_energy <= 0.01, "正午路灯应当熄灭（实际 %.2f）" % noon_energy)

	_clock.set_time(23, 0)
	var night_tint := lighting.tint_color()
	var night_energy := _max_light_energy(world)
	_check(
		night_tint.get_luminance() < noon_tint.get_luminance(),
		"夜里环境光应当比正午暗（%.2f vs %.2f）"
			% [night_tint.get_luminance(), noon_tint.get_luminance()]
	)
	_check(night_tint.b > night_tint.r, "夜里环境光应当偏冷")
	_check(night_energy > 0.5, "深夜路灯应当点亮（实际 %.2f）" % night_energy)

	# 后面的检查依赖"早上 06:00"这个起点，把时间还回去。
	_clock.set_time(GameDateClock.DAY_START_HOUR, 0)


func _max_light_energy(world: Node) -> float:
	var value := 0.0
	for node: Node in world.find_children("*", "PointLight2D", true, false):
		var light := node as PointLight2D
		if light != null:
			value = maxf(value, light.energy)
	return value


func _check_shop() -> void:
	var shop_data := Database.get_shop(&"general_store")
	_check(shop_data != null, "应当能找到杂货店数据")
	if shop_data == null:
		return

	var inventory := Inventory.new()
	_profile.set_money(1000)
	var shop := Shop.new(shop_data, _profile, Database, EventBus)
	shop.restock()
	var entries := shop.available_entries(_clock.date.day)
	_check(not entries.is_empty(), "商店应当有可购买的商品")
	if entries.is_empty():
		return

	var entry: ShopStock = entries[0]
	var price: int = shop.price_of(entry)
	_check(shop.buy(entry, 1, inventory), "应当可以购买商品")
	_check_eq(_profile.money, 1000 - price, "购买后金钱应当扣除")
	_check(inventory.count_of(entry.item_id) == 1, "购买后背包应当有该道具")


func _check_save_load() -> void:
	var grid := _farm_grid()
	var player := _player()
	if player == null:
		return

	player.inventory.add(&"turnip", 3)
	var money_before: int = _profile.money
	var day_before: int = _clock.date.day
	var tilled_before: int = grid.tilled_count() if grid != null else 0

	_check(SaveManager.save_game(0), "应当能保存到槽位 0")
	_check(SaveManager.has_save(0), "保存后槽位 0 应当存在")
	var meta := SaveManager.read_meta(0)
	_check(not meta.is_empty(), "应当能读到存档摘要")
	_check_eq(int(meta.get("money", -1)), money_before, "存档摘要中的金钱应当一致")

	# 篡改运行时状态，再读档还原。
	_profile.set_money(1)
	_clock.date.day = 1
	_check(SaveManager.load_game(0), "应当能读取槽位 0")
	_check_eq(_profile.money, money_before, "读档后金钱应当还原")
	_check_eq(_clock.date.day, day_before, "读档后日期应当还原")
	if grid != null:
		_check_eq(grid.tilled_count(), tilled_before, "读档后农田状态应当还原")


func _check_ui() -> void:
	var hud := get_tree().root.find_child("Hud", true, false)
	_check(hud != null, "应当存在 HUD")
	if hud == null:
		return
	var date_label := hud.find_child("DateLabel", true, false) as Label
	_check(date_label != null and not date_label.text.is_empty(), "HUD 日期标签应当有内容")
	var money_label := hud.find_child("MoneyLabel", true, false) as Label
	_check(money_label != null and not money_label.text.is_empty(), "HUD 金钱标签应当有内容")


func _check_audio() -> void:
	_check(AudioServer.get_bus_index(SceneAudio.BGM_BUS) >= 0, "应当存在 BGM 总线")
	_check(AudioServer.get_bus_index(SceneAudio.SFX_BUS) >= 0, "应当存在 SFX 总线")
	var audio := _scene_audio()
	_check(audio != null, "主场景应当自带音频节点")
	if audio == null:
		return
	_check_eq(String(audio.current_bgm()), "farm", "白天进农场应当播放农场 BGM")

	# 音量旋钮真的接到总线上。
	var original: float = audio.sfx_volume
	audio.set_sfx_volume(0.4)
	_check(is_equal_approx(audio.sfx_volume, 0.4), "音效音量应当可以调整")
	audio.set_sfx_volume(original)

	# 触发一次真实音效；headless 下听不见，但不应当报错或崩溃。
	audio.play_sfx(&"ui_confirm")
