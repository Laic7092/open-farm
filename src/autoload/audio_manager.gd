extends Node
## 音频总管（Autoload：[code]Audio[/code]）。
##
## 它只做三件事：把 BGM / 音效播出去、按场景与时间切换曲目、响应全局事件。
## 所有声音都通过 [EventBus] 的既有信号触发，游戏逻辑里不出现任何播放调用，
## 于是"加一个音效"不需要改玩法代码，删掉整个音频系统游戏逻辑也照常跑。
## 世界 id 来自 [signal EventBus.world_entered]，时钟状态由组合根注入，
## 因此不反向依赖 [SceneRouter] / [GameClock] 这类全局单例。
##
## 音频资源同样由脚本生成（见 [code]docs/audio_pipeline.md[/code]），
## 目录在 [AudioCatalog] 里，运行时按 id 取路径。
##
## [b]总线[/b]：启动时确保 [code]Master → BGM / SFX[/code] 两条总线存在，
## 音量控制面板只改总线音量，不碰 [member AudioStreamPlayer.volume_db]。

const Catalog := preload("res://src/audio/audio_catalog.gd")
const PlayerGroup: StringName = &"player"

## BGM / SFX 两条总线的名字。
const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"

## 同时能叠加播放的音效数量（脚步声 + 交互 + UI 足够用了）。
const SFX_VOICES: int = 12
## BGM 默认交叉淡入淡出时长（秒）。
const BGM_FADE: float = 0.7
## 脚步：每走这么多像素响一声。
const STEP_DISTANCE: float = 34.0
## 同一音效在这个间隔内重复触发会被忽略（毫秒）。
const SFX_COOLDOWN_MS: int = 22
## 专属音效之后的这段时间内，通用通知音会被抑制，避免"一个动作两声"（毫秒）。
const NOTIFY_SUPPRESS_MS: int = 140
## 这些通知意味着"没做成"，用低沉的失败音。
const NEGATIVE_NOTIFICATIONS: Array[StringName] = [
	&"NOTIFY_NOTHING_HAPPENED",
	&"NOTIFY_NOTHING_TO_SHIP",
	&"NOTIFY_NO_FEED",
	&"NOTIFY_LOAD_FAILED",
]

## 音量设置保存在用户目录；读不到或写不进都按默认值继续跑。
const SETTINGS_PATH: String = "user://audio_settings.cfg"

## BGM 音量（0 ~ 1）。
var bgm_volume: float = 0.7
## 音效音量（0 ~ 1）。
var sfx_volume: float = 0.85

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _bgm_bus: int = 0
var _sfx_bus: int = 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
## 当前 BGM 曲目 id；空表示没在放。
var _current_bgm: StringName = &""
## 标题页等"不属于任何世界"的场景，用它压过按世界自动选曲。
var _bgm_context: StringName = &""
## 组合根注入的时钟状态；Audio 只读，不推进时间。
var _clock: GameDateClock
## 最近一次 EventBus.world_entered 的世界 id，避免反向查询 SceneRouter。
var _current_world_id: StringName = &""
var _bgm_tween: Tween
var _step_accum: float = 0.0
var _step_index: int = 0
## 最近一次"专属音效"的时刻（毫秒），用于抑制随后紧跟的通用通知音。
var _last_effect_ms: int = 0


func _ready() -> void:
	# 菜单 / 对话会把整棵树暂停，音频必须继续走（否则暂停后 BGM 也停了）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_build_players()
	_load_settings()
	_connect_events()


func _process(delta: float) -> void:
	_update_footsteps(delta)


# ---------------------------------------------------------------- 对外接口

## 播放一首 BGM。[param fade] 为 0 时立即切换。
func play_bgm(track_id: StringName, fade: float = BGM_FADE) -> void:
	if track_id == _current_bgm and _bgm_player.playing:
		return
	var stream := _stream(&"bgm", track_id)
	if stream == null:
		return
	_current_bgm = track_id
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if _bgm_player.playing and fade > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", -34.0, fade * 0.5)
		_bgm_tween.tween_callback(_start_current_bgm)
		_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, fade * 0.5)
	else:
		_start_current_bgm()


## 停止 BGM。
func stop_bgm(fade: float = BGM_FADE) -> void:
	_current_bgm = &""
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if not _bgm_player.playing:
		return
	if fade <= 0.0:
		_bgm_player.stop()
		return
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -34.0, fade)
	_bgm_tween.tween_callback(_bgm_player.stop)


## 播放一次音效。
func play_sfx(sound_id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(&"sfx", sound_id)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var last := int(_last_played.get(sound_id, -100000))
	if now - last < SFX_COOLDOWN_MS:
		return
	_last_played[sound_id] = now
	_last_effect_ms = now
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.volume_db = volume_db
	player.play()


## 进入标题页：固定播放标题曲，时钟 / 世界事件不再改它。
func enter_title() -> void:
	_current_world_id = &""
	_bgm_context = Catalog.BGM_TITLE
	play_bgm(Catalog.BGM_TITLE)


## 进入某个世界：交回"按世界 + 时间选曲"。
func enter_world(world_id: StringName) -> void:
	_current_world_id = world_id
	_bgm_context = &""
	_refresh_bgm(world_id)


## 组合根注入本局时钟状态。Audio 只读取其中的时间，不持有 / 不推进时间。
func bind_clock(clock: GameDateClock) -> void:
	_clock = clock
	if _bgm_context == &"" and _current_world_id != &"":
		_refresh_bgm()


## 设置 BGM 音量（0 ~ 1）。
func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


## 设置音效音量（0 ~ 1）。
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


## 当前 BGM 曲目 id（可能在淡出中）。
func current_bgm() -> StringName:
	return _current_bgm


# ---------------------------------------------------------------- 内部：播放

func _start_current_bgm() -> void:
	var stream := _stream(&"bgm", _current_bgm)
	if stream == null:
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	_bgm_player.play()


func _refresh_bgm(world_id: StringName = &"") -> void:
	if _bgm_context != &"":
		return
	if world_id == &"":
		world_id = _current_world_id
	play_bgm(_track_for(world_id))


## 世界 → 白天曲目；夜里换成夜曲。
func _track_for(world_id: StringName) -> StringName:
	if _is_night():
		return Catalog.BGM_NIGHT
	if world_id in [&"town", &"twon", &"beach", &"library"]:
		return Catalog.BGM_TOWN
	return Catalog.BGM_FARM


## 夜晚：18:00 ~ 次日 06:00（与 [DayNight] 共用同一份定义）。时钟还没注入时按白天算。
func _is_night() -> bool:
	if _clock == null:
		return false
	return DayNight.is_night(_clock.minute_of_day)


func _stream(kind: StringName, id: StringName) -> AudioStream:
	var path := Catalog.bgm_path(id) if kind == &"bgm" else Catalog.sfx_path(id)
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("Audio: 缺少音频 %s（跑一次 ./tools/build_assets.sh）" % path)
		return null
	var stream := load(path) as AudioStream
	_streams[path] = stream
	return stream


# ---------------------------------------------------------------- 内部：基础设施

func _ensure_buses() -> void:
	_bgm_bus = _ensure_bus(BGM_BUS)
	_sfx_bus = _ensure_bus(SFX_BUS)
	_apply_volumes()


func _ensure_bus(name: StringName) -> int:
	var index := AudioServer.get_bus_index(name)
	if index != -1:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, &"Master")
	return index


func _build_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = BGM_BUS
	add_child(_bgm_player)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(_bgm_bus, _volume_db(bgm_volume))
	AudioServer.set_bus_volume_db(_sfx_bus, _volume_db(sfx_volume))


static func _volume_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


# ---------------------------------------------------------------- 内部：事件

func _connect_once(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


func _connect_events() -> void:
	_connect_once(EventBus.world_entered, _on_world_entered)
	_connect_once(EventBus.hour_changed, _on_hour_changed)
	_connect_once(EventBus.day_changed, _on_day_changed)

	_connect_once(EventBus.tool_used, _on_tool_used)
	_connect_once(EventBus.tile_tilled, _on_tile_tilled)
	_connect_once(EventBus.tile_watered, _on_tile_watered)
	_connect_once(EventBus.crop_planted, _on_crop_planted)
	_connect_once(EventBus.crop_harvested, _on_crop_harvested)
	_connect_once(EventBus.crop_died, _on_crop_died)
	_connect_once(EventBus.flora_cleared, _on_flora_cleared)

	_connect_once(EventBus.animal_placed, _on_animal_placed)
	_connect_once(EventBus.animal_fed, _on_animal_fed)
	_connect_once(EventBus.animal_petted, _on_animal_petted)
	_connect_once(EventBus.animal_product_collected, _on_animal_product_collected)
	_connect_once(EventBus.animal_matured, _on_animal_matured)

	_connect_once(EventBus.transaction_completed, _on_transaction)
	_connect_once(EventBus.dialogue_line_shown, _on_dialogue_line_shown)
	_connect_once(EventBus.game_paused_changed, _on_game_paused_changed)
	_connect_once(EventBus.notification_requested, _on_notification)
	_connect_once(EventBus.inventory_full, _on_inventory_full)
	_connect_once(EventBus.ui_sound_requested, _on_ui_sound_requested)

	_connect_once(EventBus.save_completed, _on_save_completed)
	_connect_once(EventBus.load_completed, _on_load_completed)
	_connect_once(EventBus.stamina_depleted, _on_stamina_depleted)
	_connect_once(EventBus.scene_transition_started, _on_scene_transition_started)


func _on_world_entered(world_id: StringName) -> void:
	enter_world(world_id)


func _on_hour_changed(_hour: int) -> void:
	_refresh_bgm()


func _on_day_changed(_date: GameDate) -> void:
	# 凌晨 02:00 的自然跨天不放鸡叫，只有睡到早上的那一天才放。
	if _hour() >= 5:
		play_sfx(Catalog.SFX_MORNING, 1.0, -6.0)


func _hour() -> int:
	if _clock == null:
		return 0
	return int(_clock.minute_of_day / GameDateClock.MINUTES_PER_HOUR)


func _on_tool_used(_tool_id: StringName, _cell: Vector2i, success: bool) -> void:
	# 失败的尝试由 NOTIFY_* 统一发失败音，这里避免重复。
	if success:
		play_sfx(Catalog.SFX_TOOL_SWING, 1.0, -3.0)


func _on_tile_tilled(_cell: Vector2i) -> void:
	play_sfx(Catalog.SFX_TILL)


func _on_tile_watered(_cell: Vector2i) -> void:
	play_sfx(Catalog.SFX_WATER)


func _on_crop_died(_cell: Vector2i) -> void:
	play_sfx(Catalog.SFX_ERROR, 0.7)


func _on_animal_placed(_building_id: StringName, _animal_id: StringName) -> void:
	play_sfx(Catalog.SFX_ANIMAL_HAPPY)


func _on_animal_fed(_building_id: StringName, _count: int) -> void:
	play_sfx(Catalog.SFX_ANIMAL_EAT)


func _on_animal_product_collected(
	_building_id: StringName, _animal_id: StringName, _item_id: StringName, _amount: int
) -> void:
	play_sfx(Catalog.SFX_HARVEST, 1.1)


func _on_animal_matured(_building_id: StringName, _animal_id: StringName) -> void:
	play_sfx(Catalog.SFX_MATURE)


func _on_crop_planted(_cell: Vector2i, _crop_id: StringName) -> void:
	play_sfx(Catalog.SFX_PLANT)


func _on_crop_harvested(_cell: Vector2i, _item_id: StringName, _amount: int) -> void:
	play_sfx(Catalog.SFX_HARVEST)


func _on_flora_cleared(_cell: Vector2i, _flora_id: StringName, _item_id: StringName, _amount: int) -> void:
	play_sfx(Catalog.SFX_CHOP)


func _on_dialogue_line_shown() -> void:
	play_sfx(Catalog.SFX_DIALOGUE, 1.0, -3.0)


func _on_inventory_full(_item_id: StringName) -> void:
	play_sfx(Catalog.SFX_ERROR)


func _on_ui_sound_requested(sound_id: StringName, pitch: float, volume_db: float) -> void:
	play_sfx(sound_id, pitch, volume_db)


func _on_animal_petted(_building: StringName, _animal: StringName, _affection: int) -> void:
	play_sfx(Catalog.SFX_ANIMAL_HAPPY, 1.08)


func _on_transaction(_item: StringName, _count: int, _total: int, is_purchase: bool) -> void:
	play_sfx(Catalog.SFX_COIN, 1.0 if is_purchase else 0.92)


func _on_game_paused_changed(paused: bool) -> void:
	# 打开模态（暂停）= 向上滑音；关闭 = 向下滑音。
	play_sfx(Catalog.SFX_UI_OPEN if paused else Catalog.SFX_UI_CLOSE, 1.0, -2.0)


func _on_notification(text_key: StringName, _args: Dictionary) -> void:
	# 专属音效刚响过就不再叠一层通用提示音。
	if Time.get_ticks_msec() - _last_effect_ms < NOTIFY_SUPPRESS_MS:
		return
	if NEGATIVE_NOTIFICATIONS.has(text_key):
		play_sfx(Catalog.SFX_ERROR, 1.0, -2.0)
	else:
		play_sfx(Catalog.SFX_NOTIFY, 1.0, -3.0)


func _on_save_completed(_slot: int, success: bool) -> void:
	play_sfx(Catalog.SFX_SAVE if success else Catalog.SFX_ERROR)


func _on_load_completed(_slot: int, success: bool) -> void:
	play_sfx(Catalog.SFX_LOAD if success else Catalog.SFX_ERROR)


func _on_stamina_depleted() -> void:
	play_sfx(Catalog.SFX_STAMINA_DEPLETED)


func _on_scene_transition_started(_target: StringName) -> void:
	play_sfx(Catalog.SFX_TRANSITION, 1.0, -4.0)


# ---------------------------------------------------------------- 内部：脚步

## 玩家移动时按走过的距离触发脚步，不侵入移动状态机。
func _update_footsteps(delta: float) -> void:
	if get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group(PlayerGroup) as CharacterBody2D
	if player == null or player.velocity.length() < 8.0:
		# 停下时把累积量留在"差一步"的位置，起步立刻有声音。
		_step_accum = STEP_DISTANCE * 0.75
		return
	_step_accum += player.velocity.length() * delta
	if _step_accum < STEP_DISTANCE:
		return
	_step_accum = 0.0
	_step_index += 1
	var on_path := _footstep_on_path()
	var id := Catalog.SFX_FOOTSTEP_PATH if on_path else Catalog.SFX_FOOTSTEP_GRASS
	play_sfx(id, 1.04 if (_step_index % 2) == 0 else 0.96, -6.0)


func _footstep_on_path() -> bool:
	return _current_world_id in [&"town", &"twon", &"beach", &"mine", &"library"]


# ---------------------------------------------------------------- 内部：设置

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		bgm_volume = clampf(float(config.get_value("audio", "bgm", bgm_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	_apply_volumes()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", bgm_volume)
	config.set_value("audio", "sfx", sfx_volume)
	# 写不进去（只读用户目录 / 沙箱）不应该打断游戏，静默忽略即可。
	config.save(SETTINGS_PATH)
