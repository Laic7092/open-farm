class_name PauseMenu
extends Control
## 系统菜单：继续 / 保存 / 读取 / 退出。
##
## 只通过 [SaveManager] 与 [SceneRouter] 两个门面操作游戏，
## 不直接碰任何游戏状态。

## 请求关闭菜单。
signal close_requested()

@onready var title_label: Label = %TitleLabel
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var quit_button: Button = %QuitButton
@onready var title_button: Button = %TitleButton
@onready var music_label: Label = %MusicLabel
@onready var sfx_label: Label = %SfxLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var touch_toggle: Button = %TouchToggle
@onready var touch_hint: Label = %TouchHint

func _ready() -> void:
	visible = false
	title_label.text = Text.key(&"MENU_PAUSED")
	resume_button.text = Text.key(&"MENU_RESUME")
	save_button.text = Text.key(&"MENU_SAVE")
	load_button.text = Text.key(&"MENU_LOAD")
	quit_button.text = Text.key(&"MENU_QUIT")
	title_button.text = Text.key(&"MENU_TITLE")
	music_label.text = Text.key(&"MENU_MUSIC")
	sfx_label.text = Text.key(&"MENU_SFX")
	_refresh_touch_toggle(TouchSettings.is_enabled())
	touch_toggle.toggled.connect(_on_touch_toggled)

	# 音量滑杆只改 [AudioBus] 这个共享点。
	# 先写值再连信号，避免初始化时把设置又存一遍。
	music_slider.set_value_no_signal(AudioBus.bgm_volume)
	sfx_slider.set_value_no_signal(AudioBus.sfx_volume)
	music_slider.value_changed.connect(func(value: float) -> void:
		AudioBus.set_bgm_volume(value))
	sfx_slider.value_changed.connect(func(value: float) -> void:
		AudioBus.set_sfx_volume(value))

	resume_button.pressed.connect(func() -> void: close_requested.emit())
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	title_button.pressed.connect(_on_title_pressed)


func open() -> void:
	visible = true
	# 面板可能来自更早的设置改动（或读档后），打开时同步一次。
	music_slider.set_value_no_signal(AudioBus.bgm_volume)
	sfx_slider.set_value_no_signal(AudioBus.sfx_volume)
	_refresh_touch_toggle(TouchSettings.is_enabled())
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


## 手动存档收敛成"存当前这一局"：槽位由 [SaveManager] 自己管理，菜单不再手选。
func _on_save_pressed() -> void:
	if SaveManager.save_current():
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_SAVED", {"slot": SaveManager.current_slot + 1}
		)
	else:
		EventBus.ui.notification_requested.emit(&"NOTIFY_SAVE_FAILED", {})


## 读档只重载当前这一局；要换一局请到标题页的存档列表里选。
func _on_load_pressed() -> void:
	if await SaveManager.load_current_and_restore_world():
		close_requested.emit()
	else:
		EventBus.ui.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})


func _on_quit_pressed() -> void:
	get_tree().quit()


## 回到标题页：丢掉当前这一局，重新走"标题 → 开新档 / 读档"的流程。
func _on_title_pressed() -> void:
	close()
	Main.return_to_title(get_tree())
