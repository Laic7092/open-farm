class_name TouchButton
extends Control
## 触控用的圆形动作键：手柄 ABXY 的圆形外观 + "按下 / 松开"两个事件。
##
## 只负责画圆与报告按压状态，不碰 [Input]——动作名与注入都在 [TouchControls] 里，
## 于是"界面隐藏时要释放哪些键"和摇杆共用同一套逻辑。
##
## [b]为什么不用 [Button][/b]：项目主题里的按钮皮肤是九宫格方角贴图，
## 要做圆角要么给生成器加一套圆形贴图、要么在场景里写死 [StyleBoxFlat] 的颜色
## （颜色必须来自 [ArtPalette]），两条路都更重；这里直接 [method CanvasItem._draw]，
## 与 [TouchStick] 同一套做法。
##
## [b]与 [Button] 的差异[/b]：没有焦点。触控按钮一旦能拿焦点，
## 方向键就会先在按钮之间跳，游戏里的移动 / 菜单导航会被抢。

## 圆里的图标：当前使用 ABXY 字母；菜单键已并入 B。
##
## [constant Glyph.MENU] 保留给未来可能重新加入的独立菜单键。
enum Glyph {
	LETTER,
	MENU,
}

## 按下 / 松开；外层据此注入或释放输入动作。
signal pressed()
signal released()

## [constant Glyph.LETTER] 时圆里显示的字母（当前只使用这一种）。
@export var text: String = ""
@export var glyph: Glyph = Glyph.LETTER

## 当前是否被按住（用于画高亮）。
var _held: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## 当前是否处于按下状态。
func is_held() -> bool:
	return _held


## 强制回到未按下状态（界面切上下文 / 隐藏时调用）。
##
## 与 [signal released] 不同：这里不发出松开信号，因为上层已经统一释放过动作，
## 只把按钮自己的高亮和内部状态清掉，避免"手指还没抬界面就切走"导致下次按不动。
func reset_held() -> void:
	if not _held:
		return
	_held = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_set_held((event as InputEventScreenTouch).pressed)
	elif PointerInput.accepts_mouse():
		# 桌面（含触屏笔记本调试 / 网页版）只有鼠标：也当成一次按压。
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index == MOUSE_BUTTON_LEFT:
				_set_held(button.pressed)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 1.0
	if radius <= 0.0:
		return
	# 底色要够暗、够实，不然字母在花花绿绿的地图上看不清；
	# 按下时整颗钉变成金色，和摇杆头的反馈一致。
	var face := Color(ArtPalette.UI_PANEL_DARK, 0.85 if _held else 0.7)
	var ink := ArtPalette.UI_GOLD if _held else ArtPalette.UI_TEXT
	var ring := Color(ArtPalette.UI_GOLD if _held else ArtPalette.UI_PANEL_LIGHT, 0.95 if _held else 0.8)
	draw_circle(center, radius, face)
	draw_arc(center, radius, 0.0, TAU, 24, ring, 2.0, false)
	if glyph == Glyph.MENU:
		_draw_menu_glyph(center, radius, ink)
	else:
		_draw_letter(center, radius, ink)


func _set_held(value: bool) -> void:
	if value == _held:
		return
	_held = value
	queue_redraw()
	if _held:
		pressed.emit()
	else:
		released.emit()


## 字母用主题默认字体画：与其余 UI 同一套像素字体，不额外引资源。
func _draw_letter(center: Vector2, radius: float, ink: Color) -> void:
	if text.is_empty():
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size: int = get_theme_default_font_size()
	var baseline: float = center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(
		font,
		Vector2(center.x - radius, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		font_size,
		ink
	)


## 菜单图标：三条横杠，尺寸跟着圆走。
func _draw_menu_glyph(center: Vector2, radius: float, color: Color) -> void:
	var half_width: float = radius * 0.5
	for index: int in 3:
		var y: float = center.y + (float(index) - 1.0) * (radius * 0.36)
		draw_line(
			Vector2(center.x - half_width, y), Vector2(center.x + half_width, y), color, 2.0, false
		)
