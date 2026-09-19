class_name Museum
extends RefCounted
## 博物馆单元：持有图鉴状态，并在"玩家获得新道具"时入册。
##
## 状态仍是可存档的 [MuseumState]（存档节由组合根登记）；"什么时候记、记什么"
## 属于本单元，组合根只负责装配。本单元订阅被注入的玩家事件，不做任何全局查找，
## 因此可以脱离场景树单测。

## 图鉴状态；跨场景保留、可存档。
var state: MuseumState

var _clock: GameDateClock


func _init(p_state: MuseumState = null) -> void:
	state = p_state if p_state != null else MuseumState.new()


## 订阅被注入的玩家事件；[param clock] 用于记录首次发现的游戏日。
func bind(events: PlayerEvents, clock: GameDateClock) -> void:
	_clock = clock
	if events == null:
		return
	if not events.item_obtained.is_connected(_on_item_obtained):
		events.item_obtained.connect(_on_item_obtained)


func _on_item_obtained(item_id: StringName) -> void:
	state.discover(item_id, _today())


func _today() -> int:
	if _clock == null or _clock.date == null:
		return 0
	return _clock.date.absolute_day()
