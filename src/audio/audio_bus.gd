class_name AudioBus
extends RefCounted
## 音频的"极小共享点"。
##
## 只承载真正跨归属的东西：BGM / SFX 两条总线、音量设置，以及"刚响过一声"的时间戳
## （通知音据此抑制"一个动作两声"）。不持有播放器、不认识任何域、不订阅任何事件。
## 发声者各自持有 [SfxPlayer] 直接播放，音量则统一走这里的两条总线。

## BGM / SFX 两条总线的名字。
const BGM_BUS: StringName = &"BGM"
const SFX_BUS: StringName = &"SFX"

## 音量设置保存在用户目录；读不到或写不进都按默认值继续跑。
const SETTINGS_PATH: String = "user://audio_settings.cfg"

## BGM 音量（0 ~ 1）。
static var bgm_volume: float = 0.7
## 音效音量（0 ~ 1）。
static var sfx_volume: float = 0.85

## 最近一次音效的时刻（毫秒）。
static var _last_effect_ms: int = 0


## 确保两条总线存在并应用当前音量；可重复调用。
static func ensure_buses() -> void:
	_ensure_bus(BGM_BUS)
	_ensure_bus(SFX_BUS)
	apply_volumes()


## 设置 BGM 音量（0 ~ 1）。
static func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()


## 设置音效音量（0 ~ 1）。
static func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()


## 把当前音量写进总线（不落盘）。
static func apply_volumes() -> void:
	var bgm := AudioServer.get_bus_index(BGM_BUS)
	if bgm != -1:
		AudioServer.set_bus_volume_db(bgm, volume_db(bgm_volume))
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx != -1:
		AudioServer.set_bus_volume_db(sfx, volume_db(sfx_volume))


## 记录"刚响过一声"；任何发声者播放后都应调用。
static func note_sfx() -> void:
	_last_effect_ms = Time.get_ticks_msec()


## 距最近一次音效过了多少毫秒。
static func since_last_sfx_ms() -> int:
	return Time.get_ticks_msec() - _last_effect_ms


## 从用户目录读取音量设置；读不到就用默认值。
static func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		bgm_volume = clampf(float(config.get_value("audio", "bgm", bgm_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	apply_volumes()


## 把音量写回用户目录；写不进（只读用户目录 / 沙箱）静默忽略。
static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", bgm_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)


## 线性音量（0 ~ 1）转分贝。
static func volume_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


static func _ensure_bus(bus_name: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	return index
