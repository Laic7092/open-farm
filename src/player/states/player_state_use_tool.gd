extends State
## 使用工具状态：挥动动画 → 在判定帧结算 → 回到待机。
##
## 目标格子与工具都在 [method enter] 时锁定（"抬手瞬间"确定），
## 因此挥动过程中转身或切换工具都不会影响这次判定，
## 玩家的输入意图不会被中途改写——这一点对操作手感很关键。

## 一次挥动的总时长（秒）。
const SWING_DURATION: float = 0.32
## 在第几秒结算效果（对应动画的"命中帧"）。
const IMPACT_TIME: float = 0.12

var player: Player

var _elapsed: float = 0.0
var _applied: bool = false
var _tool: ToolData
var _cell: Vector2i = Vector2i.ZERO


func enter(_previous: State) -> void:
	player = actor as Player
	_elapsed = 0.0
	_applied = false
	_tool = player.item_bar.selected_tool()
	_cell = player.target_cell()
	player.velocity = Vector2.ZERO
	player.play_animation(&"use")


func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()


func update(delta: float) -> void:
	_elapsed += delta
	if not _applied and _elapsed >= IMPACT_TIME:
		_applied = true
		if _tool == null:
			EventBus.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
		else:
			player.interactor.use_tool(_tool, _cell)
	if _elapsed >= SWING_DURATION:
		request_transition(&"idle")


func exit() -> void:
	player.play_animation(&"idle")
