class_name PlayerStateFishing
extends State
## 钓鱼状态的"模式锁"壳：锁住移动 + 把输入转给 [member Player.fishing]。
##
## 这里不写任何钓鱼逻辑——阶段时序、拉扯小游戏、浮标与音效都在
## [FishingSession] 里；本状态只负责"此刻玩家在钓鱼"这件事本身，
## 并在单元结束时切回待机。钓鱼期间举着的钓竿由 [HeldToolView] 画，
## 鱼线起点取自它的 [method HeldToolView.tip_position]。

var player: Player


func enter(_previous: State) -> void:
	player = actor as Player
	player.velocity = Vector2.ZERO
	if not player.fishing.finished.is_connected(_on_finished):
		player.fishing.finished.connect(_on_finished)
	player.fishing.begin()
	# 举着钓竿：贴图与鱼线起点都由它给出，竿尖才跟画面一致。
	player.held_tool.show_tool(player.selected_tool())
	player.held_tool.apply_hold(player.facing)


func exit() -> void:
	player.fishing.end()
	player.held_tool.hide_tool()
	if player.fishing.finished.is_connected(_on_finished):
		player.fishing.finished.disconnect(_on_finished)


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()


func update(delta: float) -> void:
	player.fishing.update(delta)


func handle_input(event: InputEvent) -> void:
	player.fishing.handle_input(event)


func _on_finished() -> void:
	request_transition(&"idle")
