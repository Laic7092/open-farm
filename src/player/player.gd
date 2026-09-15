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
	&"hoe", &"watering_can", &"sickle", &"seed_bag", &"axe", &"pickaxe",
]

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
## 手动选中的种子；为空时自动取背包里的第一种种子。
var selected_seed_id: StringName = &""

var _nearby: Array[Interactable] = []

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var state_machine: StateMachine = %StateMachine
@onready var interaction_area: Area2D = %InteractionArea
@onready var interactor: FarmInteractor = %FarmInteractor
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
	# 纯数据对象只发本地信号；由 Player 这个拥有者统一转发到 EventBus。
	stats.changed.connect(_on_stats_changed)
	stats.depleted.connect(_on_stats_depleted)
	inventory.changed.connect(_on_inventory_changed)
	inventory.full.connect(_on_inventory_full)


func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	GameClock.register_day_hook(_on_day_rollover)


func _ready() -> void:
	interactor.setup(self)

	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

	sprite.flip_h = Facing.flip_h(facing)
	_grant_default_tools()
	if not inventory.has(&"turnip_seed"):
		inventory.add(&"turnip_seed", 5)
	_emit_all()


func _exit_tree() -> void:
	GameClock.unregister_day_hook(_on_day_rollover)


func _unhandled_input(event: InputEvent) -> void:
	# 状态机（子节点）先收到事件并可能消费掉；这里只处理"随时可用"的快捷键。
	if event.is_action_pressed(&"tool_next"):
		item_bar.next()
	elif event.is_action_pressed(&"tool_prev"):
		item_bar.prev()
	elif event.is_action_pressed(&"open_inventory"):
		EventBus.inventory_toggle_requested.emit()
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
func target_cell() -> Vector2i:
	var probe: Vector2 = global_position + Vector2(facing_vector()) * float(GridUtils.TILE_SIZE)
	return GridUtils.world_to_cell(probe)


## 转身。
func face(direction: Facing.Direction) -> void:
	if facing == direction:
		return
	facing = direction
	sprite.flip_h = Facing.flip_h(facing)
	EventBus.player_facing_changed.emit(facing)


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
	EventBus.notification_requested.emit(&"NOTIFY_NOTHING_HAPPENED", {})
	return false


## 把背包里最合适的一件礼物送给面前的 NPC（G 键）。
##
## "最合适"= 对该 NPC 好感收益最高的可赠道具：优先 GIFT 分类，
## 其次是 NPC 偏好表里明确提到过的道具。求婚信物永远不会被当作普通礼物送掉。
func try_give_gift() -> bool:
	if GameClock.paused:
		return false
	var npc := current_interactable() as Npc
	if npc == null:
		EventBus.notification_requested.emit(&"NOTIFY_NO_GIFT_TARGET", {})
		return false
	if not Relationships.can_gift(npc.npc_id):
		EventBus.notification_requested.emit(
			&"NOTIFY_ALREADY_GIFTED", {"npc": npc.display_name()}
		)
		return false
	var item_id := _pick_gift(npc)
	if item_id == &"":
		EventBus.notification_requested.emit(&"NOTIFY_NO_GIFT", {})
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
		var gain := Relationships.gift_gain(npc.npc_id, slot.item_id)
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
	inventory.add(item_id, amount)
	EventBus.notification_requested.emit(
		&"NOTIFY_CROP_HARVESTED", {"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)
	return true


## 野外的花 / 蘑菇（[member FloraData.pickable_by_hand]）。
func _try_pick_flora(cell: Vector2i) -> bool:
	var field := interactor.current_flora()
	if field == null or not field.occupied(cell):
		return false
	var outcome := field.clear(cell, ToolData.Kind.SICKLE, true)
	var amount: int = int(outcome.get("amount", 0))
	if amount <= 0:
		return false
	var item_id: StringName = outcome.get("item_id", &"")
	inventory.add(item_id, amount)
	EventBus.notification_requested.emit(
		&"NOTIFY_FLORA_CLEARED", {"item": Text.item_name(Database.get_item(item_id)), "count": amount}
	)
	return true


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null or _nearby.has(interactable):
		return
	_nearby.append(interactable)
	EventBus.interaction_prompt_changed.emit(interactable.prompt_key)


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null:
		return
	_nearby.erase(interactable)
	var next := current_interactable()
	EventBus.interaction_prompt_changed.emit(next.prompt_key if next != null else &"")


func _on_day_rollover(_date: GameDate) -> void:
	if stats != null:
		stats.refill()


## 体力变化后转发给 UI / 音频。
func _on_stats_changed(current: int, maximum: int) -> void:
	EventBus.stamina_changed.emit(current, maximum)


## 力竭后转发给音频。
func _on_stats_depleted() -> void:
	EventBus.stamina_depleted.emit()


## 背包内容变化后转发给 UI（物品栏与背包界面都订阅 [signal EventBus.inventory_changed]）。
func _on_inventory_changed() -> void:
	EventBus.inventory_changed.emit()


## 背包满时转发给音频。
func _on_inventory_full(item_id: StringName) -> void:
	EventBus.inventory_full.emit(item_id)


func _emit_all() -> void:
	EventBus.stamina_changed.emit(stats.stamina, stats.max_stamina)
	EventBus.inventory_changed.emit()
	EventBus.hand_changed.emit(item_bar.selected_item_id(), item_bar.hand_index())
	EventBus.player_facing_changed.emit(facing)


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
