class_name FarmInteractor
extends Node
## 工具 → 世界的中介。
##
## 把 [ToolData]（"锄头、范围 1x1、耗体力 2"）翻译成对 [FarmGrid]（农田）
## 与 [FloraField]（野生植被）的具体调用，并负责体力结算、种子消耗与提示反馈。
## 放在玩家节点下作为子节点，因此天然拥有"玩家的手"这层语义。
##
## [b]野生植被优先于农田[/b]：一格上如果长着树/草/石，工具先作用在它身上；
## 这一格没有植被时才回落到原来的农田逻辑。于是"斧头砍树"和
## "斧头平掉翻过的地"共存，而不会出现"树脚下的土被顺手翻了"。

## 一次工具使用结算完成。
signal action_finished(tool_id: StringName, cell: Vector2i, success: bool)

## 所属玩家，由 [method setup] 注入。
var player: Player
## 组合根注入的时钟；种植时读取季节。
var _clock: GameDateClock
## 组合根注入的天气服务；工具体力消耗倍率。
var _weather: WeatherService


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


## 由 [WorldScene] 在世界进入树前下发领域服务。
func bind_services(
	weather: WeatherService,
	_relationships: RelationshipService,
	_calendar: CalendarService
) -> void:
	_weather = weather


## 由 [Player] 在 [code]_ready()[/code] 中调用。
func setup(p_player: Player) -> void:
	player = p_player


## 当前场景中的农田。
func current_grid() -> FarmGrid:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


## 当前场景中的野生植被。
##
## 矿洞用 [MineFloor] 接管同一分组，两者都提供 occupied() / clear()，
## 因此这里鸭子类型地返回 Node，而不是写死 [FloraField]。
func current_flora() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var field := tree.get_first_node_in_group(FloraField.GROUP)
	if field != null and field.has_method(&"occupied") and field.has_method(&"clear"):
		return field
	return null

## 当前场景中的水面标记。
func current_water() -> WaterField:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(WaterField.GROUP) as WaterField

## 目标格的水域类型；不是水返回 -1。
func water_kind_at(cell: Vector2i) -> int:
	var water := current_water()
	return water.kind_at(cell) if water != null else -1

## 当前天气；没有服务时按晴算。
func current_weather() -> Weather.Type:
	return _weather.current if _weather != null else Weather.Type.SUNNY


## 使用工具；返回是否真的产生了效果。
func use_tool(tool: ToolData, cell: Vector2i) -> bool:
	if tool == null:
		_notify(&"NOTIFY_NOTHING_HAPPENED")
		return false

	# 野生植被先结算：它不属于任何一张农田网格，所以不能等 grid 判空。
	if _use_tool_on_flora(tool, cell):
		return true

	var grid := current_grid()
	if grid == null:
		_notify(&"NOTIFY_NOTHING_HAPPENED")
		return false

	var success: bool = false
	for target: Vector2i in _area_cells(cell, tool.area_size):
		var worked: bool = false
		match tool.kind:
			ToolData.Kind.HOE:
				worked = grid.till(target)
			ToolData.Kind.WATERING_CAN:
				worked = grid.water(target)
			ToolData.Kind.SICKLE:
				worked = grid.clear_crop(target)
			ToolData.Kind.SEED:
				worked = _plant(grid, target)
			ToolData.Kind.AXE, ToolData.Kind.PICKAXE:
				worked = grid.revert_soil(target)
			ToolData.Kind.FISHING:
				# 钓鱼是多帧时序（抛竿 → 等鱼 → 收竿），由 PlayerStateFishing 驱动；
				# 走到这里说明状态机没有接管，按"什么也没发生"处理。
				worked = false
			_:
				worked = false
		if worked:
			success = true
		# 播种是消耗品，一次只种一格。
		if tool.kind == ToolData.Kind.SEED:
			break

	if success:
		consume_stamina(tool)
	else:
		_notify(&"NOTIFY_NOTHING_HAPPENED")

	action_finished.emit(tool.id, cell, success)
	EventBus.farm.tool_used.emit(tool.id, cell, success)
	return success


# ---------------------------------------------------------------- 内部

## 目标格上有野生植被时，由它接管这次工具使用。
##
## 返回 true 表示"这一格归植被管"——哪怕工具不对（拿斧头砍草），
## 也不该继续往下走成"把草底下的土翻了"。
func _use_tool_on_flora(tool: ToolData, cell: Vector2i) -> bool:
	if not _is_clearing_tool(tool.kind):
		return false
	var field := current_flora()
	if field == null:
		return false

	var handled: bool = false
	var success: bool = false
	for target: Vector2i in _area_cells(cell, tool.area_size):
		if not bool(field.call(&"occupied", target)):
			continue
		handled = true
		var outcome: Dictionary = field.call(&"clear", target, tool.kind, false, tool.tier)
		if not outcome.is_empty():
			_grant(outcome)
			success = true
	if not handled:
		return false

	if success:
		consume_stamina(tool)
	else:
		_notify(&"NOTIFY_NOTHING_HAPPENED")

	action_finished.emit(tool.id, cell, success)
	EventBus.farm.tool_used.emit(tool.id, cell, success)
	return true


## 以目标格为中心展开的作用范围（格子列表）。奇数边长时严格居中，偶数时偏向右下。
func _area_cells(cell: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var width: int = maxi(size.x, 1)
	var height: int = maxi(size.y, 1)
	var offset_x: int = (width - 1) / 2
	var offset_y: int = (height - 1) / 2
	for y: int in height:
		for x: int in width:
			cells.append(cell + Vector2i(x - offset_x, y - offset_y))
	return cells


func _is_clearing_tool(kind: ToolData.Kind) -> bool:
	return (
		kind == ToolData.Kind.AXE
		or kind == ToolData.Kind.PICKAXE
		or kind == ToolData.Kind.SICKLE
	)


## 把清除植被的产出放进背包并提示玩家。
func _grant(outcome: Dictionary) -> void:
	var item_id: StringName = outcome.get("item_id", &"")
	var amount: int = int(outcome.get("amount", 0))
	if item_id == &"" or amount <= 0:
		return
	if player != null:
		player.inventory.add(item_id, amount, int(outcome.get("quality", 0)))
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_FLORA_CLEARED", {"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)


func _plant(grid: FarmGrid, cell: Vector2i) -> bool:
	if player == null:
		return false
	var seed_id: StringName = player.effective_seed_id()
	if seed_id == &"" or not player.inventory.has(seed_id):
		return false
	if _clock == null or not grid.plant(cell, seed_id, _clock.date.season):
		return false

	player.inventory.remove(seed_id, 1)
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_PLANTED", {"item": Text.item_name(Database.get_item(seed_id))}
	)
	return true


func consume_stamina(tool: ToolData) -> void:
	if player == null:
		return
	var multiplier: float = _weather.stamina_multiplier() if _weather != null else 1.0
	var cost: int = int(ceilf(float(tool.stamina_cost) * multiplier))
	if cost > 0:
		player.stats.consume(cost)


func _notify(text_key: StringName, args: Dictionary = {}) -> void:
	EventBus.ui.notification_requested.emit(text_key, args)
