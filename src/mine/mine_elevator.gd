class_name MineElevator
extends Interactable
## 矿洞电梯：只在每 5 层出现，交互后打开楼层选择。
##
## 由 [MineFloor] 在运行时生成。

const TEXTURE: Texture2D = preload("res://assets/sprites/props/elevator.png")

## 所属矿洞；由 [MineFloor] 注入。
var floor: MineFloor


func _ready() -> void:
	prompt_key = &"PROMPT_ELEVATOR"
	collision_layer = 8
	collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)


func interact(actor: Node2D) -> void:
	super.interact(actor)
	if floor != null:
		floor.open_elevator()
