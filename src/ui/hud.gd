class_name Hud
extends Control
## 常驻 HUD：日期 / 时间 / 天气 / 金钱 / 体力 / 手持工具 / 交互提示 / 浮动提示。
##
## 单向数据流：HUD 只[b]订阅[/b] [EventBus]，从不主动去问游戏状态，
## 因此它可以在任何场景里存在，也不影响任何模拟逻辑。

## 浮动提示停留时长（秒）。
const TOAST_DURATION: float = 2.2

## 天气图标：与 [method Weather.to_key] 的返回值一一对应。
const WEATHER_ICON_DIR: String = "res://assets/ui"

@onready var date_label: Label = %DateLabel
@onready var time_label: Label = %TimeLabel
@onready var weather_label: Label = %WeatherLabel
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var money_label: Label = %MoneyLabel
@onready var forecast_label: Label = %ForecastLabel
@onready var forecast_icon: TextureRect = %ForecastIcon
@onready var tool_icon: TextureRect = %ToolIcon
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var tool_label: Label = %ToolLabel
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween
## 天气图标缓存：贴着同一个文件反复 load 会让每帧的 HUD 刷新变成磁盘 IO。
var _weather_icons: Dictionary[StringName, Texture2D] = {}


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
	var tool_id := _player_tool_id()
	tool_label.text = "%s: %s" % [Text.key(&"HUD_TOOL"), Text.tool_name(tool_id)]
	tool_icon.texture = _item_icon(tool_id)


func _refresh_date() -> void:
	date_label.text = Text.date_text(GameClock.date)


func _refresh_time() -> void:
	time_label.text = GameClock.time_string()


func _refresh_weather() -> void:
	weather_label.text = Text.weather_name(WeatherSystem.current)
	weather_icon.texture = _weather_icon(WeatherSystem.current)
	forecast_label.text = Text.format(&"HUD_FORECAST", {
		"weather": Text.weather_name(WeatherSystem.forecast),
	})
	forecast_icon.texture = _weather_icon(WeatherSystem.forecast)


## 取天气图标；找不到时返回 null（HUD 会只显示文字）。
func _weather_icon(weather: Weather.Type) -> Texture2D:
	var key := Weather.to_key(weather)
	if _weather_icons.has(key):
		return _weather_icons[key]
	var path := "%s/weather_%s.png" % [WEATHER_ICON_DIR, key]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_weather_icons[key] = texture
	return texture


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
	tool_icon.texture = _item_icon(tool_id)


## 手持工具的图标：工具既是 [ToolData] 也是 [ItemData]，图标挂在道具上。
func _item_icon(item_id: StringName) -> Texture2D:
	var item := Database.get_item(item_id)
	return item.icon if item != null else null


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
