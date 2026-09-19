class_name ToolSeed
extends Tool
## 种子：把手里选中的种子种进目标格；一次只种一格（消耗品）。


func kind() -> ToolData.Kind:
	return ToolData.Kind.SEED


func sfx_id() -> StringName:
	return AudioCatalog.SFX_PLANT


func apply(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> bool:
	if ctx.grid == null or ctx.player == null:
		return false
	if tool == null:
		return false
	var seed_id: StringName = ctx.player.effective_seed_id()
	if seed_id == &"" or not ctx.player.inventory.has(seed_id):
		return false
	if ctx.clock == null or not ctx.grid.plant(cell, seed_id, ctx.clock.date.season):
		return false
	ctx.player.inventory.remove(seed_id, 1)
	ctx.notify(&"NOTIFY_PLANTED", {"item": Text.item_name(Database.get_item(seed_id))})
	return true
