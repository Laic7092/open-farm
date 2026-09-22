class_name ModalShell
extends Control
## 模态界面共享外壳：遮罩 + 居中面板 + 标题 / 正文 / 说明 / 提示。
##
## 所有模态（背包 / 商店 / 图鉴 / 委托 / 料理 / 品评会 / 村庄目标 / 暂停菜单）
## 都实例化它，并在 [method _ready] 里把自己的内容节点交给 [method set_body] /
## [method set_status]。尺寸、边距、间距与字号全部来自主题类型变体
## （由 [code]tools/generate_resources.gd[/code] 从 [UiLayout] 组装），
## 响应式计算只在这里做一次。
##
## [b]归属[/b]：外壳是"界面怎么摆"的唯一实现，内容归各界面自己。
##
## [b]为什么用 [method set_body] 而不是在编辑器里往实例内部挂节点[/b]：
## Godot 的"可编辑子节点"只在编辑器里存在，运行时 [method PackedScene.instantiate]
## 会丢掉这些节点；因此改成运行时把已声明的内容控件收编进外壳。

## 面板：由本脚本按视口与内容最小尺寸设置大小 / 位置 / 缩放。
@onready var panel: PanelContainer = %Panel
## 标题行：标题 + 各界面自带的右侧状态（日期 / 金钱 / 进度）。
@onready var header: HBoxContainer = %Header
## 正文容器：各模态把列表 / 网格挂在这里。
@onready var body: VBoxContainer = %Body
@onready var title_label: Label = %TitleLabel
@onready var info_label: Label = %InfoLabel
@onready var hint_label: Label = %HintLabel

var _ui_scale: float = 1.0
var _safe: Vector4 = Vector4.ZERO
## 触控控件占用的左右宽度（左、右）；关闭触控时为零。
var _touch_insets: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	EventBus.ui.ui_scale_changed.connect(apply_ui_scale)
	EventBus.ui.safe_insets_changed.connect(_on_safe_insets_changed)
	EventBus.ui.touch_insets_changed.connect(_on_touch_insets_changed)
	# 空说明 / 空提示不占高度，否则每个模态都会白白多出两行。
	info_label.visible = false
	hint_label.visible = false
	# 内容（列表项、说明文案）变化会改最小尺寸，必须重排，否则面板会撑出画面。
	body.minimum_size_changed.connect(_on_minimum_size_changed)
	_ui_scale = UiSettings.scale()
	_fit.call_deferred()


## 设置标题文案。
func set_title(text: String) -> void:
	title_label.text = text


## 把一个状态控件（日期 / 金钱 / 进度）收编到标题行右侧。
func set_status(control: Control) -> void:
	control.reparent(header, false)


## 把一个内容控件（列表 / 网格）收编到正文容器。
func set_body(control: Control) -> void:
	control.reparent(body, false)


## 设置底部说明；空串时整行隐藏，不占高度。
func set_info(text: String) -> void:
	info_label.text = text
	info_label.visible = not text.is_empty()


## 设置底部提示；空串时整行隐藏，不占高度。
func set_hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = not text.is_empty()


## 由 [UiRoot] 统一分发；也可由信号直接驱动，重复应用是幂等的。
func apply_ui_scale(value: float) -> void:
	_ui_scale = value
	_fit.call_deferred()


func _on_safe_insets_changed(insets: Vector4) -> void:
	_safe = insets
	_fit.call_deferred()


func _on_touch_insets_changed(insets: Vector2) -> void:
	_touch_insets = insets
	_fit.call_deferred()


func _on_minimum_size_changed() -> void:
	_fit.call_deferred()


## 可用区域：扣掉安全区与触控控件占位。
##
## 摇杆钉左下、ABXY 钉右下，面板如果仍按整屏居中就会被压在两角上；
## 这里把左右两侧让出来，面板只落在两者之间的安全带里。
func _usable_rect(viewport: Vector2) -> Rect2:
	var left := maxf(_safe.x, _touch_insets.x)
	var right := maxf(_safe.z, _touch_insets.y)
	var origin := Vector2(left, _safe.y)
	var size := viewport - Vector2(left + right, _safe.y + _safe.w)
	return Rect2(origin, size.max(Vector2.ZERO))


## 按"可用区域比例 + 内容最小尺寸 + UI 缩放"重排面板，并把它夹进可用区域。
func _fit() -> void:
	if panel == null:
		return
	var viewport := size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		viewport = get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	var area := _usable_rect(viewport)
	var target := UiLayout.modal_size(area.size, panel.get_combined_minimum_size(), _ui_scale)
	panel.size = target
	panel.position = area.position + (area.size - target).max(Vector2.ZERO) * 0.5
	panel.pivot_offset = target * 0.5
	panel.scale = Vector2(_ui_scale, _ui_scale)
