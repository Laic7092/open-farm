class_name BgmPlayer
extends Node
## 极小的可复用 BGM 播放器：谁拥有这段气氛，谁挂一个。
##
## 地图挂一个放自己的地图曲（含昼夜换曲），标题页挂一个放标题曲。
## 只做四件事：按 id 播放、淡入淡出、昼夜选曲、临时接管；总线与音量走
## [AudioBus] 这个共享点。菜单 / 对话暂停整棵树时 BGM 继续播放。

const Catalog := preload("res://src/audio/audio_catalog.gd")

## 默认曲目；空表示这个宿主平时不出声。
@export var track: StringName = &""
## 夜间曲目；空表示夜里沿用白天曲，或本宿主没有昼夜之分。
@export var night_track: StringName = &""
## 进树时立刻播放（页面 / 地图被挂载时）。
@export var autoplay: bool = false
## 交叉淡入淡出时长（秒）。
@export var fade: float = 0.7

var _player: AudioStreamPlayer
var _tween: Tween
var _streams: Dictionary = {}
var _current: StringName = &""
## 临时接管的曲目（如钓鱼）；非空时 [method refresh] 不会抢回去。
var _override: StringName = &""
## 判断昼夜用的时钟；未注入时按白天算。
var _clock: GameDateClock


func _enter_tree() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)


func _exit_tree() -> void:
	if EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.disconnect(_on_hour_changed)


func _ready() -> void:
	# 菜单 / 对话会把整棵树暂停，BGM 必须继续走（否则暂停后 BGM 也停了）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBus.ensure_buses()
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = AudioBus.BGM_BUS
	add_child(_player)
	if autoplay:
		refresh()


# ---------------------------------------------------------------- 对外接口

## 注入本局时钟，用于判断昼夜选曲。
func bind_clock(clock: GameDateClock) -> void:
	_clock = clock


## 按当前昼夜重新选曲并播放；地图 / 页面每次被挂载时调用。
func refresh() -> void:
	if _override != &"":
		return
	play_bgm(_resolve(track, night_track))


## 播放一首曲目；[param fade] 为 0 时立即切换。
func play_bgm(track_id: StringName, fade_seconds: float = -1.0) -> void:
	if track_id == &"":
		stop_bgm(fade_seconds)
		return
	if track_id == _current and _player != null and _player.playing:
		return
	if _stream(track_id) == null:
		return
	var use_fade: float = fade if fade_seconds < 0.0 else fade_seconds
	_current = track_id
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _player.playing and use_fade > 0.0:
		_tween = create_tween()
		_tween.tween_property(_player, "volume_db", -34.0, use_fade * 0.5)
		_tween.tween_callback(_apply_current)
		_tween.tween_property(_player, "volume_db", 0.0, use_fade * 0.5)
	else:
		_apply_current()


## 停止播放。
func stop_bgm(fade_seconds: float = -1.0) -> void:
	_current = &""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _player == null or not _player.playing:
		return
	var use_fade: float = fade if fade_seconds < 0.0 else fade_seconds
	if use_fade <= 0.0:
		_player.stop()
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -34.0, use_fade)
	_tween.tween_callback(_player.stop)


## 当前曲目 id（可能在淡出中）。
func current() -> StringName:
	return _current


## 临时接管曲目；同一次接管只记一次，重复调用不重放。
func push_override(track_id: StringName) -> void:
	if track_id == &"" or track_id == _override:
		return
	_override = track_id
	play_bgm(track_id)


## 结束临时接管，还原宿主声明的曲目。
func pop_override() -> void:
	if _override == &"":
		return
	_override = &""
	refresh()


# ---------------------------------------------------------------- 内部

func _on_hour_changed(_hour: int) -> void:
	refresh()


func _apply_current() -> void:
	var stream := _stream(_current)
	if stream == null:
		return
	_player.stream = stream
	_player.volume_db = 0.0
	_player.play()


## 昼夜决定用白天曲还是夜晚曲；夜晚曲为空时退回白天曲。
func _resolve(day_track: StringName, night_track_id: StringName) -> StringName:
	if _is_night() and night_track_id != &"":
		return night_track_id
	return day_track


## 夜晚：18:00 ~ 次日 06:00（与 [DayNight] 共用同一份定义）。时钟还没注入时按白天算。
func _is_night() -> bool:
	if _clock == null:
		return false
	return DayNight.is_night(_clock.minute_of_day)


func _stream(track_id: StringName) -> AudioStream:
	var path := Catalog.bgm_path(track_id)
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("BgmPlayer: 缺少 BGM %s（跑一次 ./tools/build_assets.sh）" % path)
		return null
	var stream := load(path) as AudioStream
	_streams[path] = stream
	return stream
