class_name FishingSession
extends RefCounted
## 钓鱼单元：一次垂钓从蓄力到收杆的完整时序。
##
## 规则（[FishingRules] / [FishingFight]）保持纯逻辑，本单元只做编排：
## 阶段推进、喂输入、驱动 [FishingBobber] 与音效事件、结算入包。
## 宿主是 [Player]，提供竿尖 / 落点 / 水面 / 时钟等上下文；
## [PlayerStateFishing] 只是模式锁壳，把移动锁住并把输入转给本单元。
##
## [b]按键[/b]（全部与普通工具一致，只有空格）：
## [br]- 蓄力阶段[b]按住[/b]空格决定抛多远，松手即抛出；
## [br]- 等鱼时按一下 = 提前收竿；
## [br]- 拉扯时[b]按住[/b]空格收线、松开让钩子下沉，把钩子压在鱼身上攒满进度。

## 本次垂钓结束（成功 / 逃脱 / 取消都一样）；宿主据此切回待机。
signal finished()

## 各阶段的时长（秒）。
const CAST_DURATION: float = 0.35
const REEL_DURATION: float = 0.42
## 拉扯时每响一次收线音的间隔（秒）。
const REEL_TICK_INTERVAL: float = 0.16

enum Phase {
	CHARGE,  ## 按住空格蓄力
	CAST,    ## 抛竿动作
	WAIT,    ## 浮标入水，等鱼咬钩
	FIGHT,   ## 拉扯小游戏
	REEL,    ## 上钩后的收杆动作
	DONE,    ## 已出结果，等待切回待机
}

## 钓鱼用的随机源；由本单元持有，冒烟测试会固定种子来复现整条时序。
var rng := RandomNumberGenerator.new()

var _player: Player
var _phase: Phase = Phase.DONE
var _timer: float = 0.0
var _rod: ToolData
var _fish: FishData
var _water_kind: int = -1
var _held: float = 0.0
var _cast_power: float = 0.0
var _cast_distance: float = 0.0
var _bite_at: float = 0.0
var _fight: FishingFight
var _reeling: bool = false
var _reel_tick: float = 0.0
var _ended: bool = true


func _init(player: Player) -> void:
	_player = player
	rng.randomize()


## 开始一次垂钓；水面在"下竿那一刻"锁定，之后转身 / 换工具都不会改变这次垂钓。
func begin() -> void:
	_rod = _player.item_bar.selected_tool()
	_water_kind = _player.fishing_water_kind()
	_fish = null
	_fight = null
	_held = 0.0
	_cast_power = FishingRules.CAST_POWER_MIN
	_cast_distance = FishingRules.cast_distance(_cast_power)
	_reeling = false
	_reel_tick = 0.0
	_ended = false
	_phase = Phase.CHARGE
	_timer = 0.0
	_player.play_animation(&"use")


## 结束一次垂钓；重复调用安全。
func end() -> void:
	_player.play_animation(&"idle")
	_end_fishing()


func update(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_timer += delta
	match _phase:
		Phase.CHARGE:
			_update_charge(delta)
		Phase.CAST:
			if _timer >= CAST_DURATION:
				_begin_wait()
		Phase.WAIT:
			if _timer >= _bite_at:
				_begin_fight()
		Phase.FIGHT:
			_step_fight(delta)
		Phase.REEL:
			if _timer >= REEL_DURATION:
				_finish_land()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use_tool"):
		match _phase:
			Phase.WAIT:
				_cancel()
			Phase.FIGHT:
				_reeling = true
	elif event.is_action_released(&"use_tool"):
		if _phase == Phase.FIGHT:
			_reeling = false


# ---------------------------------------------------------------- 只读状态（界面 / 冒烟测试）

## 当前阶段。
func phase() -> Phase:
	return _phase


## 当前蓄力进度（0~1），仅用于界面蓄力条。
func charge_ratio() -> float:
	return clampf(_held / FishingRules.CAST_CHARGE_TIME, 0.0, 1.0)


## 上一次抛竿的蓄力（0~1）。
func cast_power() -> float:
	return _cast_power


## 上一次抛竿的落点距离（格）。
func cast_distance() -> float:
	return _cast_distance


## 当前拉扯小游戏；还没咬钩时为 null。
func fight() -> FishingFight:
	return _fight


## 玩家此刻是否在收线。
func reeling() -> bool:
	return _reeling


## 本次垂钓选中的鱼；还没选中时为 null。
func target_fish() -> FishData:
	return _fish


# ---------------------------------------------------------------- 内部：三个阶段

## 蓄力：按住空格涨条，松手（或按满）就抛出去。
##
## 直接读 [method Input.is_action_pressed] 而不是等一条"松开"事件，
## 是因为进入本单元的那次按下已经被 [code]PlayerStateIdle[/code] 消费掉了。
func _update_charge(delta: float) -> void:
	if Input.is_action_pressed(&"use_tool"):
		_held = minf(_held + delta, FishingRules.CAST_CHARGE_TIME)
		return
	_cast()


func _cast() -> void:
	_phase = Phase.CAST
	_timer = 0.0
	_cast_power = FishingRules.cast_power(_held)
	_cast_distance = FishingRules.cast_distance(_cast_power)
	# 体力在真正抛出的这一刻结算：不管最后钓没钓上来，这一杆都算数。
	_player.interactor.consume_stamina(_rod)
	_player.fishing_bobber.cast_to(
		_player.rod_tip_position(),
		_player.fishing_target_position(_cast_distance),
		_cast_power
	)
	EventBus.farm.fish_cast.emit(_cast_power, _cast_distance)
	# 蓄力越满，出力声越尖。
	_play(AudioCatalog.SFX_FISH_CHARGE, 0.88 + 0.35 * clampf(_cast_power, 0.0, 1.0), -5.0)
	_play(AudioCatalog.SFX_FISH_CAST, 1.0, -4.0)
	# 抛竿后由所在地图临时接管 BGM。
	var world := _player.world_scene()
	if world != null:
		world.push_bgm_override(AudioCatalog.BGM_FISHING)


func _begin_wait() -> void:
	_phase = Phase.WAIT
	_timer = 0.0
	_fish = _pick_fish()
	if _fish == null:
		# 这片水此刻一条鱼都没有：直接收竿，不让玩家干等。
		_cancel()
		return
	_bite_at = FishingRules.bite_delay(rng, _tier())


func _begin_fight() -> void:
	_phase = Phase.FIGHT
	_timer = 0.0
	_fight = FishingFight.new(_fish, _tier(), rng)
	# 咬钩时玩家可能还按着空格，那就当作一开始就在收线。
	_reeling = Input.is_action_pressed(&"use_tool")
	_reel_tick = 0.0
	_player.play_animation(&"use")
	_player.fishing_bobber.bite()
	_player.fishing_bobber.set_fight(true)
	EventBus.farm.fish_bite.emit(_fish.id if _fish != null else &"")
	_play(AudioCatalog.SFX_FISH_BITE)
	_play(AudioCatalog.SFX_FISH_FIGHT, 1.0, -7.0)
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_BITE", {})


func _step_fight(delta: float) -> void:
	if _fight == null:
		_cancel()
		return
	if _reeling:
		_reel_tick -= delta
		if _reel_tick <= 0.0:
			_reel_tick = REEL_TICK_INTERVAL
			EventBus.farm.fish_reel_tick.emit()
			_play(AudioCatalog.SFX_FISH_REEL, 1.0, -10.0)
	_player.fishing_bobber.set_tension(_fight.tension())
	match _fight.step(delta, _reeling):
		FishingFight.Status.LANDED:
			_begin_reel()
		FishingFight.Status.ESCAPED:
			_escape()


func _begin_reel() -> void:
	_phase = Phase.REEL
	_timer = 0.0
	_reeling = false
	_player.play_animation(&"use")
	_player.fishing_bobber.reel_in()


func _finish_land() -> void:
	_phase = Phase.DONE
	if _fish != null:
		var size: int = FishingRules.roll_size(_fish, rng)
		_player.land_fish(_fish, size)
	_end_fishing()
	finished.emit()


func _escape() -> void:
	_phase = Phase.DONE
	_player.fishing_bobber.reel_in()
	_play(AudioCatalog.SFX_FISH_LINE_BREAK)
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_ESCAPED", {})
	_end_fishing()
	finished.emit()


func _cancel() -> void:
	_phase = Phase.DONE
	_player.fishing_bobber.reel_in()
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_CANCELLED", {})
	_end_fishing()
	finished.emit()


## 保证 [signal FarmEvents.fish_ended] 每次垂钓只发一次（收杆与 [method end] 都会经过这里）。
func _end_fishing() -> void:
	if _ended:
		return
	_ended = true
	_player.fishing_bobber.reel_in()
	EventBus.farm.fish_ended.emit()
	var world := _player.world_scene()
	if world != null:
		world.pop_bgm_override()


## 钓鱼音效由鱼竿所在的玩家播放器出声。
func _play(sound_id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if _player != null and _player.sfx != null:
		_player.sfx.play(sound_id, pitch, volume_db)


func _tier() -> int:
	return _rod.tier if _rod != null else 0


## 按当前水面 / 季节 / 天气 / 时刻从数据库里抽一条鱼。
func _pick_fish() -> FishData:
	var pool: Array[FishData] = []
	for fish_id: StringName in Database.fish():
		var fish := Database.get_fish(fish_id)
		if fish != null:
			pool.append(fish)
	return FishingRules.pick(
		pool,
		rng,
		_water_kind,
		_player.current_season(),
		_player.current_weather(),
		_player.current_hour(),
		_cast_power
	)
