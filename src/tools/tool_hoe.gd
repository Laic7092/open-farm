class_name ToolHoe
extends Tool
## 锄头：把目标范围里的格子翻成耕地。


func kind() -> ToolData.Kind:
	return ToolData.Kind.HOE


func sfx_id() -> StringName:
	return AudioCatalog.SFX_TILL


func apply(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> bool:
	if ctx.grid == null:
		return false
	var success: bool = false
	for target: Vector2i in ctx.area_cells(cell, tool.area_size):
		if ctx.grid.till(target):
			success = true
	return success
