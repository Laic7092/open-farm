extends SceneTree
## BGM 生成器 → [code]assets/audio/bgm/*.wav[/code]
##
## 每首曲子都是"和弦进行 + 贝斯 + 旋律 + 鼓组"的手写配方，
## 固定 BPM、固定拍数，渲染后把超出的尾音绕回开头（[method _close_loop]），
## 于是首尾相接听不出接缝。
##
## 用法：
## [codeblock]
## godot --headless --path . -s res://tools/audio/generate_bgm.gd
## [/codeblock]

const Synth := preload("res://tools/audio/synth.gd")
const Catalog := preload("res://src/audio/audio_catalog.gd")

## 渲染时多留的尾巴（秒），之后会被绕回开头。
const TAIL: float = 1.2


func _initialize() -> void:
	Synth.write_wav(Catalog.bgm_path(Catalog.BGM_TITLE), _title(), true)
	Synth.write_wav(Catalog.bgm_path(Catalog.BGM_FARM), _farm(), true)
	Synth.write_wav(Catalog.bgm_path(Catalog.BGM_TOWN), _town(), true)
	Synth.write_wav(Catalog.bgm_path(Catalog.BGM_NIGHT), _night(), true)
	Synth.write_wav(Catalog.bgm_path(Catalog.BGM_FISHING), _fishing(), true)
	print("BGM 生成完成 → ", Catalog.BGM_DIR)
	quit()


# ---------------------------------------------------------------- 曲目

## 标题页：C 大调，84 BPM，I–V–vi–IV，安静而明亮。
func _title() -> PackedFloat32Array:
	var bpm := 84.0
	var beats := 32
	var beat := 60.0 / bpm
	var buf := _start(beat, beats)

	var chords := [
		[60.0, 64.0, 67.0],  # C
		[55.0, 59.0, 62.0],  # G
		[57.0, 60.0, 64.0],  # Am
		[53.0, 57.0, 60.0],  # F
	]
	Synth.chord_sequence(buf, 0.0, beat, chords, 8.0, Synth.Wave.TRIANGLE, 0.10, 0.05, 0.4)
	# 低音：每和弦一个长音。
	Synth.melody(
		buf, 0.0, beat,
		[[36.0, 8.0], [43.0, 8.0], [45.0, 8.0], [41.0, 8.0]],
		Synth.Wave.SINE, 0.30, 0.01, 0.25
	)
	# 琶音铺底：每个和弦 16 个八分音符来回。
	for i in chords.size():
		_arp_eighths(buf, float(i) * 8.0 * beat, beat, chords[i], 8.0, Synth.Wave.SINE, 0.075)
	# 主旋律。
	Synth.melody(
		buf, 0.0, beat,
		[
			[72.0, 1.0], [74.0, 1.0], [76.0, 1.0], [79.0, 1.0],
			[76.0, 2.0], [74.0, 2.0],
			[72.0, 1.0], [71.0, 1.0], [72.0, 1.0], [76.0, 1.0],
			[74.0, 4.0],
			[69.0, 1.0], [72.0, 1.0], [74.0, 1.0], [77.0, 1.0],
			[76.0, 2.0], [74.0, 2.0],
			[72.0, 2.0], [71.0, 2.0],
			[72.0, 4.0],
		],
		Synth.Wave.PULSE, 0.20, 0.006, 0.12, 0.3
	)
	# 每小节的 2、4 拍来一点沙锤。
	_shaker_beats(buf, beat, beats, 2.0, 0.10)
	return _finish(buf, beat, beats)


## 农场白天：F 大调，132 BPM，I–IV–V–I，轻快有鼓。
func _farm() -> PackedFloat32Array:
	var bpm := 132.0
	var beats := 32
	var beat := 60.0 / bpm
	var buf := _start(beat, beats)

	var chords := [
		[65.0, 69.0, 72.0],  # F
		[70.0, 74.0, 77.0],  # Bb
		[67.0, 71.0, 74.0],  # C
		[65.0, 69.0, 72.0],  # F
	]
	Synth.chord_sequence(buf, 0.0, beat, chords, 8.0, Synth.Wave.TRIANGLE, 0.09, 0.02, 0.2)
	# 低音：根音—五音的八分音符跳动。
	var roots := [41.0, 46.0, 43.0, 41.0]
	var fifths := [48.0, 53.0, 50.0, 48.0]
	for i in roots.size():
		_bass_eighths(buf, float(i) * 8.0 * beat, beat, roots[i], fifths[i], 8.0)
	# 旋律。
	Synth.melody(
		buf, 0.0, beat,
		[
			[77.0, 1.0], [79.0, 1.0], [81.0, 1.0], [79.0, 1.0],
			[77.0, 2.0], [74.0, 2.0],
			[72.0, 1.0], [74.0, 1.0], [77.0, 1.0], [79.0, 1.0],
			[81.0, 2.0], [79.0, 2.0],
			[77.0, 1.0], [74.0, 1.0], [72.0, 1.0], [74.0, 1.0],
			[77.0, 2.0], [81.0, 2.0],
			[79.0, 1.0], [77.0, 1.0], [74.0, 1.0], [72.0, 1.0],
			[74.0, 2.0], [72.0, 2.0],
		],
		Synth.Wave.PULSE, 0.22, 0.004, 0.06, 0.4
	)
	# 鼓：底鼓 1/3 拍，军鼓 2/4 拍，八分踩镲。
	_drums(buf, beat, ["k.h.s.h.", "k.h.s.h.", "k.hks.h.", "k.h.s.hh"])
	return _finish(buf, beat, beats)


## 小镇白天：D 大调，150 BPM，跳跃热闹。
func _town() -> PackedFloat32Array:
	var bpm := 150.0
	var beats := 32
	var beat := 60.0 / bpm
	var buf := _start(beat, beats)

	var chords := [
		[62.0, 66.0, 69.0],  # D
		[57.0, 61.0, 64.0],  # A
		[59.0, 62.0, 66.0],  # Bm
		[55.0, 59.0, 62.0],  # G
	]
	Synth.chord_sequence(buf, 0.0, beat, chords, 8.0, Synth.Wave.SQUARE, 0.07, 0.01, 0.12)
	Synth.melody(
		buf, 0.0, beat,
		[[38.0, 8.0], [33.0, 8.0], [35.0, 8.0], [31.0, 8.0]],
		Synth.Wave.TRIANGLE, 0.34, 0.008, 0.1
	)
	for i in chords.size():
		_arp_eighths(buf, float(i) * 8.0 * beat, beat, chords[i], 8.0, Synth.Wave.PULSE, 0.07)
	Synth.melody(
		buf, 0.0, beat,
		[
			[74.0, 1.0], [76.0, 1.0], [78.0, 1.0], [74.0, 1.0],
			[76.0, 2.0], [73.0, 2.0],
			[74.0, 1.0], [76.0, 1.0], [78.0, 1.0], [81.0, 1.0],
			[78.0, 2.0], [76.0, 2.0],
			[74.0, 1.0], [71.0, 1.0], [74.0, 1.0], [78.0, 1.0],
			[76.0, 2.0], [74.0, 2.0],
			[73.0, 1.0], [74.0, 1.0], [76.0, 1.0], [78.0, 1.0],
			[74.0, 2.0], [71.0, 2.0],
		],
		Synth.Wave.PULSE, 0.20, 0.004, 0.05, 0.5
	)
	_drums(buf, beat, ["k.h.s.h.", "k.h.s.h.", "k.hks.h.", "k.h.s.H."])
	return _finish(buf, beat, beats)


## 夜晚：A 小调，72 BPM，稀疏安静的琶音。
func _night() -> PackedFloat32Array:
	var bpm := 72.0
	var beats := 32
	var beat := 60.0 / bpm
	var buf := _start(beat, beats)

	var chords := [
		[57.0, 60.0, 64.0],  # Am
		[53.0, 57.0, 60.0],  # F
		[55.0, 59.0, 62.0],  # G
		[57.0, 60.0, 64.0],  # Am
	]
	Synth.chord_sequence(buf, 0.0, beat, chords, 8.0, Synth.Wave.SINE, 0.11, 0.08, 0.5)
	Synth.melody(
		buf, 0.0, beat,
		[[33.0, 8.0], [29.0, 8.0], [31.0, 8.0], [33.0, 8.0]],
		Synth.Wave.SINE, 0.32, 0.02, 0.4
	)
	# 缓慢的琶音，每个和弦 8 个四分音符。
	for i in chords.size():
		_arp_beats(buf, float(i) * 8.0 * beat, beat, chords[i], 8.0, Synth.Wave.SINE, 0.09, 1.0)
	# 一条若隐若现的旋律。
	Synth.melody(
		buf, 0.0, beat,
		[
			[69.0, 2.0], [72.0, 1.0], [76.0, 1.0],
			[74.0, 4.0],
			[72.0, 2.0], [69.0, 1.0], [67.0, 1.0],
			[69.0, 4.0],
			[71.0, 2.0], [74.0, 1.0], [79.0, 1.0],
			[76.0, 4.0],
			[72.0, 2.0], [69.0, 2.0],
			[69.0, 4.0],
		],
		Synth.Wave.TRIANGLE, 0.16, 0.02, 0.3
	)
	# 一点夜色虫鸣。
	_shaker_beats(buf, beat, beats, 4.0, 0.05)
	return _finish(buf, beat, beats)


## 钓鱼：G 大调，68 BPM，I–vi–IV–V，无鼓、只有水波似的琶音。
##
## 抛竿后接管世界曲目（见 [BgmPlayer] 的钓鱼 BGM 覆盖），
## 所以它比自己单独听时要更安静、少打击，避免拉锯时抢注意力。
func _fishing() -> PackedFloat32Array:
	var bpm := 68.0
	var beats := 32
	var beat := 60.0 / bpm
	var buf := _start(beat, beats)

	var chords := [
		[55.0, 59.0, 62.0],  # G
		[52.0, 55.0, 59.0],  # Em
		[48.0, 52.0, 55.0],  # C
		[50.0, 54.0, 57.0],  # D
	]
	Synth.chord_sequence(buf, 0.0, beat, chords, 8.0, Synth.Wave.TRIANGLE, 0.085, 0.06, 0.5)
	Synth.melody(
		buf, 0.0, beat,
		[[31.0, 8.0], [28.0, 8.0], [24.0, 8.0], [26.0, 8.0]],
		Synth.Wave.SINE, 0.30, 0.02, 0.35
	)
	# 缓慢琶音：每个和弦 8 个四分音符，像一圈圈散开的水纹。
	for i in chords.size():
		_arp_beats(buf, float(i) * 8.0 * beat, beat, chords[i], 8.0, Synth.Wave.SINE, 0.075, 1.0)
	# 若隐若现的高音旋律。
	Synth.melody(
		buf, 0.0, beat,
		[
			[74.0, 2.0], [78.0, 1.0], [81.0, 1.0],
			[79.0, 4.0],
			[76.0, 2.0], [74.0, 1.0], [71.0, 1.0],
			[74.0, 4.0],
			[72.0, 2.0], [76.0, 1.0], [79.0, 1.0],
			[78.0, 4.0],
			[74.0, 2.0], [71.0, 2.0],
			[74.0, 4.0],
		],
		Synth.Wave.TRIANGLE, 0.15, 0.03, 0.3
	)
	# 只留极稀的沙锤当水声。
	_shaker_beats(buf, beat, beats, 4.0, 0.04)
	return _finish(buf, beat, beats)


# ---------------------------------------------------------------- 编排辅助

## 建一段"正式长度 + 尾巴"的缓冲，返回时超出尾部的采样会被绕回开头。
func _start(beat_sec: float, beats: int) -> PackedFloat32Array:
	return Synth.new_buffer(float(beats) * beat_sec + TAIL)


## 把尾巴绕回开头并截成正好一整圈，再缝合接缝。
func _finish(buf: PackedFloat32Array, beat_sec: float, beats: int) -> PackedFloat32Array:
	var loop_samples := int(round(float(beats) * beat_sec * float(Synth.SR)))
	var extra := maxi(0, buf.size() - loop_samples)
	for i in extra:
		var tail: int = loop_samples + i
		if tail < buf.size():
			buf[i] += buf[tail]
	buf.resize(loop_samples)
	Synth.dc_block(buf)
	Synth.normalize(buf, 0.9)
	Synth.soft_clip(buf)
	Synth.seal_loop(buf, 0.012)
	return buf


## 低音八分音符：根音与五音交替。
func _bass_eighths(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	root: float,
	fifth: float,
	beats: float
) -> void:
	var eighth := beat_sec * 0.5
	var count := int(round(beats * 2.0))
	for i in count:
		var note := root if (i % 2) == 0 else fifth
		Synth.tone(
			buf, start_sec + float(i) * eighth, eighth * 0.85,
			Synth.midi_to_hz(note), 0.30, Synth.Wave.TRIANGLE, 0.004, 0.05
		)


## 和弦琶音：八分音符为单位，在和弦音之间上下往返。
func _arp_eighths(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	chord: Array,
	beats: float,
	wave: int,
	amp: float
) -> void:
	_arp_beats(buf, start_sec, beat_sec, chord, beats, wave, amp, 0.5)


## 和弦琶音：以 [param step_beats] 拍为一个音，在和弦音之间往返。
func _arp_beats(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	chord: Array,
	beats: float,
	wave: int,
	amp: float,
	step_beats: float
) -> void:
	var steps := int(round(beats / step_beats))
	var count := chord.size()
	for i in steps:
		var idx := i % (count * 2)
		var note: float = chord[idx] if idx < count else chord[count * 2 - 1 - idx]
		var start := start_sec + float(i) * step_beats * beat_sec
		Synth.tone(
			buf, start, step_beats * beat_sec * 0.9,
			Synth.midi_to_hz(note), amp, wave, 0.006, 0.1
		)


## 每 [param step_beats] 拍来一下沙锤。
func _shaker_beats(
	buf: PackedFloat32Array, beat_sec: float, beats: int, step_beats: float, amp: float
) -> void:
	var t := 0.0
	while t < float(beats):
		Synth.shaker(buf, t * beat_sec, amp)
		t += step_beats


## 按 8 分音符图案铺鼓。每小节 8 个字符：k 底鼓、s 军鼓、h 踩镲、x 沙锤、. 空。
func _drums(buf: PackedFloat32Array, beat_sec: float, patterns: Array) -> void:
	var eighth := beat_sec * 0.5
	for bar in patterns.size():
		var pattern: String = patterns[bar]
		for i in pattern.length():
			var t := (float(bar) * 4.0 + float(i) * 0.5) * beat_sec
			match pattern[i]:
				"k":
					Synth.kick(buf, t, 0.85)
				"s":
					Synth.snare(buf, t, 0.45)
				"h":
					Synth.hat(buf, t, 0.14)
				"H":
					Synth.hat(buf, t, 0.22)
				"x":
					Synth.shaker(buf, t, 0.12)
