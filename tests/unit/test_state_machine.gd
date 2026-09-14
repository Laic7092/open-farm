extends GdUnitTestSuite
## 状态机测试：注册、切换、回调转发、非法切换容错。

## 只记录事件的最小状态实现。
class RecordingState extends State:
	var events: Array[String] = []

	func enter(previous: State) -> void:
		events.append("enter:%s(prev=%s)" % [name, previous.name if previous != null else "-"])

	func exit() -> void:
		events.append("exit:%s" % name)

	func update(_delta: float) -> void:
		events.append("update:%s" % name)


var _actor: Node
var _machine: StateMachine
var _idle: RecordingState
var _walk: RecordingState


func before_test() -> void:
	_actor = auto_free(Node.new())
	_actor.name = "Actor"
	add_child(_actor)

	_machine = StateMachine.new()
	_machine.name = "StateMachine"
	_machine.initial_state_name = &""

	_idle = RecordingState.new()
	_idle.name = "Idle"
	_walk = RecordingState.new()
	_walk.name = "Walk"
	_machine.add_child(_idle)
	_machine.add_child(_walk)

	# 必须先装配好子节点再入树，否则 _ready() 里注册不到任何状态。
	_actor.add_child(_machine)


func test_states_are_registered_by_snake_case_name() -> void:
	assert_array(_machine.state_names()).contains_exactly([&"idle", &"walk"])
	assert_bool(_machine.has_state(&"idle")).is_true()
	assert_bool(_machine.has_state(&"nope")).is_false()


func test_actor_is_injected_into_states() -> void:
	assert_object(_idle.actor).is_same(_actor)
	assert_object(_walk.actor).is_same(_actor)


func test_transition_enters_the_target_state() -> void:
	_machine.transition_to(&"idle")
	assert_object(_machine.current_state).is_same(_idle)
	assert_array(_idle.events).contains_exactly(["enter:Idle(prev=-)"])


func test_transition_calls_exit_then_enter() -> void:
	_machine.transition_to(&"idle")
	_idle.events.clear()
	_walk.events.clear()

	_machine.transition_to(&"walk")
	assert_array(_idle.events).contains_exactly(["exit:Idle"])
	assert_array(_walk.events).contains_exactly(["enter:Walk(prev=Idle)"])


func test_transition_to_the_same_state_is_ignored() -> void:
	_machine.transition_to(&"idle")
	_idle.events.clear()
	_machine.transition_to(&"idle")
	assert_array(_idle.events).is_empty()


func test_unknown_state_is_rejected_without_changing_current() -> void:
	_machine.transition_to(&"idle")
	_machine.transition_to(&"does_not_exist")
	assert_object(_machine.current_state).is_same(_idle)


func test_state_changed_signal_carries_both_states() -> void:
	var seen: Array[String] = []
	_machine.state_changed.connect(
		func(previous: State, current: State) -> void:
			seen.append(
				"%s => %s" % [previous.name if previous != null else "-", current.name]
			)
	)
	_machine.transition_to(&"idle")
	_machine.transition_to(&"walk")
	assert_array(seen).contains_exactly(["- => Idle", "Idle => Walk"])


func test_state_can_request_its_own_transition() -> void:
	_machine.transition_to(&"idle")
	_idle.request_transition(&"walk")
	assert_object(_machine.current_state).is_same(_walk)


func test_update_is_forwarded_to_the_current_state() -> void:
	_machine.transition_to(&"idle")
	_idle.events.clear()
	_machine._process(0.016)
	assert_array(_idle.events).contains_exactly(["update:Idle"])


func test_deferred_initial_state_is_applied_after_ready() -> void:
	var actor: Node = auto_free(Node.new())
	actor.name = "DeferredActor"
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	machine.initial_state_name = &"idle"
	var state := RecordingState.new()
	state.name = "Idle"
	machine.add_child(state)
	actor.add_child(machine)
	add_child(actor)

	# 初始状态是延后触发的：宿主必须先跑完 _ready()，状态才能安全访问它的引用。
	assert_object(machine.current_state).is_null()
	await get_tree().process_frame
	assert_object(machine.current_state).is_same(state)
