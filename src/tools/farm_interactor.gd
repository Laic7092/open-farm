class_name FarmInteractor
extends Node
## 玩家的"手"，也是工具 → 世界的中介。
##
## 它只做两件事：
## [br]1. 解析本次作用的世界上下文（农田 / 植被 / 水面 / 时钟 / 天气）[b]并注入给工具[/b]；
## [br]2. 结算通用代价（体力 / 提示 / 音效），把"每种工具做什么"交给 [Tool] 单元。
##
## 世界上下文在玩家所属的世界场景内解析，因此不做全树分组查找。
##
## [b]野生植被优先于农田[/b]：一格上如果长着树/草/石，工具先作用在它身上；
## 这一格没有植被时才回落到农田逻辑。于是"斧头砍树"和"斧头平掉翻过的地"共存。

## 一次工具使用结算完成。
signal action_finished(tool_id: StringName, cell: Vector2i, success: bool)

## 所属玩家，由 [method setup] 注入。
var player: Player
## 组合根注入的时钟；播种时读取季节。
var _clock: GameDateClock
## 组合根注入的天气服务；工具体力消耗倍率。
var _weather: WeatherService

## 每种工具一个行为单元；铜 / 铁共用同一个，差别全在 [ToolData]。
var _hoe := ToolHoe.new()
var _watering_can := ToolWateringCan.new()
var _sickle := ToolSickle.new()
var _axe := ToolAxe.new()
var _pickaxe := ToolPickaxe.new()
var _fishing := ToolFishing.new()


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


# ---------------------------------------------------------------- 世界上下文

## 当前世界里的农田；玩家所在的世界场景内解析。
func current_grid() -> FarmGrid:
	var world := _world_root()
	if world == null:
		return null
	return world.get_node_or_null("FarmGrid") as FarmGrid


## 当前世界里的野生植被。
##
## 矿洞用 [MineFloor] 接管同一个节点，两者都提供 occupied() / clear()，
## 因此这里鸭子类型地返回 Node，而不是写死 [FloraField]。
func current_flora() -> Node:
	var world := _world_root()
	if world == null:
		return null
	var field := world.get_node_or_null("FloraField")
	if field != null and field.has_method(&"occupied") and field.has_method(&"clear"):
		return field
	return null


## 当前世界里的水面标记。
func current_water() -> WaterField:
	var world := _world_root()
	if world == null:
		return null
	return world.get_node_or_null("WaterField") as WaterField


## 玩家所属的世界场景根；不在世界里时返回 null。
func _world_root() -> WorldScene:
	var node: Node = get_parent()
	while node != null:
		if node is WorldScene:
			return node
		node = node.get_parent()
	return null


## 目标格的水域类型；不是水返回 -1。
func water_kind_at(cell: Vector2i) -> int:
	var water := current_water()
	return water.kind_at(cell) if water != null else -1


## 当前天气；没有服务时按晴算。
func current_weather() -> Weather.Type:
	return _weather.current if _weather != null else Weather.Type.SUNNY


# ---------------------------------------------------------------- 使用

## 使用工具；返回是否真的产生了效果。
func use_tool(tool: ToolData, cell: Vector2i) -> bool:
	if tool == null:
		return false

	var impl := _tool_for(tool.kind)
	var success: bool = impl.apply(_context(), tool, cell)
	if success:
		consume_stamina(tool)
		_play_sfx(impl)

	action_finished.emit(tool.id, cell, success)
	EventBus.farm.tool_used.emit(tool.id, cell, success)
	return success


## 把本次作用所需的世界上下文快照交给工具。
func _context() -> ToolContext:
	var ctx := ToolContext.new()
	ctx.player = player
	ctx.grid = current_grid()
	ctx.flora = current_flora()
	ctx.water = current_water()
	ctx.clock = _clock
	ctx.weather = _weather
	return ctx


func _tool_for(kind: ToolData.Kind) -> Tool:
	match kind:
		ToolData.Kind.HOE:
			return _hoe
		ToolData.Kind.WATERING_CAN:
			return _watering_can
		ToolData.Kind.AXE:
			return _axe
		ToolData.Kind.PICKAXE:
			return _pickaxe
		ToolData.Kind.SICKLE:
			return _sickle
		_:
			return _fishing


## 工具自己的音效——由"手"所在的玩家持有播放器直接播放，空串不出声。
func _play_sfx(impl: Tool) -> void:
	var sfx_id := impl.sfx_id()
	if sfx_id != &"" and player != null and player.sfx != null:
		player.sfx.play(sfx_id, 1.0, -3.0)


func consume_stamina(tool: ToolData) -> void:
	if player == null:
		return
	var multiplier: float = _weather.stamina_multiplier() if _weather != null else 1.0
	var cost: int = int(ceilf(float(tool.stamina_cost) * multiplier))
	if cost > 0:
		player.stats.consume(cost)
