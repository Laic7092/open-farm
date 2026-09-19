class_name ToolPickaxe
extends Tool
## 镐：碎石 / 采矿；行为与斧头同型（植被优先，否则平掉翻过的地）。


func kind() -> ToolData.Kind:
	return ToolData.Kind.PICKAXE


func sfx_id() -> StringName:
	return AudioCatalog.SFX_CHOP


func apply(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> bool:
	var flora: Variant = _clear_flora(ctx, tool, cell)
	if flora != null:
		return flora
	if ctx.grid == null:
		return false
	var success: bool = false
	for target: Vector2i in ctx.area_cells(cell, tool.area_size):
		if ctx.grid.revert_soil(target):
			success = true
	return success
