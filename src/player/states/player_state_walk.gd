extends State
## 行走状态：八向输入压平成四向，带简单的加速 / 摩擦，手感不生硬。

## 加速度（像素/秒²）。
const ACCELERATION: float = 900.0
## 松开方向键后的减速度（像素/秒²）。
const FRICTION: float = 1400.0

var player: Player


func enter(_previous: State) -> void:
	player = actor as Player


func physics_update(delta: float) -> void:
	var direction: Vector2 = player.input_direction()
	var target_speed: float = player.current_speed()

	if direction.is_zero_approx():
		player.velocity = player.velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		if player.velocity.is_zero_approx():
			request_transition(&"idle")
			return
	else:
		player.face(Facing.from_vector(direction, player.facing))
		var desired: Vector2 = direction.normalized() * target_speed
		player.velocity = player.velocity.move_toward(desired, ACCELERATION * delta)

	player.play_animation(&"walk")
	player.move_and_slide()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"primary_action"):
		# 边走边按主操作：判定与待机一致。
		if player.try_primary_action():
			return
		request_transition(&"fishing" if player.can_fish() else &"use_item")
