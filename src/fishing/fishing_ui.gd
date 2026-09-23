class_name FishingUi
extends Control
## 钓鱼小游戏界面：蓄力条 / 拉扯水槽 / 上钩横幅。
##
## 和 [Hud] 同一套单向数据流：它[b]只订阅[/b] [EventBus] 的钓鱼事件、
## 只读注入进来的 [FishingSession] 快照，从不反向调用玩法代码，也不去翻玩家状态机。
## [method _process] 每帧问一次"当前钓鱼单元处于哪个阶段"，命中就画，离开就整块隐藏。
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
@onready var track_area: Control = %TrackArea
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
## 组合根注入的"当前钓鱼单元"提供者；没有它时整块不显示。
var _session_provider: Callable = Callable()
## 触控控件占用的左右宽度；右侧 ABXY 会压住拉扯水槽，必须让位。
var _touch_insets: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 尺寸令牌：水槽与标记的大小只从 [UiLayout] 来，场景里不写裸数字。
	track_area.custom_minimum_size = UiLayout.FISH_TRACK_SIZE
	track.size = UiLayout.FISH_TRACK_SIZE
	zone.size = UiLayout.FISH_ZONE_SIZE
	fish_mark.size = UiLayout.FISH_MARK_SIZE
	hook_mark.size = UiLayout.FISH_HOOK_SIZE
	charge_bar.custom_minimum_size = UiLayout.FISH_CHARGE_BAR
	progress_bar.custom_minimum_size = UiLayout.BAR_SIZE
	tension_bar.custom_minimum_size = UiLayout.BAR_SIZE
	catch_icon.custom_minimum_size = UiLayout.ITEM_ICON_SIZE
	EventBus.ui.touch_insets_changed.connect(_on_touch_insets_changed)
	_layout_fight()
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


## 组合根注入"当前钓鱼单元"的提供者；界面只读它，不去翻玩家状态机。
func bind_fishing(provider: Callable) -> void:
	_session_provider = provider


func _on_touch_insets_changed(insets: Vector2) -> void:
	_touch_insets = insets
	_layout_fight()


## 把拉扯水槽放到右侧触控控件左边；触控关闭时退回令牌给定的屏幕右边距。
func _layout_fight() -> void:
	var right_margin := UiLayout.MARGIN_SCREEN
	if _touch_insets.y > 0.0:
		# 右侧占位已含屏幕边距与横向留白，这里只留两者之间的间隙。
		right_margin = _touch_insets.y + UiLayout.FISH_FIGHT_GAP
	fight_box.offset_right = -right_margin
	fight_box.offset_left = fight_box.offset_right - UiLayout.FISH_FIGHT_WIDTH


func _process(delta: float) -> void:
	_tick_catch(delta)

	var session := _current_fishing()
	if session == null:
		charge_box.visible = false
		fight_box.visible = false
		return

	match session.phase():
		FishingSession.Phase.CHARGE:
			fight_box.visible = false
			charge_box.visible = true
			charge_bar.value = session.charge_ratio() * 100.0
		FishingSession.Phase.FIGHT:
			charge_box.visible = false
			_draw_fight(session.fight())
		_:
			charge_box.visible = false
			fight_box.visible = false


# ---------------------------------------------------------------- 内部

## 当前钓鱼单元；组合根没有注入提供者时返回 null。
func _current_fishing() -> FishingSession:
	if not _session_provider.is_valid():
		return null
	return _session_provider.call() as FishingSession


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
