class_name ToolWateringCan
extends Tool
## 洒水壶：给目标范围里的耕地浇水。


func kind() -> ToolData.Kind:
	return ToolData.Kind.WATERING_CAN


func sfx_id() -> StringName:
	return AudioCatalog.SFX_WATER


func apply(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> bool:
	if ctx.grid == null:
		return false
	var success: bool = false
	for target: Vector2i in ctx.area_cells(cell, tool.area_size):
		if ctx.grid.water(target):
			success = true
	return success
