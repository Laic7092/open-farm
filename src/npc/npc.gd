class_name Npc
extends Interactable
## NPC：可以对话、按日程在场景里走动；商人上班时由柜台（[ShopCounter]）开店。
##
## 行为数据来自 [NpcData] 与 [NpcSchedule]：
## [br]- 到点后走 [NpcNavigator] 算出的格子路径前往 [SchedulePoint]；
## [br]- 路上播放行走动画，到达后按 [member ScheduleEntry.facing] 站定；
## [br]- 商人只在日程的 [code]activity == "shop"[/code] 时才可能在柜台开店（[method is_working]）；
## [br]- 交谈 / 送礼的好感度与表白 / 求婚由 [code]RelationshipService[/code] 结算，
##   本节点只是它的视图（见 [AffectionRules]）。
##
## 本脚本只负责"把数据变成移动与一次交互"，寻路算法本身在 [GridPathfinder] 里；
## 时间 / 好感 / 对白都由本图协作根 [NpcField] 转进来，本节点不订阅全局信号、
## 也不自己断开（地图会被缓存复用，那里最容易写错）。

const GROUP: StringName = &"npc"
## 距目标格中心多近算"到了"（像素）。
const ARRIVE_EPSILON: float = 1.0
## 路径失效后隔多久再重算一次（秒），避免每帧都跑 A*。
const REPATH_INTERVAL: float = 0.5

## 好感度变化。
signal affection_changed(value: int)
## 日程切换到了新地点。
signal schedule_location_changed(location_id: StringName)

## 对应的 [NpcData.id]。
@export var npc_id: StringName = &""
## 存档标识（同一场景里多个 NPC 必须各不相同）。
@export var persistence_id: StringName = &""
## 是否在站立时播放轻微起伏动画。
@export var idle_bob: bool = true
## 关闭后不按日程走动（调试或特殊 NPC 用）。
@export var schedule_enabled: bool = true
## 只有玩家拥有该剧情旗标时 NPC 才存在（例如孩子出生后才出现在农场）。
##
## 留空表示始终存在。不可用时节点会隐藏、退出 [constant GROUP] 并停掉物理处理，
## 于是"未出生的孩子"不会参与日程与寻路。
@export var required_flag: StringName = &""

## 关系里程碑：普通对话 / 表白 / 求婚。
enum Milestone {
	NONE,     ## 普通对白
	CONFESS,  ## 表白（播放结束后进入交往）
	PROPOSE,  ## 求婚（播放结束后结婚并消耗信物）
}

## 静态数据。
var data: NpcData
## 好感度（[code]RelationshipService[/code] 的镜像，方便场景内查询）。
var affection: int = 0
## 当前朝向。
var facing: Facing.Direction = Facing.Direction.DOWN

var _pending_milestone: Milestone = Milestone.NONE
## 发起表白 / 求婚的那个玩家；对白结束时从"他"身上扣信物。
var _milestone_actor: Player
var _available: bool = true
var _schedule: NpcSchedule
var _current_entry: ScheduleEntry
## 组合根注入的时钟；日程刷新读取当天分钟 / 季节。
var _clock: GameDateClock
## 组合根注入的玩家档案；required_flag 判定使用。
var _profile: PlayerProfile
## 组合根注入的天气服务；当前没有直接读取，保留给未来的天气对白 / 日程。
var _weather: WeatherService
## 组合根注入的关系服务；好感 / 婚姻状态。
var _relationships: RelationshipService
## 组合根注入的日历服务；节日聚集点。
var _calendar: CalendarService
## 本图协作根；由 [WorldScene] 在本节点进树前注入。
var _field: NpcField
## 节日聚集用的临时日程段；复用同一个实例，避免每次刷新都新建资源。
var _festival_entry: ScheduleEntry
var _target_cell: Vector2i = NpcNavigator.NO_CELL
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _moving: bool = false
var _repath_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = %Sprite


func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_profile = profile
	_clock = clock


## 由 [WorldScene] 在世界进入树前下发领域服务。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_weather = weather
	_relationships = relationships
	_calendar = calendar


## 由 [WorldScene] 在世界进入树前注入本图协作根。
##
## 时间 / 好感 / 对白这些"外面发生的事"全部由它转进来，本节点因此不订阅
## 任何全局信号，也没有需要自己断开的连接。
func bind_npc_field(field: NpcField) -> void:
	_field = field


func _enter_tree() -> void:
	# 基类会把节点加进 flora_blocker：NPC 站着的地方不该冒出野树把它卡住。
	# 生命周期回调不会自动向父类串，必须显式调一次。
	super._enter_tree()
	add_to_group(GROUP)
	refresh_availability()


func _ready() -> void:
	data = Database.get_npc(npc_id)
	if data != null:
		prompt_key = &"PROMPT_TALK"
		if persistence_id == &"":
			persistence_id = StringName("npc_%s" % npc_id)
	else:
		push_warning("Npc: 找不到 NpcData '%s'" % npc_id)

	if persistence_id != &"":
		Persistence.register(self, persistence_id)

	# 动画来自 NpcData：同一个 npc.tscn 换个 npc_id 就换一张脸。
	if data != null:
		_schedule = data.schedule
		if data.frames != null:
			sprite.sprite_frames = data.frames
		affection = _relationships.affection(npc_id)

	if idle_bob:
		_play(&"idle")

	refresh_availability()
	_refresh_schedule()


func _physics_process(delta: float) -> void:
	if _repath_timer > 0.0:
		_repath_timer = maxf(_repath_timer - delta, 0.0)
	# 日程推进只由协作根在分钟变化时触发，不必每帧重排一次日程表。
	_advance(delta)


# ---------------------------------------------------------------- 日程

## 当前生效的日程段；没有日程时为 null。
func current_entry() -> ScheduleEntry:
	return _current_entry


## 当前要前往的地点 id；没有目标时为空。
func target_location_id() -> StringName:
	return _current_entry.location_id if _current_entry != null else &""


## 当前是否在路上。
func is_moving() -> bool:
	return _moving


## 剩余路径点数量（调试与测试用）。
func path_size() -> int:
	return _path.size()


## 商人是否"在上班"（可以开店）；没有日程数据时一律为 true，保持旧行为。
func is_working() -> bool:
	if _current_entry == null or _schedule == null:
		return true
	return _current_entry.activity == &"shop"


## 到点推进日程；由本图协作根在分钟变化时调用。
func tick_schedule() -> void:
	if schedule_enabled:
		_refresh_schedule()


func _refresh_schedule() -> void:
	if _clock == null or not _available or _schedule == null or _schedule.is_empty():
		return
	var entry := _schedule.entry_at(_clock.minute_of_day)
	# 节日优先于日常日程：全村到点放下手里的活儿去会场。
	var festival_point := _calendar.gather_point_for(npc_id)
	if festival_point != &"":
		entry = _festival_entry_for(festival_point)
	if entry == null or entry == _current_entry:
		return
	_current_entry = entry
	schedule_location_changed.emit(entry.location_id)
	_navigate_to(entry.location_id)


## 节日聚集用的日程段：复用同一个 [ScheduleEntry]，只改地点。
func _festival_entry_for(location_id: StringName) -> ScheduleEntry:
	if _festival_entry == null:
		_festival_entry = ScheduleEntry.new()
		_festival_entry.start_minute = 0
		_festival_entry.activity = &"festival"
		_festival_entry.facing = Facing.Direction.DOWN
	_festival_entry.location_id = location_id
	return _festival_entry


func _navigate_to(location_id: StringName) -> void:
	var point := _schedule_point(location_id)
	if point == null:
		push_warning("Npc '%s': 找不到日程地点 '%s'" % [npc_id, location_id])
		_target_cell = NpcNavigator.NO_CELL
		_clear_path()
		return
	var navigator := _navigator()
	if navigator != null:
		_target_cell = navigator.cell_of(point.global_position)
	else:
		_target_cell = GridUtils.world_to_cell(point.global_position)
	_recompute_path(true)


func _recompute_path(force: bool) -> void:
	if _target_cell == NpcNavigator.NO_CELL:
		return
	if not force and _repath_timer > 0.0:
		return
	var navigator := _navigator()
	if navigator == null:
		# 导航网格是父节点在 _ready() 里挂的，比 NPC 的 _ready() 晚，
		# 这里不设冷却，下一帧就会再试。
		_clear_path()
		return
	_repath_timer = REPATH_INTERVAL

	var goal := navigator.nearest_walkable(_target_cell)
	if goal == NpcNavigator.NO_CELL:
		_clear_path()
		return
	var from := navigator.cell_of(global_position)
	if from == goal:
		_finish_path()
		return
	_path = navigator.find_path(from, goal)
	_path_index = 0


func _advance(delta: float) -> void:
	if _path.is_empty():
		_set_moving(false)
		if _target_cell != NpcNavigator.NO_CELL:
			_recompute_path(false)
		return

	var next: Vector2i = _path[_path_index]
	var navigator := _navigator()
	var target_world: Vector2 = (
		navigator.world_of(next) if navigator != null else GridUtils.cell_to_world(next)
	)
	if navigator != null and next != _target_cell and not navigator.is_walkable(next):
		# 路上冒出了新障碍（例如今天长成的树），重算一次。
		_recompute_path(true)
		return

	var offset: Vector2 = target_world - global_position
	var step: float = _move_speed() * delta
	if offset.length() <= maxf(step, ARRIVE_EPSILON):
		global_position = target_world
		_path_index += 1
		if _path_index >= _path.size():
			_finish_path()
		return

	_set_moving(true)
	face(Facing.from_vector(offset, facing))
	global_position += offset.normalized() * step


func _finish_path() -> void:
	_path.clear()
	_path_index = 0
	_set_moving(false)
	if _current_entry != null:
		face(_current_entry.facing)


func _clear_path() -> void:
	_path.clear()
	_path_index = 0
	_set_moving(false)


# ---------------------------------------------------------------- 能力

## 转身；站立时会同步切换到对应朝向的待机动画。
func face(direction: Facing.Direction) -> void:
	if facing == direction:
		return
	facing = direction
	if sprite != null:
		sprite.flip_h = Facing.flip_h(facing)
	if not _moving:
		_play(&"idle")


func _set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	_play(&"walk" if moving else &"idle")


## 播放 [code]prefix_方向[/code] 形式的动画；旧帧表只有 idle_down 时退回它。
func _play(prefix: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var animation := StringName("%s_%s" % [prefix, Facing.animation_suffix(facing)])
	if not sprite.sprite_frames.has_animation(animation):
		if not sprite.sprite_frames.has_animation(&"idle_down"):
			return
		animation = &"idle_down"
	if sprite.animation == animation and sprite.is_playing():
		return
	sprite.play(animation)


func _move_speed() -> float:
	return maxf(data.move_speed, 1.0) if data != null else 24.0


## 本图导航网格；协作根没注入时返回 null（此时 NPC 原地不动）。
func _navigator() -> NpcNavigator:
	return _field.navigator() if _field != null else null


## 本图日程地点；没有这个地点时返回 null。
func _schedule_point(location_id: StringName) -> SchedulePoint:
	return _field.schedule_point(location_id) if _field != null else null


# ---------------------------------------------------------------- 对白 / 交互

## 当前应该说的话：关系阶段优先于季节。
func current_dialogue() -> DialogueData:
	if data == null:
		return null
	if data.romanceable:
		var relationship := _relationships.status(npc_id)
		if relationship == AffectionRules.Status.MARRIED and data.married_dialogue != null:
			return data.married_dialogue
		if relationship == AffectionRules.Status.DATING and data.lover_dialogue != null:
			return data.lover_dialogue
		if (
			AffectionRules.hearts(affection) >= AffectionRules.FRIEND_HEARTS
			and data.friend_dialogue != null
		):
			return data.friend_dialogue
	if _clock == null:
		return null
	return data.dialogue_for_season(_clock.date.season)


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	super.interact(actor)
	# 每次交互都先清掉上一次的引用，避免对白被强行中断后残留下副作用。
	_milestone_actor = null

	# 1) 聊天好感每天只结算一次；先结算，里程碑判定用得到最新值。
	var gained := _relationships.talk(npc_id)
	if gained > 0:
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_AFFECTION_GAIN", {"npc": display_name(), "amount": gained}
		)

	# 2) 表白 / 求婚里程碑优先于日常对白。
	var milestone := _milestone_for(actor)
	if milestone != Milestone.NONE:
		_pending_milestone = milestone
		_milestone_actor = actor as Player
		_face_actor(actor)
		_open_dialogue(_milestone_dialogue(milestone))
		return

	var dialogue := current_dialogue()
	if dialogue == null or dialogue.is_empty():
		return

	_face_actor(actor)
	_pending_milestone = Milestone.NONE
	_open_dialogue(dialogue)


## 把对白交给本图协作根：由它记下"谁在说话"，结束 / 选项时再找回来。
func _open_dialogue(dialogue: DialogueData) -> void:
	if _field != null:
		_field.open_dialogue(self, dialogue)


## 增加好感度（转发到全局关系系统 [code]RelationshipService[/code]）。
func add_affection(amount: int) -> void:
	if data == null or amount == 0:
		return
	_relationships.add_affection(npc_id, amount)


## 收到玩家送出的礼物；返回好感度收益（0 表示今天已经送过或数据缺失）。
func receive_gift(item_id: StringName) -> int:
	if data == null or item_id == &"":
		return 0
	if not _relationships.can_gift(npc_id):
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_ALREADY_GIFTED", {"npc": display_name()}
		)
		return 0
	var gain := _relationships.give_gift(npc_id, item_id)
	var key: StringName = &"NOTIFY_GIFT_NEUTRAL"
	if gain >= AffectionRules.GIFT_LOVED:
		key = &"NOTIFY_GIFT_LOVED"
	elif gain > 0:
		key = &"NOTIFY_GIFT_LIKED"
	elif gain < 0:
		key = &"NOTIFY_GIFT_DISLIKED"
	EventBus.ui.notification_requested.emit(key, {
		"npc": display_name(),
		"item": Text.item_name(Database.get_item(item_id)),
		"amount": gain,
	})
	return gain


## NPC 显示名（找不到数据时退回 id）。
func display_name() -> String:
	return Text.key(data.display_name_key) if data != null else String(npc_id)


# ---------------------------------------------------------------- 关系里程碑

## 本次交互是否应触发表白 / 求婚。
func _milestone_for(actor: Node2D) -> Milestone:
	if data == null or not data.romanceable:
		return Milestone.NONE
	if _relationships.can_confess(npc_id) and data.confession_dialogue != null:
		return Milestone.CONFESS
	if _relationships.can_marry(npc_id) and data.proposal_dialogue != null:
		var player := actor as Player
		if player != null and player.inventory.has(AffectionRules.PROPOSAL_ITEM):
			return Milestone.PROPOSE
	return Milestone.NONE


func _milestone_dialogue(milestone: Milestone) -> DialogueData:
	return data.proposal_dialogue if milestone == Milestone.PROPOSE else data.confession_dialogue


func _face_actor(actor: Node2D) -> void:
	if actor != null:
		face(Facing.from_vector(actor.global_position - global_position, facing))


## 扣除求婚信物；没有则返回 false。
##
## 信物从发起求婚的那个玩家身上扣：他已经在 [method interact] 里给过我们，
## 不必再去全局找"当前玩家"。
func _consume_proposal_item() -> bool:
	if not is_instance_valid(_milestone_actor):
		return false
	if not _milestone_actor.inventory.has(AffectionRules.PROPOSAL_ITEM):
		return false
	return _milestone_actor.inventory.remove(AffectionRules.PROPOSAL_ITEM, 1)


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"affection": affection,
		"position": [global_position.x, global_position.y],
	}


func from_dict(data_dict: Dictionary) -> void:
	# 关系状态现在由 RelationshipService 统一持有；这里的 affection 字段仅用于兼容旧档。
	var legacy_affection := maxi(int(data_dict.get("affection", 0)), 0)
	if legacy_affection > 0 and _relationships.affection(npc_id) == 0:
		_relationships.set_affection(npc_id, legacy_affection)
	affection = _relationships.affection(npc_id)
	var raw_position: Variant = data_dict.get("position", null)
	if raw_position is Array and (raw_position as Array).size() >= 2:
		global_position = Vector2(
			float((raw_position as Array)[0]), float((raw_position as Array)[1])
		)
	# 位置被存档改写后，立刻按当前时间重新挑一段日程并寻路。
	_current_entry = null
	_repath_timer = 0.0
	_clear_path()
	_refresh_schedule()
	affection_changed.emit(affection)


## 对白播完（或被关掉）；由本图协作根只回传给发起者。
func finish_dialogue() -> void:
	var milestone := _pending_milestone
	_pending_milestone = Milestone.NONE
	if milestone == Milestone.CONFESS:
		_relationships.confess(npc_id)
	elif milestone == Milestone.PROPOSE:
		# 只有真的扣掉了信物才结婚，避免对白被跳过时"白嫖"。
		if _consume_proposal_item():
			_relationships.marry(npc_id)
	_milestone_actor = null


## 结算对白选项的副作用（好感 / 旗标）；由本图协作根只回传给发起者。
func apply_dialogue_choice(choice: DialogueChoice) -> void:
	if choice == null:
		return
	if choice.affection_delta != 0:
		_relationships.add_affection(npc_id, choice.affection_delta)
	if choice.set_flag != &"" and _profile != null:
		_profile.set_flag(choice.set_flag)


# ---------------------------------------------------------------- 关系 / 可用性

## 好感度被外部改写时同步镜像并发本地信号；由协作根只转给对应的那个人。
func mirror_affection(value: int) -> void:
	affection = value
	affection_changed.emit(value)


## 按 [member required_flag] 决定这个 NPC 当前是否存在。
##
## 由协作根在跨天 / 孩子出生时调用，[method _ready] 也会先跑一次。
## 不存在时隐藏、退出 [constant GROUP] 并停掉物理处理，
## 这样"未出生的孩子"不会出现在日程 / 寻路 / 存档遍历里。
func refresh_availability() -> void:
	if required_flag == &"":
		return
	var available := _profile != null and _profile.has_flag(required_flag)
	if available == _available:
		return
	_available = available
	visible = available
	enabled = available
	set_physics_process(available)
	if available:
		if not is_in_group(GROUP):
			add_to_group(GROUP)
		_refresh_schedule()
	else:
		if is_in_group(GROUP):
			remove_from_group(GROUP)
		_clear_path()
