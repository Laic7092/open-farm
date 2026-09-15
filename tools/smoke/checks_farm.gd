extends "res://tools/smoke/smoke_base.gd"
## 农场 / 植被 / 畜牧 / 跨场景农田状态 的冒烟检查；公共断言 / 取用器见 smoke_base.gd。

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
		grid.advance_day(_clock.date, true)
	_check(
		CropGrowth.can_harvest(data, grid.get_crop(cell)),
		"浇水 %d 天后萝卜应当成熟" % mature_days
	)

	var outcome := grid.harvest(cell)
	_check_eq(String(outcome.get("item_id", &"")), "turnip", "收获产物应当是萝卜")
	_check(int(outcome.get("amount", 0)) >= 1, "收获数量应当至少为 1")
	_check(grid.get_crop(cell) == null, "一次性作物收获后应当从地里消失")


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
		_clock.sleep_until_morning()
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
		if data != null and FloraGrowth.can_grow(data, _clock.date.season):
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
		mgr.advance_day(_clock.date)
	var state := mgr.animal_state_at(&"coop", 0)
	_check(
		AnimalHusbandry.is_mature(chicken, state),
		"喂够 %d 天后鸡应当成年" % chicken.mature_days
	)

	# 产出：成年后再过 produce_days 个喂养日，就有鸡蛋可收。
	for _i: int in chicken.produce_days:
		mgr.feed(&"coop", player.inventory)
		mgr.advance_day(_clock.date)
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
		_clock.sleep_until_morning()
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
