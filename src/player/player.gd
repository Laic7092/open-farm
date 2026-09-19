class_name Player
extends CharacterBody2D
## 玩家角色。
##
## 职责边界：
## [br]- 持有体力 / 背包这些[b]属于角色自己[/b]的状态（物品栏只是背包的快捷视图）
## [br]- 提供朝向、动画、目标格子等[b]能力[/b]给状态机使用
## [br]- 处理"面前有东西就交互"这类[b]输入意图[/b]
##
## 具体的移动、挥工具等行为全部交给 [StateMachine] 下的状态节点，
## 因此本脚本里没有 [code]match state[/code] 之类的分支。

## 玩家所在分组（全局唯一，场景路由与存档都依赖它）。
const GROUP: StringName = &"player"

## 开局自带的工具（作为普通道具放进背包，不会消耗）。
##
## 斧头与镐子必须自带：世界会自己长树长石头，玩家没有清理手段的话，
## "更真实的世界"就变成了"走不动的世界"。
const DEFAULT_TOOLS: Array[StringName] = [
	&"hoe", &"watering_can", &"sickle", &"seed_bag", &"axe", &"pickaxe", &"fishing_rod",
]

## 脚步：每走这么多像素响一声。
const STEP_DISTANCE: float = 34.0

## 走路速度（像素/秒）。
@export var walk_speed: float = 52.0
## 奔跑速度（像素/秒）。
@export var run_speed: float = 92.0
## 存档标识。
@export var persistence_id: StringName = &"player"

## 当前朝向。
var facing: Facing.Direction = Facing.Direction.DOWN
## 体力。
var stats: PlayerStats
## 背包（唯一存放道具的地方，工具也在里面）。
var inventory: Inventory
## 物品栏：背包前几格的快捷访问视图，不存放任何道具。
var item_bar: ItemBar
## 钓鱼单元：一次垂钓的完整时序与随机源；随机源可固定种子复现冒烟测试。
var fishing: FishingSession
## 玩家自己的音效播放器（脚步 / 体力 / 背包满）；谁发声谁持有。
var sfx: SfxPlayer
## 脚步累积距离与左右脚交替计数。
var _step_accum: float = 0.0
var _step_index: int = 0
## 手动选中的种子；为空时自动取背包里的第一种种子。
var selected_seed_id: StringName = &""

var _nearby: Array[Interactable] = []
## 组合根注入的时钟；日结转钩子注册在它上面。
var _clock: GameDateClock
## 组合根注入的关系服务；赠礼结算。
var _relationships: RelationshipService


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


## 由 [WorldScene] 在世界进入树前下发领域服务。
func bind_services(
	_weather: WeatherService,
	relationships: RelationshipService,
	_calendar: CalendarService
) -> void:
	_relationships = relationships

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var state_machine: StateMachine = %StateMachine
@onready var interaction_area: Area2D = %InteractionArea
@onready var interactor: FarmInteractor = %FarmInteractor
@onready var fishing_bobber: FishingBobber = %FishingBobber
@onready var camera: Camera2D = $Camera2D


## 运行期对象在 [code]_init()[/code] 里建立，而不是 [code]_ready()[/code]：
## 世界场景会被 [SceneRouter] 缓存复用、多次进出场景树，
## 而 [code]_ready()[/code] 只跑一次、[code]_init()[/code] 也只会跑一次——
## 但把它放这里语义更清楚：这些是"这个角色自己的东西"，跟进没进树无关。
func _init() -> void:
	stats = PlayerStats.new()
	inventory = Inventory.new()
	inventory.set_stack_limit_provider(Callable(Database, &"get_item"))
	item_bar = ItemBar.new(inventory)
	fishing = FishingSession.new(self)
	# 纯数据对象只发本地信号；由 Player 这个拥有者统一转发到 EventBus。
	stats.changed.connect(_on_stats_changed)
	stats.depleted.connect(_on_stats_depleted)
	inventory.changed.connect(_on_inventory_changed)
	inventory.item_added.connect(_on_item_added)
	inventory.full.connect(_on_inventory_full)


func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WORLD)


func _ready() -> void:
	interactor.setup(self)
	sfx = SfxPlayer.new()
	sfx.name = "Sfx"
	add_child(sfx)

	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

	sprite.flip_h = Facing.flip_h(facing)
	_grant_default_tools()
	if not inventory.has(&"turnip_seed"):
		inventory.add(&"turnip_seed", 5)
	_emit_all()


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


# ---------------------------------------------------------------- 脚步

## 按走过的距离触发脚步；不侵入移动状态机。
func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	if velocity.length() < 8.0:
		# 停下时把累积量留在"差一步"的位置，起步立刻有声音。
		_step_accum = STEP_DISTANCE * 0.75
		return
	_step_accum += velocity.length() * delta
	if _step_accum < STEP_DISTANCE:
		return
	_step_accum = 0.0
	_step_index += 1
	if sfx != null:
		sfx.play(_footstep_id(), 1.04 if (_step_index % 2) == 0 else 0.96, -6.0)


## 脚步音由玩家所在的世界场景声明；没有世界时退回草地。
func _footstep_id() -> StringName:
	var world := _world_scene()
	if world != null and world.footstep_sfx != &"":
		return world.footstep_sfx
	return AudioCatalog.SFX_FOOTSTEP_GRASS


## 玩家所属的世界场景根；不在世界里时返回 null。
func _world_scene() -> WorldScene:
	var node: Node = get_parent()
	while node != null:
		if node is WorldScene:
			return node
		node = node.get_parent()
	return null


func _unhandled_input(event: InputEvent) -> void:
	# 状态机（子节点）先收到事件并可能消费掉；这里只处理"随时可用"的快捷键。
	if event.is_action_pressed(&"tool_next"):
		item_bar.next()
	elif event.is_action_pressed(&"tool_prev"):
		item_bar.prev()
	elif event.is_action_pressed(&"open_inventory"):
		EventBus.ui.inventory_toggle_requested.emit()
	elif event.is_action_pressed(&"give_gift"):
		try_give_gift()


# ---------------------------------------------------------------- 能力

## 归一化的输入方向。
func input_direction() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## 当前速度上限。
func current_speed() -> float:
	return run_speed if Input.is_action_pressed(&"run") else walk_speed


## 当前朝向对应的格子步进。
func facing_vector() -> Vector2i:
	return Facing.to_vector(facing)


## 面朝的格子（工具作用的目标格）。
##
## 距离取手持工具的 [member ToolData.reach]，于是升级后的工具能伸得更远。
func target_cell() -> Vector2i:
	var reach: int = 1
	var tool := selected_tool()
	if tool != null:
		reach = maxi(tool.reach, 1)
	var probe: Vector2 = global_position + Vector2(facing_vector()) * float(GridUtils.TILE_SIZE * reach)
	return GridUtils.world_to_cell(probe)


## 转身。
func face(direction: Facing.Direction) -> void:
	if facing == direction:
		return
	facing = direction
	sprite.flip_h = Facing.flip_h(facing)
	EventBus.player.player_facing_changed.emit(facing)


## 播放 [code]prefix_方向[/code] 形式的动画；同一动画正在播放时不会重头开始。
func play_animation(prefix: StringName) -> void:
	var animation := StringName("%s_%s" % [prefix, Facing.animation_suffix(facing)])
	if not sprite.sprite_frames.has_animation(animation):
		return
	if sprite.animation == animation and sprite.is_playing():
		return
	sprite.play(animation)


## 背包中可用的种子（优先手动选中的那个）。
func effective_seed_id() -> StringName:
	if selected_seed_id != &"" and inventory.has(selected_seed_id):
		return selected_seed_id
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty():
			continue
		var item := Database.get_item(slot.item_id)
		if item != null and item.category == ItemData.Category.SEED:
			return slot.item_id
	return &""


## 当前手持道具对应的工具数据；手持的不是工具时返回 null。
func selected_tool() -> ToolData:
	return item_bar.selected_tool()


## 手持的是不是钓竿。
func wants_fishing() -> bool:
	var tool := item_bar.selected_tool()
	return tool != null and tool.kind == ToolData.Kind.FISHING


## 面前那一格的水域类型；不是水返回 -1。
func fishing_water_kind() -> int:
	return interactor.water_kind_at(target_cell())


## 抛竿落点的世界坐标；[param distance] 为离玩家几格（1 = 面前那一格）。
func fishing_target_position(distance: float) -> Vector2:
	var base := GridUtils.cell_to_world(target_cell())
	var overshoot := Vector2(facing_vector()) \
		* (maxf(distance, 1.0) - 1.0) * float(GridUtils.TILE_SIZE)
	return base + overshoot


## 竿尖的世界坐标（鱼线的起点）。
##
## 只是一个跟着朝向走的近似点：抛竿时“手抬到哪”、鱼线就从哪开始。
func rod_tip_position() -> Vector2:
	return global_position + Vector2(facing_vector()) * 9.0 + Vector2(0.0, -9.0)


## 此刻能否下竿（手持钓竿 + 面前是水）。
func can_fish() -> bool:
	return wants_fishing() and fishing_water_kind() >= 0


## 当前季节；没有时钟时按春算。
func current_season() -> Season.Type:
	return _clock.date.season if _clock != null else Season.Type.SPRING


## 当前整点小时。
func current_hour() -> int:
	return _clock.hour() if _clock != null else GameDateClock.DAY_START_HOUR


## 当前天气；没有服务时按晴算。
func current_weather() -> Weather.Type:
	return interactor.current_weather()


## 结算一次成功钓鱼：放进背包并广播。背包放不下时返回 false（不吞掉这条鱼）。
func land_fish(fish: FishData, size_cm: int) -> bool:
	if fish == null or fish.item_id == &"":
		return false
	if inventory.add(fish.item_id, 1) > 0:
		return false
	EventBus.farm.fish_caught.emit(fish.id, fish.item_id, size_cm)
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_FISH_CAUGHT",
		{"item": Text.item_name(Database.get_item(fish.item_id)), "size": size_cm}
	)
	return true


# ---------------------------------------------------------------- 交互

## 当前距离最近且朝向更优的可交互目标。
func current_interactable() -> Interactable:
	var best: Interactable = null
	var best_score: float = -INF
	var forward := Vector2(facing_vector())
	for candidate: Interactable in _nearby:
		if not is_instance_valid(candidate) or not candidate.can_interact():
			continue
		var to_target: Vector2 = candidate.global_position - global_position
		var distance: float = maxf(to_target.length(), 0.001)
		# 越"正前方"越优先，距离作为次要因素。
		var score: float = to_target.normalized().dot(forward) * 2.0 - distance * 0.01
		if score > best_score:
			best_score = score
			best = candidate
	return best


## 按下交互键时的完整意图解析。
func try_interact() -> bool:
	if _try_harvest():
		return true
	var target := current_interactable()
	if target != null:
		target.interact(self)
		return true
	EventBus.ui.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
	return false


## 把背包里最合适的一件礼物送给面前的 NPC（G 键）。
##
## "最合适"= 对该 NPC 好感收益最高的可赠道具：优先 GIFT 分类，
## 其次是 NPC 偏好表里明确提到过的道具。求婚信物永远不会被当作普通礼物送掉。
func try_give_gift() -> bool:
	if _clock == null:
		return false
	var npc := current_interactable() as Npc
	if npc == null:
		EventBus.ui.notification_requested.emit(&"NOTIFY_NO_GIFT_TARGET", {})
		return false
	if not _relationships.can_gift(npc.npc_id):
		EventBus.ui.notification_requested.emit(
			&"NOTIFY_ALREADY_GIFTED", {"npc": npc.display_name()}
		)
		return false
	var item_id := _pick_gift(npc)
	if item_id == &"":
		EventBus.ui.notification_requested.emit(&"NOTIFY_NO_GIFT", {})
		return false
	if not inventory.remove(item_id, 1):
		return false
	npc.receive_gift(item_id)
	return true


## 挑一件对 [param npc] 收益最高的可赠道具；没有可赠道具时返回空串。
func _pick_gift(npc: Npc) -> StringName:
	var best: StringName = &""
	var best_gain: int = -99999
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty() or slot.item_id == AffectionRules.PROPOSAL_ITEM:
			continue
		var item := Database.get_item(slot.item_id)
		if item == null or not _is_giftable(item, npc):
			continue
		var gain := _relationships.gift_gain(npc.npc_id, slot.item_id)
		if gain > best_gain:
			best_gain = gain
			best = slot.item_id
	return best


func _is_giftable(item: ItemData, npc: Npc) -> bool:
	if item.category == ItemData.Category.GIFT:
		return true
	if npc.data == null:
		return false
	return (
		npc.data.loved_gifts.has(item.id)
		or npc.data.liked_gifts.has(item.id)
		or npc.data.disliked_gifts.has(item.id)
	)


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": String(Facing.to_key(facing)),
		"selected_seed_id": String(selected_seed_id),
		"stats": stats.to_dict(),
		"inventory": inventory.to_dict(),
		"item_bar": item_bar.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	var raw_position: Variant = data.get("position", null)
	if raw_position is Array and (raw_position as Array).size() >= 2:
		global_position = Vector2(
			float((raw_position as Array)[0]), float((raw_position as Array)[1])
		)
	facing = Facing.from_key(str(data.get("facing", "down")))
	selected_seed_id = StringName(str(data.get("selected_seed_id", "")))
	sprite.flip_h = Facing.flip_h(facing)

	var raw_stats: Variant = data.get("stats", {})
	if raw_stats is Dictionary:
		stats.from_dict(raw_stats)
	var raw_inventory: Variant = data.get("inventory", {})
	if raw_inventory is Dictionary:
		inventory.from_dict(raw_inventory)
	# 旧存档把工具单独放在 tool_belt 里；先并回背包，再补齐开局工具。
	_migrate_legacy_tool_belt(data)
	_grant_default_tools()

	var raw_bar: Variant = data.get("item_bar", {})
	if raw_bar is Dictionary:
		item_bar.from_dict(raw_bar)
	_emit_all()


# ---------------------------------------------------------------- 内部

func _try_harvest() -> bool:
	var cell := target_cell()
	var grid := interactor.current_grid()
	if grid != null and _try_harvest_crop(grid, cell):
		return true
	return _try_pick_flora(cell)


## 农田上的作物（成熟后徒手收）。
func _try_harvest_crop(grid: FarmGrid, cell: Vector2i) -> bool:
	var crop := grid.get_crop(cell)
	if crop == null:
		return false
	var data := Database.get_crop(crop.crop_id)
	if not CropGrowth.can_harvest(data, crop):
		return false

	var outcome := grid.harvest(cell)
	var amount: int = int(outcome.get("amount", 0))
	if amount <= 0:
		return false
	var item_id: StringName = outcome.get("item_id", &"")
	inventory.add(item_id, amount, int(outcome.get("quality", 0)))
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_CROP_HARVESTED", {"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)
	return true


## 野外的花 / 蘑菇（[member FloraData.pickable_by_hand]）。
func _try_pick_flora(cell: Vector2i) -> bool:
	var field := interactor.current_flora()
	if field == null or not bool(field.call(&"occupied", cell)):
		return false
	var outcome: Dictionary = field.call(&"clear", cell, ToolData.Kind.SICKLE, true)
	var amount: int = int(outcome.get("amount", 0))
	if amount <= 0:
		return false
	var item_id: StringName = outcome.get("item_id", &"")
	inventory.add(item_id, amount, int(outcome.get("quality", 0)))
	EventBus.ui.notification_requested.emit(
		&"NOTIFY_FLORA_CLEARED", {"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)
	return true


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null or _nearby.has(interactable):
		return
	_nearby.append(interactable)
	EventBus.ui.interaction_prompt_changed.emit(interactable.prompt_key)


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null:
		return
	_nearby.erase(interactable)
	var next := current_interactable()
	EventBus.ui.interaction_prompt_changed.emit(next.prompt_key if next != null else &"")


func _on_day_rollover(_date: GameDate) -> void:
	if stats != null:
		stats.refill()


## 体力变化后转发给 UI / 音频。
func _on_stats_changed(current: int, maximum: int) -> void:
	EventBus.player.stamina_changed.emit(current, maximum)


## 力竭：广播给域事件，并由玩家自己的播放器出声。
func _on_stats_depleted() -> void:
	EventBus.player.stamina_depleted.emit()
	if sfx != null:
		sfx.play(AudioCatalog.SFX_STAMINA_DEPLETED)


## 背包内容变化后转发给 UI（物品栏与背包界面都订阅 [signal EventBus.player.inventory_changed]）。
func _on_inventory_changed() -> void:
	EventBus.player.inventory_changed.emit()


## 新道具入包后转发给图鉴等"收藏"逻辑。
func _on_item_added(item_id: StringName) -> void:
	EventBus.player.item_obtained.emit(item_id)


## 背包满：广播给域事件，并由玩家自己的播放器出声。
func _on_inventory_full(item_id: StringName) -> void:
	EventBus.player.inventory_full.emit(item_id)
	if sfx != null:
		sfx.play(AudioCatalog.SFX_ERROR)


func _emit_all() -> void:
	EventBus.player.stamina_changed.emit(stats.stamina, stats.max_stamina)
	EventBus.player.inventory_changed.emit()
	EventBus.player.hand_changed.emit(item_bar.selected_item_id(), item_bar.hand_index())
	EventBus.player.player_facing_changed.emit(facing)


## 保证背包里一定有开局工具（幂等：已有就不再加）。
func _grant_default_tools() -> void:
	for tool_id: StringName in DEFAULT_TOOLS:
		if not inventory.has(tool_id):
			inventory.add(tool_id, 1)


## 把旧存档 [code]tool_belt[/code] 里的工具并回背包。
##
## 旧版本把工具当成"背包之外的永久库存"，新版本里工具就是普通道具；
## 这里只做一次性兼容，缺的工具之后由 [method _grant_default_tools] 补齐。
func _migrate_legacy_tool_belt(data: Dictionary) -> void:
	var legacy: Variant = data.get("tool_belt", {})
	if not (legacy is Dictionary):
		return
	var raw: Variant = (legacy as Dictionary).get("tools", [])
	if not (raw is Array):
		return
	for entry: Variant in raw:
		var tool_id := StringName(str(entry))
		if tool_id != &"" and not inventory.has(tool_id):
			inventory.add(tool_id, 1)
