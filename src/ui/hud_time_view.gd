class_name HudTimeView
extends Node
## HUD 上的日期与时间。
##
## [b]时钟自己的小视图[/b]：只订阅时间域的信号（分钟 / 跨天 / 换季 / 换年），
## 只读时钟。金钱 / 体力、物品栏各有自己的视图，[Hud] 不认识它们，也不替它们保存状态。

@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel

var _clock: GameDateClock


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.minute_changed.connect(func(_hour: int, _minute: int) -> void: refresh())
	EventBus.day_changed.connect(func(_date: GameDate) -> void: refresh())
	EventBus.season_changed.connect(func(_season: Season.Type) -> void: refresh())
	EventBus.year_changed.connect(func(_year: int) -> void: refresh())
	refresh()


## 重画日期与时间；时钟还没注入时留空。
func refresh() -> void:
	if _clock != null:
		date_label.text = Text.date_text(_clock.date)
		time_label.text = _clock.time_string()
