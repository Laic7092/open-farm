class_name State
extends Node
## 有限状态机中的单个状态。
##
## 每个状态是一个 [Node]，作为 [StateMachine] 的子节点存在，
## 由节点自身的名字（snake_case）注册为状态名。
## 状态不直接跳转，而是发出 [signal transition_requested]，由状态机统一处理，
## 这样状态的依赖方向始终指向状态机，不会互相引用。

## 请求切换到名为 [param to_state] 的状态。
signal transition_requested(to_state: StringName)

## 由 [StateMachine] 在注册时注入，状态内部可以用它查询当前状态。
var state_machine: StateMachine

## 状态机所服务的角色节点（即 [StateMachine] 的父节点），由状态机注入。
## 状态通过 [code]actor as Player[/code] 拿到宿主，无需自己数节点层级。
var actor: Node


## 进入该状态；[param _previous] 为切换前的状态，首次进入时为 [code]null[/code]。
func enter(_previous: State) -> void:
	pass


## 离开该状态，用于清理计时器、还原速度等。
func exit() -> void:
	pass


## 每帧逻辑。
func update(_delta: float) -> void:
	pass


## 物理帧逻辑。
func physics_update(_delta: float) -> void:
	pass


## 未消费的输入事件。
func handle_input(_event: InputEvent) -> void:
	pass


## 便捷方法：请求状态机切换到 [param to_state]。
func request_transition(to_state: StringName) -> void:
	transition_requested.emit(to_state)
