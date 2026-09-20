class_name Hud
extends Control
## 常驻 HUD 的容器。
##
## 它[b]只负责组装[/b]：左上角状态卡（日期 / 时间 / 金钱 / 体力）与底部物品栏
## 各由自己的小视图（[HudTimeView] / [HudPlayerView] / [HudItemBarView]）
## 订阅自己域的信号并渲染，容器不认识它们的状态，也不替它们保存一份。
##
## 交互提示与浮动提示是 UI 域自己的东西，所以留在这里。
##
## 底部常驻物品栏只是背包前几格的[b]快捷访问视图[/b]，不存放任何道具；
## 工具与种子都放在背包里。Q / R 在装有可用道具的格子之间切换。

## 浮动提示停留时长（秒）。
const TOAST_DURATION: float = 2.2
## 专属音效之后这段时间内的通用通知音会被抑制，避免"一个动作两声"（毫秒）。
const NOTIFY_SUPPRESS_MS: int = 140
## 这些通知意味着"没做成"，用低沉的失败音。
const NEGATIVE_NOTIFICATIONS: Array[StringName] = [
	&"NOTIFY_NOTHING_HAPPENED",
	&"NOTIFY_NOTHING_TO_SHIP",
	&"NOTIFY_NO_FEED",
	&"NOTIFY_LOAD_FAILED",
]

@onready var prompt_label: Label = %PromptLabel
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween
## 本界面自己的音效播放器：通知音由显示通知的界面发出。
var sfx: SfxPlayer


## 由 [UiRoot] 转发的组合根依赖；继续下发给各小视图。
func bind_dependencies(profile: PlayerProfile, clock: GameDateClock) -> void:
	_dispatch(&"bind_dependencies", [profile, clock])


## 由 [UiRoot] 转发的领域服务；继续下发给各小视图。
func bind_services(
	weather: WeatherService,
	relationships: RelationshipService,
	calendar: CalendarService
) -> void:
	_dispatch(&"bind_services", [weather, relationships, calendar])


## 由 [UiRoot] 转发的"当前物品栏"提供者；下发给物品栏视图。
func bind_item_bar(provider: Callable) -> void:
	_dispatch(&"bind_item_bar", [provider])


func _ready() -> void:
	sfx = SfxPlayer.attach(self)
	EventBus.ui.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.ui.notification_requested.connect(_on_notification)
	toast_label.modulate.a = 0.0
	prompt_label.text = ""


## 把注入原样转给实现了该方法的子视图；视图自己决定要不要读、什么时候读。
func _dispatch(method: StringName, args: Array) -> void:
	var container := get_node_or_null(^"Views")
	if container == null:
		return
	for view: Node in container.get_children():
		if view.has_method(method):
			view.callv(method, args)


func _on_prompt_changed(prompt_key: StringName) -> void:
	prompt_label.text = Text.key(prompt_key)


func _on_notification(text_key: StringName, args: Dictionary) -> void:
	var message := Text.format(text_key, args)
	if message.is_empty():
		return

	toast_label.text = message

	if sfx != null and AudioBus.since_last_sfx_ms() >= NOTIFY_SUPPRESS_MS:
		if NEGATIVE_NOTIFICATIONS.has(text_key):
			sfx.play(AudioCatalog.SFX_ERROR, 1.0, -2.0)
		else:
			sfx.play(AudioCatalog.SFX_NOTIFY, 1.0, -3.0)

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)
