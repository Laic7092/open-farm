class_name SfxPlayer
extends Node
## 极小的可复用音效播放器：谁制造声音，谁挂一个、直接调用。
##
## 只做三件事：占几条 [AudioStreamPlayer] 声部、按 id 取流、对同音做去抖。
## 总线与音量走 [AudioBus]（共享点），因此本组件不持有任何全局状态、不认识任何域，
## 放到地图 / 界面 / 实体节点下都能用。

## 同时能叠加播放的声部数。
@export var voices: int = 8
## 同一音效在这个间隔内重复触发会被忽略（毫秒）。
@export var cooldown_ms: int = 22

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	AudioBus.ensure_buses()
	for i: int in maxi(voices, 1):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = AudioBus.SFX_BUS
		add_child(player)
		_players.append(player)


## 在 [param host] 下挂一个播放器节点。宿主动不动在 [method Node._ready] 里调一次即可。
static func attach(host: Node, node_name: StringName = &"Sfx") -> SfxPlayer:
	var player := SfxPlayer.new()
	player.name = node_name
	host.add_child(player)
	return player


## 播放一次音效；缺资源时静默跳过（首次会警告）。
func play(sound_id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if _players.is_empty():
		return
	var stream := _stream(sound_id)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound_id, -100000)) < cooldown_ms:
		return
	_last_played[sound_id] = now
	AudioBus.note_sfx()
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.volume_db = volume_db
	player.play()


func _stream(sound_id: StringName) -> AudioStream:
	if sound_id == &"":
		return null
	var path := AudioCatalog.sfx_path(sound_id)
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("SfxPlayer: 缺少音效 %s（跑一次 ./tools/build_assets.sh）" % path)
		return null
	var stream := load(path) as AudioStream
	_streams[path] = stream
	return stream
