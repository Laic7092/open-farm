class_name PauseMenu
extends Control
## 系统菜单：继续 / 画面与音量设置 / 回标题 / 退出。
##
## 只发请求（关菜单、回标题、改设置），不直接碰任何游戏状态；
## 存档由日结自动存档与标题页的存档列表负责。

## 请求关闭菜单。
signal close_requested()

@onready var title_label: Label = %TitleLabel
@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton
@onready var title_button: Button = %TitleButton
@onready var music_label: Label = %MusicLabel
@onready var sfx_label: Label = %SfxLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var zoom_label: Label = %ZoomLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var touch_toggle: Button = %TouchToggle
@onready var touch_hint: Label = %TouchHint

func _ready() -> void:
	visible = false
	title_label.text = Text.key(&"MENU_PAUSED")
	resume_button.text = Text.key(&"MENU_RESUME")
	quit_button.text = Text.key(&"MENU_QUIT")
	title_button.text = Text.key(&"MENU_TITLE")
	music_label.text = Text.key(&"MENU_MUSIC")
	sfx_label.text = Text.key(&"MENU_SFX")
	_refresh_touch_toggle(TouchSettings.is_enabled())
	touch_toggle.toggled.connect(_on_touch_toggled)

	# 画面大小只改 [ViewSettings] 这个纯数据设置，应用交给相机的主人（玩家）。
	zoom_slider.min_value = ViewSettings.ZOOM_MIN
	zoom_slider.max_value = ViewSettings.ZOOM_MAX
	zoom_slider.step = ViewSettings.ZOOM_STEP
	zoom_slider.set_value_no_signal(ViewSettings.zoom())
	_refresh_zoom_label(ViewSettings.zoom())
	zoom_slider.value_changed.connect(_on_zoom_changed)

	# 音量滑杆只改 [AudioBus] 这个共享点。
	# 先写值再连信号，避免初始化时把设置又存一遍。
	music_slider.set_value_no_signal(AudioBus.bgm_volume)
	sfx_slider.set_value_no_signal(AudioBus.sfx_volume)
	music_slider.value_changed.connect(func(value: float) -> void:
		AudioBus.set_bgm_volume(value))
	sfx_slider.value_changed.connect(func(value: float) -> void:
		AudioBus.set_sfx_volume(value))

	resume_button.pressed.connect(func() -> void: close_requested.emit())
	quit_button.pressed.connect(_on_quit_pressed)
	title_button.pressed.connect(_on_title_pressed)


func open() -> void:
	visible = true
	# 面板可能来自更早的设置改动（或读档后），打开时同步一次。
	music_slider.set_value_no_signal(AudioBus.bgm_volume)
	sfx_slider.set_value_no_signal(AudioBus.sfx_volume)
	_refresh_touch_toggle(TouchSettings.is_enabled())
	zoom_slider.set_value_no_signal(ViewSettings.zoom())
	_refresh_zoom_label(ViewSettings.zoom())
	resume_button.grab_focus()


func close() -> void:
	visible = false


## 存进 [TouchSettings] 并广播，让触控层与指针策略当场生效。
func _on_touch_toggled(toggled_on: bool) -> void:
	TouchSettings.set_enabled(toggled_on)
	_refresh_touch_toggle(toggled_on)
	EventBus.ui.touch_controls_toggled.emit(toggled_on)


## 文案跟着状态走，所以是"虚拟摇杆：开 / 关"而不是一个复选框。
##
## 顺便把 ABXY 的键位写在这里：圆里塞不下中文，屏幕上的摇杆自己说不清楚。
func _refresh_touch_toggle(enabled: bool) -> void:
	touch_toggle.set_pressed_no_signal(enabled)
	touch_toggle.text = Text.format(&"MENU_TOUCH_CONTROLS", {
		"state": Text.key(&"MENU_ON" if enabled else &"MENU_OFF"),
	})
	touch_hint.text = Text.key(&"TOUCH_HINT")
	touch_hint.visible = enabled


## 画面大小滑杆：只写 [ViewSettings] 并广播，应用由相机的主人决定。
func _on_zoom_changed(value: float) -> void:
	ViewSettings.set_zoom(value)
	_refresh_zoom_label(ViewSettings.zoom())
	EventBus.ui.view_zoom_changed.emit(ViewSettings.zoom())


func _refresh_zoom_label(value: float) -> void:
	zoom_label.text = Text.format(&"MENU_ZOOM", {"value": "%.2f" % value})


func _on_quit_pressed() -> void:
	get_tree().quit()


## 回到标题页：丢掉当前这一局，重新走"标题 → 开新档 / 读档"的流程。
func _on_title_pressed() -> void:
	close()
	Main.return_to_title(get_tree())
