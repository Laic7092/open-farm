class_name StateMachine
extends Node
## 通用有限状态机（Godot 官方 FiniteStateMachine 模式的工程化版本）。
##
## 子节点中所有 [State] 会被自动注册，状态名取自节点名的 snake_case。
## 用法：把本节点作为角色子节点，挂上若干 State 子节点，并设置
## [member initial_state_name]。
##
## 状态机负责把输入与每帧回调转发给当前状态，因此角色脚本本身
## 不需要写 [code]match current_state[/code] 这种分支。

## 状态切换完成后发出，携带切换前后的状态（首次进入时 previous 为 null）。
signal state_changed(previous: State, current: State)

## 初始状态名（对应 State 子节点名的 snake_case）。
@export var initial_state_name: StringName = &"idle"

## 当前状态，可能为 null（尚未初始化）。
var current_state: State

var _states: Dictionary[StringName, State] = {}


func _ready() -> void:
	_register_states()
	# 必须延后进入初始状态：Godot 先执行子节点的 _ready()，再执行父节点的。
	# 状态机是宿主的子节点，若在这里立刻切换状态，状态的 enter() 会去访问
	# 宿主上尚未被 @onready 赋值的引用（sprite、stats……）而拿到一堆 null。
	if initial_state_name != &"":
		transition_to.call_deferred(initial_state_name)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


## 已注册的状态名列表，便于调试与测试。
func state_names() -> Array[StringName]:
	return _states.keys()


## 是否存在名为 [param state_name] 的状态。
func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


## 切换到 [param state_name]。
##
## 目标不存在或与当前状态相同时直接返回，不会重复触发 enter/exit。
func transition_to(state_name: StringName) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: 未注册的状态 '%s'（已注册：%s）" % [state_name, _states.keys()])
		return
	if current_state == _states[state_name]:
		return

	var previous: State = current_state
	if previous != null:
		previous.exit()

	current_state = _states[state_name]
	current_state.enter(previous)
	state_changed.emit(previous, current_state)


func _register_states() -> void:
	_states.clear()
	var owner_actor: Node = get_parent()
	for child: Node in get_children():
		if child is not State:
			continue
		var state := child as State
		state.state_machine = self
		state.actor = owner_actor
		if not state.transition_requested.is_connected(transition_to):
			state.transition_requested.connect(transition_to)
		_states[StringName(state.name.to_snake_case())] = state
