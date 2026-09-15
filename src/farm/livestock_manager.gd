class_name LivestockManager
extends Node2D
## 畜舍与牲畜的权威状态（对应农田的 [FarmGrid]）。
##
## 负责：
## [br]- 保存每座畜舍里住了哪些牲畜、各自长到几岁 / 好感度 / 今天是否喂过
## [br]- 按需生成牲畜的可视化节点（[Animal]）
## [br]- 在日结转时推进所有牲畜的成长与产出
##
## 设计取舍与 [FarmGrid] 一致：状态放在 [BuildingState] 里，于是"养殖存档"
## 就是一次 [method to_dict]，牲畜节点只是视图、随时可以丢弃重建。

## 加入该分组后，测试与 UI 可以找到当前场景的畜舍系统。
const GROUP: StringName = &"livestock"

## 牲畜场景 [Animal]。
@export var animal_scene: PackedScene

## 牲畜节点的父节点；留空则用本节点。
@export var animal_root: Node2D

## 存档标识。
@export var persistence_id: StringName = &"farm_livestock"

## 畜舍状态表：building_id → 状态。
var buildings: Dictionary[StringName, BuildingState] = {}

var _pens: Dictionary[StringName, AnimalPen] = {}
var _views: Dictionary[StringName, Array] = {}
var _rng := RandomNumberGenerator.new()
## 组合根注入的时钟；日结转钩子注册在它上面。
var _clock: GameDateClock


func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


func _enter_tree() -> void:
	add_to_group(GROUP)
	Persistence.register(self, persistence_id)
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WORLD)


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


func _ready() -> void:
	_rng.randomize()
	_collect_pens()
	_rebuild_visuals()


# ---------------------------------------------------------------- 查询

## 某栋建筑对应的畜舍节点。
func pen_for(building_id: StringName) -> AnimalPen:
	return _pens.get(building_id) as AnimalPen


## 某栋建筑的静态定义。
func building_data(building_id: StringName) -> BuildingData:
	return Database.get_building(building_id)


## 畜舍状态；不存在时按需创建。
func state_for(building_id: StringName) -> BuildingState:
	if not buildings.has(building_id):
		buildings[building_id] = BuildingState.new(building_id)
	return buildings[building_id]


## 畜舍容量。
func capacity_of(building_id: StringName) -> int:
	var data := building_data(building_id)
	return data.capacity if data != null else 0


## 舍内牲畜数量。
func animal_count(building_id: StringName) -> int:
	var state := buildings.get(building_id) as BuildingState
	return state.size() if state != null else 0


## 是否住满。
func is_full(building_id: StringName) -> bool:
	var data := building_data(building_id)
	return data != null and animal_count(building_id) >= data.capacity


## 还饿着的牲畜数量（今天没喂过的）。
func hungry_count(building_id: StringName) -> int:
	var state := buildings.get(building_id) as BuildingState
	if state == null:
		return 0
	var total: int = 0
	for animal_state: AnimalState in state.animals:
		var data := Database.get_animal(animal_state.animal_id)
		if data != null and AnimalHusbandry.needs_feed(data, animal_state):
			total += 1
	return total


# ---------------------------------------------------------------- 操作

## 把背包里合适的牲畜安置进畜舍；返回是否成功。
##
## 遍历背包而不是"指定道具 id"，于是鸡 / 牛可以共用一个交互键：
## 玩家拿着什么，畜舍就收什么；不合适的东西会被忽略。
func introduce(building_id: StringName, player: Player) -> bool:
	if player == null:
		return false
	var data := building_data(building_id)
	if data == null or pen_for(building_id) == null or is_full(building_id):
		return false

	for slot: InventorySlot in player.inventory.slots:
		if slot.is_empty():
			continue
		var item := Database.get_item(slot.item_id)
		if item == null or item.category != ItemData.Category.ANIMAL:
			continue
		var animal := Database.get_animal(item.animal_id)
		if animal == null or not data.allows(animal):
			continue
		if not player.inventory.remove(slot.item_id, 1):
			continue
		_add_animal(building_id, animal.id)
		EventBus.ui.notification_requested.emit(&"NOTIFY_ANIMAL_PLACED", {
			"animal": Text.animal_name(Database.get_animal(animal.id)),
			"building": Text.building_name(Database.get_building(building_id)),
		})
		return true
	return false


## 用背包里的饲料喂饱一座畜舍；返回实际喂食数量。
##
## 先统计缺口、确认饲料充足，再一次性扣除，避免"喂到一半发现饲料不够"。
func feed(building_id: StringName, inventory: Inventory) -> int:
	var state := buildings.get(building_id) as BuildingState
	if state == null or inventory == null or state.animals.is_empty():
		return 0

	var needed: Dictionary[StringName, int] = {}
	for animal_state: AnimalState in state.animals:
		var data := Database.get_animal(animal_state.animal_id)
		if data == null or not AnimalHusbandry.needs_feed(data, animal_state):
			continue
		needed[data.feed_item_id] = needed.get(data.feed_item_id, 0) + 1
	if needed.is_empty():
		return 0
	for item_id: StringName in needed:
		if not inventory.has(item_id, needed[item_id]):
			return 0

	for item_id: StringName in needed:
		inventory.remove(item_id, needed[item_id])

	var fed_count: int = 0
	for animal_state: AnimalState in state.animals:
		var data := Database.get_animal(animal_state.animal_id)
		if data != null and AnimalHusbandry.feed(data, animal_state):
			fed_count += 1
	if fed_count > 0:
		EventBus.farm.animal_fed.emit(building_id, fed_count)
	return fed_count


## 抚摸一头牲畜；返回增加的好感度（0 表示今天已经摸过）。
func pet(building_id: StringName, index: int) -> int:
	var animal_state := _animal_at(building_id, index)
	if animal_state == null:
		return 0
	var data := Database.get_animal(animal_state.animal_id)
	var gained: int = AnimalHusbandry.pet(data, animal_state)
	if gained > 0:
		EventBus.farm.animal_petted.emit(building_id, animal_state.animal_id, animal_state.affection)
	return gained


## 收一头牲畜的产出。
##
## 返回 [code]{ "item_id": StringName, "amount": int, "bonus": bool }[/code]，
## [code]amount[/code] 为 0 表示现在没有可收的。
func collect(building_id: StringName, index: int) -> Dictionary:
	var animal_state := _animal_at(building_id, index)
	if animal_state == null:
		return {}
	var data := Database.get_animal(animal_state.animal_id)
	var outcome := AnimalHusbandry.apply_collect(data, animal_state, _rng)
	var amount: int = int(outcome.get("amount", 0))
	if amount > 0:
		EventBus.farm.animal_product_collected.emit(
			building_id, animal_state.animal_id, outcome["item_id"], amount
		)
		_refresh_views(building_id)
	return outcome


## 某头牲畜的运行时状态；越界返回 null。
func animal_state_at(building_id: StringName, index: int) -> AnimalState:
	return _animal_at(building_id, index)


# ---------------------------------------------------------------- 日结转

## 推进一天：所有牲畜结算成长 / 产出计时，当天的喂食 / 抚摸标记清零。
func advance_day(_date: GameDate) -> void:
	for building_id: StringName in buildings:
		var state: BuildingState = buildings[building_id]
		for animal_state: AnimalState in state.animals:
			var data := Database.get_animal(animal_state.animal_id)
			if data == null:
				continue
			var change := AnimalHusbandry.advance(
				data, animal_state, animal_state.fed_today
			)
			if bool(change.get(AnimalHusbandry.KEY_MATURED, false)):
				EventBus.farm.animal_matured.emit(building_id, animal_state.animal_id)
	_refresh_all()


# ---------------------------------------------------------------- 序列化

func to_dict() -> Dictionary:
	var entries: Array = []
	var ids: Array = buildings.keys()
	# 排序保证存档内容稳定，便于 diff 与测试。
	ids.sort()
	for building_id: StringName in ids:
		entries.append(buildings[building_id].to_dict())
	return {"buildings": entries}


func from_dict(data: Dictionary) -> void:
	buildings.clear()
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for entry: Variant in raw:
			if not entry is Dictionary:
				continue
			var state := BuildingState.new()
			state.from_dict(entry)
			buildings[state.building_id] = state
	_rebuild_visuals()


# ---------------------------------------------------------------- 内部

func _collect_pens() -> void:
	_pens.clear()
	for child: Node in get_children():
		var pen := child as AnimalPen
		if pen != null and pen.building_id != &"":
			_pens[pen.building_id] = pen


func _animal_at(building_id: StringName, index: int) -> AnimalState:
	var state := buildings.get(building_id) as BuildingState
	if state == null or index < 0 or index >= state.animals.size():
		return null
	return state.animals[index]


func _add_animal(building_id: StringName, animal_id: StringName) -> void:
	var state := state_for(building_id)
	state.add(AnimalState.new(animal_id))
	_spawn_view(building_id, state.animals.size() - 1)
	EventBus.farm.animal_placed.emit(building_id, animal_id)


func _view_list(building_id: StringName) -> Array:
	if not _views.has(building_id):
		_views[building_id] = []
	return _views[building_id]


func _spawn_view(building_id: StringName, index: int) -> void:
	if animal_scene == null:
		return
	var animal_state := _animal_at(building_id, index)
	if animal_state == null:
		return
	var view := animal_scene.instantiate() as Animal
	if view == null:
		push_error("LivestockManager: animal_scene 的根节点必须是 Animal")
		return

	var parent: Node = animal_root if animal_root != null else self
	parent.add_child(view)

	var pen := pen_for(building_id)
	var bounds: Rect2 = (
		pen.world_wander_area() if pen != null else Rect2(global_position, Vector2(16, 16))
	)
	view.setup(self, building_id, index, animal_state, bounds)

	var list: Array = _view_list(building_id)
	while list.size() <= index:
		list.append(null)
	if is_instance_valid(list[index]):
		list[index].queue_free()
	list[index] = view


func _refresh_views(building_id: StringName) -> void:
	var state := buildings.get(building_id) as BuildingState
	if state == null:
		return
	var list: Array = _views.get(building_id, [])
	for index: int in mini(list.size(), state.animals.size()):
		var view := list[index] as Animal
		if is_instance_valid(view):
			view.refresh_sprite()


func _refresh_all() -> void:
	for building_id: StringName in buildings:
		_refresh_views(building_id)


func _rebuild_visuals() -> void:
	for list: Array in _views.values():
		for node: Variant in list:
			if is_instance_valid(node):
				(node as Node).queue_free()
	_views.clear()
	for building_id: StringName in buildings:
		var state: BuildingState = buildings[building_id]
		for index: int in state.animals.size():
			_spawn_view(building_id, index)


func _on_day_rollover(date: GameDate) -> void:
	advance_day(date)
