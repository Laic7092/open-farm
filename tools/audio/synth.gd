extends RefCounted
## 音频合成基座：生成器用它把音符、噪点与包络拼成采样缓冲，再落盘成 WAV。
##
## [b]为什么音频也由代码生成[/b]：和美术同样的理由（见 [code]AGENTS.md[/code]）——
## 仓库里不放来源不明、无法审查、无法微调的二进制音频；改一个音符或音色就是改一行代码。
##
## [b]确定性[/b]：所有噪声都来自 [method noise_at] 的位置哈希，而不是 [RandomNumberGenerator]。
## 同样的脚本跑两次，WAV 逐采样相同，[code]git status[/code] 干净。
##
## 输出格式固定为 [constant AudioCatalog.SAMPLE_RATE] Hz / 16 bit / 单声道 PCM。

const Catalog := preload("res://src/audio/audio_catalog.gd")

## 采样率（Hz）。
const SR: int = Catalog.SAMPLE_RATE

## 可用波形。[code]NOISE[/code] 不是相位的函数，单独走 [method noise_at]。
enum Wave { SINE, SQUARE, PULSE, TRIANGLE, SAW, NOISE }

## 低通滤波里"几乎不滤波"的截止频率。
const OPEN_CLIP: float = 20000.0


# ---------------------------------------------------------------- 基础换算

## 秒 → 采样数（至少 1）。
static func seconds_to_samples(seconds: float) -> int:
	return maxi(1, int(round(seconds * float(SR))))


## 新建一段静音缓冲。
static func new_buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(seconds_to_samples(seconds))
	return buf


## 保证缓冲至少有这么多个采样（不够就补零）。
static func ensure_size(buf: PackedFloat32Array, samples: int) -> void:
	if buf.size() < samples:
		buf.resize(samples)


## MIDI 音高 → 频率（A4 = 69 = 440 Hz）。
static func midi_to_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## 确定性白噪：返回 -1.0 ~ 1.0。用位置哈希而不是 RNG，保证可复现。
static func noise_at(index: int, salt: int = 0) -> float:
	var h: int = (index * 374761393 + salt * 668265263) & 0xFFFFFFFF
	h = (((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF)
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h % 200001) / 100000.0 - 1.0


# ---------------------------------------------------------------- 波形与包络

## 取某个波形在 [param phase]（0 ~ 1）处的值。
static func wave_value(wave: int, phase: float, duty: float) -> float:
	match wave:
		Wave.SINE:
			return sin(TAU * phase)
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.PULSE:
			return 1.0 if phase < duty else -1.0
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
	return 0.0


## 极简 AR（可选指数衰减）包络。
## [param decay] 大于 0 时叠加 [code]exp(-decay * t)[/code]，用来做打击乐的"啪"。
static func envelope(
	t: float, duration: float, attack: float, release: float, decay: float
) -> float:
	var value := 1.0
	if attack > 0.0:
		value *= clampf(t / attack, 0.0, 1.0)
	if release > 0.0:
		value *= clampf((duration - t) / release, 0.0, 1.0)
	if decay > 0.0:
		value *= exp(-decay * t)
	return value


# ---------------------------------------------------------------- 单音 / 滑音

## 往缓冲里叠加一个音。
static func tone(
	buf: PackedFloat32Array,
	start_sec: float,
	dur_sec: float,
	freq: float,
	amp: float,
	wave: int,
	attack: float = 0.004,
	release: float = 0.02,
	duty: float = 0.5,
	decay: float = 0.0,
	salt: int = 0
) -> void:
	var start := seconds_to_samples(start_sec)
	var count := seconds_to_samples(dur_sec)
	ensure_size(buf, start + count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(SR)
		phase = fmod(phase + freq / float(SR), 1.0)
		var sample := 0.0
		if wave == Wave.NOISE:
			sample = noise_at(start + i, salt)
		else:
			sample = wave_value(wave, phase, duty)
		buf[start + i] += sample * amp * envelope(t, dur_sec, attack, release, decay)


## 频率从 [param freq0] 滑到 [param freq1] 的音（线性）。
static func sweep(
	buf: PackedFloat32Array,
	start_sec: float,
	dur_sec: float,
	freq0: float,
	freq1: float,
	amp: float,
	wave: int,
	attack: float = 0.004,
	release: float = 0.02,
	duty: float = 0.5,
	decay: float = 0.0
) -> void:
	var start := seconds_to_samples(start_sec)
	var count := seconds_to_samples(dur_sec)
	ensure_size(buf, start + count)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var freq := lerpf(freq0, freq1, u)
		var t := float(i) / float(SR)
		phase = fmod(phase + freq / float(SR), 1.0)
		buf[start + i] += wave_value(wave, phase, duty) * amp * envelope(t, dur_sec, attack, release, decay)


# ---------------------------------------------------------------- 噪声

## 噪声爆发。[param cutoff] 小于 [constant OPEN_CLIP] 时做一阶低通（越低的越"闷"）。
static func noise_burst(
	buf: PackedFloat32Array,
	start_sec: float,
	dur_sec: float,
	amp: float,
	decay: float = 0.0,
	salt: int = 0,
	cutoff: float = OPEN_CLIP,
	attack: float = 0.001,
	release: float = 0.01
) -> void:
	var start := seconds_to_samples(start_sec)
	var count := seconds_to_samples(dur_sec)
	ensure_size(buf, start + count)
	var alpha := 1.0
	if cutoff < OPEN_CLIP:
		alpha = clampf(1.0 - exp(-TAU * cutoff / float(SR)), 0.0, 1.0)
	var low := 0.0
	for i in count:
		var raw := noise_at(start + i, salt)
		low += alpha * (raw - low)
		var t := float(i) / float(SR)
		buf[start + i] += low * amp * envelope(t, dur_sec, attack, release, decay)


# ---------------------------------------------------------------- 打击乐

## 底鼓：低频正弦音高下坠 + 一点瞬态噪声。
static func kick(buf: PackedFloat32Array, start_sec: float, amp: float = 0.9) -> void:
	var dur := 0.18
	sweep(buf, start_sec, dur, 130.0, 42.0, amp, Wave.SINE, 0.002, 0.08, 0.5, 9.0)
	noise_burst(buf, start_sec, 0.02, amp * 0.25, 40.0, 11, 4000.0)


## 军鼓：中频噪声 + 一点鼓皮音。
static func snare(buf: PackedFloat32Array, start_sec: float, amp: float = 0.5) -> void:
	noise_burst(buf, start_sec, 0.16, amp, 16.0, 23, 7000.0)
	tone(buf, start_sec, 0.09, 190.0, amp * 0.4, Wave.TRIANGLE, 0.001, 0.03, 0.5, 22.0)


## 踩镲：短促的高频噪声。
static func hat(buf: PackedFloat32Array, start_sec: float, amp: float = 0.18) -> void:
	noise_burst(buf, start_sec, 0.05, amp, 55.0, 37, OPEN_CLIP)


## 沙锤 / 铺底碎拍。
static func shaker(buf: PackedFloat32Array, start_sec: float, amp: float = 0.14) -> void:
	noise_burst(buf, start_sec, 0.07, amp, 30.0, 53, 9000.0)


# ---------------------------------------------------------------- 序列

## 顺序播放一段旋律。[param steps] 每项为 [code][midi, beats][/code]，midi < 0 表示休止。
## 返回整段结束时刻（秒），方便接着排下一声部。
static func melody(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	steps: Array,
	wave: int,
	amp: float,
	attack: float = 0.004,
	release: float = 0.03,
	duty: float = 0.5,
	decay: float = 0.0,
	salt: int = 0
) -> float:
	var t := start_sec
	for step: Array in steps:
		var midi: float = float(step[0])
		var beats: float = float(step[1])
		var dur: float = beats * beat_sec
		if midi >= 0.0:
			tone(buf, t, dur * 0.92, midi_to_hz(midi), amp, wave, attack, release, duty, decay, salt)
		t += dur
	return t


## 播放一串和弦（每项是一个 midi 数组），每个和弦持续 [param beats] 拍。
static func chord_sequence(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	chords: Array,
	beats: float,
	wave: int,
	amp: float,
	attack: float = 0.01,
	release: float = 0.08,
	duty: float = 0.5,
	decay: float = 0.0,
	salt: int = 0
) -> float:
	var t := start_sec
	var dur := beats * beat_sec
	for chord: Array in chords:
		for note: float in chord:
			tone(buf, t, dur * 0.95, midi_to_hz(note), amp, wave, attack, release, duty, decay, salt)
		t += dur
	return t


## 把一串和弦拆成琶音（上行 / 下行 / 上下行）。
static func arpeggio(
	buf: PackedFloat32Array,
	start_sec: float,
	beat_sec: float,
	chords: Array,
	step_beats: float,
	wave: int,
	amp: float,
	attack: float = 0.004,
	release: float = 0.05,
	duty: float = 0.5,
	decay: float = 0.0,
	direction: int = 0
) -> float:
	var t := start_sec
	for chord: Array in chords:
		var notes: Array = chord.duplicate()
		if direction < 0:
			notes.reverse()
		elif direction == 0:
			var down: Array = notes.slice(1, notes.size() - 1)
			down.reverse()
			notes.append_array(down)
		for note: float in notes:
			tone(buf, t, step_beats * beat_sec * 0.9, midi_to_hz(note), amp, wave, attack, release, duty, decay)
			t += step_beats * beat_sec
	return t


# ---------------------------------------------------------------- 处理

## 整体缩放。
static func gain(buf: PackedFloat32Array, factor: float) -> void:
	for i in buf.size():
		buf[i] *= factor


## 峰值归一到 [param peak]（静音缓冲原样返回）。
static func normalize(buf: PackedFloat32Array, peak: float = 0.92) -> void:
	var loudest := 0.0
	for i in buf.size():
		loudest = maxf(loudest, absf(buf[i]))
	if loudest <= 0.0001:
		return
	var factor := peak / loudest
	gain(buf, factor)


## 一阶高通（去直流）。方波 / 脉冲不对称时会有不为零的均值，
## 叠加久了会吃掉动态余量、在接缝处"咚"一下，所以混完先去掉直流。
static func dc_block(buf: PackedFloat32Array, cutoff: float = 20.0) -> void:
	var alpha := clampf(1.0 - exp(-TAU * cutoff / float(SR)), 0.0, 1.0)
	var previous_input := 0.0
	var previous_output := 0.0
	for i in buf.size():
		var sample := buf[i]
		var filtered := sample - previous_input + (1.0 - alpha) * previous_output
		previous_input = sample
		previous_output = filtered
		buf[i] = filtered


## 软削波：把过冲压回去，而不是硬截断出"呲"声。
static func soft_clip(buf: PackedFloat32Array) -> void:
	for i in buf.size():
		buf[i] = tanh(buf[i] * 1.2) * 0.9


## 给首尾各加一小段淡入淡出，消除起止爆音。BGM 请谨慎使用（会在接缝留一个极短的下陷）。
static func fade_edges(buf: PackedFloat32Array, fade_sec: float = 0.004) -> void:
	var count := mini(seconds_to_samples(fade_sec), buf.size() / 2)
	for i in count:
		var factor := float(i) / float(count)
		buf[i] *= factor
		buf[buf.size() - 1 - i] *= factor


## 给 BGM 的循环接缝做淡化：结尾与开头各淡一点，接缝处不会"啪"。
static func seal_loop(buf: PackedFloat32Array, fade_sec: float = 0.012) -> void:
	var count := mini(seconds_to_samples(fade_sec), buf.size() / 2)
	for i in count:
		var factor := float(i) / float(count)
		buf[i] *= factor
		buf[buf.size() - 1 - i] *= factor


# ---------------------------------------------------------------- 输出

## 把浮点缓冲写成 16 bit 单声道 PCM WAV。
## [param loop] 为 true 时写入 [code]smpl[/code] 循环块，Godot 导入时按"从 WAV 检测循环"处理。
static func write_wav(path: String, buf: PackedFloat32Array, loop: bool = false) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())

	var count := buf.size()
	var data_size := count * 2
	var smpl_bytes := 68 if loop else 0
	var riff_size := 4 + 24 + smpl_bytes + 8 + data_size

	var out := PackedByteArray()
	out.append_array(_ascii("RIFF"))
	out.append_array(_u32(riff_size))
	out.append_array(_ascii("WAVE"))
	out.append_array(_ascii("fmt "))
	out.append_array(_u32(16))
	out.append_array(_u16(1))
	out.append_array(_u16(Catalog.CHANNELS))
	out.append_array(_u32(SR))
	out.append_array(_u32(SR * Catalog.CHANNELS * Catalog.BITS_PER_SAMPLE / 8))
	out.append_array(_u16(Catalog.CHANNELS * Catalog.BITS_PER_SAMPLE / 8))
	out.append_array(_u16(Catalog.BITS_PER_SAMPLE))

	if loop:
		out.append_array(_ascii("smpl"))
		out.append_array(_u32(60))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(int(1000000000.0 / float(SR))))
		out.append_array(_u32(60))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(1))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(0))
		out.append_array(_u32(maxi(0, count - 1)))
		out.append_array(_u32(0))
		out.append_array(_u32(0))

	out.append_array(_ascii("data"))
	out.append_array(_u32(data_size))
	for i in count:
		out.append_array(_s16(int(clampf(buf[i], -1.0, 1.0) * 32767.0)))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Synth: 无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	file.store_buffer(out)
	file.close()
	print("  → ", path, "  %.2fs" % (float(count) / float(SR)))
	return true


static func _ascii(text: String) -> PackedByteArray:
	return text.to_ascii_buffer()


static func _u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value & 0xFFFFFFFF)
	return bytes


static func _u16(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_u16(0, value & 0xFFFF)
	return bytes


static func _s16(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_s16(0, value)
	return bytes
