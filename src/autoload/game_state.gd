extends Node
## 全局游戏状态（Autoload：`GameState`）。
##
## 存放"跨场景存活、且不属于任何单个场景"的数据：金钱、剧情旗标、统计。
## 玩家的体力 / 背包属于 [Player] 实体，不放在这里，避免全局状态无限膨胀。

## 开局资金。
const STARTING_MONEY: int = 500

## 玩家名字（新游戏时可由 UI 输入）。
var player_name: String = "农夫"

## 当前金钱，永不为负。
var money: int = STARTING_MONEY

## 剧情旗标：键为旗标名，值为计数 / 布尔。
var flags: Dictionary[StringName, int] = {}

## 累计赚到的钱（成就 / 结算用）。
var total_earned: int = 0

## 累计出货件数。
var total_shipped: int = 0

## 累计游玩秒数。
var play_seconds: float = 0.0

var _counting_playtime: bool = false


func _ready() -> void:
	reset()
	EventBus.day_changed.connect(_on_day_changed)


func _process(delta: float) -> void:
	if _counting_playtime:
		play_seconds += delta


# ---------------------------------------------------------------- 金钱

## 是否买得起。
func can_afford(amount: int) -> bool:
	return money >= amount


## 花钱；余额不足时返回 false 且不改变状态。
func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	_set_money(money - amount, -amount)
	return true


## 赚钱。
func earn(amount: int) -> void:
	if amount <= 0:
		return
	total_earned += amount
	_set_money(money + amount, amount)


## 直接设置金钱（读档 / 调试用）。
func set_money(value: int) -> void:
	_set_money(maxi(value, 0), 0)


# ---------------------------------------------------------------- 旗标

## 设置旗标。
func set_flag(flag: StringName, value: int = 1) -> void:
	flags[flag] = value


## 读取旗标（默认 0 / false）。
func get_flag(flag: StringName, default_value: int = 0) -> int:
	return flags.get(flag, default_value)


## 旗标是否为真。
func has_flag(flag: StringName) -> bool:
	return flags.get(flag, 0) != 0


## 清除旗标。
func clear_flag(flag: StringName) -> void:
	flags.erase(flag)


# ---------------------------------------------------------------- 统计

## 记录一次出货。
func record_shipped(count: int = 1) -> void:
	total_shipped += maxi(count, 0)


# ---------------------------------------------------------------- 生命周期

## 复位到新游戏状态。
func reset() -> void:
	player_name = "农夫"
	money = STARTING_MONEY
	flags.clear()
	total_earned = 0
	total_shipped = 0
	play_seconds = 0.0
	_counting_playtime = false
	EventBus.money_changed.emit(money, 0)


## 开始 / 停止累计游玩时长（读档完成前不计时）。
func set_playtime_counting(enabled: bool) -> void:
	_counting_playtime = enabled


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	var flag_data := {}
	for flag: StringName in flags:
		flag_data[String(flag)] = flags[flag]
	return {
		"player_name": player_name,
		"money": money,
		"flags": flag_data,
		"total_earned": total_earned,
		"total_shipped": total_shipped,
		"play_seconds": play_seconds,
	}


func from_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", "农夫"))
	money = maxi(int(data.get("money", STARTING_MONEY)), 0)
	flags.clear()
	var flag_data: Variant = data.get("flags", {})
	if flag_data is Dictionary:
		for key: Variant in flag_data:
			flags[StringName(str(key))] = int(flag_data[key])
	total_earned = maxi(int(data.get("total_earned", 0)), 0)
	total_shipped = maxi(int(data.get("total_shipped", 0)), 0)
	play_seconds = maxf(float(data.get("play_seconds", 0.0)), 0.0)
	EventBus.money_changed.emit(money, 0)


# ---------------------------------------------------------------- 内部

func _set_money(value: int, delta: int) -> void:
	money = maxi(value, 0)
	EventBus.money_changed.emit(money, delta)


func _on_day_changed(_date: GameDate) -> void:
	# 跨天时给玩家结算一次"今天还在玩"的计时开关，读档流程会临时关掉它。
	_counting_playtime = true
