class_name HudPlayerView
extends Node
## HUD 上的金钱与体力。
##
## [b]玩家状态自己的小视图[/b]：只订阅玩家域的金钱 / 体力变化，只读玩家档案。
## 体力由变化信号驱动（玩家一进图就会报一次），所以这里不重复去问。

@onready var money_label: Label = %MoneyLabel
@onready var stamina_bar: ProgressBar = %StaminaBar

var _profile: PlayerProfile


func bind_dependencies(profile: PlayerProfile, _clock: GameDateClock) -> void:
	_profile = profile
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.player.money_changed.connect(_on_money_changed)
	EventBus.player.stamina_changed.connect(_on_stamina_changed)
	refresh()


## 重画金钱（读档 / 重新注入依赖后也要跟上）。
func refresh() -> void:
	_on_money_changed(_profile.money if _profile != null else 0, 0)


func _on_money_changed(money: int, _delta: int) -> void:
	money_label.text = Text.format(&"HUD_MONEY", {"value": money})


func _on_stamina_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
