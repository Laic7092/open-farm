class_name HudTimeView
extends Node
## HUD 上的日期 / 时间 / 今日节日。
##
## [b]时钟与日历自己的小视图[/b]：只订阅时间域的信号（分钟 / 跨天 / 换季 / 换年 /
## 节日开始），只读时钟与日历。天气、金钱、体力、物品栏各有自己的视图，
## [Hud] 不认识它们，也不替它们保存状态。

@onready var date_label: Label = %DateLabel
@onready var festival_label: Label = %FestivalLabel
@onready var time_label: Label = %TimeLabel

var _clock: GameDateClock
var _calendar: CalendarService


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock
	if is_node_ready():
		refresh()


func bind_services(
	_weather: WeatherService,
	_relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_calendar = calendar
	if is_node_ready():
		refresh()


func _ready() -> void:
	EventBus.minute_changed.connect(func(_hour: int, _minute: int) -> void: refresh())
	EventBus.day_changed.connect(func(_date: GameDate) -> void: refresh())
	EventBus.season_changed.connect(func(_season: Season.Type) -> void: refresh())
	EventBus.year_changed.connect(func(_year: int) -> void: refresh())
	EventBus.world.festival_day_started.connect(
		func(_festival_id: StringName) -> void: refresh()
	)
	refresh()


## 重画三行；时钟还没注入时日期与时间留空。
func refresh() -> void:
	if _clock != null:
		date_label.text = Text.date_text(_clock.date)
		time_label.text = _clock.time_string()
	# 今日节日横幅：没有节日时整行隐藏，不占屏幕。
	var festival := _calendar.today_text() if _calendar != null else ""
	festival_label.text = festival
	festival_label.visible = not festival.is_empty()
