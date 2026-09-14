extends Node
## 端到端冒烟测试：真的把游戏跑起来，再断言关键行为。
##
## 单元测试（gdUnit4）覆盖纯逻辑，但"场景能不能加载、autoload 有没有接错线、
## 存档写不写得进去"这类问题只有把游戏跑起来才暴露得出来。
## 这个脚本就是干这个的，也方便在没有显示器的机器上做 CI。
##
## 注意：这里必须用[b]场景[/b]而不是 [code]-s[/code] 脚本启动。
## Godot 在加载 [code]-s[/code] 脚本时还没注册 autoload 的全局标识符，
## 脚本里直接写 [code]GameClock[/code] 会编译失败；跑场景则没有这个问题。
##
## 用法：[code]godot --headless --path . res://tools/smoke_test.tscn[/code]
## 退出码 0 表示全部通过。

## 冒烟测试期间把存档重定向到工作区内，不污染真实的 user:// 目录。
const TEST_SAVE_ROOT: String = "res://.tmp/smoke_saves"
## 最多等待多少帧（超时即判失败，避免 CI 卡死）。
const MAX_FRAMES: int = 6000

const FARM_SCENE: String = "res://scenes/world/farm.tscn"
const TOWN_SCENE: String = "res://scenes/world/town.tscn"

var _failures := PackedStringArray()
var _checks: int = 0
var _frames: int = 0
var _phase: int = 0

## 跨场景往返测试用的锚点。
var _anchor_cell: Vector2i = Vector2i.ZERO
var _anchor_tilled: int = 0


func _ready() -> void:
	SaveManager.save_root = TEST_SAVE_ROOT
	_cleanup_saves()
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	if scene == null:
		_fail("无法加载 main.tscn")
		_report()
		return
	add_child(scene.instantiate())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_fail("超时：%d 帧内仍未完成（当前阶段 %d）" % [MAX_FRAMES, _phase])
		_report()
		return

	match _phase:
		0:
			if not SceneRouter.is_transitioning() and _world() != null:
				_phase = 1
		1:
			_run_checks()
			_prepare_persistence_anchor()
			_phase = 2
			SceneRouter.change_scene_to(TOWN_SCENE, &"from_farm")
		2:
			if SceneRouter.is_transitioning():
				return
			_check_town()
			_phase = 3
			SceneRouter.change_scene_to(FARM_SCENE, &"from_town")
		3:
			if SceneRouter.is_transitioning():
				return
			_check_farm_state_survived()
			_report()


# ---------------------------------------------------------------- 断言

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_fail("%s（期望 %s，实际 %s）" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	_cleanup_saves()
	if _failures.is_empty():
		print("SMOKE OK：%d 项检查全部通过" % _checks)
		get_tree().quit(0)
		return
	print("SMOKE FAILED：%d / %d 项失败" % [_failures.size(), _checks])
	for failure: String in _failures:
		print("  ✗ ", failure)
	get_tree().quit(1)


# ---------------------------------------------------------------- 检查项

func _run_checks() -> void:
	_check_database()
	_check_world()
	_check_spawn()
	_check_clock()
	_check_farming()
	_check_shop()
	_check_save_load()
	_check_ui()


func _check_database() -> void:
	_check(Database.crops.size() >= 3, "作物数据应当至少有 3 种")
	_check(Database.items.size() >= 10, "道具数据应当至少有 10 种")
	_check(Database.tools.size() >= 4, "工具数据应当至少有 4 种")
	_check(Database.shops.has(&"general_store"), "应当存在 general_store 商店")
	_check(Database.npcs.has(&"merchant"), "应当存在 merchant NPC")
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
	_check(not get_tree().get_nodes_in_group(Npc.GROUP).is_empty(), "农场场景应当有 NPC")

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
	_check_eq(GameClock.hour(), GameClock.DAY_START_HOUR, "开局时间应当是 06:00")
	var day_before: int = GameClock.date.day

	# 刚好跨过 02:00 这个分界点：应当同时推进日期并停在 02:00。
	GameClock.set_time(GameClock.DAY_ROLLOVER_HOUR - 1, 59)
	GameClock.advance_minutes(1)
	_check_eq(GameClock.date.day, day_before + 1, "跨过 02:00 后日期应当 +1")
	_check_eq(GameClock.hour(), GameClock.DAY_ROLLOVER_HOUR, "跨天后应当停在 02:00")
	_check(GameClock.minutes_since_day_start() >= 0, "当天已过分钟数不应为负")

	# 睡到早上：应当回到 06:00。
	GameClock.sleep_until_morning()
	_check_eq(GameClock.hour(), GameClock.DAY_START_HOUR, "睡醒后应当回到 06:00")
	_check_eq(GameClock.date.day, day_before + 2, "睡觉应当再推进一天")


func _check_farming() -> void:
	var grid := _farm_grid()
	if grid == null:
		return
	var cell: Vector2i = grid.farmable_area.position + Vector2i(1, 1)
	_check(grid.is_farmable(cell), "农田区域内应当可以耕种")

	_check(grid.till(cell), "应当可以翻地")
	_check(not grid.till(cell), "重复翻地应当失败")
	_check(grid.water(cell), "应当可以浇水")
	_check(grid.plant(cell, &"turnip_seed", Season.Type.SPRING), "春季应当可以种萝卜")

	var crop := grid.get_crop(cell)
	_check(crop != null, "播种后格子上应当有作物")
	if crop == null:
		return
	var data := Database.get_crop(&"turnip")
	var mature_days: int = CropGrowth.mature_days(data)
	for _i: int in mature_days:
		grid.advance_day(GameClock.date, true)
	_check(
		CropGrowth.can_harvest(data, grid.get_crop(cell)),
		"浇水 %d 天后萝卜应当成熟" % mature_days
	)

	var outcome := grid.harvest(cell)
	_check_eq(String(outcome.get("item_id", &"")), "turnip", "收获产物应当是萝卜")
	_check(int(outcome.get("amount", 0)) >= 1, "收获数量应当至少为 1")
	_check(grid.get_crop(cell) == null, "一次性作物收获后应当从地里消失")


func _check_shop() -> void:
	var shop_data := Database.get_shop(&"general_store")
	_check(shop_data != null, "应当能找到杂货店数据")
	if shop_data == null:
		return

	var inventory := Inventory.new()
	GameState.set_money(1000)
	var shop := Shop.new(shop_data)
	shop.restock()
	var entries := shop.available_entries(GameClock.date.day)
	_check(not entries.is_empty(), "商店应当有可购买的商品")
	if entries.is_empty():
		return

	var entry: ShopStock = entries[0]
	var price: int = shop.price_of(entry)
	_check(shop.buy(entry, 1, inventory), "应当可以购买商品")
	_check_eq(GameState.money, 1000 - price, "购买后金钱应当扣除")
	_check(inventory.count_of(entry.item_id) == 1, "购买后背包应当有该道具")


func _check_save_load() -> void:
	var grid := _farm_grid()
	var player := _player()
	if player == null:
		return

	player.inventory.add(&"turnip", 3)
	var money_before: int = GameState.money
	var day_before: int = GameClock.date.day
	var tilled_before: int = grid.tilled_count() if grid != null else 0

	_check(SaveManager.save_game(0), "应当能保存到槽位 0")
	_check(SaveManager.has_save(0), "保存后槽位 0 应当存在")
	var meta := SaveManager.read_meta(0)
	_check(not meta.is_empty(), "应当能读到存档摘要")
	_check_eq(int(meta.get("money", -1)), money_before, "存档摘要中的金钱应当一致")

	# 篡改运行时状态，再读档还原。
	GameState.set_money(1)
	GameClock.date.day = 1
	_check(SaveManager.load_game(0), "应当能读取槽位 0")
	_check_eq(GameState.money, money_before, "读档后金钱应当还原")
	_check_eq(GameClock.date.day, day_before, "读档后日期应当还原")
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


# ---------------------------------------------------------------- 跨场景往返

## 在地里留下"翻过的土 + 一株作物"，用于验证传送往返后进度还在。
func _prepare_persistence_anchor() -> void:
	var grid := _farm_grid()
	if grid == null:
		return
	_anchor_cell = grid.farmable_area.position + Vector2i(3, 3)
	grid.till(_anchor_cell)
	grid.water(_anchor_cell)
	grid.plant(_anchor_cell, &"potato_seed", Season.Type.SPRING)
	_anchor_tilled = grid.tilled_count()
	_check(grid.get_crop(_anchor_cell) != null, "锚点格子应当已种下土豆")


func _check_town() -> void:
	var world := _world()
	_check(world != null, "小镇场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "town", "切换后应当在小镇")
	_check(_player() != null, "小镇里应当有玩家")
	_check(_farm_grid() == null, "小镇里不应该有农场网格")

	var spawn := _find_spawn(&"from_farm")
	_check(spawn != null, "小镇应当有 from_farm 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在小镇的 from_farm 出生点（实际 %s）" % player.global_position
		)


func _check_farm_state_survived() -> void:
	var world := _world()
	_check(world != null, "返回后农场场景应当仍可访问")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "farm", "应当回到农场")

	var grid := _farm_grid()
	_check(grid != null, "返回后应当能找到 FarmGrid")
	if grid == null:
		return

	# 关键回归：农田进度必须活过"农场 → 小镇 → 农场"。
	_check_eq(grid.tilled_count(), _anchor_tilled, "往返后已翻耕的格子数应当不变")
	var crop := grid.get_crop(_anchor_cell)
	_check(crop != null, "往返后锚点上的作物应当还在")
	if crop != null:
		_check_eq(String(crop.crop_id), "potato", "往返后锚点上的作物应当还是土豆")

	# 关键回归：日结转钩子必须在重新进入场景树时被重新注册，
	# 否则作物再也不会生长。
	if crop != null:
		var grown_before: int = crop.days_grown
		GameClock.sleep_until_morning()
		_check(
			crop.days_grown > grown_before,
			"往返后日结转钩子应当仍然生效（作物应当继续生长）"
		)


# ---------------------------------------------------------------- 工具

func _world() -> Node:
	return SceneRouter.current_world()


func _farm_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _find_spawn(spawn_id: StringName) -> SpawnPoint:
	for node: Node in get_tree().get_nodes_in_group(SceneRouter.SPAWN_GROUP):
		var point := node as SpawnPoint
		if point != null and point.spawn_id == spawn_id:
			return point
	return null


func _cleanup_saves() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_SAVE_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
