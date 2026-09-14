extends Node
## 截图工具：把标题页与游戏跑起来、按顺序各截几张图。
##
## 用途：在没有编辑器的环境（CI / 远程开发机）里快速确认画面没坏——
## 尤其是"美术是脚本生成的"这件事：改完生成器跑一次截图就知道有没有画崩。
## 需要真正的渲染后端，[code]--headless[/code] 下无法使用。
##
## 整个流程写成一条协程：每一步都是"等一下 → 截一张"，
## 比手写帧计数器状态机好读，也不会出现"截图还没落盘就切了场景"。
##
## 用法：
## [codeblock]
## godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn
## [/codeblock]
## 输出到 [code]res://.tmp/screenshots/[/code]：
## [code]title.png[/code]、[code]shot_00.png[/code]…、[code]town.png[/code]、[code]twon.png[/code]。

## 输出目录。
const OUTPUT_DIR: String = "res://.tmp/screenshots"
const TITLE_SCENE: String = "res://scenes/title/title_screen.tscn"
const GAME_SCENE: String = "res://scenes/main/main.tscn"
const TOWN_SCENE: String = "res://scenes/world/town.tscn"
const TWON_SCENE: String = "res://scenes/world/twon.tscn"
const BEACH_SCENE: String = "res://scenes/world/beach.tscn"
const MINE_SCENE: String = "res://scenes/world/mine.tscn"
const LIBRARY_SCENE: String = "res://scenes/world/library.tscn"

## 标题页稳定后再等多少帧截图（等云飘一点、布局完成）。
const TITLE_SETTLE_FRAMES: int = 20
## 世界加载完成后再等多少帧才开始截图（等淡入结束、UI 稳定）。
const SETTLE_FRAMES: int = 30
## 总帧数上限，防止某个 await 永远等不到。
const MAX_FRAMES: int = 2400

## 进入游戏后要截图的时刻（秒），用于抓取不同时间的画面。
@export var capture_delays: Array[float] = [0.0]
## 是否先截标题页（关掉可以只测游戏内画面）。
@export var capture_title: bool = true
## 是否顺带截一张集市（村庄与海滩之间的那一站）。
@export var capture_town: bool = true
## 是否顺带截一张村庄（大场景 twon）。
@export var capture_twon: bool = true
## 是否顺带截新增地图：海滩 / 矿洞 / 图书馆。
@export var capture_extras: bool = true

var _frames: int = 0
var _current: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_run()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		push_error("Screenshot: 超时")
		get_tree().quit(1)


# ---------------------------------------------------------------- 流程

func _run() -> void:
	if capture_title:
		_instantiate(TITLE_SCENE)
		await _wait_frames(TITLE_SETTLE_FRAMES)
		await _capture("title")

	Main.boot_mode = Main.BootMode.NEW_GAME
	_instantiate(GAME_SCENE)
	if not await _wait_world():
		return

	for index: int in capture_delays.size():
		if capture_delays[index] > 0.0:
			await _wait_seconds(capture_delays[index])
		await _capture("shot_%02d" % index)

	if capture_town:
		SceneRouter.change_scene_to(TOWN_SCENE, &"from_twon")
		if not await _wait_world():
			return
		await _capture("town")

	if capture_twon:
		SceneRouter.change_scene_to(TWON_SCENE, &"from_farm")
		if not await _wait_world():
			return
		await _capture("twon")

	if capture_extras:
		if not await _capture_world(BEACH_SCENE, &"from_town", "beach"):
			return
		if not await _capture_world(MINE_SCENE, &"from_beach", "mine"):
			return
		if not await _capture_world(LIBRARY_SCENE, &"from_twon", "library"):
			return

	print("截图完成 → ", OUTPUT_DIR)
	get_tree().quit(0)


## 切到某张地图并截一张图；等待超时时返回 false。
func _capture_world(path: String, spawn_id: StringName, name: String) -> bool:
	SceneRouter.change_scene_to(path, spawn_id)
	if not await _wait_world():
		return false
	await _capture(name)
	return true


## 等世界加载完成（含淡入淡出）；超时返回 false 并让流程结束。
func _wait_world() -> bool:
	var guard: int = 0
	while SceneRouter.is_transitioning() or SceneRouter.current_world() == null:
		guard += 1
		if guard > MAX_FRAMES:
			push_error("Screenshot: 等待世界加载超时")
			get_tree().quit(1)
			return false
		await get_tree().process_frame
	await _wait_frames(SETTLE_FRAMES)
	return true


func _wait_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _instantiate(path: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		push_error("Screenshot: 无法加载 %s" % path)
		get_tree().quit(1)
		return
	# 必须真正释放上一个场景：queue_free() 要等到帧末，
	# 那时候截图已经把两个场景叠在一起拍下来了。
	if _current != null and is_instance_valid(_current):
		remove_child(_current)
		_current.free()
	_current = scene.instantiate()
	add_child(_current)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Screenshot: 无法写入 %s（错误码 %d）" % [path, error])
	else:
		print("截图已保存：", path)
