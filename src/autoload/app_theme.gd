extends Node
## 外观与语言引导（Autoload：`AppTheme`）。
##
## 负责两件"进入游戏之前就该定好"的事：
## [br]1. [b]语言[/b]——Godot 默认完全跟随系统语言，
##    而 [code]internationalization/locale/fallback[/code] 只在"某个键缺翻译"时兜底，
##    不会改变整体语言。这里显式匹配一次，保证中文玩家默认看到中文。
## [br]2. [b]中文字体[/b]——[code]assets/fonts/ui_font.tres[/code] 用的是 [SystemFont]，
##    它会向操作系统要字体。但有些环境（精简 Linux 容器、WSL、
##    未装 CJK 包的发行版）fontconfig 里根本没有中文字体，
##    结果就是满屏"豆腐块"。这里在启动时探测一次，
##    必要时从已知路径里加载一个中文字体作为兜底。
##
## 这两件事都属于"表现层设置"，因此不放 [GameState]（那是玩法状态）。

## 系统语言不在支持列表里时使用的语言。
const DEFAULT_LOCALE: String = "zh_CN"

## 用来探测字体是否覆盖中文的字符。
const CJK_PROBE_CHAR: int = 0x7267  # "牧"

## 项目设置里指定的默认字体路径。
const PROJECT_FONT_SETTING: String = "gui/theme/custom_font"

## 找不到系统 CJK 字体时，依次尝试加载的绝对路径。
##
## 覆盖常见平台：Linux 各发行版、macOS、Windows，以及 WSL 挂载的 Windows 字体目录。
const CJK_FONT_CANDIDATES: Array[String] = [
	# Linux
	"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
	"/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
	"/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
	"/usr/share/fonts/truetype/arphic/uming.ttc",
	# macOS
	"/System/Library/Fonts/PingFang.ttc",
	"/System/Library/Fonts/STHeiti Light.ttc",
	"/Library/Fonts/Arial Unicode.ttf",
	# Windows
	"C:/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/simhei.ttf",
	"C:/Windows/Fonts/simsun.ttc",
	# WSL 挂载的 Windows 字体目录
	"/mnt/c/Windows/Fonts/msyh.ttc",
	"/mnt/c/Windows/Fonts/simhei.ttf",
	"/mnt/c/Windows/Fonts/simsun.ttc",
]

## 当前实际生效的语言。
var locale: String = ""


func _ready() -> void:
	apply_system_locale()
	install_cjk_fallback()


## 应用语言：系统语言受支持就用系统语言，否则回退到 [constant DEFAULT_LOCALE]。
func apply_system_locale() -> void:
	var supported := TranslationServer.get_loaded_locales()
	if supported.is_empty():
		return
	var system_locale := OS.get_locale()
	for candidate: String in supported:
		if system_locale == candidate or system_locale.begins_with(candidate + "_"):
			set_locale(candidate)
			return
	set_locale(DEFAULT_LOCALE if supported.has(DEFAULT_LOCALE) else supported[0])


## 切换语言（设置界面用）。
func set_locale(value: String) -> void:
	if not TranslationServer.get_loaded_locales().has(value):
		return
	locale = value
	TranslationServer.set_locale(value)


## 当前字体是否已经能显示中文。
func font_supports_chinese() -> bool:
	var font := current_font()
	return font != null and font.has_char(CJK_PROBE_CHAR)


## 当前生效的默认字体。
func current_font() -> Font:
	var theme := ThemeDB.get_default_theme()
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font


## 探测系统字体是否覆盖中文；不覆盖时加载一个兜底字体。
##
## 返回是否成功装上了兜底字体（已经支持中文时返回 true）。
func install_cjk_fallback() -> bool:
	if font_supports_chinese():
		return true

	var base := current_font()
	for path: String in CJK_FONT_CANDIDATES:
		var candidate := _load_font(path)
		if candidate == null or not candidate.has_char(CJK_PROBE_CHAR):
			continue
		_attach_fallback(base, candidate)
		push_warning(
			"AppTheme: 系统缺少中文字体，已使用 '%s' 作为兜底。" % path
		)
		return true

	push_warning(
		"AppTheme: 未找到任何中文字体，中文将显示为方块。"
		+ "请安装中文字体（例如 fonts-noto-cjk），或把字体文件放到 "
		+ "assets/fonts/ 并修改 ui_font.tres。"
	)
	return false


## 把 [param extra] 挂到 [param base] 的 fallback 链上。
##
## 用 [FontVariation] 而不是直接改 [SystemFont]，是因为 FontVariation 的
## fallback 链在 TextServer 层有明确定义，行为可预期。
func _attach_fallback(base: Font, extra: Font) -> void:
	var variation := FontVariation.new()
	variation.base_font = base
	var chain: Array[Font] = []
	if base != null:
		chain.append_array(base.fallbacks)
	if not chain.has(extra):
		chain.append(extra)
	variation.fallbacks = chain

	var theme := ThemeDB.get_default_theme()
	if theme != null:
		theme.default_font = variation
	ThemeDB.fallback_font = variation


func _load_font(path: String) -> FontFile:
	if not FileAccess.file_exists(path):
		return null
	var font := FontFile.new()
	if font.load_dynamic_font(path) != OK:
		return null
	return font
