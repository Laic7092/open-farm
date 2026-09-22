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
## [b]按钮条件显示[/b]：没有任何存档时"继续游戏"整个隐藏（而不是只置灰），
## 焦点自动落到"新游戏"，避免键盘玩家停在按不动的按钮上；
## 有存档时两个按钮都出现，"继续游戏"打开存档列表让人选一局。
##
## 操作：WASD / 方向键选择，Enter / 空格 确认；鼠标指针可见，也可直接点按。
##
## W / A / S / D 已经并进内置的 ui_* 动作（见 [code]project.godot[/code] 的 InputMap），
## 所以菜单直接用 Godot 的焦点导航；存档列表也是按钮，方向键天然可选中。

## 语言选择按钮上显示的本地化名称（翻译键）。
const LOCALE_NAME_KEYS := {
	"zh_CN": &"LOCALE_NAME_ZH_CN",
	"en": &"LOCALE_NAME_EN",
}

## 每朵云的水平漂移速度（像素/秒），负值向左。
const CLOUD_SPEEDS: Array[float] = [-6.0, -3.5, -9.0]

## 删除存档的按键；纯键盘操作下用它管理存档列表。
const DELETE_KEY: Key = KEY_DELETE

@onready var _title_block: VBoxContainer = %TitleBlock
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _menu: VBoxContainer = %Menu
@onready var _continue_button: Button = %ContinueButton
@onready var _save_info_label: Label = %SaveInfoLabel
@onready var _new_game_button: Button = %NewGameButton
@onready var _language_button: Button = %LanguageButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint_label: Label = %HintLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _save_panel: Control = %SavePanel
@onready var _save_title_label: Label = %SaveTitleLabel
@onready var _save_list: VBoxContainer = %SaveList
@onready var _save_hint_label: Label = %SaveHintLabel
@onready var _cloud_1: TextureRect = %Cloud1
@onready var _cloud_2: TextureRect = %Cloud2
@onready var _cloud_3: TextureRect = %Cloud3
@onready var _bgm: BgmPlayer = %Bgm

var _clouds: Array[TextureRect] = []
## 开局的「点击 / 按键开始」遮罩；默认所有平台都展示，接住第一次输入后再起 BGM。
var _start_veil: Control
## 本页面自己的音效播放器。
var sfx: SfxPlayer
## 标题底板的基准高度，用于做轻微的上下浮动。
var _title_base_y: float = 0.0
## 是否已经记录过底板的基准位置（容器布局要等一帧才生效）。
var _title_base_ready: bool = false
var _elapsed: float = 0.0
## 标题页当前看到的存档摘要；按最近保存时间倒序。
var _saves: Array[Dictionary] = []


func _ready() -> void:
	add_child(RotateOverlay.new())
	PointerInput.sync_cursor()
	sfx = SfxPlayer.attach(self)
	_clouds = [_cloud_1, _cloud_2, _cloud_3]

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_language_button.pressed.connect(_on_language_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button: Button in [_continue_button, _new_game_button, _language_button, _quit_button]:
		button.custom_minimum_size = Vector2(
			UiLayout.TITLE_MENU_WIDTH, UiLayout.TITLE_MENU_BUTTON_HEIGHT
		)
		button.focus_entered.connect(_on_menu_focus)
	# 对话 / 商店等模态界面可能在切换场景时留下暂停状态。
	get_tree().paused = false

	_save_panel.visible = false
	_refresh()
	_focus_default()
	_setup_start_veil()


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


func _input(event: InputEvent) -> void:
	# 开始遮罩还在时，先吞掉这次输入，只用来撤掉遮罩并开始 BGM。
	if _start_veil != null:
		if event.is_pressed() and not event.is_echo():
			_dismiss_start_veil()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	# 存档列表打开时接住 Esc（返回）与 Delete（删档）。
	if not _save_panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_save_panel()
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == DELETE_KEY
	):
		get_viewport().set_input_as_handled()
		_delete_focused_save()


# ---------------------------------------------------------------- 开始遮罩

## 默认展示“点击 / 按键开始”遮罩，等第一次输入后再播 BGM。
## 它不负责唤醒浏览器的 AudioContext —— 那是引擎在 canvas 收到输入时自己做的；
## 这里只保证「玩家给出第一次输入之后」才开始放 BGM。
func _setup_start_veil() -> void:
	_start_veil = Control.new()
	_start_veil.name = "StartVeil"
	_start_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_start_veil)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_veil.add_child(dim)

	var hint := Label.new()
	hint.text = Text.key(&"TITLE_TAP_TO_START")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.add_theme_font_size_override("font_size", UiLayout.FONT_TITLE)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_veil.add_child(hint)


## 第一次输入：撤掉遮罩并开始标题 BGM。
func _dismiss_start_veil() -> void:
	if _start_veil == null:
		return
	_start_veil.queue_free()
	_start_veil = null
	_bgm.refresh.call_deferred()


# ---------------------------------------------------------------- 文本

## 按当前语言刷新所有文案与存档摘要。
func _refresh() -> void:
	_title_label.text = Text.key(&"GAME_TITLE")
	_subtitle_label.text = Text.key(&"GAME_SUBTITLE")
	_continue_button.text = Text.key(&"TITLE_CONTINUE")
	_save_title_label.text = Text.key(&"TITLE_SAVE_TITLE")
	_save_hint_label.text = Text.key(&"TITLE_SAVE_HINT")
	_new_game_button.text = Text.key(&"TITLE_NEW_GAME")
	_language_button.text = "%s：%s" % [Text.key(&"TITLE_LANGUAGE"), _next_locale_name()]
	_quit_button.text = Text.key(&"TITLE_QUIT")
	_hint_label.text = Text.key(&"TITLE_HINT")
	_footer_label.text = "v%s · %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0"),
		Text.key(&"TITLE_FOOTER"),
	]
	_refresh_save_info()


## 刷新"继续游戏"按钮的可见性与下方的存档摘要。
##
## 没有存档时按钮整个隐藏：禁用按钮仍会占位、且对纯键盘玩家没有意义。
func _refresh_save_info() -> void:
	_saves = SaveManager.all_meta()
	if _saves.is_empty():
		_set_continue_visible(false)
		_save_info_label.text = Text.key(&"TITLE_SAVE_EMPTY")
		return

	_set_continue_visible(true)
	_save_info_label.text = _slot_text(_saves[0])


## 启用 / 隐藏"继续游戏"按钮。
##
## 隐藏的按钮要同时退出焦点链，否则方向键会在它上面停住。
func _set_continue_visible(visible_now: bool) -> void:
	_continue_button.visible = visible_now
	_continue_button.disabled = not visible_now
	_continue_button.focus_mode = Control.FOCUS_ALL if visible_now else Control.FOCUS_NONE


## 一行存档摘要："存档 2　春 3 日　1200G"。
func _slot_text(meta: Dictionary) -> String:
	var date: GameDate = meta.get("date", GameDate.new())
	return "%s　%s　%dG" % [
		Text.format(&"TITLE_SAVE_LABEL", {"slot": int(meta.get("slot", 0)) + 1}),
		Text.date_text(date),
		int(meta.get("money", 0)),
	]


# ---------------------------------------------------------------- 存档列表

## 打开存档列表：藏起主菜单、按最近保存顺序铺出每一局。
func _open_save_panel() -> void:
	if _saves.is_empty():
		return
	_refresh_save_list()
	_save_panel.visible = true
	_menu.visible = false
	_focus_save_list(0)


func _close_save_panel() -> void:
	_save_panel.visible = false
	_menu.visible = true
	# 删过档或时间变了，回到主菜单时同步一次。
	_refresh_save_info()
	_focus_default()


## 重建存档列表；每一项都是按钮，直接复用 Godot 的焦点导航。
func _refresh_save_list() -> void:
	for child: Node in _save_list.get_children():
		_save_list.remove_child(child)
		child.queue_free()
	for meta: Dictionary in _saves:
		var slot := int(meta.get("slot", 0))
		var button := Button.new()
		button.text = _slot_text(meta)
		button.custom_minimum_size = Vector2(0.0, UiLayout.TITLE_SAVE_ROW_HEIGHT)
		button.pressed.connect(_on_slot_chosen.bind(slot))
		button.focus_entered.connect(_on_menu_focus)
		_save_list.add_child(button)


## 把焦点放到列表第 [param index] 项；列表为空时不动。
func _focus_save_list(index: int) -> void:
	var buttons := _save_list.get_children()
	if buttons.is_empty():
		return
	var target := clampi(index, 0, buttons.size() - 1)
	(buttons[target] as Button).grab_focus()


## 删除当前焦点所在的那一局；删完还有存档就继续留在列表里。
func _delete_focused_save() -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or focused.get_parent() != _save_list:
		return
	var index := focused.get_index()
	var slot := int(_saves[index].get("slot", -1)) if index < _saves.size() else -1
	if slot < 0:
		return
	sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
	SaveManager.delete_save(slot)
	_saves = SaveManager.all_meta()
	if _saves.is_empty():
		_close_save_panel()
		return
	_refresh_save_list()
	_focus_save_list(index)


# ---------------------------------------------------------------- 交互

func _focus_default() -> void:
	var target: Button = _continue_button if _continue_button.visible else _new_game_button
	target.grab_focus()


## 焦点落到某个按钮上时的移动音效。
func _on_menu_focus() -> void:
	sfx.play(AudioCatalog.SFX_UI_MOVE, 1.0, -4.0)

func _on_continue_pressed() -> void:
	if _saves.is_empty():
		return
	sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
	_open_save_panel()

func _on_slot_chosen(slot: int) -> void:
	sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
	_start_game(Main.BootMode.LOAD_SLOT, slot)

func _on_new_game_pressed() -> void:
	sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
	_start_game(Main.BootMode.NEW_GAME, 0)

func _on_language_pressed() -> void:
	sfx.play(AudioCatalog.SFX_UI_CONFIRM, 1.0, -3.0)
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
	var name_key: StringName = LOCALE_NAME_KEYS.get(locale, &"")
	if name_key == &"":
		return locale
	return Text.key(name_key)

# ---------------------------------------------------------------- 云

## 云漂到左边界外就从右侧绕回来，形成无限循环。
func _drift_clouds(delta: float) -> void:
	var width: float = get_viewport_rect().size.x
	for index: int in _clouds.size():
		var cloud: TextureRect = _clouds[index]
		cloud.position.x += CLOUD_SPEEDS[index % CLOUD_SPEEDS.size()] * delta
		if cloud.position.x + cloud.size.x < 0.0:
			cloud.position.x = width
