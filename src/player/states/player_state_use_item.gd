extends State
## 使用手上道具的状态：挥动动画 → 在判定帧结算 → 回到待机。
##
## 手上可能是工具（走 [FarmInteractor]），也可能是种子（走 [ItemUse] 播种）。
## 目标格子与"手上拿的东西"都在 [method enter] 时锁定（"抬手瞬间"确定），
## 因此挥动过程中转身或切换道具都不会影响这次判定，玩家的输入意图不会被
## 中途改写——这一点对操作手感很关键。
##
## [b]空挥[/b]：挥动是否命中由 [method FarmInteractor.use_tool] 结算，
## 但挥动本身[t]总会[/t]整套播完（含手里那件工具的转动），命中失败只是不出效果、
## 不出体力，挥空由 [FarmInteractor] 补一声挥空音。

## 一次挥动的总时长（秒）。
const SWING_DURATION: float = 0.32
## 在第几秒结算效果（对应动画的"命中帧"）。
const IMPACT_TIME: float = 0.12

var player: Player

var _elapsed: float = 0.0
var _applied: bool = false
var _tool: ToolData
var _seed: StringName = &""
var _cell: Vector2i = Vector2i.ZERO


func enter(_previous: State) -> void:
	player = actor as Player
	_elapsed = 0.0
	_applied = false
	_tool = player.item_bar.selected_tool()
	_seed = player.held_seed_id()
	_cell = player.target_cell()
	player.velocity = Vector2.ZERO
	player.play_animation(&"use")
	# 手里有工具就亮出对应贴图；空手 / 拿种子时收起。
	player.held_tool.show_tool(_tool)
	player.held_tool.apply_swing(0.0, player.facing)


func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()


func update(delta: float) -> void:
	_elapsed += delta
	player.held_tool.apply_swing(_elapsed / SWING_DURATION, player.facing)
	if not _applied and _elapsed >= IMPACT_TIME:
		_applied = true
		if _seed != &"":
			player.plant_seed(_seed, _cell)
		elif _tool != null:
			player.interactor.use_tool(_tool, _cell)
	if _elapsed >= SWING_DURATION:
		request_transition(&"idle")


func exit() -> void:
	player.play_animation(&"idle")
	player.held_tool.hide_tool()
