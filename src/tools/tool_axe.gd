class_name ToolAxe
extends Tool
## 斧头：砍树桩；目标格有野生植被时先由植被接管，否则平掉翻过的地。


func kind() -> ToolData.Kind:
	return ToolData.Kind.AXE


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
