class_name ToolSwing
extends RefCounted
## 挥动弧线：把 0~1 的挥动进度映射成握柄的旋转角（度）。
##
## 纯函数，与 [PlayerStateUseItem] 的时长解耦——改挥动时长不用改曲线；
## [HeldToolView] 只负责把角度画出来。角度以"握柄竖直向上"为 0，
## 正负分别朝屏幕右 / 左（由朝向决定符号）。

## 起手（持械待命）。
const REST_DEG: float = 10.0
## 蓄力（向后举起）。
const WINDUP_DEG: float = -70.0
## 命中（向前下方劈出）。
const STRIKE_DEG: float = 105.0
## 蓄力结束、命中结束的进度点；与 [constant PlayerStateUseItem.IMPACT_TIME] 对齐。
const WINDUP_END: float = 0.30
const STRIKE_END: float = 0.42


## [param progress] 处的挥动角度（度）。
static func angle_deg(progress: float) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	if t < WINDUP_END:
		return lerpf(REST_DEG, WINDUP_DEG, smoothstep(0.0, WINDUP_END, t))
	if t < STRIKE_END:
		return lerpf(WINDUP_DEG, STRIKE_DEG, smoothstep(WINDUP_END, STRIKE_END, t))
	return lerpf(STRIKE_DEG, REST_DEG, smoothstep(STRIKE_END, 1.0, t))
