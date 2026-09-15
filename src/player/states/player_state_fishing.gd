extends State
## 钓鱼状态：抛竿 → 等鱼 → 咬钩窗口 → 收竿结算。
##
## 目标水面在 [method enter] 时锁定（"下竿那一刻"决定在哪片水钓），
## 之后转身 / 换工具都不会改变这次垂钓；整条时间轴由 [FishingRules] 的
## 纯函数算出来，本状态只负责计时与响应输入。
##
## 按键（与普通工具一致）：空格 = 收竿。等鱼时按一次 = 提前收竿，
## 咬钩窗口内按 = 上鱼，窗口过去 = 跑鱼。

enum Phase {
	CAST,      ## 抛竿动作
	WAIT,      ## 浮标入水，等鱼咬钩
	BITE,      ## 咬钩了，窗口内必须收竿
	RESOLVED,  ## 已出结果，等待切回待机
}

## 抛竿动作的时长（秒）。
const CAST_DURATION: float = 0.45

var player: Player

var _phase: Phase = Phase.CAST
var _timer: float = 0.0
var _rod: ToolData
var _fish: FishData
var _water_kind: int = -1
var _bite_at: float = 0.0
var _bite_window: float = 0.0


func enter(_previous: State) -> void:
	player = actor as Player
	player.velocity = Vector2.ZERO
	_rod = player.item_bar.selected_tool()
	_water_kind = player.fishing_water_kind()
	_fish = null
	_phase = Phase.CAST
	_timer = 0.0
	player.play_animation(&"use")
	Audio.play_sfx(AudioCatalog.SFX_FISH_CAST, 1.0, -4.0)
	# 体力在抛竿时结算：不管最后钓没钓上来，这一杆都算数。
	player.interactor.consume_stamina(_rod)


func exit() -> void:
	player.play_animation(&"idle")


func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()


func update(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.CAST:
			if _timer >= CAST_DURATION:
				_begin_wait()
		Phase.WAIT:
			if _timer >= _bite_at:
				_begin_bite()
		Phase.BITE:
			if _timer >= _bite_window:
				_escape()


func handle_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"use_tool") or event.is_action_pressed(&"interact")):
		return
	match _phase:
		Phase.WAIT:
			_cancel()
		Phase.BITE:
			_land()


## 当前阶段；供冒烟测试与调试观察。
func phase() -> Phase:
	return _phase


## 本次垂钓选中的鱼；还没选中时为 null。
func target_fish() -> FishData:
	return _fish


# ---------------------------------------------------------------- 内部

func _begin_wait() -> void:
	_phase = Phase.WAIT
	_timer = 0.0
	_fish = _pick_fish()
	_bite_at = FishingRules.bite_delay(player.fishing_rng, _tier())
	if _fish == null:
		# 这片水此刻一条鱼都没有：直接收竿，不让玩家干等。
		_cancel()


func _begin_bite() -> void:
	_phase = Phase.BITE
	_timer = 0.0
	_bite_window = FishingRules.bite_window(_fish, _tier())
	player.play_animation(&"idle")
	EventBus.farm.fish_bite.emit(_fish.id if _fish != null else &"")
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_BITE", {})


func _land() -> void:
	_phase = Phase.RESOLVED
	var size: int = FishingRules.roll_size(_fish, player.fishing_rng)
	player.land_fish(_fish, size)
	request_transition(&"idle")


func _escape() -> void:
	_phase = Phase.RESOLVED
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_ESCAPED", {})
	request_transition(&"idle")


func _cancel() -> void:
	_phase = Phase.RESOLVED
	EventBus.ui.notification_requested.emit(&"NOTIFY_FISH_CANCELLED", {})
	request_transition(&"idle")


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
		player.fishing_rng,
		_water_kind,
		player.current_season(),
		player.current_weather(),
		player.current_hour()
	)
