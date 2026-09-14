class_name Crop
extends Sprite2D
## 田里一株作物的可视化节点。
##
## 只是 [CropState] 的"视图"：自己不保存任何游戏状态，
## 由 [FarmGrid] 在状态变化后调用 [method refresh] 同步画面。

## 精灵图集中枯死形态的帧号（最后一帧）。
const WITHERED_FRAME: int = 4

var state: CropState
var data: CropData


## 绑定数据并立即刷新画面。
func setup(p_state: CropState, p_data: CropData) -> void:
	state = p_state
	data = p_data
	refresh()


## 按当前状态更新帧号。
func refresh() -> void:
	if state == null or data == null:
		return
	frame = WITHERED_FRAME if state.dead else clampi(
		CropGrowth.stage_of(data, state.days_grown), 0, WITHERED_FRAME - 1
	)
	modulate = Color(1, 1, 1, 1)


## 收获时的小反馈：弹一下再消失（节点之后会被 FarmGrid 释放）。
func play_harvest_feedback() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.06)
