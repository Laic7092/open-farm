class_name Hud
extends Control
## 常驻 HUD：日期 / 时间 / 天气 / 金钱 / 体力 / 手持工具 / 交互提示 / 浮动提示。
##
## 单向数据流：HUD 只[b]订阅[/b] [EventBus]，从不主动去问游戏状态，
## 因此它可以在任何场景里存在，也不影响任何模拟逻辑。

## 浮动提示停留时长（秒）。
const TOAST_DURATION: float = 2.2

@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel
@onready var weather_label: Label = %WeatherLabel
@onready var money_label: Label = %MoneyLabel
@onready var forecast_label: Label = %ForecastLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var tool_label: Label = %ToolLabel
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween


func _ready() -> void:
	EventBus.minute_changed.connect(_on_minute_changed)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.season_changed.connect(func(_season: Season.Type) -> void: _refresh_date())
	EventBus.year_changed.connect(func(_year: int) -> void: _refresh_date())
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.tool_changed.connect(_on_tool_changed)
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.notification_requested.connect(_on_notification)

	toast_label.modulate.a = 0.0
	prompt_label.text = ""
	_refresh_all()


# ---------------------------------------------------------------- 刷新

func _refresh_all() -> void:
	_refresh_date()
	_refresh_time()
	_refresh_weather()
	_on_money_changed(GameState.money, 0)
	tool_label.text = "%s: %s" % [
		Text.key(&"HUD_TOOL"),
		Text.tool_name(_player_tool_id()),
	]


func _refresh_date() -> void:
	date_label.text = Text.date_text(GameClock.date)


func _refresh_time() -> void:
	time_label.text = GameClock.time_string()


func _refresh_weather() -> void:
	weather_label.text = Text.weather_name(WeatherSystem.current)
	forecast_label.text = Text.format(&"HUD_FORECAST", {
		"weather": Text.weather_name(WeatherSystem.forecast),
	})


func _player_tool_id() -> StringName:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	return player.tool_belt.selected_id() if player != null else &""


# ---------------------------------------------------------------- 事件

func _on_minute_changed(_hour: int, _minute: int) -> void:
	_refresh_time()


func _on_day_changed(_date: GameDate) -> void:
	_refresh_all()


func _on_weather_changed(_weather: Weather.Type) -> void:
	_refresh_weather()


func _on_money_changed(money: int, _delta: int) -> void:
	money_label.text = Text.format(&"HUD_MONEY", {"value": money})


func _on_stamina_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_tool_changed(tool_id: StringName, _index: int) -> void:
	tool_label.text = "%s: %s" % [Text.key(&"HUD_TOOL"), Text.tool_name(tool_id)]


func _on_prompt_changed(prompt_key: StringName) -> void:
	prompt_label.text = Text.key(prompt_key)


func _on_notification(text_key: StringName, args: Dictionary) -> void:
	var message := Text.format(text_key, args)
	if message.is_empty():
		return
	toast_label.text = message

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)
