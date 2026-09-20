extends "res://tools/smoke/smoke_base.gd"
## 世界 / 时间 / 数据 的冒烟检查；公共断言 / 取用器见 smoke_base.gd。

## 节日与事件：数据装载、今日播报、会场开放时间、参加奖励与存档往返。
func _check_calendar() -> void:
	_check(Database.get_festival(&"new_year") != null, "应当有新年祭数据")
	_check(Database.get_event(&"traveler_visit") != null, "应当有旅人事件数据")
	_check(_calendar.has_festival_today(), "春 1 日应当是新年祭")
	_check_eq(_calendar.today_text(), Text.key(&"FESTIVAL_NEW_YEAR"), "今日节日文本应当是新年祭")

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

	# 日结自动存档：跨天时由 Main 的日结钩子落盘，槽位自动分配。
	_check(
		SaveManager.current_slot >= 0 and SaveManager.has_save(SaveManager.current_slot),
		"跨天后应当自动存档到本局槽位"
	)

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

	var sun := world.find_child("Sun", true, false) as DirectionalLight2D
	_check(sun != null, "WorldLighting 应当挂载方向光")
	if sun != null:
		_check(not sun.shadow_enabled, "方向光不应开启无限长阴影")
	_check(
		not world.find_children("*", "LightOccluder2D", true, false).is_empty(),
		"实体摆件应当生成 LightOccluder2D"
	)

	_clock.set_time(12, 0)
	var noon_tint := lighting.tint_color()
	var noon_energy := _max_light_energy(world)
	_check(noon_energy <= 0.01, "正午路灯应当熄灭（实际 %.2f）" % noon_energy)
	if sun != null:
		_check(sun.energy > 0.1, "正午方向光应当点亮（实际 %.2f）" % sun.energy)

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
	if sun != null:
		_check(sun.energy <= 0.001, "夜里方向光应当熄灭（实际 %.2f）" % sun.energy)

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

	# v0.5：图鉴 / 委托界面能构建、能开关；直接调 open/close，不走模态以避免暂停场景树。
	var museum_ui := get_tree().root.find_child("MuseumUi", true, false) as MuseumUi
	_check(museum_ui != null, "应当存在博物馆图鉴界面")
	if museum_ui != null:
		museum_ui.open()
		_check(museum_ui.visible, "图鉴界面应当能打开")
		museum_ui.close()
		_check(not museum_ui.visible, "图鉴界面应当能关闭")
	var commission_ui := get_tree().root.find_child("CommissionUi", true, false) as CommissionUi
	_check(commission_ui != null, "应当存在委托板界面")
	if commission_ui != null:
		commission_ui.open()
		_check(commission_ui.visible, "委托板界面应当能打开")
		commission_ui.close()
		_check(not commission_ui.visible, "委托板界面应当能关闭")

	_check_touch_controls()


## 触控层：开关要能整层显隐，摇杆方向要真的落进 [Input]。
##
## 不模拟真实触摸（无头环境没有触点），而是直接调公开接口：
## 它和手指拖动走的是同一条 [code]_gui_input → set_stick[/code] 路径。
func _check_touch_controls() -> void:
	var touch := get_tree().root.find_child("TouchControls", true, false) as TouchControls
	_check(touch != null, "应当存在触控控件层")
	if touch == null:
		return

	var enabled_before := TouchSettings.is_enabled()
	touch.apply_enabled(true)
	_check(touch.visible, "打开设置后触控控件应当可见")
	touch.set_stick(Vector2.RIGHT)
	_check(Input.get_action_strength(&"move_right") > 0.0, "摇杆应当把方向写进输入动作")
	touch.set_stick(Vector2.ZERO)
	_check_eq(Input.get_action_strength(&"move_right"), 0.0, "摇杆回中应当松开方向")

	touch.apply_enabled(enabled_before)
	_check_eq(touch.visible, enabled_before, "关掉设置后触控控件应当隐藏")

	# 屏幕按钮走的是另一条注入路径（InputEventAction）：这里直接给 X（换具）按钮
	# 送一个合成触摸事件，走完整的 _gui_input → pressed → hold_action。
	# 不手调 hold_action，否则"按钮没接上线"这类改动就漏了。
	# 无头环境不会传送真实输入事件，所以自己造一个（Input.flush_buffered_events()
	# 是主循环每帧自己做的那步，手动调一次就能在同一帧里断言结果）。
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	_check(player != null, "应当存在玩家")
	var x_button := touch.get_node_or_null("%XButton") as TouchButton
	_check(x_button != null, "右上角应当有 X（换具）键")
	if player == null or x_button == null:
		return
	touch.apply_enabled(true)
	var hand_before := player.item_bar.hand_index()
	_tap(x_button, true)
	Input.flush_buffered_events()
	_tap(x_button, false)
	Input.flush_buffered_events()
	_check(
		player.item_bar.hand_index() != hand_before,
		"屏幕按钮应当把事件驱动的动作送到 _unhandled_input"
	)
	_check(not x_button.is_held(), "松开后按钮应当回到未按下状态")
	touch.apply_enabled(enabled_before)


## 合成一次按下 / 松开：位置用控件中心（本函数里位置本身不影响结果）。
func _tap(button: TouchButton, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = button.size * 0.5
	button._gui_input(event)


func _check_audio() -> void:
	_check(AudioServer.get_bus_index(AudioBus.BGM_BUS) >= 0, "应当存在 BGM 总线")
	_check(AudioServer.get_bus_index(AudioBus.SFX_BUS) >= 0, "应当存在 SFX 总线")
	_check(_bgm() != null, "当前地图应当自带 BGM 播放器")
	_check_eq(_current_bgm(), "farm", "白天进农场应当播放农场 BGM")

	# 音量旋钮真的接到总线上。
	var original: float = AudioBus.sfx_volume
	AudioBus.set_sfx_volume(0.4)
	_check(is_equal_approx(AudioBus.sfx_volume, 0.4), "音效音量应当可以调整")
	AudioBus.set_sfx_volume(original)

	# 触发一次真实音效；headless 下听不见，但不应当报错或崩溃。
	var player := _player()
	if player != null and player.sfx != null:
		player.sfx.play(&"ui_confirm")
