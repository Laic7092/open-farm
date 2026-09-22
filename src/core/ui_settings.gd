class_name UiSettings
extends RefCounted
## 显示设置：常驻 UI（HUD / 触控控件）的缩放。
##
## 与 [ViewSettings] / [TouchSettings] 同构、共用 [code]user://display_settings.cfg[/code]，
## 各写各的 section，读不到 / 写不进都静默降级（[code]user://[/code] 不可写时游戏照常能玩）。
##
## 只放纯状态 + 文件 IO，不碰场景树、不发信号——“改了设置要通知谁”由调用方
## （系统菜单）决定；应用由各界面主人自己完成：所有响应式界面（[Hud] /
## [TouchControls] / [ModalShell] / [DialogueBox]）都订阅 [signal UiEvents.ui_scale_changed]，
## 于是 HUD、触控、模态与对话统一缩放。
## 世界相机不在这里，不会被这个缩放带着一起变。

## 默认设置文件；与 [ViewSettings] / [TouchSettings] 共用，保存前先 load，避免互相覆盖。
const DEFAULT_SETTINGS_PATH: String = "user://display_settings.cfg"
const SECTION: String = "ui"
const KEY_SCALE: String = "ui_scale"

## UI 缩放挡位：1.00 ~ 3.00，每 0.25 一挡。
const SCALE_MIN: float = 1.0
const SCALE_MAX: float = 3.0
const SCALE_STEP: float = 0.25
## 触屏设备的出厂默认：手机屏幕小，常驻 HUD 与虚拟键开箱先给 1.5 挡。
const DEFAULT_SCALE_TOUCH: float = 1.5

## 设置文件路径；测试 / 冒烟可以指到别处，避免污染真实设置。
static var settings_path: String = DEFAULT_SETTINGS_PATH

static var _loaded: bool = false
static var _scale: float = SCALE_MIN


## 没有设置文件时的默认值：触屏用 [constant DEFAULT_SCALE_TOUCH]，桌面保持 1.0。
static func default_scale() -> float:
	return default_scale_for(DisplayServer.is_touchscreen_available())


## [method default_scale] 的纯函数版：把“是不是触屏”当参数，便于脱离设备跑规范。
static func default_scale_for(is_touch: bool) -> float:
	return DEFAULT_SCALE_TOUCH if is_touch else SCALE_MIN


## 当前 UI 缩放；启动时未读过盘会先读一次。
static func scale() -> float:
	if not _loaded:
		_load()
	return _scale


## 写入缩放；[param persist] 为 false 时只改内存（测试 / 冒烟用）。
##
## 吸附到 [constant SCALE_STEP] 的整数倍并夹到 [constant SCALE_MIN] ~ [constant SCALE_MAX]，
## 于是无论滑杆、配置文件还是调用方传什么都不可能越界。
static func set_scale(value: float, persist: bool = true) -> void:
	_loaded = true
	var stepped: float = clampf(snappedf(value, SCALE_STEP), SCALE_MIN, SCALE_MAX)
	if is_equal_approx(_scale, stepped):
		return
	_scale = stepped
	if persist:
		_save()


## 丢掉内存缓存，下次访问重新读盘（测试用）。
static func reload_from_disk() -> void:
	_loaded = false


## 恢复出厂值并清掉缓存（测试用）。
static func reset() -> void:
	_loaded = true
	_scale = default_scale()


static func _load() -> void:
	_loaded = true
	_scale = default_scale()
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_scale = clampf(float(config.get_value(SECTION, KEY_SCALE, _scale)), SCALE_MIN, SCALE_MAX)


static func _save() -> void:
	var config := ConfigFile.new()
	# 先读一遍，保住同一文件里 [ViewSettings] / [TouchSettings] 写的其它设置。
	config.load(settings_path)
	config.set_value(SECTION, KEY_SCALE, _scale)
	config.save(settings_path)
