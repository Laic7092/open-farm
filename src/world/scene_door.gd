class_name SceneDoor
extends Interactable
## 场景传送门：交互后切换到目标世界场景。
##
## 目标场景与出生点都是导出属性，因此"农场 ↔ 小镇"这类连接关系
## 完全由场景文件描述，不需要任何中央传送表。

## 目标场景路径。
@export_file("*.tscn") var target_scene: String = ""
## 落在目标场景的哪个出生点。
@export var target_spawn_id: StringName = &"default"
## 需要哪个剧情旗标才开放（留空表示始终可用）。
@export var required_flag: StringName = &""


func _ready() -> void:
	if prompt_key == &"PROMPT_INTERACT":
		prompt_key = &"PROMPT_ENTER"


func can_interact() -> bool:
	if not super.can_interact():
		return false
	return required_flag == &"" or GameState.has_flag(required_flag)


func interact(actor: Node2D) -> void:
	super.interact(actor)
	if target_scene.is_empty():
		push_warning("SceneDoor: 未设置 target_scene")
		return
	# 这里不 await：传送是"发出去就不用管"的演出，交互本身应当立即结束。
	SceneRouter.change_scene_to(target_scene, target_spawn_id)
