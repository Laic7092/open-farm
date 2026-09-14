extends SceneTree
## 音效生成器 → [code]assets/audio/sfx/*.wav[/code]
##
## 每个音效都是手写的"合成配方"：振荡器 + 噪声 + 包络，
## 没有任何采样素材。音色走芯片风，和像素画保持一致。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/audio/generate_sfx.gd
## [/codeblock]

const Synth := preload("res://tools/audio/synth.gd")
const Catalog := preload("res://src/audio/audio_catalog.gd")


func _initialize() -> void:
	var builders := {
		Catalog.SFX_UI_MOVE: _ui_move,
		Catalog.SFX_UI_CONFIRM: _ui_confirm,
		Catalog.SFX_UI_CANCEL: _ui_cancel,
		Catalog.SFX_UI_OPEN: _ui_open,
		Catalog.SFX_UI_CLOSE: _ui_close,
		Catalog.SFX_NOTIFY: _notify,
		Catalog.SFX_TOOL_SWING: _tool_swing,
		Catalog.SFX_TILL: _till,
		Catalog.SFX_WATER: _water,
		Catalog.SFX_PLANT: _plant,
		Catalog.SFX_HARVEST: _harvest,
		Catalog.SFX_CHOP: _chop,
		Catalog.SFX_COIN: _coin,
		Catalog.SFX_ITEM_GET: _item_get,
		Catalog.SFX_DIALOGUE: _dialogue,
		Catalog.SFX_ANIMAL_HAPPY: _animal_happy,
		Catalog.SFX_ANIMAL_EAT: _animal_eat,
		Catalog.SFX_MATURE: _mature,
		Catalog.SFX_SAVE: _save,
		Catalog.SFX_LOAD: _load,
		Catalog.SFX_FOOTSTEP_GRASS: _footstep_grass,
		Catalog.SFX_FOOTSTEP_PATH: _footstep_path,
		Catalog.SFX_STAMINA_DEPLETED: _stamina_depleted,
		Catalog.SFX_TRANSITION: _transition,
		Catalog.SFX_ERROR: _error,
		Catalog.SFX_MORNING: _morning,
	}

	for id: StringName in Catalog.SFX_ALL:
		var builder: Callable = builders[id]
		var buf: PackedFloat32Array = builder.call()
		Synth.dc_block(buf)
		Synth.fade_edges(buf)
		Synth.write_wav(Catalog.sfx_path(id), buf, false)

	print("音效生成完成 → ", Catalog.SFX_DIR)
	quit()


# ---------------------------------------------------------------- UI

## 光标移动：一声干脆的木鱼。
func _ui_move() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.07)
	Synth.tone(buf, 0.0, 0.05, 932.0, 0.5, Synth.Wave.PULSE, 0.001, 0.025, 0.25, 26.0)
	Synth.normalize(buf, 0.5)
	return buf


## 确认：上行的两连音。
func _ui_confirm() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.18)
	Synth.tone(buf, 0.0, 0.07, 659.0, 0.5, Synth.Wave.TRIANGLE, 0.002, 0.03)
	Synth.tone(buf, 0.06, 0.11, 988.0, 0.5, Synth.Wave.TRIANGLE, 0.002, 0.05)
	Synth.normalize(buf, 0.6)
	return buf


## 取消：下行的两连音。
func _ui_cancel() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.18)
	Synth.tone(buf, 0.0, 0.07, 523.0, 0.5, Synth.Wave.TRIANGLE, 0.002, 0.03)
	Synth.tone(buf, 0.06, 0.11, 349.0, 0.5, Synth.Wave.TRIANGLE, 0.002, 0.05)
	Synth.normalize(buf, 0.6)
	return buf


## 打开面板：向上滑音。
func _ui_open() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.2)
	Synth.sweep(buf, 0.0, 0.16, 280.0, 920.0, 0.5, Synth.Wave.SINE, 0.004, 0.06)
	Synth.tone(buf, 0.12, 0.06, 1244.0, 0.18, Synth.Wave.SINE, 0.002, 0.03)
	Synth.normalize(buf, 0.6)
	return buf


## 关闭面板：向下滑音。
func _ui_close() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.2)
	Synth.sweep(buf, 0.0, 0.16, 920.0, 280.0, 0.5, Synth.Wave.SINE, 0.004, 0.06)
	Synth.normalize(buf, 0.6)
	return buf


## 通知：清脆的两声铃。
func _notify() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.4)
	Synth.tone(buf, 0.0, 0.18, 1047.0, 0.5, Synth.Wave.SINE, 0.002, 0.1)
	Synth.tone(buf, 0.0, 0.18, 2093.0, 0.12, Synth.Wave.SINE, 0.002, 0.1)
	Synth.tone(buf, 0.09, 0.26, 1319.0, 0.5, Synth.Wave.SINE, 0.002, 0.18)
	Synth.normalize(buf, 0.7)
	return buf


# ---------------------------------------------------------------- 农活

## 挥动工具：一阵短促的风声。
func _tool_swing() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.18)
	Synth.noise_burst(buf, 0.0, 0.15, 1.0, 16.0, 101, 3200.0, 0.02, 0.04)
	Synth.sweep(buf, 0.0, 0.13, 520.0, 190.0, 0.18, Synth.Wave.SINE, 0.01, 0.05)
	Synth.normalize(buf, 0.7)
	return buf


## 翻地：闷响 + 土块碎裂。
func _till() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.26)
	Synth.noise_burst(buf, 0.0, 0.18, 1.0, 14.0, 7, 900.0, 0.001, 0.05)
	Synth.tone(buf, 0.0, 0.16, 92.0, 0.6, Synth.Wave.SINE, 0.002, 0.06, 0.5, 16.0)
	Synth.normalize(buf, 0.85)
	return buf


## 浇水：水花 + 几滴回落。
func _water() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.36)
	Synth.noise_burst(buf, 0.0, 0.28, 1.0, 7.0, 313, 2600.0, 0.004, 0.08)
	Synth.sweep(buf, 0.1, 0.08, 900.0, 1500.0, 0.22, Synth.Wave.SINE, 0.002, 0.03)
	Synth.sweep(buf, 0.2, 0.08, 1200.0, 700.0, 0.18, Synth.Wave.SINE, 0.002, 0.03)
	Synth.normalize(buf, 0.72)
	return buf


## 播种：轻点入土。
func _plant() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.16)
	Synth.tone(buf, 0.0, 0.08, 587.0, 0.4, Synth.Wave.SINE, 0.002, 0.03)
	Synth.noise_burst(buf, 0.02, 0.09, 0.5, 30.0, 19, 1500.0)
	Synth.normalize(buf, 0.6)
	return buf


## 收获：上行的采摘音 + 一声脆响。
func _harvest() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.28)
	Synth.tone(buf, 0.0, 0.09, 784.0, 0.45, Synth.Wave.TRIANGLE, 0.002, 0.04)
	Synth.tone(buf, 0.07, 0.16, 1175.0, 0.45, Synth.Wave.TRIANGLE, 0.002, 0.08)
	Synth.noise_burst(buf, 0.0, 0.05, 0.4, 40.0, 71, 5000.0)
	Synth.normalize(buf, 0.72)
	return buf


## 清除植被：木头 / 石头断裂。
func _chop() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.3)
	Synth.noise_burst(buf, 0.0, 0.12, 1.0, 26.0, 211, 6000.0, 0.001, 0.04)
	Synth.tone(buf, 0.0, 0.1, 196.0, 0.5, Synth.Wave.TRIANGLE, 0.001, 0.04, 0.5, 20.0)
	Synth.tone(buf, 0.0, 0.2, 73.0, 0.5, Synth.Wave.SINE, 0.002, 0.08, 0.5, 12.0)
	Synth.normalize(buf, 0.85)
	return buf


# ---------------------------------------------------------------- 经济 / 物品

## 金币：三连高音。
func _coin() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.34)
	var notes := [1319.0, 1760.0, 2093.0]
	for i in notes.size():
		Synth.tone(buf, float(i) * 0.06, 0.12, notes[i], 0.45, Synth.Wave.SQUARE, 0.001, 0.05, 0.5, 12.0)
	Synth.normalize(buf, 0.68)
	return buf


## 拾取物品：上行琶音。
func _item_get() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.42)
	var notes := [659.0, 880.0, 1047.0, 1319.0]
	for i in notes.size():
		Synth.tone(buf, float(i) * 0.07, 0.16, notes[i], 0.4, Synth.Wave.PULSE, 0.002, 0.08, 0.35, 6.0)
	Synth.normalize(buf, 0.7)
	return buf


# ---------------------------------------------------------------- 交互 / 动物

## 对话推进：极短的一声"嘟"。
func _dialogue() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.06)
	Synth.tone(buf, 0.0, 0.04, 720.0, 0.4, Synth.Wave.PULSE, 0.001, 0.02, 0.25, 30.0)
	Synth.normalize(buf, 0.45)
	return buf


## 牲畜开心：两声上扬的啾鸣。
func _animal_happy() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.26)
	Synth.sweep(buf, 0.0, 0.08, 620.0, 900.0, 0.45, Synth.Wave.TRIANGLE, 0.003, 0.03)
	Synth.sweep(buf, 0.1, 0.12, 760.0, 1080.0, 0.45, Synth.Wave.TRIANGLE, 0.003, 0.05)
	Synth.normalize(buf, 0.62)
	return buf


## 牲畜进食：咀嚼声。
func _animal_eat() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.22)
	Synth.noise_burst(buf, 0.0, 0.18, 1.0, 18.0, 401, 850.0, 0.004, 0.05)
	Synth.tone(buf, 0.0, 0.1, 130.0, 0.4, Synth.Wave.TRIANGLE, 0.003, 0.05, 0.5, 14.0)
	Synth.normalize(buf, 0.6)
	return buf


## 牲畜成年：闪亮的琶音。
func _mature() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.5)
	var notes := [784.0, 988.0, 1175.0, 1568.0]
	for i in notes.size():
		Synth.tone(buf, float(i) * 0.08, 0.22, notes[i], 0.4, Synth.Wave.SINE, 0.002, 0.1)
	Synth.normalize(buf, 0.78)
	return buf


# ---------------------------------------------------------------- 存档

## 保存成功：温暖的和弦。
func _save() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.42)
	Synth.tone(buf, 0.0, 0.3, 523.0, 0.4, Synth.Wave.TRIANGLE, 0.004, 0.14)
	Synth.tone(buf, 0.02, 0.3, 784.0, 0.35, Synth.Wave.TRIANGLE, 0.004, 0.14)
	Synth.tone(buf, 0.04, 0.3, 1047.0, 0.3, Synth.Wave.SINE, 0.004, 0.14)
	Synth.normalize(buf, 0.7)
	return buf


## 读取成功：先下后上的提示音。
func _load() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.42)
	Synth.tone(buf, 0.0, 0.12, 659.0, 0.4, Synth.Wave.SINE, 0.003, 0.05)
	Synth.tone(buf, 0.1, 0.3, 880.0, 0.42, Synth.Wave.SINE, 0.003, 0.14)
	Synth.normalize(buf, 0.7)
	return buf


# ---------------------------------------------------------------- 移动 / 系统

## 草地脚步：柔和的沙沙声。
func _footstep_grass() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.1)
	Synth.noise_burst(buf, 0.0, 0.08, 1.0, 55.0, 601, 1700.0, 0.003, 0.03)
	Synth.tone(buf, 0.0, 0.05, 120.0, 0.2, Synth.Wave.SINE, 0.002, 0.02, 0.5, 30.0)
	Synth.normalize(buf, 0.5)
	return buf


## 石板 / 路面脚步：更干脆的"嗒"。
func _footstep_path() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.08)
	Synth.noise_burst(buf, 0.0, 0.05, 1.0, 90.0, 613, 5200.0, 0.001, 0.02)
	Synth.tone(buf, 0.0, 0.04, 230.0, 0.3, Synth.Wave.TRIANGLE, 0.001, 0.02, 0.5, 40.0)
	Synth.normalize(buf, 0.5)
	return buf


## 体力耗尽：一路下滑的疲惫音。
func _stamina_depleted() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.7)
	Synth.sweep(buf, 0.0, 0.65, 440.0, 110.0, 0.5, Synth.Wave.TRIANGLE, 0.006, 0.2)
	Synth.tone(buf, 0.0, 0.3, 220.0, 0.2, Synth.Wave.SINE, 0.006, 0.15)
	Synth.normalize(buf, 0.7)
	return buf


## 场景切换：风声式的过场。
func _transition() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.32)
	Synth.noise_burst(buf, 0.0, 0.28, 1.0, 6.0, 701, 2200.0, 0.03, 0.1)
	Synth.sweep(buf, 0.0, 0.26, 1500.0, 180.0, 0.3, Synth.Wave.SINE, 0.02, 0.1)
	Synth.normalize(buf, 0.65)
	return buf


## 操作失败：低沉的"不行"。
func _error() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.24)
	Synth.tone(buf, 0.0, 0.1, 165.0, 0.5, Synth.Wave.SQUARE, 0.003, 0.04, 0.5, 10.0)
	Synth.tone(buf, 0.11, 0.11, 139.0, 0.5, Synth.Wave.SQUARE, 0.003, 0.05, 0.5, 10.0)
	Synth.normalize(buf, 0.68)
	return buf


## 清晨 / 新的一天：一声鸡鸣。
func _morning() -> PackedFloat32Array:
	var buf := Synth.new_buffer(0.85)
	Synth.sweep(buf, 0.0, 0.12, 700.0, 1050.0, 0.5, Synth.Wave.SAW, 0.004, 0.03)
	Synth.sweep(buf, 0.12, 0.18, 1050.0, 620.0, 0.5, Synth.Wave.SAW, 0.004, 0.05)
	Synth.sweep(buf, 0.32, 0.3, 620.0, 980.0, 0.5, Synth.Wave.SAW, 0.006, 0.12)
	Synth.tone(buf, 0.0, 0.6, 350.0, 0.18, Synth.Wave.SQUARE, 0.01, 0.2, 0.5, 3.0)
	Synth.noise_burst(buf, 0.0, 0.5, 0.12, 4.0, 811, 3000.0, 0.02, 0.2)
	Synth.normalize(buf, 0.88)
	return buf
