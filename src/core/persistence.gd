class_name Persistence
extends RefCounted
## 存档参与的约定与查找工具。
##
## [SaveManager] 不直接认识任何具体系统，它只遍历 [constant GROUP] 组里的节点，
## 鸭子类型地调用 [code]to_dict()[/code] / [code]from_dict()[/code]。
## 任何节点只要：
## [codeblock]
## func _ready() -> void:
##     Persistence.register(self, &"farm_grid")
## [/codeblock]
## 并实现上述两个方法，就会被自动纳入存档——新增系统无需改动 SaveManager。

## 参与存档的节点所属分组。
const GROUP: StringName = &"persistent"

## 存储持久化 id 的元数据键。
const META_ID: StringName = &"persistence_id"


## 声明某节点参与存档；[param id] 必须在全局唯一且稳定（不要用节点路径）。
static func register(node: Node, id: StringName) -> void:
	node.add_to_group(GROUP)
	node.set_meta(META_ID, id)


## 读取节点的持久化 id；未显式注册时回退到节点名。
static func id_of(node: Node) -> StringName:
	var meta: Variant = node.get_meta(META_ID, null)
	if meta is StringName:
		return meta
	return StringName(node.name.to_snake_case())


## 校验一个节点是否满足存档契约，返回错误原因列表（为空表示合格）。
static func validate(node: Node) -> PackedStringArray:
	var problems := PackedStringArray()
	if not node.has_method(&"to_dict"):
		problems.append("缺少 to_dict() 方法")
	if not node.has_method(&"from_dict"):
		problems.append("缺少 from_dict(data) 方法")
	if id_of(node) == &"":
		problems.append("持久化 id 为空")
	return problems
