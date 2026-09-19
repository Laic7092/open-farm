class_name Tool
extends RefCounted
## 一种工具的行为单元。
##
## 数值仍由 [ToolData] 给，规则不在这里复制——本类只把"这次使用"翻译成对
## 上下文（农田 / 植被 / 背包）的具体调用。粒度按 [enum ToolData.Kind]，
## 不按 id：铜锄与铁锄共用同一个工具单元，差别全在数据。
##
## 每种工具自带音效 id，由"手"在成功时请求播放，音效因此有唯一归属。

## 本单元对应的工具种类。
func kind() -> ToolData.Kind:
	return ToolData.Kind.HOE


## 使用时播放的音效；空串表示不出声。
func sfx_id() -> StringName:
	return &""


## 对上下文施加一次作用；返回是否真的产生了效果。
func apply(_ctx: ToolContext, _tool: ToolData, _cell: Vector2i) -> bool:
	return false


## 清除类工具的共同前置：目标格上的野生植被优先接管这次使用。
##
## 返回 [code]null[/code] 表示"这些格子不归植被管"，交给农田逻辑；
## 否则返回植被路径的结果（可能成功、也可能因工具等级不够而失败）。
func _clear_flora(ctx: ToolContext, tool: ToolData, cell: Vector2i) -> Variant:
	if ctx.flora == null:
		return null
	var handled: bool = false
	var success: bool = false
	for target: Vector2i in ctx.area_cells(cell, tool.area_size):
		if not bool(ctx.flora.call(&"occupied", target)):
			continue
		handled = true
		var outcome: Dictionary = ctx.flora.call(&"clear", target, tool.kind, false, tool.tier)
		if not outcome.is_empty():
			ctx.grant(outcome)
			success = true
	if not handled:
		return null
	return success
