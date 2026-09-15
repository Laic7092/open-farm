class_name SaveSection
extends RefCounted
## 存档节统一契约。
##
## 核心 Resource / 服务节点、场景内持久化节点都先包装成 [SaveSection] 再参与
## 收集与恢复；[SaveManager] 只处理节，不再区分“核心单例”和“组内节点”的
## 不同代码路径。
##
## [member target] 必须实现 [code]to_dict()[/code] / [code]from_dict(data)[/code]；
## [member id] 是稳定的存档键名（不是节点路径）。

## 被包装的存档参与者。
var target: Object
## 存档键名。
var id: StringName = &""
## 恢复顺序；数值越小越先恢复。
var order: int = 0
## 是否写进顶层核心节（false 表示写进 payload["nodes"]）。
var core: bool = false


func _init(
	p_target: Object = null,
	p_id: StringName = &"",
	p_order: int = 0,
	p_core: bool = false
) -> void:
	target = p_target
	id = p_id
	order = p_order
	core = p_core


## 从已注册对象创建存档节；优先读取 [Persistence] 元数据。
static func from_object(object: Object, p_core: bool = false) -> SaveSection:
	return SaveSection.new(
		object,
		Persistence.id_of(object),
		Persistence.core_order_of(object) if p_core else 0,
		p_core
	)


## 校验目标是否满足 [code]to_dict()[/code] / [code]from_dict(data)[/code] 契约。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not is_valid():
		problems.append("目标对象已失效")
		return problems
	if id == &"":
		problems.append("存档节 id 为空")
	if not target.has_method(&"to_dict"):
		problems.append("缺少 to_dict() 方法")
	if not target.has_method(&"from_dict"):
		problems.append("缺少 from_dict(data) 方法")
	return problems


## 是否指向有效对象。
func is_valid() -> bool:
	return target != null and is_instance_valid(target)


func to_dict() -> Dictionary:
	return target.call(&"to_dict") as Dictionary


func from_dict(data: Dictionary) -> void:
	target.call(&"from_dict", data)
