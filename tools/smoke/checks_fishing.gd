extends "res://tools/smoke/smoke_base.gd"
## 钓鱼时序 的冒烟检查；公共断言 / 取用器见 smoke_base.gd。

## 钓鱼的数据与水面接线：海滩挂没挂 WaterField、鱼种是否齐全、抽不抽得出鱼。
func _check_fishing_data() -> void:
	_check(Database.fish().size() >= 10, "鱼种数据应当至少有 10 种")
	var water := get_tree().get_first_node_in_group(WaterField.GROUP) as WaterField
	_check(water != null, "海滩应当自动挂载 WaterField")
	if water != null:
		_check(water.is_water(Vector2i(5, 18)), "海滩 (5,18) 应当是水面")
		_check(
			water.kind_at(Vector2i(5, 18)) == WaterKind.Kind.OCEAN,
			"海滩的水应当算作海"
		)
		_check(not water.is_water(Vector2i(5, 17)), "沙滩不该被当成水面")

	var pool: Array[FishData] = []
	for fish_id: StringName in Database.fish():
		var fish := Database.get_fish(fish_id)
		if fish != null:
			pool.append(fish)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_check(
		FishingRules.pick(
			pool, rng, WaterKind.Kind.OCEAN, Season.Type.SPRING, Weather.Type.SUNNY, 12
		) != null,
		"春 12:00 的海边应当至少抽得出一种鱼"
	)
	_check(
		FishingRules.pick(
			pool, rng, WaterKind.Kind.POND, Season.Type.SPRING, Weather.Type.SUNNY, 12
		) != null,
		"春 12:00 的池塘应当至少抽得出一种鱼"
	)


## 站到海边、拿出钓竿，把真实的状态机切进 Fishing。
func _start_fishing_check() -> void:
	_check_fishing_data()
	var water := get_tree().get_first_node_in_group(WaterField.GROUP) as WaterField
	var player := _player()
	if player == null or water == null:
		_fail("钓鱼检查缺少玩家或水面")
		_fishing_state = null
		return

	player.global_position = GridUtils.cell_to_world(Vector2i(5, 17))
	player.face(Facing.Direction.DOWN)
	var rod_slot: int = player.inventory.find_slot(&"fishing_rod")
	_check(rod_slot >= 0, "背包里应当有钓竿")
	_check(player.item_bar.select(rod_slot), "应当能选中钓竿")
	_check(player.wants_fishing(), "选中钓竿后 wants_fishing 应为真")
	_check(player.can_fish(), "面朝海水时应当能下竿（目标格 %s）" % player.target_cell())
	_check(
		player.fishing_water_kind() == WaterKind.Kind.OCEAN,
		"面前的一格应当算作海水"
	)

	_fishing_before = _fish_count(player)
	_fishing_frames = 0
	_fish_bit = false
	# 固定随机源，让咬钩时间与整场拉扯在 CI 里可复现。
	player.fishing.rng.seed = 20240601
	if not EventBus.farm.fish_bite.is_connected(_on_smoke_fish_bite):
		EventBus.farm.fish_bite.connect(_on_smoke_fish_bite)
	player.state_machine.transition_to(&"fishing")
	_fishing_state = player.state_machine.current_state
	_check(_fishing_state != null, "应当进入钓鱼状态")


## 推进钓鱼时序；返回 true 表示这次垂钓已出结果。
func _advance_fishing_check() -> bool:
	if _fishing_state == null:
		return true
	var player := _player()
	if player == null:
		_fail("钓鱼过程中玩家消失了")
		_fishing_state = null
		return true
	_fishing_frames += 1
	if _fishing_frames > 3600:
		_fail("钓鱼时序超时：%d 帧仍未收竿" % _fishing_frames)
		_fishing_state = null
		return true

	# 拉扯小游戏里模拟“鱼往哪游就往哪收线”，直到上岸。
	var fishing := player.fishing
	if fishing != null and fishing.phase() == FishingSession.Phase.FIGHT:
		_fish_bit = true
		_drive_reel(fishing)

	if player.state_machine.current_state != _fishing_state:
		_check(_fish_bit, "等待过程中应当进入拉扯小游戏")
		_check(
			_fish_count(player) > _fishing_before,
			"收竿之后背包里应当多一条鱼（%d → %d）"
				% [_fishing_before, _fish_count(player)]
		)
		_fishing_state = null
		return true
	return false


## 钩子沉在鱼下方就收线，否则松手——和真人“把钩子压在鱼身上”一个意思。
func _drive_reel(fishing: FishingSession) -> void:
	var fight := fishing.fight()
	if fight == null:
		return
	var want := fight.fish_pos() < fight.hook_pos()
	if want == fishing.reeling():
		return
	var event := InputEventAction.new()
	event.action = &"use_tool"
	event.pressed = want
	fishing.handle_input(event)


func _on_smoke_fish_bite(_fish_id: StringName) -> void:
	_fish_bit = true


## 背包里全部鱼类的总数。
func _fish_count(player: Player) -> int:
	var total: int = 0
	for fish_id: StringName in Database.fish():
		var fish := Database.get_fish(fish_id)
		if fish != null:
			total += player.inventory.count_of(fish.item_id)
	return total
