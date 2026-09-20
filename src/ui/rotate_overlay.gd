class_name RotateOverlay
extends CanvasLayer
## 竖屏提示遮罩：本作只服务横屏，窗口「高 ≥ 宽」时盖住画面、吞掉输入并暂停整棵树，
## 提示玩家旋转设备。[Main] 与标题页各自在 [code]_ready()[/code] 里挂一个。
##
## 归属：它是「窗口方向」这个全局显示事实的 UI 投影——自己读 [method Window.size]，
## 监听 [signal Window.size_changed] 并逐帧比对兜底（Web 旋转时信号可能漏报），
## 不依赖任何域，也不新增 Autoload。

## 压在常驻 UI 之上（[code]UiRoot[/code] 是 10），保证竖屏时盖住一切。
const LAYER: int = 100
## 提示文案的翻译键。
const HINT_KEY: StringName = &"ROTATE_DEVICE_HINT"
## 提示文案字号；竖屏时它是全屏唯一内容，给足尺寸才看得清。
const HINT_FONT_SIZE: int = 32

## 遮罩本体；它的 [member CanvasItem.visible] 即「是否正在提示旋转」。
var _dim: ColorRect
## 登录过的窗口，用于进出树时连 / 断尺寸变化。
var _window: Window
## 上一次看到的窗口尺寸；[method _process] 用它兜底补一次信号漏报。
var _last_size: Vector2i = Vector2i.ZERO
## 遮罩弹出前的暂停状态；收起时恢复，免得抢走模态界面正在用的暂停。
var _paused_before: bool = false
## 遮罩当前是否已经接管暂停。
var _pause_taken: bool = false


## 纯函数：窗口是否需要提示旋转（竖屏与正方形都算非横屏）。
## 尺寸为 0（窗口未就绪）不算竖屏，否则会误弹遮罩吞掉输入。
static func should_show(window_size: Vector2i) -> bool:
	if window_size.x <= 0 or window_size.y <= 0:
		return false
	return window_size.x <= window_size.y


func _ready() -> void:
	# 旋转提示压在暂停之上：模态界面暂停整棵树时也要能弹出来，并接管暂停。
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	_build()
	_window = get_window()
	if _window != null:
		_last_size = _window.size
		if not _window.size_changed.is_connected(_refresh):
			_window.size_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	# Web / 移动端旋转屏幕时 [signal Window.size_changed] 可能漏报，
	# 逐帧比对窗口尺寸兜底；信号正常时这里不会重复刷新。
	if _window != null and _window.size != _last_size:
		_refresh()
	# 别的清场逻辑（切回标题页）可能把暂停改回运行，竖屏期间每帧补一次。
	_apply_pause(_dim != null and _dim.visible)


func _exit_tree() -> void:
	if _window != null and _window.size_changed.is_connected(_refresh):
		_window.size_changed.disconnect(_refresh)
	# 遮罩随场景一起走时也要把暂停还回去，别把下一幕冻在暂停里。
	_apply_pause(false)
	_window = null


func _input(event: InputEvent) -> void:
	# 竖屏下也可能有键盘输入；遮罩可见时吞掉，别让玩家在不受支持的构图里操作。
	if _dim != null and _dim.visible and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _dim == null:
		return
	if _window != null:
		_last_size = _window.size
	# 无头环境没有真实屏幕方向（测试窗口往往是方块），一律不提示，
	# 否则会盖住画面、吞掉合成输入，把冒烟测试打成假红。
	var headless := DisplayServer.get_name() == "headless"
	_dim.visible = not headless and _window != null and should_show(_window.size)
	_apply_pause(_dim.visible)


## 竖屏遮罩也要冻结世界：否则玩家会在看不见的构图里继续走动、时间继续流逝。
##
## 只收回自己造成的那次暂停：弹出前若树已暂停（模态界面），收起时保持暂停。
func _apply_pause(pressed: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if pressed:
		if not _pause_taken:
			_paused_before = tree.paused
			_pause_taken = true
		tree.paused = true
	elif _pause_taken:
		_pause_taken = false
		tree.paused = _paused_before


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.06, 0.08, 1.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP：盖住时同时吞掉触控，避免点到底下的按钮。
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

	var hint := Label.new()
	hint.text = Text.key(HINT_KEY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(hint)
