extends Node
## 截图工具：把游戏跑起来、等世界加载完成后截一张图。
##
## 用途：在没有编辑器的环境（CI / 远程开发机）里快速确认画面没坏。
## 需要真正的渲染后端，[code]--headless[/code] 下无法使用。
##
## 用法：
## [codeblock]
## godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn --quit-after 600
## [/codeblock]
## 输出到 [code]res://.tmp/screenshots/[/code]。

## 输出目录。
const OUTPUT_DIR: String = "res://.tmp/screenshots"
## 世界加载完成后再等多少帧才开始截图（等淡入结束、UI 稳定）。
const SETTLE_FRAMES: int = 30
## 最多等待多少帧。
const MAX_FRAMES: int = 1200

## 要截图的时刻（秒），用于抓取不同时间的画面。
@export var capture_delays: Array[float] = [0.0]

var _elapsed: float = 0.0
var _settled_at: float = -1.0
var _frames: int = 0
var _captured: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	if scene != null:
		add_child(scene.instantiate())


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta

	if _frames > MAX_FRAMES:
		push_error("Screenshot: 超时")
		get_tree().quit(1)
		return

	if _settled_at < 0.0:
		if SceneRouter.is_transitioning() or SceneRouter.current_world() == null:
			return
		if _frames < SETTLE_FRAMES:
			return
		_settled_at = _elapsed
		return

	if _captured >= capture_delays.size():
		get_tree().quit(0)
		return

	if _elapsed - _settled_at < capture_delays[_captured]:
		return
	_capture(_captured)


func _capture(index: int) -> void:
	_captured += 1
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/shot_%02d.png" % [OUTPUT_DIR, index]
	var error := image.save_png(path)
	if error != OK:
		push_error("Screenshot: 无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("截图已保存：", path)
