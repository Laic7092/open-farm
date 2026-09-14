class_name Player
extends CharacterBody2D
## 玩家角色。
##
## 职责边界：
## [br]- 持有体力 / 背包 / 工具腰带这些[b]属于角色自己[/b]的状态
## [br]- 提供朝向、动画、目标格子等[b]能力[/b]给状态机使用
## [br]- 处理"面前有东西就交互"这类[b]输入意图[/b]
##
## 具体的移动、挥工具等行为全部交给 [StateMachine] 下的状态节点，
## 因此本脚本里没有 [code]match state[/code] 之类的分支。

## 玩家所在分组（全局唯一，场景路由与存档都依赖它）。
const GROUP: StringName = &"player"

## 开局自带的工具。
const DEFAULT_TOOLS: Array[StringName] = [
	&"hoe", &"watering_can", &"sickle", &"seed_bag",
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
## 背包。
var inventory: Inventory
## 工具腰带。
var tool_belt: ToolBelt
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
	tool_belt = ToolBelt.new(DEFAULT_TOOLS)


func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	GameClock.register_day_hook(_on_day_rollover)


func _ready() -> void:
	interactor.setup(self)

	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

	sprite.flip_h = Facing.flip_h(facing)
	_emit_all()

	if not inventory.has(&"turnip_seed"):
		inventory.add(&"turnip_seed", 5)


func _exit_tree() -> void:
	GameClock.unregister_day_hook(_on_day_rollover)


func _unhandled_input(event: InputEvent) -> void:
	# 状态机（子节点）先收到事件并可能消费掉；这里只处理"随时可用"的快捷键。
	if event.is_action_pressed(&"tool_next"):
		tool_belt.next()
	elif event.is_action_pressed(&"tool_prev"):
		tool_belt.prev()
	elif event.is_action_pressed(&"open_inventory"):
		EventBus.inventory_toggle_requested.emit()


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


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": String(Facing.to_key(facing)),
		"selected_seed_id": String(selected_seed_id),
		"stats": stats.to_dict(),
		"inventory": inventory.to_dict(),
		"tool_belt": tool_belt.to_dict(),
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
	var raw_belt: Variant = data.get("tool_belt", {})
	if raw_belt is Dictionary:
		tool_belt.from_dict(raw_belt)
	_emit_all()


# ---------------------------------------------------------------- 内部

func _try_harvest() -> bool:
	var grid := interactor.current_grid()
	if grid == null:
		return false
	var cell := target_cell()
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
		&"NOTIFY_CROP_HARVESTED", {"item": Text.item_name(item_id), "count": amount}
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


func _emit_all() -> void:
	EventBus.stamina_changed.emit(stats.stamina, stats.max_stamina)
	EventBus.inventory_changed.emit()
	EventBus.tool_changed.emit(tool_belt.selected_id(), tool_belt.selected_index())
	EventBus.player_facing_changed.emit(facing)
