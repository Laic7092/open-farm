class_name SceneAudio
extends Node
## 场景音频节点：属于某个场景自己的 BGM / 音效播放器。
##
## 全局 [code]Audio[/code] Autoload 已被删除——声音由场景里的这个节点负责。
## 一个场景放一个（标题页 / [Main] / 将来任何独立场景），在 [code].tscn[/code]
## 里用导出字段声明"这个场景听起来是什么样"：
## [br]- [member bgm_track] / [member autoplay_bgm]：场景自己的曲目；
## [br]- [member follow_world_bgm]：跟随当前 [WorldScene] 声明的曲目与昼夜；
## [br]- [member listen_ui_sfx] / [member listen_gameplay_sfx]：订阅哪几类既有事件。
##
## [b]总线与音量[/b]：总线创建、音量与设置文件都收在 [AudioBus] 这个极小共享点里；
## 玩家 / 工具 / 界面等发声者各自持有 [SfxPlayer] 直接播放，本节点只留场景自己的 BGM
## 与尚未归位的跨场景音效。
##
## [b]为什么不写死世界 → 曲目[/b]：农场 / 小镇 / 夜晚的对应关系属于地图自己，
## 因此这里只读 [member WorldScene.bgm_track] / [member WorldScene.bgm_night_track] /
## [member WorldScene.footstep_sfx]，新增地图不需要改音频代码。

const Catalog := preload("res://src/audio/audio_catalog.gd")

## 场景音频节点所在分组；界面找不到注入引用时按它兜底。
const GROUP: StringName = &"scene_audio"
## BGM / SFX 两条总线的名字（与 [AudioBus] 一致）。
const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"

## 同时能叠加播放的音效数量。
const SFX_VOICES: int = 12
## BGM 默认交叉淡入淡出时长（秒）。
const BGM_FADE: float = 0.7
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

# ---------------------------------------------------------------- 场景声明

## 不跟随世界时播放的曲目；空表示这个场景没有自己的 BGM。
@export var bgm_track: StringName = &""
## 进入树时立刻播放 [member bgm_track]。
@export var autoplay_bgm: bool = false
## 跟随当前世界场景声明的曲目，并在世界切换 / 小时变化时刷新。
@export var follow_world_bgm: bool = false
## 订阅 [signal EventBus.ui.ui_sound_requested] 及 UI / 存读档类音效。
@export var listen_ui_sfx: bool = false
## 订阅农场 / 世界 / 玩家玩法信号。
@export var listen_gameplay_sfx: bool = false

## BGM 音量（0 ~ 1）；实际存储在 [AudioBus] 共享点里。
var bgm_volume: float:
	get:
		return AudioBus.bgm_volume
	set(value):
		AudioBus.set_bgm_volume(value)
## 音效音量（0 ~ 1）；实际存储在 [AudioBus] 共享点里。
var sfx_volume: float:
	get:
		return AudioBus.sfx_volume
	set(value):
		AudioBus.set_sfx_volume(value)

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
## 当前 BGM 曲目 id；空表示没在放。
var _current_bgm: StringName = &""
## 临时接管的 BGM（如钓鱼）；非空时 [method _refresh_world_bgm] 不会抢回去。
var _bgm_override: StringName = &""
## 组合根注入的时钟状态；本节点只读，不推进时间。
var _clock: GameDateClock
var _bgm_tween: Tween


func _ready() -> void:
	# 菜单 / 对话会把整棵树暂停，音频必须继续走（否则暂停后 BGM 也停了）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	AudioBus.ensure_buses()
	_build_players()
	AudioBus.load_settings()
	_hook_events()
	if autoplay_bgm and bgm_track != &"":
		play_bgm(bgm_track)
	elif follow_world_bgm:
		_refresh_world_bgm()


# ---------------------------------------------------------------- 对外接口

## 组合根注入本局时钟状态；只用于判断昼夜与世界曲目。
func bind_clock(clock: GameDateClock) -> void:
	_clock = clock
	# 组合根注入时本节点可能还没进树（Main 的 _enter_tree 早于子节点），
	# 此时没有世界可读，等 _ready() / world_entered 再刷新。
	if follow_world_bgm and is_inside_tree():
		_refresh_world_bgm()


## 播放一首 BGM。[param fade] 为 0 时立即切换。
func play_bgm(track_id: StringName, fade: float = BGM_FADE) -> void:
	if track_id == &"":
		stop_bgm(fade)
		return
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
	AudioBus.note_sfx()
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.volume_db = volume_db
	player.play()


## 设置 BGM 音量（0 ~ 1）；落在 [AudioBus] 共享点上。
func set_bgm_volume(value: float) -> void:
	AudioBus.set_bgm_volume(value)


## 设置音效音量（0 ~ 1）；落在 [AudioBus] 共享点上。
func set_sfx_volume(value: float) -> void:
	AudioBus.set_sfx_volume(value)


## 当前 BGM 曲目 id（可能在淡出中）。
func current_bgm() -> StringName:
	return _current_bgm


## 临时接管 BGM（例：抛竿后切钓鱼曲）；同一次接管只记一次，重复调用不重放。
func push_bgm_override(track_id: StringName) -> void:
	if track_id == &"" or track_id == _bgm_override:
		return
	_bgm_override = track_id
	play_bgm(track_id)


## 结束临时接管，还原世界声明的曲目。
func pop_bgm_override() -> void:
	if _bgm_override == &"":
		return
	_bgm_override = &""
	if follow_world_bgm:
		_refresh_world_bgm()
	else:
		play_bgm(bgm_track)


# ---------------------------------------------------------------- 内部：播放

func _start_current_bgm() -> void:
	var stream := _stream(&"bgm", _current_bgm)
	if stream == null:
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	_bgm_player.play()


## 读当前世界场景声明的曲目；没有世界时什么都不做。
func _refresh_world_bgm() -> void:
	# 钓鱼等临时接管期间不要用世界曲目抢回 BGM。
	if _bgm_override != &"":
		return
	var world := _current_world()
	if world == null:
		return
	play_bgm(_resolve_track(world.bgm_track, world.bgm_night_track))


## 昼夜决定用白天曲还是夜晚曲；夜晚曲为空时退回白天曲。
func _resolve_track(day_track: StringName, night_track: StringName) -> StringName:
	if _is_night() and night_track != &"":
		return night_track
	return day_track


## 夜晚：18:00 ~ 次日 06:00（与 [DayNight] 共用同一份定义）。时钟还没注入时按白天算。
func _is_night() -> bool:
	if _clock == null:
		return false
	return DayNight.is_night(_clock.minute_of_day)


## 当前挂载的世界场景；没有则返回 null。
func _current_world() -> WorldScene:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var host := tree.get_first_node_in_group(WorldHost.GROUP) as WorldHost
	if host == null:
		return null
	return host.current_world() as WorldScene


func _stream(kind: StringName, id: StringName) -> AudioStream:
	var path := Catalog.bgm_path(id) if kind == &"bgm" else Catalog.sfx_path(id)
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("SceneAudio: 缺少音频 %s（跑一次 ./tools/build_assets.sh）" % path)
		return null
	var stream := load(path) as AudioStream
	_streams[path] = stream
	return stream


# ---------------------------------------------------------------- 内部：基础设施

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


# ---------------------------------------------------------------- 内部：事件

func _connect_once(sig: Signal, callback: Callable) -> void:
	if not sig.is_connected(callback):
		sig.connect(callback)


func _hook_events() -> void:
	if follow_world_bgm:
		_connect_once(EventBus.world_entered, _on_world_entered)
		_connect_once(EventBus.hour_changed, _on_hour_changed)

	if listen_gameplay_sfx:
		_connect_once(EventBus.farm.crop_planted, _on_crop_planted)
		_connect_once(EventBus.farm.crop_harvested, _on_crop_harvested)
		_connect_once(EventBus.farm.crop_died, _on_crop_died)
		_connect_once(EventBus.farm.animal_placed, _on_animal_placed)
		_connect_once(EventBus.farm.animal_fed, _on_animal_fed)
		_connect_once(EventBus.farm.animal_petted, _on_animal_petted)
		_connect_once(EventBus.farm.animal_product_collected, _on_animal_product_collected)
		_connect_once(EventBus.farm.animal_matured, _on_animal_matured)
		_connect_once(EventBus.farm.fish_cast, _on_fish_cast)
		_connect_once(EventBus.farm.fish_bite, _on_fish_bite)
		_connect_once(EventBus.farm.fish_reel_tick, _on_fish_reel_tick)
		_connect_once(EventBus.farm.fish_ended, _on_fish_ended)
		_connect_once(EventBus.farm.fish_caught, _on_fish_caught)
		_connect_once(EventBus.world.flora_cleared, _on_flora_cleared)
		_connect_once(EventBus.day_changed, _on_day_changed)

	if listen_ui_sfx:
		_connect_once(EventBus.ui.ui_sound_requested, _on_ui_sound_requested)
		_connect_once(EventBus.ui.transaction_completed, _on_transaction)
		_connect_once(EventBus.ui.dialogue_line_shown, _on_dialogue_line_shown)
		_connect_once(EventBus.ui.game_paused_changed, _on_game_paused_changed)
		_connect_once(EventBus.ui.notification_requested, _on_notification)
		_connect_once(EventBus.save_completed, _on_save_completed)
		_connect_once(EventBus.load_completed, _on_load_completed)
		_connect_once(EventBus.scene_transition_started, _on_scene_transition_started)


func _on_world_entered(_world_id: StringName) -> void:
	_refresh_world_bgm()


func _on_hour_changed(_hour: int) -> void:
	_refresh_world_bgm()


func _on_day_changed(_date: GameDate) -> void:
	# 凌晨 02:00 的自然跨天不放鸡叫，只有睡到早上的那一天才放。
	if _hour() >= 5:
		play_sfx(Catalog.SFX_MORNING, 1.0, -6.0)


func _hour() -> int:
	if _clock == null:
		return 0
	return int(_clock.minute_of_day / GameDateClock.MINUTES_PER_HOUR)


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


func _on_fish_cast(power: float, _distance: float) -> void:
	# 蓄力越满，出力声越尖；同时用钓鱼曲接管世界 BGM。
	play_sfx(Catalog.SFX_FISH_CHARGE, 0.88 + 0.35 * clampf(power, 0.0, 1.0), -5.0)
	play_sfx(Catalog.SFX_FISH_CAST, 1.0, -4.0)
	push_bgm_override(Catalog.BGM_FISHING)


func _on_fish_bite(_fish_id: StringName) -> void:
	play_sfx(Catalog.SFX_FISH_BITE)
	play_sfx(Catalog.SFX_FISH_FIGHT, 1.0, -7.0)


func _on_fish_reel_tick() -> void:
	play_sfx(Catalog.SFX_FISH_REEL, 1.0, -10.0)


func _on_fish_ended() -> void:
	pop_bgm_override()


func _on_fish_caught(_fish_id: StringName, _item_id: StringName, _size_cm: int) -> void:
	play_sfx(Catalog.SFX_FISH_CATCH)


func _on_dialogue_line_shown() -> void:
	play_sfx(Catalog.SFX_DIALOGUE, 1.0, -3.0)


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
	# 断线有专属音效，不再叠通用失败音。
	if text_key == &"NOTIFY_FISH_ESCAPED":
		play_sfx(Catalog.SFX_FISH_LINE_BREAK)
		return
	# 专属音效刚响过就不再叠一层通用提示音（时间戳是 [AudioBus] 共享点）。
	if AudioBus.since_last_sfx_ms() < NOTIFY_SUPPRESS_MS:
		return
	if NEGATIVE_NOTIFICATIONS.has(text_key):
		play_sfx(Catalog.SFX_ERROR, 1.0, -2.0)
	else:
		play_sfx(Catalog.SFX_NOTIFY, 1.0, -3.0)


func _on_save_completed(_slot: int, success: bool) -> void:
	play_sfx(Catalog.SFX_SAVE if success else Catalog.SFX_ERROR)


func _on_load_completed(_slot: int, success: bool) -> void:
	play_sfx(Catalog.SFX_LOAD if success else Catalog.SFX_ERROR)


func _on_scene_transition_started(_target: StringName) -> void:
	play_sfx(Catalog.SFX_TRANSITION, 1.0, -4.0)



