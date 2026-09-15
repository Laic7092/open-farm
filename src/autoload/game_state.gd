extends Node
## 全局游戏状态门面（Autoload：`GameState`）。
##
## 真正的跨场景数据在 [PlayerProfile]（Resource）里，由 [Main] 持有并注入。
## 本节点只负责：
## [br]- 给现有调用方稳定的全局名；
## [br]- 在状态变化时转发 [EventBus] 信号；
## [br]- 承担存档核心节。
##
## 测试 / 组合根可以调用 [method set_profile] 换入一份全新的 [PlayerProfile]，
## 从而获得干净的隔离状态。

## 开局资金（兼容旧调用方；权威值在 [constant PlayerProfile.STARTING_MONEY]）。
const STARTING_MONEY: int = PlayerProfile.STARTING_MONEY

var _profile: PlayerProfile = PlayerProfile.new()


func _ready() -> void:
	Persistence.register_core(self, &"GameState", 20)
	reset()
	EventBus.day_changed.connect(_on_day_changed)


func _process(delta: float) -> void:
	_profile.tick(delta)


# ---------------------------------------------------------------- 状态注入

## 当前玩家档案。
func profile() -> PlayerProfile:
	return _profile


## 换入玩家档案；传 null 会创建一份新的默认档案。
func set_profile(value: PlayerProfile) -> void:
	_profile = value if value != null else PlayerProfile.new()


# ---------------------------------------------------------------- 只读视图

## 玩家名字。
var player_name: String:
	get:
		return _profile.player_name

## 当前金钱。
var money: int:
	get:
		return _profile.money

## 剧情旗标只读视图。
var flags: Dictionary[StringName, int]:
	get:
		return _profile.flags

## 累计赚到的钱。
var total_earned: int:
	get:
		return _profile.total_earned

## 累计出货件数。
var total_shipped: int:
	get:
		return _profile.total_shipped

## 累计游玩秒数。
var play_seconds: float:
	get:
		return _profile.play_seconds


# ---------------------------------------------------------------- 金钱

## 是否买得起。
func can_afford(amount: int) -> bool:
	return _profile.can_afford(amount)


## 花钱；余额不足时返回 false 且不改变状态。
func spend(amount: int) -> bool:
	if not _profile.spend(amount):
		return false
	EventBus.money_changed.emit(_profile.money, -amount)
	return true


## 赚钱。
func earn(amount: int) -> void:
	var gained := _profile.earn(amount)
	if gained > 0:
		EventBus.money_changed.emit(_profile.money, gained)


## 直接设置金钱（读档 / 调试用）。
func set_money(value: int) -> void:
	_profile.set_money(value)
	EventBus.money_changed.emit(_profile.money, 0)


## 设置玩家名字（新游戏 UI / 读档用）。
func set_player_name(value: String) -> void:
	_profile.set_player_name(value)


# ---------------------------------------------------------------- 旗标

## 设置旗标。
func set_flag(flag: StringName, value: int = 1) -> void:
	_profile.set_flag(flag, value)


## 读取旗标（默认 0 / false）。
func get_flag(flag: StringName, default_value: int = 0) -> int:
	return _profile.get_flag(flag, default_value)


## 旗标是否为真。
func has_flag(flag: StringName) -> bool:
	return _profile.has_flag(flag)


## 清除旗标。
func clear_flag(flag: StringName) -> void:
	_profile.clear_flag(flag)


# ---------------------------------------------------------------- 统计

## 记录一次出货。
func record_shipped(count: int = 1) -> void:
	_profile.record_shipped(count)


# ---------------------------------------------------------------- 生命周期

## 复位当前档案。
func reset() -> void:
	_profile.reset()
	EventBus.money_changed.emit(_profile.money, 0)


## 开始 / 停止累计游玩时长（读档完成前不计时）。
func set_playtime_counting(enabled: bool) -> void:
	_profile.set_playtime_counting(enabled)


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return _profile.to_dict()


func from_dict(data: Dictionary) -> void:
	_profile.from_dict(data)
	EventBus.money_changed.emit(_profile.money, 0)


# ---------------------------------------------------------------- 内部

func _on_day_changed(_date: GameDate) -> void:
	# 跨天时给玩家结算一次"今天还在玩"的计时开关，读档流程会临时关掉它。
	_profile.set_playtime_counting(true)
