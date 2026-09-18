class_name FishingUi
extends Control
## 钓鱼小游戏界面：蓄力条 / 拉扯水槽 / 上钩横幅。
##
## 和 [Hud] 同一套单向数据流：它[b]只订阅[/b] [EventBus] 的钓鱼事件、只读玩家状态机的
## 只读快照，从不反向调用玩法代码。[method _process] 每帧问一次"玩家此刻在钓鱼吗、
## 处于哪个阶段"，命中就画，离开就整块隐藏——因此它不需要知道钓鱼状态何时开始何时结束。
##
## 拉扯水槽的竖直轴与 [FishingFight] 的深度轴一一对应（0 = 水面）：
## 浅色带是判定区（跟着鱼走），红白点是钩子，右侧两条横条分别是上钩进度与鱼线张力。

## 标记在水槽内的上下留白（像素）。
const MARKER_PADDING: float = 2.0
## 判定区在高难度下也不会窄过这么多像素，否则看不清。
const ZONE_MIN_PIXELS: float = 6.0
## 上钩横幅停留时长（秒）。
const CATCH_DURATION: float = 1.8

@onready var charge_box: VBoxContainer = %ChargeBox
@onready var charge_label: Label = %ChargeLabel
@onready var charge_bar: ProgressBar = %ChargeBar
@onready var fight_box: VBoxContainer = %FightBox
@onready var track: TextureRect = %Track
@onready var zone: TextureRect = %Zone
@onready var fish_mark: TextureRect = %FishMark
@onready var hook_mark: TextureRect = %HookMark
@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var tension_label: Label = %TensionLabel
@onready var tension_bar: ProgressBar = %TensionBar
@onready var catch_box: HBoxContainer = %CatchBox
@onready var catch_icon: TextureRect = %CatchIcon
@onready var catch_label: Label = %CatchLabel

var _catch_timer: float = 0.0


func _ready() -> void:
	charge_box.visible = false
	fight_box.visible = false
	catch_box.visible = false
	progress_bar.max_value = 100.0
	tension_bar.max_value = 100.0
	# 标签文案走 [Text]，和其余 UI 一样可被本地化。
	charge_label.text = Text.key(&"UI_FISHING_CHARGE")
	progress_label.text = Text.key(&"UI_FISHING_PROGRESS")
	tension_label.text = Text.key(&"UI_FISHING_TENSION")
	EventBus.farm.fish_caught.connect(_on_fish_caught)


func _process(delta: float) -> void:
	_tick_catch(delta)

	var state := _fishing_state()
	if state == null:
		charge_box.visible = false
		fight_box.visible = false
		return

	match state.phase():
		PlayerStateFishing.Phase.CHARGE:
			fight_box.visible = false
			charge_box.visible = true
			charge_bar.value = state.charge_ratio() * 100.0
		PlayerStateFishing.Phase.FIGHT:
			charge_box.visible = false
			_draw_fight(state.fight())
		_:
			charge_box.visible = false
			fight_box.visible = false


# ---------------------------------------------------------------- 内部

## 当前玩家是否处于钓鱼状态；不是则返回 null。
func _fishing_state() -> PlayerStateFishing:
	if get_tree() == null:
		return null
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.state_machine == null:
		return null
	return player.state_machine.current_state as PlayerStateFishing


## 把 [FishingFight] 的深度快照画到水槽上。
func _draw_fight(fight: FishingFight) -> void:
	if fight == null:
		fight_box.visible = false
		return
	fight_box.visible = true

	var area := Vector2(track.size.x, maxf(track.size.y, 1.0))
	var usable := maxf(area.y - MARKER_PADDING * 2.0, 1.0)
	var fish_y := MARKER_PADDING + fight.fish_pos() * usable
	var hook_y := MARKER_PADDING + fight.hook_pos() * usable

	var zone_height := maxf(fight.zone_half() * 2.0 * usable, ZONE_MIN_PIXELS)
	zone.size = Vector2(area.x, zone_height)
	zone.position = Vector2(
		0.0, clampf(fish_y - zone_height * 0.5, 0.0, maxf(area.y - zone_height, 0.0))
	)

	fish_mark.position = Vector2(
		(area.x - fish_mark.size.x) * 0.5, fish_y - fish_mark.size.y * 0.5
	)
	hook_mark.position = Vector2(
		(area.x - hook_mark.size.x) * 0.5, hook_y - hook_mark.size.y * 0.5
	)
	# 没压住鱼时钩子泛红，提示"张力在涨"。
	hook_mark.modulate = Color.WHITE if fight.in_contact() else Color(1.0, 0.66, 0.66)

	progress_bar.value = fight.progress() * 100.0
	tension_bar.value = fight.tension() * 100.0


func _on_fish_caught(_fish_id: StringName, item_id: StringName, size_cm: int) -> void:
	var item := Database.get_item(item_id)
	catch_icon.texture = item.icon if item != null else null
	catch_label.text = Text.format(
		&"UI_FISHING_CATCH", {"item": Text.item_name(item), "size": size_cm}
	)
	catch_box.visible = true
	_catch_timer = CATCH_DURATION


func _tick_catch(delta: float) -> void:
	if _catch_timer <= 0.0:
		return
	_catch_timer -= delta
	if _catch_timer <= 0.0:
		catch_box.visible = false
