class_name PointerInput
extends RefCounted
## 纯键盘操作：隐藏鼠标指针，并吞掉所有指针事件。
##
## 本项目所有界面都用方向键 + Enter / Esc 操作，鼠标只是"误触来源"。
## 场景根节点（[Main] / [TitleScreen]）调用 [method hide_cursor] 隐藏指针，
## 再在 [code]_input()[/code] 里用 [method is_pointer] 判断并标记已处理，
## 指针事件就到不了任何 [Control]。
##
## 用 [code]_input()[/code] 而不是把每个 [member Control.mouse_filter] 改成
## [constant Control.MOUSE_FILTER_IGNORE]：后者覆盖不到动态生成的格子，
## 而且会连鼠标悬停样式一起丢掉。

## 是否是鼠标 / 触摸产生的指针事件。
static func is_pointer(event: InputEvent) -> bool:
	return (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	)


## 隐藏鼠标指针；无头（测试）环境里没有指针，直接跳过。
static func hide_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
