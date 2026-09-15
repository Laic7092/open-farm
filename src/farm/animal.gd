class_name Animal
extends Interactable
## 畜舍里一头牲畜的可视化节点。
##
## 自己不保存任何游戏状态（状态在 [AnimalState] / [LivestockManager]），
## 只负责在围栏内慢慢踱步，并把"互动"翻译成"收产出 / 抚摸"。

## 踱步速度（像素/秒）。刻意很慢：牲畜是氛围，不是追逐。
const WANDER_SPEED: float = 11.0
## 到达目标后原地停留的时间范围（秒）。
const MIN_IDLE: float = 1.5
const MAX_IDLE: float = 4.5

## 在畜舍中的下标（与 [BuildingState.animals] 对齐）。
var index: int = -1

var _manager: LivestockManager
var _building_id: StringName = &""
var _state: AnimalState
var _bounds: Rect2 = Rect2()
var _target: Vector2 = Vector2.ZERO
var _idle: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = %Sprite


## 由 [LivestockManager] 在实例化后调用。
func setup(
	p_manager: LivestockManager,
	p_building_id: StringName,
	p_index: int,
	p_state: AnimalState,
	p_bounds: Rect2
) -> void:
	_manager = p_manager
	_building_id = p_building_id
	index = p_index
	_state = p_state
	_bounds = p_bounds
	_rng.seed = hash("%s:%d" % [p_building_id, p_index])
	global_position = _random_point()
	_pick_target()
	refresh_sprite()


## 按当前状态更新贴图帧。
func refresh_sprite() -> void:
	if _state == null:
		return
	var data := Database.get_animal(_state.animal_id)
	if data != null and data.sprite_sheet != null:
		sprite.texture = data.sprite_sheet
		sprite.hframes = 3
		sprite.frame = AnimalHusbandry.sprite_column(data, _state)


func interact(actor: Node2D) -> void:
	super.interact(actor)
	var player := actor as Player
	if _manager == null or player == null or _state == null:
		return
	var data := Database.get_animal(_state.animal_id)

	if AnimalHusbandry.can_collect(data, _state):
		var outcome := _manager.collect(_building_id, index)
		var amount: int = int(outcome.get("amount", 0))
		if amount > 0:
			var item_id: StringName = outcome.get("item_id", &"")
			player.inventory.add(item_id, amount)
			EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMAL_PRODUCT", {
				"item": Text.item_name(Database.get_item(item_id)), "count": amount,
			})
		return

	var gained: int = _manager.pet(_building_id, index)
	if gained > 0:
		EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMAL_PETTED", {
			"animal": Text.animal_name(Database.get_animal(_state.animal_id)), "amount": gained,
		})
	else:
		EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMAL_ALREADY_PETTED", {
			"animal": Text.animal_name(Database.get_animal(_state.animal_id)),
		})


# ---------------------------------------------------------------- 踱步

func _process(delta: float) -> void:
	if _bounds.size == Vector2.ZERO or _state == null:
		return
	if _idle > 0.0:
		_idle -= delta
		if _idle <= 0.0:
			_pick_target()
		return
	var to_target: Vector2 = _target - global_position
	if to_target.length() < 1.0:
		_idle = _rng.randf_range(MIN_IDLE, MAX_IDLE)
		return
	global_position += to_target.normalized() * WANDER_SPEED * delta
	# 朝目标方向翻转贴图，让踱步有一点生命感。
	if absf(to_target.x) > 0.5:
		sprite.flip_h = to_target.x < 0.0


func _pick_target() -> void:
	_target = _random_point()


func _random_point() -> Vector2:
	if _bounds.size == Vector2.ZERO:
		return global_position
	return Vector2(
		_rng.randf_range(_bounds.position.x, _bounds.end.x),
		_rng.randf_range(_bounds.position.y, _bounds.end.y)
	)
