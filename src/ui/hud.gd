class_name Hud
extends Control
## 常驻 HUD：日期 / 时间 / 天气 / 金钱 / 体力 / 物品栏 / 交互提示 / 浮动提示。
##
## 单向数据流：HUD 只[b]订阅[/b] [EventBus]，从不主动去问游戏状态，
## 因此它可以在任何场景里存在，也不影响任何模拟逻辑。
##
## 底部常驻物品栏只是背包前几格的[b]快捷访问视图[/b]，不存放任何道具；
## 工具也放在背包里。Q / R 在装有工具的格子之间切换，
## 因此不需要低头找文字，也能一眼看到刚捡到的道具。

## 浮动提示停留时长（秒）。
const TOAST_DURATION: float = 2.2

## 天气图标：与 [method Weather.to_key] 的返回值一一对应。
const WEATHER_ICON_DIR: String = "res://assets/ui"

## 底部物品栏格数（= 背包的前几格）。
const ITEM_BAR_SIZE: int = ItemBar.SIZE

## 物品栏格子场景。
const HUD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/hud_slot.tscn")

@onready var date_label: Label = %DateLabel
@onready var festival_label: Label = %FestivalLabel
@onready var time_label: Label = %TimeLabel
@onready var weather_label: Label = %WeatherLabel
@onready var weather_icon: TextureRect = %WeatherIcon
@onready var money_label: Label = %MoneyLabel
@onready var forecast_label: Label = %ForecastLabel
@onready var forecast_icon: TextureRect = %ForecastIcon
@onready var tool_icon: TextureRect = %ToolIcon
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var tool_label: Label = %ToolLabel
@onready var inventory_bar: HBoxContainer = %InventoryBar
@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween
## 天气图标缓存：贴着同一个文件反复 load 会让每帧的 HUD 刷新变成磁盘 IO。
var _weather_icons: Dictionary[StringName, Texture2D] = {}
## 物品栏格子，按从左到右排列。
var _item_slots: Array[HudSlot] = []
## 组合根注入的玩家档案；HUD 只读。
var _profile: PlayerProfile
## 组合根注入的时钟；HUD 只读。
var _clock: GameDateClock
## 组合根注入的天气服务；HUD 只读。
var _weather: WeatherService
## 组合根注入的日历服务；HUD 只读。
var _calendar: CalendarService


func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_profile = profile
	_clock = clock
	if is_node_ready():
		_refresh_all()


## 由 [UiRoot] 在 UI 进入树前下发领域服务；HUD 只读。
func bind_services(
	weather: WeatherService,
	_relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_weather = weather
	_calendar = calendar
	if is_node_ready():
		_refresh_all()


func _ready() -> void:
	EventBus.minute_changed.connect(_on_minute_changed)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.season_changed.connect(func(_season: Season.Type) -> void: _refresh_date())
	EventBus.year_changed.connect(func(_year: int) -> void: _refresh_date())
	EventBus.world.weather_changed.connect(_on_weather_changed)
	EventBus.world.festival_day_started.connect(_on_festival_day_started)
	EventBus.player.money_changed.connect(_on_money_changed)
	EventBus.player.stamina_changed.connect(_on_stamina_changed)
	EventBus.player.hand_changed.connect(_on_hand_changed)
	EventBus.player.inventory_changed.connect(_on_inventory_changed)
	EventBus.ui.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.ui.notification_requested.connect(_on_notification)

	toast_label.modulate.a = 0.0
	prompt_label.text = ""
	_build_item_bar()
	_refresh_all()


# ---------------------------------------------------------------- 刷新

func _refresh_all() -> void:
	_refresh_date()
	_refresh_festival()
	_refresh_time()
	_refresh_weather()
	_on_money_changed(_profile.money if _profile != null else 0, 0)
	_refresh_item_bar()
	_refresh_hand()


func _refresh_date() -> void:
	if _clock != null:
		date_label.text = Text.date_text(_clock.date)


## 今日节日横幅：没有节日时整行隐藏，不占屏幕。
func _refresh_festival() -> void:
	var text := _calendar.today_text() if _calendar != null else ""
	festival_label.text = text
	festival_label.visible = not text.is_empty()


func _refresh_time() -> void:
	if _clock != null:
		time_label.text = _clock.time_string()


func _refresh_weather() -> void:
	var current: Weather.Type = _weather.current if _weather != null else Weather.Type.SUNNY
	var forecast: Weather.Type = _weather.forecast if _weather != null else Weather.Type.SUNNY
	var weather_name := Text.weather_name(current)
	var forecast_name := Text.weather_name(forecast)

	# 天气 / 明日预报只保留图标；文字塞进 tooltip，减少屏幕上的常驻文案。
	weather_label.text = weather_name
	weather_label.visible = false
	weather_icon.texture = _weather_icon(current)
	weather_icon.tooltip_text = weather_name

	forecast_label.text = Text.format(&"HUD_FORECAST", {"weather": forecast_name})
	forecast_label.visible = false
	forecast_icon.texture = _weather_icon(forecast)
	forecast_icon.tooltip_text = Text.format(&"HUD_FORECAST", {"weather": forecast_name})


## 取天气图标；找不到时返回 null（HUD 会只显示文字）。
func _weather_icon(weather: Weather.Type) -> Texture2D:
	var key := Weather.to_key(weather)
	if _weather_icons.has(key):
		return _weather_icons[key]
	var path := "%s/weather_%s.png" % [WEATHER_ICON_DIR, key]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_weather_icons[key] = texture
	return texture


func _refresh_hand() -> void:
	var item_id := _hand_item_id()
	# 旧的手持文字行已经隐藏，但保留节点以便兼容外部查找；
	# 真正的手持道具由底部物品栏高亮显示。
	tool_label.text = Text.item_name(Database.get_item(item_id))
	tool_icon.texture = _item_icon(item_id)


func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


func _hand_item_id() -> StringName:
	var player := _player()
	return player.item_bar.selected_item_id() if player != null else &""


# ---------------------------------------------------------------- 物品栏

func _build_item_bar() -> void:
	for node: HudSlot in _item_slots:
		node.queue_free()
	_item_slots.clear()

	if HUD_SLOT_SCENE == null:
		push_error("Hud: 找不到 hud_slot.tscn")
		return

	for _index: int in ITEM_BAR_SIZE:
		var slot := HUD_SLOT_SCENE.instantiate() as HudSlot
		inventory_bar.add_child(slot)
		_item_slots.append(slot)


## 刷新底部物品栏：直接映射背包的前几格。
##
## 物品栏不存放任何道具，所以这里只做"读背包 + 标出当前手持格"。
func _refresh_item_bar() -> void:
	if _item_slots.is_empty():
		return

	var player := _player()
	if player == null:
		for slot: HudSlot in _item_slots:
			slot.clear()
		return

	var item_bar: ItemBar = player.item_bar
	var selected := item_bar.hand_index()
	for bar_index: int in _item_slots.size():
		var backpack_index := item_bar.slot_index(bar_index)
		if backpack_index < 0:
			_item_slots[bar_index].clear()
			continue
		var inventory_slot: InventorySlot = player.inventory.slots[backpack_index]
		_item_slots[bar_index].set_item(
			inventory_slot.item_id,
			inventory_slot.count,
			backpack_index == selected,
			inventory_slot.quality
		)


# ---------------------------------------------------------------- 事件

func _on_minute_changed(_hour: int, _minute: int) -> void:
	_refresh_time()


func _on_day_changed(_date: GameDate) -> void:
	_refresh_all()


func _on_weather_changed(_weather: Weather.Type) -> void:
	_refresh_weather()


func _on_festival_day_started(_festival_id: StringName) -> void:
	_refresh_festival()


func _on_money_changed(money: int, _delta: int) -> void:
	money_label.text = Text.format(&"HUD_MONEY", {"value": money})


func _on_stamina_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_hand_changed(_item_id: StringName, _index: int) -> void:
	_refresh_hand()
	_refresh_item_bar()


func _on_inventory_changed() -> void:
	_refresh_item_bar()


## 手持道具的图标：工具本身就是 [ItemData]，图标挂在道具上。
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
