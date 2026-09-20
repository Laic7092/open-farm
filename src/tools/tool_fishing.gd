class_name ToolFishing
extends Tool
## 钓竿：不在地面上结算多帧时序，由 [FishingSession] 驱动。
##
## 走到这里说明状态机没有接管这次使用，按"没有效果"处理。


func kind() -> ToolData.Kind:
	return ToolData.Kind.FISHING


func apply(_ctx: ToolContext, _tool: ToolData, _cell: Vector2i) -> bool:
	return false
