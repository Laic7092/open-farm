class_name MineLadder
extends Interactable
## 矿洞的下层爬梯：交互后到下一层。
##
## 由 [MineFloor] 在运行时生成，所以位置固定、样式统一，
## 100 层不需要 100 份场景。

const TEXTURE: Texture2D = preload("res://assets/sprites/props/ladder.png")

## 所属矿洞；由 [MineFloor] 注入。
var floor: MineFloor


func _ready() -> void:
	prompt_key = &"PROMPT_DESCEND"
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
		floor.descend()
