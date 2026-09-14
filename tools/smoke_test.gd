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
const TWON_SCENE: String = "res://scenes/world/twon.tscn"

var _failures := PackedStringArray()
var _checks: int = 0
var _frames: int = 0
var _phase: int = 0

## 跨场景往返测试用的锚点。
var _anchor_cell: Vector2i = Vector2i.ZERO
var _anchor_tilled: int = 0
## 野生植被锚点：验证"离开这几天，世界也在长"。
var _anchor_flora_cell: Vector2i = Vector2i(-1, -1)
var _anchor_flora_days: int = 0
var _anchor_flora_total: int = 0
## 日程寻路：记录 NPC 起始位置，等几帧后确认它们真的移动了。
var _npc_positions: Dictionary = {}
var _twon_wait: int = 0


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
			SceneRouter.change_scene_to(TWON_SCENE, &"from_farm")
		3:
			if SceneRouter.is_transitioning():
				return
			_check_twon()
			_record_npc_positions()
			_twon_wait = 0
			_phase = 5
		# 等几帧，验证 NPC 真的按日程走起来了，再回农场。
		5:
			if SceneRouter.is_transitioning():
				return
			_twon_wait += 1
			if _twon_wait < 30:
				return
			_check_npcs_moved()
			_phase = 4
			SceneRouter.change_scene_to(FARM_SCENE, &"from_twon")
		4:
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
	_check_flora()
	_check_livestock()
	_check_shop()
	_check_save_load()
	_check_ui()
	_check_audio()


func _check_database() -> void:
	_check(Database.crops.size() >= 3, "作物数据应当至少有 3 种")
	_check(Database.floras.size() >= 7, "野生植被数据应当至少有 7 种")
	_check(Database.items.size() >= 10, "道具数据应当至少有 10 种")
	_check(Database.tools.size() >= 6, "工具数据应当至少有 6 种")
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

	# 田里可能已经长了杂草——这本身就是"更真实的世界"的一部分，
	# 但要让翻地/播种的断言稳定，先把它清掉。
	_clear_flora_at(cell)

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


# ---------------------------------------------------------------- 野生植被

## 世界自然生长系统的端到端检查：开局有植被、过一天会长、对的工具能清掉。
func _check_flora() -> void:
	var field := _flora_field()
	_check(field != null, "农场场景应当包含 FloraField")
	if field == null:
		return

	_check(field.total() > 0, "开局农场应当已经自然长出植被")

	var resolved: int = 0
	for cell: Vector2i in field.flora:
		if Database.get_flora(field.flora[cell].flora_id) != null:
			resolved += 1
	_check_eq(resolved, field.total(), "每一株野生植被都应当能解析到数据")

	# 生长：睡一觉之后再回来看那株长了几天。
	var growing := _first_growing_flora(field)
	if growing != Vector2i(-1, -1):
		var before: int = field.flora[growing].days_grown
		GameClock.sleep_until_morning()
		if field.occupied(growing):
			_check(
				field.flora[growing].days_grown > before,
				"过一天之后野生植被应当长了一点"
			)
		else:
			_fail("睡了一觉之后那株植被不该消失")

	_check(_clear_one_flora(field), "用对应的工具应当能清掉一株野生植被")


## 找一株"今天确实会生长"的植被。
func _first_growing_flora(field: FloraField) -> Vector2i:
	for cell: Vector2i in field.flora:
		var data := Database.get_flora(field.flora[cell].flora_id)
		if data != null and FloraGrowth.can_grow(data, GameClock.date.season):
			return cell
	return Vector2i(-1, -1)


## 用 [FarmInteractor] 走一遍真实的工具链路，清掉任意一株植被。
func _clear_one_flora(field: FloraField) -> bool:
	var player := _player()
	if player == null:
		return false
	# 先快照一份格子：工具生效会改动 field.flora，不能边遍历边删。
	var cells: Array[Vector2i] = []
	for cell: Vector2i in field.flora:
		cells.append(cell)
	for cell: Vector2i in cells:
		var data := Database.get_flora(field.flora[cell].flora_id)
		if data == null:
			continue
		var tool := Database.get_tool(_tool_id_for_kind(data.tool_kind))
		if tool == null:
			continue
		var before: int = field.total()
		if player.interactor.use_tool(tool, cell) and field.total() < before:
			return true
	return false


func _tool_id_for_kind(kind: ToolData.Kind) -> StringName:
	match kind:
		ToolData.Kind.HOE:
			return &"hoe"
		ToolData.Kind.WATERING_CAN:
			return &"watering_can"
		ToolData.Kind.AXE:
			return &"axe"
		ToolData.Kind.PICKAXE:
			return &"pickaxe"
		ToolData.Kind.SICKLE:
			return &"sickle"
		_:
			return &"seed_bag"


## 把某一格上的植被清掉（冒烟测试里用来给"翻地"腾地方）。
func _clear_flora_at(cell: Vector2i) -> void:
	var field := _flora_field()
	if field == null or not field.occupied(cell):
		return
	var state := field.flora_at(cell)
	if state == null:
		return
	var data := Database.get_flora(state.flora_id)
	if data != null:
		field.clear(cell, data.tool_kind)


# ---------------------------------------------------------------- 畜牧

## 养殖系统的端到端检查：放养、物种限制、喂食成长、收产出、序列化。
func _check_livestock() -> void:
	var mgr := _livestock()
	_check(mgr != null, "农场场景应当包含 LivestockManager")
	if mgr == null:
		return
	_check(mgr.pen_for(&"coop") != null, "农场应当有鸡舍")
	_check(mgr.pen_for(&"barn") != null, "农场应当有牛舍")

	var player := _player()
	if player == null:
		return

	# 放养：拿着鸡走到鸡舍，鸡被消耗、鸡舍多一只。
	player.inventory.add(&"chicken", 1)
	_check(mgr.introduce(&"coop", player), "拿着鸡应当能放进鸡舍")
	_check_eq(mgr.animal_count(&"coop"), 1, "鸡舍里应当有 1 只鸡")
	_check(not player.inventory.has(&"chicken"), "放养后背包里的鸡应当被消耗")

	# 物种限制：牛不能住鸡舍、只能住牛舍。
	player.inventory.add(&"cow", 1)
	_check(not mgr.introduce(&"coop", player), "牛不应该能住进鸡舍")
	_check(mgr.introduce(&"barn", player), "牛应当能住进牛舍")
	_check_eq(mgr.animal_count(&"barn"), 1, "牛舍里应当有 1 头牛")

	# 喂食 + 成长：每天喂一次，喂够 mature_days 天后成年。
	var chicken := Database.get_animal(&"chicken")
	player.inventory.add(&"hay", 20)
	for _i: int in chicken.mature_days:
		_check(mgr.feed(&"coop", player.inventory) > 0, "饿着的鸡应当能被喂到")
		mgr.advance_day(GameClock.date)
	var state := mgr.animal_state_at(&"coop", 0)
	_check(
		AnimalHusbandry.is_mature(chicken, state),
		"喂够 %d 天后鸡应当成年" % chicken.mature_days
	)

	# 产出：成年后再过 produce_days 个喂养日，就有鸡蛋可收。
	for _i: int in chicken.produce_days:
		mgr.feed(&"coop", player.inventory)
		mgr.advance_day(GameClock.date)
	state = mgr.animal_state_at(&"coop", 0)
	_check(AnimalHusbandry.can_collect(chicken, state), "过了一个产出周期后应当有鸡蛋可收")
	var outcome := mgr.collect(&"coop", 0)
	_check_eq(String(outcome.get("item_id", &"")), "egg", "产出的应当是鸡蛋")
	_check(int(outcome.get("amount", 0)) >= 1, "鸡蛋数量应当至少为 1")

	# 序列化往返：存档 / 读档不能把牲畜弄丢。
	var snapshot := mgr.to_dict()
	mgr.from_dict(snapshot)
	_check_eq(mgr.animal_count(&"coop"), 1, "序列化往返后鸡舍里的鸡应当还在")
	_check_eq(mgr.animal_count(&"barn"), 1, "序列化往返后牛舍里的牛应当还在")


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
	_clear_flora_at(_anchor_cell)
	grid.till(_anchor_cell)
	grid.water(_anchor_cell)
	grid.plant(_anchor_cell, &"potato_seed", Season.Type.SPRING)
	_anchor_tilled = grid.tilled_count()
	_check(grid.get_crop(_anchor_cell) != null, "锚点格子应当已种下土豆")

	# 另记一株野生植被：离开这几天它应当靠"进图补算"继续长大。
	var field := _flora_field()
	if field != null:
		_anchor_flora_cell = _first_growing_flora(field)
		_anchor_flora_total = field.total()
		if _anchor_flora_cell != Vector2i(-1, -1):
			_anchor_flora_days = field.flora[_anchor_flora_cell].days_grown


func _check_town() -> void:
	var world := _world()
	_check(world != null, "小镇场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "town", "切换后应当在小镇")
	_check_eq(String(Audio.current_bgm()), "town", "白天进小镇应当换成小镇 BGM")
	_check(_player() != null, "小镇里应当有玩家")
	_check(_farm_grid() == null, "小镇里不应该有农场网格")
	_check(_flora_field() != null, "小镇也应当有自己的野生植被")

	var spawn := _find_spawn(&"from_farm")
	_check(spawn != null, "小镇应当有 from_farm 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在小镇的 from_farm 出生点（实际 %s）" % player.global_position
		)
	_check(
		get_tree().get_nodes_in_group(Npc.GROUP).is_empty(),
		"NPC 应当已从小镇移入 twon"
	)

	# 在别的地图上过一天：农场不在场景树里，它的日结转钩子是注销的，
	# 所以农场的植被只能靠"重新进图时补算"追上——这正是下面要验证的。
	GameClock.sleep_until_morning()


func _check_twon() -> void:
	var world := _world()
	_check(world != null, "twon 场景应当已加载")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "twon", "切换后应当在大场景 twon")
	_check(_player() != null, "twon 里应当有玩家")
	_check(_farm_grid() == null, "twon 里不应该有农场网格")
	_check(_flora_field() != null, "twon 也应当有自己的野生植被")

	var limits: Rect2 = world.get(&"camera_limits")
	_check(
		limits.size.x >= 1280.0 and limits.size.y >= 720.0,
		"twon 应当是一个大地图（实际 %s）" % limits.size
	)
	var ground := world.find_child("Ground", true, false) as TileMapLayer
	_check(
		ground != null and ground.get_used_cells().size() > 0,
		"twon 地面应当已绘制瓦片"
	)

	var spawn := _find_spawn(&"from_farm")
	_check(spawn != null, "twon 应当有 from_farm 出生点")
	var player := _player()
	if spawn != null and player != null:
		_check(
			player.global_position.distance_to(spawn.global_position) < 1.0,
			"玩家应当落在 twon 的 from_farm 出生点（实际 %s）" % player.global_position
		)

	var npc_ids: Dictionary = {}
	for npc: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		npc_ids[npc.get(&"npc_id")] = true
	_check(npc_ids.has(&"merchant"), "twon 应当包含商人 NPC")
	_check(npc_ids.has(&"mayor"), "twon 应当包含村长 NPC")

	_check_npc_schedule()


## 日程 + 寻路的端到端检查：导航网格可用、两个 NPC 有日程、路径能算出来。
func _check_npc_schedule() -> void:
	var navigator := get_tree().get_first_node_in_group(NpcNavigator.GROUP) as NpcNavigator
	_check(navigator != null, "twon 应当自动挂载 NPC 导航网格")
	_check(_find_schedule_point(&"store") != null, "twon 应当有 store 日程地点")

	if navigator != null:
		var from: Vector2i = navigator.cell_of(Vector2(768, 888))
		var to: Vector2i = navigator.cell_of(Vector2(448, 392))
		_check(navigator.is_walkable(from), "农场入口应当是可行走格")
		_check(navigator.is_walkable(to), "商店门口应当是可行走格")
		var path := navigator.find_path(from, to)
		_check(not path.is_empty(), "从农场入口到商店应当能找到路径")
		if not path.is_empty():
			_check_eq(path[0], from, "路径应当从起点开始")
			_check_eq(path[path.size() - 1], to, "路径应当以终点结束")

	# 06:00：商人应当在商店、村长应当在镇公所。
	_check_npc_at(&"merchant", &"store")
	_check_npc_at(&"mayor", &"town_hall")


func _check_npc_at(npc_id: StringName, location_id: StringName) -> void:
	var npc := _find_npc(npc_id)
	_check(npc != null, "twon 应当有 NPC %s" % npc_id)
	if npc == null:
		return
	_check(npc.data != null and npc.data.schedule != null, "NPC %s 应当有日程" % npc_id)
	_check_eq(
		String(npc.target_location_id()),
		String(location_id),
		"NPC %s 在 06:00 的目标地点" % npc_id
	)


## 记下 NPC 当前坐标，等几帧后确认它们确实动过。
func _record_npc_positions() -> void:
	_npc_positions.clear()
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null:
			_npc_positions[npc.npc_id] = npc.global_position


func _check_npcs_moved() -> void:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null:
			continue
		var start: Variant = _npc_positions.get(npc.npc_id, null)
		if start is Vector2:
			_check(
				npc.global_position.distance_to(start) > 0.5,
				"NPC %s 应当按日程走起来（起点 %s，现在 %s）"
					% [npc.npc_id, start, npc.global_position]
			)


func _find_npc(npc_id: StringName) -> Npc:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == npc_id:
			return npc
	return null


func _find_schedule_point(point_id: StringName) -> SchedulePoint:
	for node: Node in get_tree().get_nodes_in_group(SchedulePoint.GROUP):
		var point := node as SchedulePoint
		if point != null and point.point_id == point_id:
			return point
	return null


func _check_audio() -> void:
	_check(AudioServer.get_bus_index(&"BGM") >= 0, "应当存在 BGM 总线")
	_check(AudioServer.get_bus_index(&"SFX") >= 0, "应当存在 SFX 总线")
	_check_eq(String(Audio.current_bgm()), "farm", "白天进农场应当播放农场 BGM")

	# 音量旋钮真的接到总线上。
	var original: float = Audio.sfx_volume
	Audio.set_sfx_volume(0.4)
	_check(is_equal_approx(Audio.sfx_volume, 0.4), "音效音量应当可以调整")
	Audio.set_sfx_volume(original)

	# 触发一次真实音效；headless 下听不见，但不应当报错或崩溃。
	Audio.play_sfx(&"ui_confirm")


func _check_farm_state_survived() -> void:
	var world := _world()
	_check(world != null, "返回后农场场景应当仍可访问")
	if world == null:
		return
	_check_eq(String(world.get(&"world_id")), "farm", "应当回到农场")

	var grid := _farm_grid()
	_check(grid != null, "返回后应当能找到 FarmGrid")

	# 关键回归：畜舍进度也必须活过"农场 → 小镇 → 农场"。
	var livestock := _livestock()
	_check(livestock != null, "返回后应当能找到 LivestockManager")
	if livestock != null:
		_check(livestock.animal_count(&"coop") >= 1, "往返后鸡舍里的鸡应当还在")

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

	# 关键回归：不在场的地图靠"重新进图时补算"继续生长。
	var field := _flora_field()
	_check(field != null, "返回后应当能找到 FloraField")
	if field == null:
		return
	_check(
		field.total() >= _anchor_flora_total,
		"往返后野生植被总数不该变少（%d → %d）" % [_anchor_flora_total, field.total()]
	)
	if _anchor_flora_cell != Vector2i(-1, -1) and field.occupied(_anchor_flora_cell):
		_check(
			field.flora[_anchor_flora_cell].days_grown > _anchor_flora_days,
			"在小镇过了一天之后，农场的植被应当已经补算生长过"
		)


# ---------------------------------------------------------------- 工具

func _world() -> Node:
	return SceneRouter.current_world()


func _farm_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


func _livestock() -> LivestockManager:
	return get_tree().get_first_node_in_group(LivestockManager.GROUP) as LivestockManager


func _flora_field() -> FloraField:
	return get_tree().get_first_node_in_group(FloraField.GROUP) as FloraField


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
