class_name Main
extends Node2D
## 游戏主入口（常驻节点）。
##
## 结构：
## [codeblock]
## Main
## ├── WorldHost   ← 世界场景在这里被换进换出（组 world_host）
## └── UiRoot      ← CanvasLayer，常驻不销毁
## [/codeblock]
##
## 世界场景用"换子节点"而不是 [method SceneTree.change_scene_to_file]，
## 这样 UI、全局输入、存档系统都不会因为一次传送被重建。

## 新游戏从哪个世界开始。
const FIRST_WORLD: String = "res://scenes/world/farm.tscn"
## 新游戏落地的出生点。
const FIRST_SPAWN: StringName = &"start"
## 快捷存 / 读档使用的槽位。
const QUICK_SLOT: int = 0

@onready var world_host: Node2D = %WorldHost


func _ready() -> void:
	GameState.set_playtime_counting(true)
	EventBus.pause_menu_toggle_requested.connect(_on_pause_menu_requested)
	await SceneRouter.change_scene_to(FIRST_WORLD, FIRST_SPAWN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		SaveManager.save_game(QUICK_SLOT)
		EventBus.notification_requested.emit(
			&"NOTIFY_SAVED", {"slot": QUICK_SLOT}
		)
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		_quick_load()


func _quick_load() -> void:
	if not await SaveManager.load_game_and_restore_world(QUICK_SLOT):
		EventBus.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})
		return
	EventBus.notification_requested.emit(&"NOTIFY_LOADED", {"slot": QUICK_SLOT})


func _on_pause_menu_requested() -> void:
	# UiRoot 已经负责开关菜单与暂停，这里只留一个扩展点（例如自动存档）。
	pass
