class_name UiLayout
extends RefCounted
## UI 布局令牌与响应式计算——[b]界面尺寸的唯一来源[/b]。
##
## 与 [code]src/art/atlas_layout.gd[/code] 同构：那边管像素素材的格子，
## 这里管界面的边距 / 间距 / 字号 / 最小尺寸。场景与脚本里不得再出现裸数字，
## 需要新尺寸时先在本文件起一个有名字的常量。
##
## 只放常量与纯静态函数，不碰场景树、不依赖任何域——因此可以直接被
## [code]tools/generate_resources.gd[/code] 在生成主题时 preload。
##
## [b]坐标系[/b]：项目基准画布是 640×360（见 [code]project.godot[/code]），
## [code]stretch=canvas_items[/code] 下所有数值都是这个虚拟画布上的像素。

## 设计基准画布；与 [code]project.godot[/code] 的 viewport 尺寸保持一致。
const DESIGN_SIZE := Vector2i(640, 360)

# ---------------------------------------------------------------- 间距

## 所有边距 / 间距的最小单位，数值尽量取它的整数倍。
const GRID: int = 4
## 面板内边距（左右）。
const MARGIN_PANEL_H: int = 12
## 面板内边距（上下）。
const MARGIN_PANEL_V: int = 10
## 通用行距。
const GAP: int = 6

# ---------------------------------------------------------------- 字号 / 描边

const FONT_BODY: int = 12
const FONT_TITLE: int = 14
const FONT_DISPLAY: int = 36
const FONT_SMALL: int = 8
## 描边宽度（HUD 白字压在场景上必须描边）。
const OUTLINE_WIDTH: int = 4

# ---------------------------------------------------------------- 模态面板

## 面板最小尺寸：内容再少也保持可读的按钮 / 列表。
const PANEL_MIN := Vector2(216, 140)
## 面板最大尺寸：超宽 / 大屏下不再无限拉伸。
const PANEL_MAX := Vector2(520, 344)
## 面板相对可视区域的目标比例（配合 UI 缩放取较小者）。
const PANEL_RATIO := Vector2(0.82, 0.86)
## 面板与屏幕边缘之间至少留出的安全边距。
const MARGIN_SCREEN: int = 8

## 窄高比阈值：可视区域宽高比小于它时进入精简布局（隐藏次要信息）。
const COMPACT_ASPECT: float = 1.6

# ---------------------------------------------------------------- 控件尺寸

const HUD_SLOT_SIZE := Vector2(22, 22)
const HUD_SLOT_PATCH: int = 3
const ITEM_SLOT_SIZE := Vector2(100, 28)
const ITEM_ICON_SIZE := Vector2(16, 16)
const QUALITY_STAR_SIZE: float = 6.0
const DIVIDER_HEIGHT: float = 1.0
const BAR_SIZE := Vector2(72, 10)
const FISH_TRACK_SIZE := Vector2(18, 88)
const FISH_ZONE_SIZE := Vector2(18, 14)
const FISH_MARK_SIZE := Vector2(12, 10)
const FISH_HOOK_SIZE := Vector2(8, 8)
const FISH_CHARGE_BAR := Vector2(144, 12)
## 拉扯水槽宽度与它同触控控件之间的间隙。
const FISH_FIGHT_WIDTH: float = 118.0
const FISH_FIGHT_GAP: float = 4.0
const TOUCH_BUTTON_SIZE: float = 44.0
const TOUCH_PAD_SIZE: float = 116.0
## HUD 左上状态卡相对屏幕左上角的内边距。
const HUD_STATUS_MARGIN := Vector2(6, 4)
## 底部物品栏距屏幕底边的距离。
const HUD_BAR_BOTTOM: float = 10.0
## 顶部提示行距屏幕顶边 / 左右的安全距离。
const HUD_HINTS_TOP: float = 6.0
const HUD_HINTS_SIDE: float = 20.0
const TITLE_MENU_WIDTH: float = 228.0
const TITLE_MENU_BUTTON_HEIGHT: float = 28.0
const TITLE_SAVE_ROW_HEIGHT: float = 24.0
const DIALOGUE_MIN_HEIGHT: float = 140.0
const DIALOGUE_TEXT_MIN_HEIGHT: float = 40.0
const DIALOGUE_SIDE: float = 16.0
const DIALOGUE_BOTTOM: float = 10.0
const TOUCH_STICK_SIZE: float = 128.0
const TOUCH_PAD_MARGIN: float = 10.0
## 触控面板的横向默认留白：没有安全区（桌面 / headless）时至少让出这么多。
const TOUCH_PAD_PADDING: float = 48.0


# ---------------------------------------------------------------- 响应式

## 模态面板的目标尺寸（[b]未缩放[/b]）。
##
## [param area] 是"可用区域"（已经扣掉安全区与触控占位），[param content_min] 是内容
## 最小尺寸，[param scale] 是实际生效的 UI 缩放（调用方先用 [method fitted_scale] 夹好），
## [param ratio] 是目标相对可用区的比例：某轴传 0 表示该轴贴内容最小尺寸（竖向菜单用）。
## 目标取可用区域的 [param ratio]，再被 [constant PANEL_MIN] / [constant PANEL_MAX]
## 与可用区域上限夹取；因为调用方会把面板整体放大 [param scale] 倍，所以这里先除以它，
## 于是"放大 UI"不会把面板顶出画面。
##
## [b]内容最小尺寸是硬下限[/b]：宁可撑破 [constant PANEL_MAX] / 可用上限，也不被容器压小，
## 因此调用方必须先用 [method fitted_scale] 保证 [code]content_min * scale[/code] 放得下。
static func modal_size(
	area: Vector2, content_min: Vector2, scale: float, ratio: Vector2 = PANEL_RATIO
) -> Vector2:
	var safe_scale: float = maxf(scale, 0.01)
	if area.x <= 0.0 or area.y <= 0.0:
		return PANEL_MIN.max(content_min)
	var limit := (area - Vector2(MARGIN_SCREEN, MARGIN_SCREEN) * 2.0) / safe_scale
	limit = limit.max(Vector2.ONE)
	var desired := area * ratio / safe_scale
	var lower := PANEL_MIN.min(limit)
	var target := desired.max(content_min)
	target = target.min(PANEL_MAX)
	target = target.min(limit)
	target = target.max(content_min)
	return target.max(lower)


## 居中的模态面板矩形：尺寸为 [method modal_size]，坐标在 [param area] 里居中。
##
## 返回的尺寸是"未缩放尺寸"；调用方用 [method grow_pivot] 把 pivot 放到中心后整体放大。
static func modal_rect(area: Vector2, content_min: Vector2, scale: float) -> Rect2:
	var target := modal_size(area, content_min, scale)
	return Rect2((area - target) * 0.5, target)


## 在 [param available] 内完整容纳 [param content_min] 的前提下，最接近
## [param requested] 的缩放。内容比可用区还大时会低于 1，但绝不溢出。
## 因为界面是整体缩放（[code]Control.scale[/code]），内容最小尺寸也被一起放大，
## 所以必须用它先把请求的 UI 缩放夹到"内容放得下"。
static func fitted_scale(available: Vector2, content_min: Vector2, requested: float) -> float:
	var scale: float = maxf(requested, 0.01)
	if available.x > 0.0 and content_min.x > 0.0:
		scale = minf(scale, available.x / content_min.x)
	if available.y > 0.0 and content_min.y > 0.0:
		scale = minf(scale, available.y / content_min.y)
	return maxf(scale, 0.01)


## 贴边留白：显示安全区为 0（桌面 / headless）时退回 [param fallback]。
## 触控面板等贴边界面统一用它把安全区补成“安全区或默认值”，不再各自写 maxf。
static func edge_inset(safe: float, fallback: float = 0.0) -> float:
	return maxf(safe, fallback)


## 贴边界面单侧实际要让出的距离：显示安全区与触控控件占位取较大者。
static func edge_clearance(safe: float, touch: float) -> float:
	return maxf(safe, touch)


## 扣掉显示安全区后的屏幕矩形；模态 / 对话在它里面夹取，不贴到刘海 / 圆角。
static func safe_rect(viewport: Vector2, safe: Vector4) -> Rect2:
	var origin := Vector2(safe.x, safe.y)
	var size := viewport - Vector2(safe.x + safe.z, safe.y + safe.w)
	return Rect2(origin, size.max(Vector2.ZERO))


## 扣掉安全区与触控控件占位后的可用区域；模态与对话都按它排布。
static func usable_rect(viewport: Vector2, safe: Vector4, touch_insets: Vector2) -> Rect2:
	var left := maxf(safe.x, touch_insets.x)
	var right := maxf(safe.z, touch_insets.y)
	var origin := Vector2(left, safe.y)
	var size := viewport - Vector2(left + right, safe.y + safe.w)
	return Rect2(origin, size.max(Vector2.ZERO))


## 是否进入精简布局（窄高比不够）。宽高比为 0（窗口未就绪）不算精简。
static func is_compact(viewport: Vector2) -> bool:
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return false
	return viewport.x / viewport.y < COMPACT_ASPECT


## 按锚点方向算缩放的 pivot：放大时只朝屏幕内侧生长。
##
## [param anchor] 用 0..1 表示锚在矩形里的位置（左上=(0,0)，居中=(0.5,0.5)，
## 底中=(0.5,1)），[param size] 是控件自身尺寸。
static func grow_pivot(anchor: Vector2, size: Vector2) -> Vector2:
	return Vector2(anchor.x * size.x, anchor.y * size.y)


## 把显示安全区（刘海 / 圆角）换算成虚拟画布的四周内边距。
##
## [param safe] 是 [method DisplayServer.get_display_safe_area] 的返回值（屏幕像素），
## [param window_size] 是窗口像素尺寸，[param viewport] 是虚拟画布尺寸。
## 返回 [code]Vector4(left, top, right, bottom)[/code]；无安全区时为零向量。
static func safe_insets(safe: Rect2i, window_size: Vector2i, viewport: Vector2) -> Vector4:
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var map := Vector2(viewport.x / float(window_size.x), viewport.y / float(window_size.y))
	var left := maxf(float(safe.position.x), 0.0) * map.x
	var top := maxf(float(safe.position.y), 0.0) * map.y
	var right := maxf(float(window_size.x - safe.end.x), 0.0) * map.x
	var bottom := maxf(float(window_size.y - safe.end.y), 0.0) * map.y
	return Vector4(left, top, right, bottom)
