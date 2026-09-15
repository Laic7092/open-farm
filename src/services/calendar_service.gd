class_name CalendarService
extends Node
## 节日与事件服务（由 [Main] 组合根持有，不再是 Autoload）。
##
## 节日与事件是[b]跨场景[/b]的日历状态：玩家在农场睡觉时"今天是花祭"
## 就已经成立，换到小镇才看得见会场；"哪些事件已经发生过"也必须跟着存档走。
## 状态本体是 [CalendarProgress]（Resource），服务只负责查表、判定与广播。
##
## 职责边界：
## [br]- 从 [Database] 装填节日 / 事件表；
## [br]- 在 [DayPipeline] 的 [constant DayPipeline.PRIORITY_CALENDAR] 钩子里判定；
## [br]- 持有"今年参加过哪些节日 / 哪些事件已触发"并负责存档；
## [br]- 通过 [EventBus] 广播，不直接碰 UI 或场景节点。
##
## 判定规则全在纯静态的 [FestivalRules] / [EventRules] 里，本脚本只做"查状态 + 落状态"。

## 今天有节日时的提示文案键。
const NOTIFY_TODAY: StringName = &"NOTIFY_FESTIVAL_TODAY"
## 参加节日成功的提示文案键。
const NOTIFY_ATTENDED: StringName = &"NOTIFY_FESTIVAL_ATTENDED"
## 今年已经参加过时的提示文案键。
const NOTIFY_ALREADY: StringName = &"NOTIFY_FESTIVAL_ALREADY"

## 节日表（按 id 排序，保证输出稳定）。
var _festivals: Array[FestivalData] = []
## 事件表（按 id 排序）。
var _events: Array[EventData] = []
## 今天要办的节日缓存。
var _today: Array[FestivalData] = []
## 缓存对应的绝对天数；-1 表示需要重算。
var _today_absolute_day: int = -1
## 节日 / 事件进度；由组合根持有，可整体替换。
var _progress: CalendarProgress = CalendarProgress.new()
## 组合根注入的时钟；未注入时刷新 / 判定查询安全地返回空。
var _clock: GameDateClock
## 组合根注入的玩家档案；用于旗标与奖励。
var _profile: PlayerProfile
## 组合根注入的天气服务；事件条件需要读取当天天气。
var _weather: WeatherService
## 组合根注入的关系服务；事件条件需要读取指定 NPC 好感。
var _relationships: RelationshipService
## 表数据是否已经从 [Database] 装入，避免重复 reload 造成重复播报。
var _tables_loaded: bool = false


func _ready() -> void:
	# 存档键名继续保持 "Calendar"，兼容旧存档。
	Persistence.register_core(self, &"Calendar", 50)
	if not Database.reloaded.is_connected(reload):
		Database.reloaded.connect(reload)
	if not _tables_loaded:
		reload()


## 注入组合根持有的状态与服务，并重新注册日结转钩子。
func bind_dependencies(
	profile: PlayerProfile,
	clock: GameDateClock,
	weather: WeatherService,
	relationships: RelationshipService
) -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)
	_profile = profile
	_clock = clock
	_weather = weather
	_relationships = relationships
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_CALENDAR)
	_today_absolute_day = -1
	reload()


## 当前节日 / 事件进度；由组合根持有，可整体替换。
func state() -> CalendarProgress:
	return _progress


## 换入节日 / 事件进度；传 null 会创建一份新的默认状态。
func set_state(value: CalendarProgress) -> void:
	_progress = value if value != null else CalendarProgress.new()
	_today_absolute_day = -1


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)
	if Database.reloaded.is_connected(reload):
		Database.reloaded.disconnect(reload)


# ---------------------------------------------------------------- 装载 / 刷新

## 重新从 [Database] 装填节日与事件表。
func reload() -> void:
	_festivals = Database.festival_list()
	_events = Database.event_list()
	_tables_loaded = true
	_today_absolute_day = -1
	refresh()


## 重算"今天有哪些节日"并广播 [signal EventBus.world.festival_day_started]。
##
## 开新档 / 读档 / 日结转后都要调用一次：前两者不会触发日结转钩子，
## 但 HUD 的节日横幅必须立刻正确。
func refresh() -> void:
	var today := today_festivals()
	for festival: FestivalData in today:
		EventBus.world.festival_day_started.emit(festival.id)


# ---------------------------------------------------------------- 查询

## 全部节日（副本，防止调用方改动内部表）。
func festivals() -> Array[FestivalData]:
	var result: Array[FestivalData] = []
	result.assign(_festivals)
	return result


## 全部事件（副本）。
func events() -> Array[EventData]:
	var result: Array[EventData] = []
	result.assign(_events)
	return result


## 按 id 取节日；不存在返回 null。
func festival(festival_id: StringName) -> FestivalData:
	for entry: FestivalData in _festivals:
		if entry.id == festival_id:
			return entry
	return null


## 按 id 取事件；不存在返回 null。
func event(event_id: StringName) -> EventData:
	for entry: EventData in _events:
		if entry.id == event_id:
			return entry
	return null


## 今天要办的节日（缓存 + 惰性重算，跨天由 [method _on_day_rollover] 置脏）。
func today_festivals() -> Array[FestivalData]:
	if _clock == null:
		return []
	if _today_absolute_day != _clock.date.absolute_day():
		_today_absolute_day = _clock.date.absolute_day()
		_today = []
		for entry: FestivalData in FestivalRules.on_date(_festivals, _clock.date):
			if is_available(entry):
				_today.append(entry)
	return _today


## 节日是否满足前置旗标。
func is_available(entry: FestivalData) -> bool:
	if entry == null:
		return false
	if entry.required_flag == &"":
		return true
	if _profile == null:
		return false
	return _profile.has_flag(entry.required_flag)


## 今天是否有节日。
func has_festival_today() -> bool:
	return not today_festivals().is_empty()


## 该节日此刻是否"正在进行"（是今天、且会场已开门）。
func is_active(festival_id: StringName) -> bool:
	if _clock == null:
		return false
	var entry := festival(festival_id)
	if entry == null or not today_festivals().has(entry):
		return false
	return FestivalRules.is_within(entry, _clock.minute_of_day)


## 此刻正在进行的节日；没有则返回 null。
func active_festival() -> FestivalData:
	if _clock == null:
		return null
	for entry: FestivalData in today_festivals():
		if FestivalRules.is_within(entry, _clock.minute_of_day):
			return entry
	return null


## 该 NPC 此刻应该去哪个节日聚集点；不参加时返回空串。
##
## [Npc] 在每次刷新日程时问一次，于是"节日一到，全村放下手里的活儿去广场"
## 不需要给每个 NPC 写一份节日日程。
func gather_point_for(npc_id: StringName) -> StringName:
	var entry := active_festival()
	if entry == null or not entry.npc_ids.has(npc_id):
		return &""
	return entry.gather_point


## 今年是否已经参加过该节日（节日每年重办，奖励每年一次）。
func has_attended(festival_id: StringName) -> bool:
	if _clock == null:
		return false
	return int(_progress.attended.get(festival_id, 0)) == _clock.date.year


## 此刻能不能参加（会场开着且今年还没参加过）。
func can_attend(festival_id: StringName) -> bool:
	return is_active(festival_id) and not has_attended(festival_id)


## 事件是否已经发生过（[member EventData.once] 为 false 时按"今年"判断）。
func has_triggered(event_id: StringName) -> bool:
	if _clock == null:
		return false
	return _was_triggered(event_id, _clock.date)


## 今天已命中条件、可触发的事件。
func events_for_today() -> Array[EventData]:
	var result: Array[EventData] = []
	if _clock == null or _profile == null:
		return result
	var weather := _current_weather()
	for entry: EventData in _events:
		if _was_triggered(entry.id, _clock.date):
			continue
		if _matches(entry, _clock.date, weather, _affection_for(entry.required_npc)):
			result.append(entry)
	return result


## 节日显示名；找不到数据时退回 id。
func festival_name(festival_id: StringName) -> String:
	var entry := festival(festival_id)
	if entry == null:
		return String(festival_id)
	return Text.key(entry.display_name_key)


## HUD 用的"今日节日"文本；没有节日时返回空串。
func today_text() -> String:
	var names := PackedStringArray()
	for entry: FestivalData in today_festivals():
		names.append(Text.key(entry.display_name_key))
	return "、".join(names)


# ---------------------------------------------------------------- 参加

## 参加节日：给每位到场 NPC 加好感、打旗标；每年只能领一次奖励。
##
## 返回 true 表示这次真的结算了（调用方据此决定要不要播首次对白）。
func attend(festival_id: StringName) -> bool:
	if _clock == null or _profile == null:
		return false
	if not is_active(festival_id):
		return false
	if has_attended(festival_id):
		EventBus.ui.notification_requested.emit(NOTIFY_ALREADY, {
			"festival": festival_name(festival_id),
		})
		return false
	var entry := festival(festival_id)
	_progress.attended[festival_id] = _clock.date.year
	if entry.attendance_flag != &"":
		_profile.set_flag(entry.attendance_flag)
	for npc_id: StringName in entry.npc_ids:
		if _relationships != null:
			_relationships.add_affection(npc_id, entry.attendance_affection)
	EventBus.world.festival_attended.emit(festival_id, entry.attendance_affection)
	EventBus.ui.notification_requested.emit(NOTIFY_ATTENDED, {
		"festival": Text.key(entry.display_name_key),
		"amount": entry.attendance_affection,
	})
	return true


# ---------------------------------------------------------------- 复位 / 序列化

## 复位到新游戏状态（开新档时调用）。
func reset() -> void:
	_progress.reset()
	_today_absolute_day = -1
	refresh()


func to_dict() -> Dictionary:
	return _progress.to_dict()


func from_dict(data: Dictionary) -> void:
	_progress.from_dict(data)
	_today_absolute_day = -1
	refresh()


# ---------------------------------------------------------------- 内部

## 日结转：先播报今天的节日，再判定一次性事件。
##
## [constant DayPipeline.PRIORITY_WEATHER] 数值低于本钩子，保证此时
## [WeatherService] 已经掷出了今天的天气，事件可以拿天气当条件。
func _on_day_rollover(date: GameDate) -> void:
	_today_absolute_day = -1
	for entry: FestivalData in today_festivals():
		EventBus.world.festival_day_started.emit(entry.id)
		EventBus.ui.notification_requested.emit(NOTIFY_TODAY, {
			"festival": Text.key(entry.display_name_key),
		})
	var weather := _current_weather()
	for entry: EventData in _events:
		if _was_triggered(entry.id, date):
			continue
		if not _matches(entry, date, weather, _affection_for(entry.required_npc)):
			continue
		_trigger(entry, date)


## 纯函数式判定入口：所有外部事实（日期 / 天气 / 旗标 / 好感）都由调用方
## 查好后传入，规则层不读任何 Autoload 或服务。
func _matches(entry: EventData, date: GameDate, weather: int, affection: int) -> bool:
	if _profile == null:
		return false
	return EventRules.matches(
		entry,
		date,
		weather,
		_profile.has_flag(entry.required_flag),
		_profile.has_flag(entry.forbidden_flag),
		affection
	)


## 当前天气；服务未注入时按晴天处理，保证纯测试可运行。
func _current_weather() -> int:
	return int(_weather.current) if _weather != null else int(Weather.Type.SUNNY)


## 指定 NPC 的好感；关系服务未注入或 NPC 为空时返回 0。
func _affection_for(npc_id: StringName) -> int:
	if npc_id == &"" or _relationships == null:
		return 0
	return _relationships.affection(npc_id)


func _trigger(entry: EventData, date: GameDate) -> void:
	_progress.triggered[entry.id] = date.absolute_day()
	if _profile != null:
		if entry.set_flag != &"":
			_profile.set_flag(entry.set_flag)
		if entry.grant_money > 0:
			_profile.earn(entry.grant_money)
	EventBus.world.calendar_event_triggered.emit(entry.id)
	var message_key: StringName = entry.message_key if entry.message_key != &"" else entry.title_key
	EventBus.ui.notification_requested.emit(message_key, {"money": entry.grant_money})
	if entry.dialogue != null and not entry.dialogue.is_empty():
		EventBus.ui.dialogue_requested.emit(entry.dialogue)


## 是否已经发生过；[member EventData.once] 为 false 时按"同一个游戏年内"判断。
func _was_triggered(event_id: StringName, date: GameDate) -> bool:
	if not _progress.triggered.has(event_id):
		return false
	var entry := event(event_id)
	if entry != null and not entry.once:
		var at := GameDate.from_absolute_day(int(_progress.triggered[event_id]))
		return at.year == date.year
	return true
