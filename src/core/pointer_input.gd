class_name PointerInput
extends RefCounted
## 指针策略：键鼠模式隐藏鼠标指针并吞掉所有指针事件；触控模式两者都反过来。
##
## 本项目默认用键盘玩，所有界面都用方向键 + Enter / Esc 操作，鼠标只是"误触来源"：
## 场景根节点（[Main] / [TitleScreen]）调用 [method sync_cursor] 隐藏指针，
## 再在 [code]_input()[/code] 里用 [method swallows_pointer] + [method is_pointer] 判断并标记已处理，
## 指针事件就到不了任何 [Control]。
##
## 一旦用户在系统菜单里打开[TouchSettings]（虚拟摇杆 / 屏幕按钮），
## 同一套逻辑必须放行指针：否则摇杆、按钮、菜单里的 Button 都点不到。
## 用 [code]_input()[/code] 而不是把每个 Control.mouse_filter 改成
## [constant Control.MOUSE_FILTER_IGNORE]：后者覆盖不到动态生成的格子，
## 而且会连鼠标悬停样式一起丢掉。

## 是否是鼠标 / 触摸产生的指针事件。
static func is_pointer(event: InputEvent) -> bool:
	return (
		event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	)


## 指针事件该不该被吞掉：键鼠模式吞（隐藏的光标全是误触来源），触控模式放行。
static func swallows_pointer() -> bool:
	return not TouchSettings.is_enabled()


## 按当前操作模式同步指针可见性：键鼠隐藏光标，触控显示。
##
## 触控模式在桌面上也要能玩（触屏笔记本 / 网页版 / 调试摇杆），所以是显示而不是隐藏。
static func sync_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if TouchSettings.is_enabled() else Input.MOUSE_MODE_HIDDEN
	)


## 触控控件该不该把鼠标事件也当输入。
##
## 触摸设备上 Godot 会把触摸[b]再合成一份鼠标事件[/b]（[code]emulate_mouse_from_touch[/code]）：
## 两边都处理会让摇杆抖一下、按钮按两次，所以有触摸屏时只认触摸；
## 桌面（含使用鼠标调试的触屏笔记本）没有触摸屏，就认鼠标。
static func accepts_mouse() -> bool:
	return not DisplayServer.is_touchscreen_available()
