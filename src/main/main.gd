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
##
## [b]入口参数[/b]：标题页在切换场景之前设置 [member boot_mode] / [member boot_slot]，
## 本节点据此决定"开新档"还是"继续上次的档"。
## 用静态变量而不是新增一个 autoload，是因为这两个值
## 只在"标题页 → 游戏"这一瞬间有意义，没有跨系统共享的必要。

## 启动方式。
enum BootMode {
	NEW_GAME,   ## 从零开始
	LOAD_SLOT,  ## 读取指定槽位
}

## 本次启动的方式，由标题页设置。
static var boot_mode: BootMode = BootMode.NEW_GAME
## [constant BootMode.LOAD_SLOT] 时要读取的槽位。
static var boot_slot: int = 0

## 新游戏从哪个世界开始。
const FIRST_WORLD: String = "res://scenes/world/farm.tscn"
## 新游戏落地的出生点。
const FIRST_SPAWN: StringName = &"start"
## 快捷存 / 读档使用的槽位。
const QUICK_SLOT: int = 0
## 标题页场景路径（"回到标题"要知道回到哪）。
const TITLE_SCENE: String = "res://scenes/title/title_screen.tscn"

@onready var world_host: Node2D = %WorldHost


func _ready() -> void:
	PointerInput.hide_cursor()
	GameState.set_playtime_counting(true)
	EventBus.pause_menu_toggle_requested.connect(_on_pause_menu_requested)

	if boot_mode == BootMode.LOAD_SLOT and await _boot_from_save():
		return
	_boot_new_game()


## 回到标题页。
##
## 会先清空世界场景缓存：标题页回来时 [Main] 整棵子树都会被释放，
## 缓存里的世界节点随之作废，留着只会在下一次开新档时被复用成"上一局的农场"。
static func return_to_title(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.paused = false
	SceneRouter.clear_world_cache()
	tree.change_scene_to_file(TITLE_SCENE)


func _input(event: InputEvent) -> void:
	# 纯键盘操作：指针事件一律吞掉，避免隐藏的光标误触 UI。
	if PointerInput.is_pointer(event):
		get_viewport().set_input_as_handled()


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


# ---------------------------------------------------------------- 启动

## 读档启动；失败时返回 false，由调用方退回"开新档"。
func _boot_from_save() -> bool:
	if not SaveManager.has_save(boot_slot):
		push_warning("Main: 槽位 %d 没有存档，改为新游戏" % boot_slot)
		return false
	# 新游戏 / 读档都要丢掉上一局缓存的世界场景。
	SceneRouter.clear_world_cache()
	if await SaveManager.load_game_and_restore_world(boot_slot):
		return true
	push_warning("Main: 读取槽位 %d 失败，改为新游戏" % boot_slot)
	return false


func _boot_new_game() -> void:
	GameState.reset()
	Relationships.reset()
	GameClock.reset()
	Calendar.reset()
	SceneRouter.clear_world_cache()
	await SceneRouter.change_scene_to(FIRST_WORLD, FIRST_SPAWN)


func _quick_load() -> void:
	if not await SaveManager.load_game_and_restore_world(QUICK_SLOT):
		EventBus.notification_requested.emit(&"NOTIFY_LOAD_FAILED", {})
		return
	EventBus.notification_requested.emit(&"NOTIFY_LOADED", {"slot": QUICK_SLOT})


func _on_pause_menu_requested() -> void:
	# UiRoot 已经负责开关菜单与暂停，这里只留一个扩展点（例如自动存档）。
	pass
