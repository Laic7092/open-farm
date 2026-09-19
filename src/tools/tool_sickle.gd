class_name ToolSickle
extends Tool
## 镰刀：割草 / 清除枯死作物；目标格有野生植被时先由植被接管。


func kind() -> ToolData.Kind:
	return ToolData.Kind.SICKLE


func sfx_id() -> StringName:
	return AudioCatalog.SFX_TOOL_SWING


func apply(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> bool:
	var flora: Variant = _clear_flora(ctx, tool, cell)
	if flora != null:
		return flora
	if ctx.grid == null:
		return false
	var success: bool = false
	for target: Vector2i in ctx.area_cells(cell, tool.area_size):
		if ctx.grid.clear_crop(target):
			success = true
	return success
