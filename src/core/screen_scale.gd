class_name ScreenScale
extends RefCounted
## 整数覆盖（integer cover）：把窗口按最大整数倍铺满，消掉整数缩放留下的黑边。
##
## 背景：基准 640×360 与真机 ~2.16:1 不一致，[code]aspect="expand"[/code] 只是把
## 设备黑边从 306px 缩到 97px；[code]scale_mode="integer"[/code] 会把"窗口/视口"的
## 小数倍向下取整，差额就是那条黑边。fractional 能填满，但像素比例 3.25（有的 3px、
## 有的 4px）且插值发糊，与像素风"整数倍"原则冲突。
##
## 做法：N = floor(min(宽/基准宽, 高/基准高))（至少 1），根视口 = ceil(宽/N) × ceil(高/N)。
## 绝大多数手机 / 桌面分辨率都能整除（iPhone 2532×1170 → N=3 → 844×390 正好 3×）；
## 不整除时最多裁 1~N-1 px，像素仍是 N×。
##
## 归属：这里只做纯计算，不碰场景树。"什么时候应用到 [Window]（含窗口尺寸变化）"
## 由场景壳决定——标题页与 [Main] 各自在 [code]_ready()[/code] 里应用并监听
## [signal Window.size_changed]。不新增 Autoload，也不让某个域越界持有窗口。

## 基准分辨率兜底值；正常从 project.godot 的 viewport 设置读。
const BASE_FALLBACK := Vector2i(640, 360)


## 工程里配置的基准分辨率（读不到时退回 [constant BASE_FALLBACK]）。
static func base_size() -> Vector2i:
	var width: int = int(
		ProjectSettings.get_setting("display/window/size/viewport_width", BASE_FALLBACK.x)
	)
	var height: int = int(
		ProjectSettings.get_setting("display/window/size/viewport_height", BASE_FALLBACK.y)
	)
	return Vector2i(width, height)


## 纯函数：窗口像素尺寸 → 整数覆盖下的根视口尺寸；方便脱离设备跑规范。
static func cover_size(window_size: Vector2i, base: Vector2i = BASE_FALLBACK) -> Vector2i:
	if window_size.x <= 0 or window_size.y <= 0 or base.x <= 0 or base.y <= 0:
		return BASE_FALLBACK
	var nx: int = floori(float(window_size.x) / float(base.x))
	var ny: int = floori(float(window_size.y) / float(base.y))
	var n: int = maxi(1, mini(nx, ny))
	return Vector2i(
		ceili(float(window_size.x) / float(n)), ceili(float(window_size.y) / float(n))
	)


## 把整数覆盖应用到窗口；窗口尺寸变化后要重新调用。
static func apply(window: Window) -> void:
	if window == null or window.size.x <= 0 or window.size.y <= 0:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	# 覆盖尺寸已按窗口算好；拉伸若取整会把 N× 打成 (N-1)×，必须用 fractional。
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	window.content_scale_size = cover_size(window.size, base_size())
