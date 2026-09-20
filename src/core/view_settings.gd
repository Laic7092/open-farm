class_name ViewSettings
extends RefCounted
## 显示设置：相机缩放（画面大小）。
##
## 与 [TouchSettings] 同构、共用 [code]user://display_settings.cfg[/code]，各写各的
## section，读不到 / 写不进都静默降级（[code]user://[/code] 不可写时游戏照常能玩）。
##
## 只放纯状态 + 文件 IO，不碰场景树、不发信号——“改了设置要通知谁”由调用方
## （系统菜单）决定；相机归玩家，应用也在玩家（见 [method Player.apply_view_zoom]）。
## 注意：这里保存的是用户请求的 zoom；若地图边界比当前视口小，[method Player.apply_camera_limits]
## 会把实际相机 zoom 抬高到不露出地图外空白，避免预览时出现左右黑边。

## 默认设置文件；与 [TouchSettings] 共用，保存前先 load，避免互相覆盖。
const DEFAULT_SETTINGS_PATH: String = "user://display_settings.cfg"
const SECTION: String = "display"
const KEY_ZOOM: String = "camera_zoom"

## 画面大小的挡位：1.00 ~ 5.00，每 0.25 一挡。
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 5.0
const ZOOM_STEP: float = 0.25
## 触屏设备的出厂默认：手机屏幕小，开箱先给 1.5 挡。
const DEFAULT_ZOOM_TOUCH: float = 1.5

## 设置文件路径；测试 / 冒烟可以指到别处，避免污染真实设置。
static var settings_path: String = DEFAULT_SETTINGS_PATH

static var _loaded: bool = false
static var _zoom: float = ZOOM_MIN


## 没有设置文件时的默认值：触屏用 [constant DEFAULT_ZOOM_TOUCH]，桌面保持 1.0。
static func default_zoom() -> float:
	return default_zoom_for(DisplayServer.is_touchscreen_available())


## [method default_zoom] 的纯函数版：把"是不是触屏"当参数，便于脱离设备跑规范。
static func default_zoom_for(is_touch: bool) -> float:
	return DEFAULT_ZOOM_TOUCH if is_touch else ZOOM_MIN


## 当前相机缩放；启动时未读过盘会先读一次。
static func zoom() -> float:
	if not _loaded:
		_load()
	return _zoom


## 写入缩放；[param persist] 为 false 时只改内存（测试 / 冒烟用）。
##
## 吸附到 [constant ZOOM_STEP] 的整数倍并夹到 [constant ZOOM_MIN] ~ [constant ZOOM_MAX]，
## 于是无论滑杆、配置文件还是调用方传什么都不可能越界。
static func set_zoom(value: float, persist: bool = true) -> void:
	_loaded = true
	var stepped: float = clampf(snappedf(value, ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(_zoom, stepped):
		return
	_zoom = stepped
	if persist:
		_save()


## 丢掉内存缓存，下次访问重新读盘（测试用）。
static func reload_from_disk() -> void:
	_loaded = false


## 恢复出厂值并清掉缓存（测试用）。
static func reset() -> void:
	_loaded = true
	_zoom = default_zoom()


static func _load() -> void:
	_loaded = true
	_zoom = default_zoom()
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_zoom = clampf(float(config.get_value(SECTION, KEY_ZOOM, _zoom)), ZOOM_MIN, ZOOM_MAX)


static func _save() -> void:
	var config := ConfigFile.new()
	# 先读一遍，保住同一文件里 [TouchSettings] 写的其它设置。
	config.load(settings_path)
	config.set_value(SECTION, KEY_ZOOM, _zoom)
	config.save(settings_path)
