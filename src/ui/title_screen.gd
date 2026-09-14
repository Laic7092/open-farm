class_name TitleScreen
extends Control
## 标题页：整个游戏的入口。
##
## 它[b]不属于[/b] [Main] 的 UI 层——标题页在游戏之前存在，扮演"引导者"：
## 设置 [member Main.boot_mode] 之后把场景切成 [Main]，
## 之后自己整个被释放。因此这里不能用 [SceneRouter]（它假定 [Main] 已经就位）。
##
## 画面全部来自 [code]tools/art/generate_title.gd[/code] 生成的像素素材：
## 背景是 1:1 的 640×360 像素画，云朵单独出图以便在代码里飘。
##
## 操作：方向键 / W S 选择，Enter / 空格 确认，鼠标同样可用。

## 语言选择按钮上显示的本地化名称。
const LOCALE_NAMES := {
	"zh_CN": "中文",
	"en": "English",
}

## 每朵云的水平漂移速度（像素/秒），负值向左。
const CLOUD_SPEEDS: Array[float] = [-6.0, -3.5, -9.0]

@onready var _title_block: VBoxContainer = %TitleBlock
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _save_info_label: Label = %SaveInfoLabel
@onready var _new_game_button: Button = %NewGameButton
@onready var _language_button: Button = %LanguageButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint_label: Label = %HintLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _cloud_1: TextureRect = %Cloud1
@onready var _cloud_2: TextureRect = %Cloud2
@onready var _cloud_3: TextureRect = %Cloud3

var _clouds: Array[TextureRect] = []
## 标题底板的基准高度，用于做轻微的上下浮动。
var _title_base_y: float = 0.0
## 是否已经记录过底板的基准位置（容器布局要等一帧才生效）。
var _title_base_ready: bool = false
var _elapsed: float = 0.0
## 本次要读的存档槽位；-1 表示没有存档。
var _continue_slot: int = -1


func _ready() -> void:
	_clouds = [_cloud_1, _cloud_2, _cloud_3]

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_language_button.pressed.connect(_on_language_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	# 对话 / 商店等模态界面可能在切换场景时留下暂停状态。
	get_tree().paused = false

	_refresh()
	_focus_default()


func _process(delta: float) -> void:
	# 容器布局要等第一帧才生效，基准位置必须在那之后记录，
	# 否则会把 (0, 0) 当成基准、把标题画到屏幕外面去。
	if not _title_base_ready:
		_title_base_y = _title_block.position.y
		_title_base_ready = true

	_elapsed += delta
	_drift_clouds(delta)
	# 标题轻微呼吸，静止的标题页容易让人以为卡住了。
	_title_block.position.y = _title_base_y + sin(_elapsed * 1.6) * 2.0


func _unhandled_input(event: InputEvent) -> void:
	# W / S 不在 Godot 内置的 ui_up / ui_down 里，这里补上。
	if event.is_action_pressed(&"move_down"):
		get_viewport().set_input_as_handled()
		_move_focus(1)
	elif event.is_action_pressed(&"move_up"):
		get_viewport().set_input_as_handled()
		_move_focus(-1)


# ---------------------------------------------------------------- 文本

## 按当前语言刷新所有文案与存档摘要。
func _refresh() -> void:
	_title_label.text = Text.key(&"GAME_TITLE")
	_subtitle_label.text = Text.key(&"GAME_SUBTITLE")
	_new_game_button.text = Text.key(&"TITLE_NEW_GAME")
	_language_button.text = "%s：%s" % [Text.key(&"TITLE_LANGUAGE"), _next_locale_name()]
	_quit_button.text = Text.key(&"TITLE_QUIT")
	_hint_label.text = Text.key(&"TITLE_HINT")
	_footer_label.text = "v%s · %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0"),
		Text.key(&"TITLE_FOOTER"),
	]
	_refresh_save_info()


func _refresh_save_info() -> void:
	_continue_slot = _newest_slot()
	if _continue_slot < 0:
		_continue_button.text = Text.key(&"TITLE_CONTINUE")
		_continue_button.disabled = true
		_save_info_label.text = Text.key(&"TITLE_SAVE_EMPTY")
		return

	_continue_button.disabled = false
	_continue_button.text = Text.key(&"TITLE_CONTINUE")
	var meta := SaveManager.read_meta(_continue_slot)
	var date: GameDate = meta.get("date", GameDate.new())
	_save_info_label.text = "%s　%s　%sG" % [
		Text.format(&"TITLE_SAVE_LABEL", {"slot": _continue_slot + 1}),
		Text.date_text(date),
		meta.get("money", 0),
	]


## 最近一次保存的槽位；没有存档时返回 -1。
func _newest_slot() -> int:
	var slots := SaveManager.existing_slots()
	if slots.is_empty():
		return -1
	var best: int = slots[0]
	var best_time: String = str(SaveManager.read_meta(best).get("saved_at", ""))
	for slot: int in slots:
		var stamp: String = str(SaveManager.read_meta(slot).get("saved_at", ""))
		if stamp > best_time:
			best = slot
			best_time = stamp
	return best


# ---------------------------------------------------------------- 交互

func _focus_default() -> void:
	var target: Button = _continue_button if not _continue_button.disabled else _new_game_button
	target.grab_focus()


## 在可选按钮之间移动焦点（跳过被禁用的）。
func _move_focus(step: int) -> void:
	var buttons: Array[Button] = []
	for button: Button in [_continue_button, _new_game_button, _language_button, _quit_button]:
		if not button.disabled:
			buttons.append(button)
	if buttons.is_empty():
		return
	var current: int = buttons.find(get_viewport().gui_get_focus_owner() as Button)
	var next: int = posmod(current + step, buttons.size()) if current >= 0 else 0
	buttons[next].grab_focus()


func _on_continue_pressed() -> void:
	if _continue_slot < 0:
		return
	_start_game(Main.BootMode.LOAD_SLOT, _continue_slot)


func _on_new_game_pressed() -> void:
	_start_game(Main.BootMode.NEW_GAME, 0)


func _on_language_pressed() -> void:
	AppTheme.set_locale(_next_locale())
	_refresh()
	_focus_default()


func _on_quit_pressed() -> void:
	get_tree().quit()


## 交给 [Main] 的入口参数，然后切场景。
func _start_game(mode: Main.BootMode, slot: int) -> void:
	Main.boot_mode = mode
	Main.boot_slot = slot
	# 标题页到此为止：它会被 change_scene_to_file 整个释放。
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


# ---------------------------------------------------------------- 语言

## 已加载语言里，当前语言的下一个（用于"点一下换一种语言"）。
func _next_locale() -> String:
	var locales := TranslationServer.get_loaded_locales()
	if locales.size() <= 1:
		return TranslationServer.get_locale()
	locales.sort()
	var index: int = locales.find(TranslationServer.get_locale())
	return locales[posmod(index + 1, locales.size())]


func _next_locale_name() -> String:
	var locale := _next_locale()
	return LOCALE_NAMES.get(locale, locale)


# ---------------------------------------------------------------- 云

## 云漂到左边界外就从右侧绕回来，形成无限循环。
func _drift_clouds(delta: float) -> void:
	var width: float = get_viewport_rect().size.x
	for index: int in _clouds.size():
		var cloud: TextureRect = _clouds[index]
		cloud.position.x += CLOUD_SPEEDS[index % CLOUD_SPEEDS.size()] * delta
		if cloud.position.x + cloud.size.x < 0.0:
			cloud.position.x = width
