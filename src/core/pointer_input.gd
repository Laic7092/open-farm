class_name PointerInput
extends RefCounted
## 指针策略：保证鼠标指针可见，键盘与鼠标并行操作。
##
## 光标常显、指针事件照常下发，UI 用鼠标点得到，键盘焦点导航不受影响。
##
## 触控设备上 Godot 会把触摸再合成一份鼠标事件，[method accepts_mouse] 用来让
## 摇杆 / ABXY 只认其中一种，避免同一次触摸被处理两遍。

## 确保鼠标指针可见；无头（测试）环境没有指针，直接跳过。
static func sync_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## 触控控件该不该把鼠标事件也当输入。
##
## 触摸设备上 Godot 会把触摸[b]再合成一份鼠标事件[/b]（[code]emulate_mouse_from_touch[/code]）：
## 两边都处理会让摇杆抖一下、按钮按两次，所以有触摸屏时只认触摸；
## 桌面（含使用鼠标调试的触屏笔记本）没有触摸屏，就认鼠标。
static func accepts_mouse() -> bool:
	return not DisplayServer.is_touchscreen_available()
