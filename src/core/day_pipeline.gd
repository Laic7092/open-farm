class_name DayPipeline
extends RefCounted
## 显式优先级的日结转流水线。
##
## [GameDateClock] 在跨天时只负责调用 [method run]；各系统在组合根
## 或自己的 [code]_enter_tree()[/code] 里用 [method register] 声明钩子与
## [b]显式优先级[/b]，不再依赖 Autoload / 节点进入树的先后顺序。
##
## 同一优先级内按注册顺序执行，保证结果稳定；需要严格先后的依赖必须通过
## 不同优先级表达，而不是碰运气。

## 天气：必须最先执行，节日 / 事件和农场日结转都要读"今天什么天气"。
const PRIORITY_WEATHER: int = 10
## 关系：清每日标记、推进婚育，并可能写入 [code]child_born[/code] 旗标。
const PRIORITY_RELATIONSHIPS: int = 20
## 日历：判定今日节日与一次性事件，可能写旗标 / 发钱 / 播报。
const PRIORITY_CALENDAR: int = 30
## 世界内模拟：作物、植被、牲畜、玩家状态等。
const PRIORITY_WORLD: int = 100
## 未声明优先级时的默认值；与 [constant PRIORITY_WORLD] 同层。
const PRIORITY_DEFAULT: int = PRIORITY_WORLD

var _entries: Array[Dictionary] = []
var _next_sequence: int = 0


## 注册一个日结转钩子。
##
## 同一个 [Callable] 重复注册会更新优先级，不会叠加执行。
func register(callback: Callable, priority: int = PRIORITY_DEFAULT) -> void:
	if not callback.is_valid():
		return
	for entry: Dictionary in _entries:
		if entry.get("callback") == callback:
			entry["priority"] = priority
			_sort()
			return
	_next_sequence += 1
	_entries.append({
		"callback": callback,
		"priority": priority,
		"sequence": _next_sequence,
	})
	_sort()


## 注销日结转钩子；不存在时静默忽略。
func unregister(callback: Callable) -> void:
	for index: int in range(_entries.size() - 1, -1, -1):
		if _entries[index].get("callback") == callback:
			_entries.remove_at(index)


## 清空全部钩子（测试 / 重建组合根时使用）。
func clear() -> void:
	_entries.clear()
	_next_sequence = 0


## 按优先级顺序同步执行所有有效钩子。
func run(date: GameDate) -> void:
	for entry: Dictionary in _entries.duplicate():
		var callback: Callable = entry.get("callback")
		if callback.is_valid():
			callback.call(date)


## 已注册的钩子数量（只读诊断用途）。
func size() -> int:
	return _entries.size()


## 当前钩子顺序的快照；返回的数组是副本。
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate())
	return result


func _sort() -> void:
	_entries.sort_custom(_compare_entries)


func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = int(a.get("priority", PRIORITY_DEFAULT))
	var priority_b: int = int(b.get("priority", PRIORITY_DEFAULT))
	if priority_a == priority_b:
		return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
	return priority_a < priority_b
