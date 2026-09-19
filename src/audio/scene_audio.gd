class_name SceneAudio
extends Node
## 场景音频节点：属于某个场景自己的 BGM / 音效播放器。
##
## 全局 [code]Audio[/code] Autoload 已被删除——声音由场景里的这个节点负责。
## 一个场景放一个（标题页 / [Main] / 将来任何独立场景），在 [code].tscn[/code]
## 里用导出字段声明"这个场景听起来是什么样"：
## [br]- [member bgm_track] / [member autoplay_bgm]：场景自己的曲目；
## [br]- [member follow_world_bgm]：跟随当前 [WorldScene] 声明的曲目与昼夜；
## [br]- [member listen_gameplay_sfx]：订阅玩法信号（钓鱼接管 BGM / 跨天晨鸣）。
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
# ---------------------------------------------------------------- 场景声明

## 不跟随世界时播放的曲目；空表示这个场景没有自己的 BGM。
@export var bgm_track: StringName = &""
## 进入树时立刻播放 [member bgm_track]。
@export var autoplay_bgm: bool = false
## 跟随当前世界场景声明的曲目，并在世界切换 / 小时变化时刷新。
@export var follow_world_bgm: bool = false
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
		_connect_once(EventBus.farm.fish_cast, _on_fish_cast)
		_connect_once(EventBus.farm.fish_ended, _on_fish_ended)
		_connect_once(EventBus.day_changed, _on_day_changed)


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


func _on_fish_cast(_power: float, _distance: float) -> void:
	# 钓鱼用专属曲目接管世界 BGM（音效已由鱼竿所在的玩家播放）。
	push_bgm_override(Catalog.BGM_FISHING)


func _on_fish_ended() -> void:
	pop_bgm_override()



