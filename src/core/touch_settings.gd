class_name TouchSettings
extends RefCounted
## 显示 / 输入设置：要不要在屏幕上摆虚拟摇杆与动作按钮。
##
## 与 [BgmPlayer] 的音量设置同构：写进 [code]user://display_settings.cfg[/code]，
## 读不到 / 写不进都静默降级（[code]user://[/code] 不可写时游戏照常能玩）。
##
## 缺省值取"这台机器有没有触摸屏"：手机 / 平板上开箱即用，桌面上保持纯键盘。
## [TouchControls] 拿它决定"屏幕上要不要摆虚拟摇杆与动作键"；
## 鼠标指针可见性由 [method PointerInput.sync_cursor] 统一保证，与本开关无关。
## 所以这里只放纯状态 + 文件 IO，不碰场景树、不发信号——
## "改了设置要通知谁"由调用方（系统菜单）决定。

## 默认设置文件；与音频设置分开，互不覆盖。
const DEFAULT_SETTINGS_PATH: String = "user://display_settings.cfg"
const SECTION: String = "input"
const KEY_TOUCH_CONTROLS: String = "touch_controls"

## 设置文件路径；测试 / 冒烟可以指到别处，避免污染真实设置。
static var settings_path: String = DEFAULT_SETTINGS_PATH

## 是否已经读过盘（首次访问才读，之后走内存）。
static var _loaded: bool = false
static var _enabled: bool = false


## 当前是否显示触控控件。
static func is_enabled() -> bool:
	if not _loaded:
		_load()
	return _enabled


## 写入设置；[param persist] 为 false 时只改内存（测试 / 冒烟用）。
static func set_enabled(enabled: bool, persist: bool = true) -> void:
	_loaded = true
	if _enabled == enabled:
		return
	_enabled = enabled
	if persist:
		_save()


## 丢掉内存缓存，下次访问重新读盘（测试用）。
##
## 名字不叫 [code]reload()[/code]：那是 [GDScript] 自己的原生方法，
## 同名时静态函数会被原生方法顶掉（调用它只会重新加载脚本、顺带清空全部静态变量）。
static func reload_from_disk() -> void:
	_loaded = false


## 恢复成"按机器能力判断"的出厂状态，并清掉缓存（测试用）。
static func reset() -> void:
	_loaded = true
	_enabled = _default_enabled()


## 没有设置文件时的默认值：有触摸屏就开。
static func _default_enabled() -> bool:
	return DisplayServer.is_touchscreen_available()


static func _load() -> void:
	_loaded = true
	_enabled = _default_enabled()
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_enabled = bool(config.get_value(SECTION, KEY_TOUCH_CONTROLS, _enabled))


static func _save() -> void:
	var config := ConfigFile.new()
	# 先读一遍，保住同一文件里将来可能加的其它显示设置。
	config.load(settings_path)
	config.set_value(SECTION, KEY_TOUCH_CONTROLS, _enabled)
	config.save(settings_path)
