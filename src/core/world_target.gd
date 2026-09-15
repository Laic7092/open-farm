class_name WorldTarget
extends RefCounted
## 一次世界切换的显式目标：场景路径 + 出生点。
##
## 读档、缓存重挂载与普通传送都只传这个值，不再让 [SceneRouter] 保存
## “待切换地图 / 出生点”这类隐式状态。

## 目标场景资源路径。
var scene_path: String = ""
## 落地出生点 id。
var spawn_id: StringName = &"default"


func _init(p_scene_path: String = "", p_spawn_id: StringName = &"default") -> void:
	scene_path = p_scene_path
	spawn_id = p_spawn_id


## 是否没有有效目标。
func is_empty() -> bool:
	return scene_path.is_empty()


## 转成 [SceneRouter] 可直接消费的字典。
func to_dict() -> Dictionary:
	return {"world_path": scene_path, "spawn_id": String(spawn_id)}


## 从存档字典恢复。
static func from_dict(data: Dictionary) -> WorldTarget:
	return WorldTarget.new(
		str(data.get("world_path", "")),
		StringName(str(data.get("spawn_id", "default")))
	)
