extends State
## 待机状态：站住不动，等待移动 / 使用工具 / 交互输入。

var player: Player


func enter(_previous: State) -> void:
	player = actor as Player
	player.velocity = Vector2.ZERO
	player.play_animation(&"idle")


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	if not player.input_direction().is_zero_approx():
		request_transition(&"walk")
		return
	player.move_and_slide()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use_tool"):
		request_transition(&"use_tool")
	elif event.is_action_pressed(&"interact"):
		player.try_interact()
