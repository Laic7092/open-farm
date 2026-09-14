class_name PlayerStats
extends RefCounted
## 玩家体力值。
##
## 纯数据对象（[RefCounted]），不依赖场景树，因此可以脱离引擎循环做单元测试。
## 变化通过 [signal EventBus.stamina_changed] 广播给 HUD。

## 默认体力上限。
const DEFAULT_MAX_STAMINA: int = 100

## 体力上限。
var max_stamina: int

## 当前体力。
var stamina: int

## 是否已经力竭（力竭后继续使用工具会昏倒）。
var exhausted: bool = false

var _last_emitted: int = -1


func _init(p_max_stamina: int = DEFAULT_MAX_STAMINA) -> void:
	max_stamina = maxi(p_max_stamina, 1)
	stamina = max_stamina


## 消耗体力；体力不足时不扣减并返回 false。
func consume(amount: int) -> bool:
	if amount <= 0:
		return true
	if stamina < amount:
		_mark_exhausted()
		return false
	stamina -= amount
	if stamina == 0:
		_mark_exhausted()
	else:
		_emit()
	return true


## 恢复体力，不超过上限。
func restore(amount: int) -> void:
	if amount <= 0:
		return
	var was_exhausted: bool = exhausted
	stamina = mini(stamina + amount, max_stamina)
	exhausted = false
	if was_exhausted or stamina != _last_emitted:
		_emit()


## 睡一觉，体力全满。
func refill() -> void:
	stamina = max_stamina
	exhausted = false
	_emit()


## 当前体力比例（0..1），供进度条使用。
func ratio() -> float:
	return float(stamina) / float(max_stamina)


## 是否还能继续干活。
func can_work() -> bool:
	return stamina > 0


## 强制把体力置为 0（昏倒演出用）。
func deplete() -> void:
	stamina = 0
	_mark_exhausted()


func to_dict() -> Dictionary:
	return {
		"max_stamina": max_stamina,
		"stamina": stamina,
		"exhausted": exhausted,
	}


func from_dict(data: Dictionary) -> void:
	max_stamina = maxi(int(data.get("max_stamina", DEFAULT_MAX_STAMINA)), 1)
	stamina = clampi(int(data.get("stamina", max_stamina)), 0, max_stamina)
	exhausted = bool(data.get("exhausted", stamina == 0))
	_emit()


func _emit() -> void:
	_last_emitted = stamina
	EventBus.stamina_changed.emit(stamina, max_stamina)


func _mark_exhausted() -> void:
	exhausted = true
	_emit()
	EventBus.stamina_depleted.emit()
