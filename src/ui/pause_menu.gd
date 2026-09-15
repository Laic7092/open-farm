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

## 本场景的音频节点；由 [UiRoot] 注入，独立预览时按分组兜底。
var _audio: SceneAudio


## 由 [UiRoot] 注入本场景的音频节点。
func bind_audio(audio: SceneAudio) -> void:
	_audio = audio


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

	# 未注入时（单场景预览）退化到按分组找场景音频节点。
	if _audio == null:
		_audio = get_tree().get_first_node_in_group(SceneAudio.GROUP) as SceneAudio

	# 先写值再连信号，避免初始化时把设置又存一遍。
	if _audio != null:
		music_slider.set_value_no_signal(_audio.bgm_volume)
		sfx_slider.set_value_no_signal(_audio.sfx_volume)
	music_slider.value_changed.connect(func(value: float) -> void:
		if _audio != null:
			_audio.set_bgm_volume(value))
	sfx_slider.value_changed.connect(func(value: float) -> void:
		if _audio != null:
			_audio.set_sfx_volume(value))

	resume_button.pressed.connect(func() -> void: close_requested.emit())
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	title_button.pressed.connect(_on_title_pressed)


func open() -> void:
	visible = true
	# 面板可能来自更早的设置改动（或读档后），打开时同步一次。
	if _audio != null:
		music_slider.set_value_no_signal(_audio.bgm_volume)
		sfx_slider.set_value_no_signal(_audio.sfx_volume)
	resume_button.grab_focus()


func close() -> void:
	visible = false


func _on_save_pressed() -> void:
	SaveManager.save_game(0)


func _on_load_pressed() -> void:
	if await SaveManager.load_game_and_restore_world(0):
		close_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()


## 回到标题页：丢掉当前这一局，重新走"标题 → 开新档 / 读档"的流程。
func _on_title_pressed() -> void:
	close()
	Main.return_to_title(get_tree())
