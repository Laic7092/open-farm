class_name PlayerProfile
extends Resource
## 玩家跨场景档案（Resource）。
##
## 只存放"属于玩家、且要跨场景 / 存档"的可变数据：姓名、金钱、剧情旗标、
## 统计与游玩时长。金钱 / 旗标等规则集中在这里；不依赖场景树，也不认识
## EventBus，因此可以由 [Main] 持有、测试里直接 new 一份干净实例。
##
## 场景节点由 [Main] 显式注入同一份实例，不再通过 Autoload 全局名访问。

## 开局资金。
const STARTING_MONEY: int = 500

## 玩家域事件对象；由本档案持有，供节点在进入场景树时连接。
var events: PlayerEvents = PlayerEvents.new()

## 金钱变化；由拥有者（[Main]）转发到 [EventBus]。
signal money_changed(money: int, delta: int)

## 玩家名字。
@export var player_name: String = "农夫"

## 当前金钱，永不为负。
@export var money: int = STARTING_MONEY

## 剧情旗标：键为旗标名，值为计数 / 布尔。
var flags: Dictionary[StringName, int] = {}

## 累计赚到的钱（成就 / 结算用）。
@export var total_earned: int = 0

## 累计出货件数。
@export var total_shipped: int = 0

## 累计游玩秒数。
@export var play_seconds: float = 0.0

## 是否正在累计游玩时长（读档完成前不计时）。
var counting_playtime: bool = false


## 复位到新游戏状态。
func reset() -> void:
	player_name = "农夫"
	money = STARTING_MONEY
	flags.clear()
	total_earned = 0
	total_shipped = 0
	play_seconds = 0.0
	counting_playtime = false
	money_changed.emit(money, 0)


## 每帧累计游玩时长。
func tick(delta: float) -> void:
	if counting_playtime:
		play_seconds += delta


## 设置玩家名字；空白输入回退为默认名。
func set_player_name(value: String) -> void:
	var trimmed := value.strip_edges()
	player_name = trimmed if not trimmed.is_empty() else "农夫"


## 是否买得起。
func can_afford(amount: int) -> bool:
	return money >= amount


## 花钱；余额不足时返回 false 且不改变状态。
func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	money -= amount
	money_changed.emit(money, -amount)
	return true


## 赚钱；返回实际入账金额。
func earn(amount: int) -> int:
	if amount <= 0:
		return 0
	total_earned += amount
	money += amount
	money_changed.emit(money, amount)
	return amount


## 直接设置金钱（读档 / 调试用）。
func set_money(value: int) -> void:
	money = maxi(value, 0)
	money_changed.emit(money, 0)


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


## 记录一次出货。
func record_shipped(count: int = 1) -> void:
	total_shipped += maxi(count, 0)


## 开始 / 停止累计游玩时长。
func set_playtime_counting(enabled: bool) -> void:
	counting_playtime = enabled


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
	money_changed.emit(money, 0)
