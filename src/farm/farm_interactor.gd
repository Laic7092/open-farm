class_name FarmInteractor
extends Node
## 工具 → 农场的中介。
##
## 把 [ToolData]（"锄头、范围 1x1、耗体力 2"）翻译成对 [FarmGrid] 的具体调用，
## 并负责体力结算、种子消耗与提示反馈。
## 放在玩家节点下作为子节点，因此天然拥有"玩家的手"这层语义。

## 一次工具使用结算完成。
signal action_finished(tool_id: StringName, cell: Vector2i, success: bool)

## 所属玩家，由 [method setup] 注入。
var player: Player


## 由 [Player] 在 [code]_ready()[/code] 中调用。
func setup(p_player: Player) -> void:
	player = p_player


## 当前场景中的农田。
func current_grid() -> FarmGrid:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(FarmGrid.GROUP) as FarmGrid


## 使用工具；返回是否真的产生了效果。
func use_tool(tool: ToolData, cell: Vector2i) -> bool:
	var grid := current_grid()
	if grid == null or tool == null:
		_notify(&"NOTIFY_NOTHING_HAPPENED")
		return false

	var success: bool = false
	match tool.kind:
		ToolData.Kind.HOE:
			success = grid.till(cell)
		ToolData.Kind.WATERING_CAN:
			success = grid.water(cell)
		ToolData.Kind.SICKLE:
			success = grid.clear_crop(cell)
		ToolData.Kind.SEED:
			success = _plant(grid, cell)
		ToolData.Kind.AXE, ToolData.Kind.PICKAXE:
			success = grid.revert_soil(cell)
		_:
			success = false

	if success:
		_consume_stamina(tool)
	else:
		_notify(&"NOTIFY_NOTHING_HAPPENED")

	action_finished.emit(tool.id, cell, success)
	EventBus.tool_used.emit(tool.id, cell, success)
	return success


# ---------------------------------------------------------------- 内部

func _plant(grid: FarmGrid, cell: Vector2i) -> bool:
	if player == null:
		return false
	var seed_id: StringName = player.effective_seed_id()
	if seed_id == &"" or not player.inventory.has(seed_id):
		return false
	if not grid.plant(cell, seed_id, GameClock.date.season):
		return false

	player.inventory.remove(seed_id, 1)
	EventBus.notification_requested.emit(
		&"NOTIFY_PLANTED", {"item": Text.item_name(seed_id)}
	)
	return true


func _consume_stamina(tool: ToolData) -> void:
	if player == null:
		return
	var cost: int = int(ceilf(float(tool.stamina_cost) * WeatherSystem.stamina_multiplier()))
	if cost > 0:
		player.stats.consume(cost)


func _notify(text_key: StringName, args: Dictionary = {}) -> void:
	EventBus.notification_requested.emit(text_key, args)
