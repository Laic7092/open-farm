class_name FestivalGround
extends Interactable
## 节日会场：节日当天开门，玩家按 E 参加。
##
## 会场只认 [member festival_ids] 里的节日 id："今天办不办、现在开不开门"全部问
## [code]CalendarService[/code]，因此同一个地点按 E 会参加"此刻正在进行的那一场"。
## 子节点 `Stall`（可空）是摊位贴图，非节日期间自动收起来。

## 在这个会场举办的节日 id（同一地点可以轮办多场节日）。
@export var festival_ids: Array[StringName] = []

@onready var _stall: Sprite2D = get_node_or_null(^"Stall") as Sprite2D
## 组合根注入的日历服务；判断节日是否进行中并参加。
var _calendar: CalendarService


## 由 [WorldScene] 在世界进入树前下发领域服务。
func bind_services(
	_weather: WeatherService,
	_relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_calendar = calendar
	_refresh_visual()


func _enter_tree() -> void:
	super._enter_tree()
	prompt_key = &"PROMPT_FESTIVAL"
	# 世界场景会被缓存复用，所以"每次进树都要接上"的信号放在 _enter_tree 里。
	if not EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.connect(_on_day_changed)
	if not EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.connect(_on_minute_changed)
	_refresh_visual()


func _exit_tree() -> void:
	if EventBus.day_changed.is_connected(_on_day_changed):
		EventBus.day_changed.disconnect(_on_day_changed)
	if EventBus.minute_changed.is_connected(_on_minute_changed):
		EventBus.minute_changed.disconnect(_on_minute_changed)


## 此刻正在这个会场举办的节日；没有则返回空串。
func active_id() -> StringName:
	for festival_id: StringName in festival_ids:
		if _calendar.is_active(festival_id):
			return festival_id
	return &""


## 只有节日进行中才能交互；玩家因此不会在空无一人的广场上按 E 参加明天的祭典。
func can_interact() -> bool:
	return active_id() != &""


func interact(actor: Node2D) -> void:
	var festival_id := active_id()
	if festival_id == &"":
		return
	super.interact(actor)
	var entry := _calendar.festival(festival_id)
	var first_time: bool = not _calendar.has_attended(festival_id)
	# 首次参加：结算好感 / 旗标并播开场对白；有比赛的话下次交互再开。
	if first_time:
		if not _calendar.attend(festival_id):
			return
		if entry != null and entry.intro_dialogue != null:
			if not entry.intro_dialogue.is_empty():
				EventBus.ui.dialogue_requested.emit(entry.intro_dialogue)
		return
	# 已经参加过：有比赛就开赛，没有就只提醒今年来过。
	if entry != null and entry.game_id != &"":
		EventBus.ui.festival_game_requested.emit(festival_id)
		return
	_calendar.attend(festival_id)


func _on_day_changed(_date: GameDate) -> void:
	_refresh_visual()


func _on_minute_changed(_hour: int, _minute: int) -> void:
	_refresh_visual()


## 摊位贴图只在节日进行中露出来。
func _refresh_visual() -> void:
	if _stall != null:
		_stall.visible = active_id() != &""
