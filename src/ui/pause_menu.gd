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


func _ready() -> void:
	visible = false
	title_label.text = Text.key(&"MENU_PAUSED")
	resume_button.text = Text.key(&"MENU_RESUME")
	save_button.text = Text.key(&"MENU_SAVE")
	load_button.text = Text.key(&"MENU_LOAD")
	quit_button.text = Text.key(&"MENU_QUIT")

	resume_button.pressed.connect(func() -> void: close_requested.emit())
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func open() -> void:
	visible = true
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
