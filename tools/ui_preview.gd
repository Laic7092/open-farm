extends Node
## UI 预览工具：把每个界面依次打开并截图，用来检查手写场景的布局。
##
## 需要真正的渲染后端（[code]--headless[/code] 下无法截图）。
##
## 用法：[code]godot --path . --rendering-driver opengl3 res://tools/ui_preview.tscn[/code]
## 输出到 [code]res://.tmp/ui_preview/[/code]。

const OUTPUT_DIR: String = "res://.tmp/ui_preview"
## 打开界面后等多少帧再截图（等容器完成布局）。
const SETTLE_FRAMES: int = 8
## 全部界面跑完后等多少帧再退出。
const MAX_FRAMES: int = 4000

## 每个预览步骤：名称 + 打开动作。
var _steps: Array[Dictionary] = []
var _index: int = -1
var _frames: int = 0
var _settle: int = 0
var _world_ready: bool = false


func _ready() -> void:
	# 界面会暂停整棵树，预览工具必须能在暂停时继续跑。
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_steps = [
		{"name": "01_inventory", "open": _open_inventory},
		{"name": "02_dialogue", "open": _open_dialogue},
		{"name": "03_shop", "open": _open_shop},
		{"name": "04_pause_menu", "open": _open_pause_menu},
	]
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	if scene != null:
		add_child(scene.instantiate())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		push_error("UiPreview: 超时")
		get_tree().quit(1)
		return

	if not _world_ready:
		if SceneRouter.is_transitioning() or SceneRouter.current_world() == null:
			return
		_world_ready = true
		_next()
		return

	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_capture()
		return


func _next() -> void:
	if _index >= 0 and _index < _steps.size():
		_close_current()
	_index += 1
	if _index >= _steps.size():
		print("UI 预览完成 → ", OUTPUT_DIR)
		get_tree().quit(0)
		return
	var step: Dictionary = _steps[_index]
	var open: Callable = step["open"]
	open.call()
	_settle = SETTLE_FRAMES


func _capture() -> void:
	var step: Dictionary = _steps[_index]
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, step["name"]]
	if image.save_png(path) == OK:
		print("截图已保存：", path)
	_next()


# ---------------------------------------------------------------- 打开动作

func _open_inventory() -> void:
	EventBus.ui.inventory_toggle_requested.emit()


func _open_dialogue() -> void:
	EventBus.ui.dialogue_requested.emit(Database.get_dialogue(&"merchant_greeting"))


func _open_shop() -> void:
	EventBus.ui.shop_requested.emit(&"general_store")


func _open_pause_menu() -> void:
	EventBus.ui.pause_menu_toggle_requested.emit()


func _close_current() -> void:
	var ui := get_tree().root.find_child("UiRoot", true, false) as UiRoot
	if ui != null:
		ui.close_all()
	else:
		get_tree().paused = false
