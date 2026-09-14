class_name SpawnPoint
extends Marker2D
## 场景出生点。
##
## [SceneRouter] 切换场景后，会查找目标场景中 [code]spawn_id[/code] 匹配的出生点，
## 并把玩家（组 [code]player[/code]）移动到该位置。
## 出生点用标记节点而不是硬编码坐标，场景就能自由重排而不影响传送逻辑。

## 出生点标识；场景切换时传入同名 id 即可落到这里。
@export var spawn_id: StringName = &"default"

## 落地后玩家应朝向的方向。
@export var facing: Facing.Direction = Facing.Direction.DOWN


func _enter_tree() -> void:
	add_to_group(&"spawn_point")
