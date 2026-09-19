class_name Commission
extends RefCounted
## 委托单元：持有委托板状态，负责"今天有哪些委托、交付怎么结算"。
##
## 挑选规则仍在 [CommissionRules]（纯静态函数），静态数据仍在 [CommissionData]，
## 本单元只做编排。结算所需的档案 / 背包 / 日期都靠注入，不做全局查找，
## 因此可以脱离界面与场景树单测。

## 交付结果；界面据此翻译成提示与音效。
enum Result {
	DELIVERED,     ## 交付成功：已扣道具、发钱、标记完成
	ALREADY_DONE,  ## 今天已经交过这个委托
	INSUFFICIENT,  ## 道具不足
	UNKNOWN,       ## 没有这个委托数据
}

## 委托板可存档状态。
var state: CommissionState

var _profile: PlayerProfile
var _clock: GameDateClock
var _inventory_provider: Callable = Callable()


func _init(p_state: CommissionState = null) -> void:
	state = p_state if p_state != null else CommissionState.new()


## 注入结算所需协作者：玩家档案、时钟，以及"当前背包"的提供者。
func bind(profile: PlayerProfile, clock: GameDateClock, inventory_provider: Callable) -> void:
	_profile = profile
	_clock = clock
	_inventory_provider = inventory_provider


## 今日上板的委托 id；顺带把状态刷新到当前日期。
func offers() -> Array[StringName]:
	ensure_current()
	var pool: Array[StringName] = []
	for data: CommissionData in Database.commission_list():
		pool.append(data.id)
	var date: GameDate = _clock.date if _clock != null else null
	return CommissionRules.offers_for(date, pool)


## 把状态刷新到当前日期；返回 true 表示跨天刷新过。
func ensure_current() -> bool:
	if _clock == null:
		return false
	return state.ensure_for(_clock.date)


## 某个委托今天是否已完成。
func is_completed(commission_id: StringName) -> bool:
	return state.is_completed(commission_id)


## 交付一个委托：扣道具、发钱、标记完成；返回结果供界面展示。
func deliver(commission_id: StringName) -> Result:
	var data := Database.get_commission(commission_id)
	if data == null:
		return Result.UNKNOWN
	ensure_current()
	if state.is_completed(commission_id):
		return Result.ALREADY_DONE
	var inventory := _current_inventory()
	if inventory == null or not inventory.has(data.item_id, data.amount):
		return Result.INSUFFICIENT
	if not inventory.remove(data.item_id, data.amount):
		return Result.INSUFFICIENT
	if _profile != null:
		_profile.earn(CommissionRules.reward_of(data))
	state.complete(commission_id)
	return Result.DELIVERED


func _current_inventory() -> Inventory:
	if not _inventory_provider.is_valid():
		return null
	return _inventory_provider.call() as Inventory
