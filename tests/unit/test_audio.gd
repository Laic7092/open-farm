extends GdUnitTestSuite
## 音频资源规范的可执行版本（对应 [code]docs/audio_pipeline.md[/code]）。
##
## 和 [code]test_assets.gd[/code] 同样的思路：把"音频也必须由脚本生成"写成断言——
## [br]- 目录里声明的每个 id 都有对应 WAV（漏生成会红）
## [br]- WAV 真的是 22050 Hz / 16 bit / 单声道 PCM（改错格式会红）
## [br]- BGM 带循环点、音效足够短（曲目接缝 / 提示音拖尾会红）
## [br]- 运行时总线就位、音量可调（音频系统没接线会红）

const Catalog := preload("res://src/audio/audio_catalog.gd")

## 采样率 / 位深 / 声道的唯一事实来源在 [AudioCatalog] 与 [constant Synth.SR]，
## 这里只做"落盘结果是否符合声明"的核对。
const EXPECTED_RATE: int = 22050
const EXPECTED_BITS: int = 16
const EXPECTED_CHANNELS: int = 1
## 音效长度上限（秒）：再长就不像"反馈音"了。
const MAX_SFX_SECONDS: float = 1.2


# ---------------------------------------------------------------- 文件存在性

func test_all_generated_audio_exists() -> void:
	for id: StringName in Catalog.bgm_ids():
		assert_bool(ResourceLoader.exists(Catalog.bgm_path(id))).override_failure_message(
			"缺少 BGM %s（跑一次 ./tools/build_assets.sh）" % Catalog.bgm_path(id)
		).is_true()
	for id: StringName in Catalog.sfx_ids():
		assert_bool(ResourceLoader.exists(Catalog.sfx_path(id))).override_failure_message(
			"缺少音效 %s（跑一次 ./tools/build_assets.sh）" % Catalog.sfx_path(id)
		).is_true()


func test_catalog_ids_are_unique() -> void:
	var seen := {}
	for id: StringName in Catalog.bgm_ids():
		assert_bool(seen.has(id)).override_failure_message("BGM id 重复：%s" % id).is_false()
		seen[id] = true
	for id: StringName in Catalog.sfx_ids():
		assert_bool(seen.has(id)).override_failure_message("音效 id 重复：%s" % id).is_false()
		seen[id] = true


# ---------------------------------------------------------------- WAV 头

## 逐个解析 WAV 头，确认生成器写出的确实是标准 16 bit PCM。
func test_wav_format_matches_catalog() -> void:
	var paths: Array[String] = []
	for id: StringName in Catalog.bgm_ids():
		paths.append(Catalog.bgm_path(id))
	for id: StringName in Catalog.sfx_ids():
		paths.append(Catalog.sfx_path(id))

	for path: String in paths:
		var header := _read_wav_header(path)
		assert_int(header.get("format", -1)).override_failure_message(
			"%s 不是 PCM（format=%d）" % [path, header.get("format", -1)]
		).is_equal(1)
		assert_int(header.get("channels", -1)).override_failure_message(
			"%s 声道数不是 %d" % [path, EXPECTED_CHANNELS]
		).is_equal(EXPECTED_CHANNELS)
		assert_int(header.get("sample_rate", -1)).override_failure_message(
			"%s 采样率不是 %d" % [path, EXPECTED_RATE]
		).is_equal(EXPECTED_RATE)
		assert_int(header.get("bits", -1)).override_failure_message(
			"%s 位深不是 %d" % [path, EXPECTED_BITS]
		).is_equal(EXPECTED_BITS)
		assert_int(header.get("data_size", 0)).override_failure_message(
			"%s 的 data 块是空的" % path
		).is_greater(0)


## BGM 必须在 [code]smpl[/code] 块里写循环点，导入后才会自循环。
func test_bgm_wavs_declare_loop_points() -> void:
	for id: StringName in Catalog.bgm_ids():
		var header := _read_wav_header(Catalog.bgm_path(id))
		assert_bool(header.get("has_smpl", false)).override_failure_message(
			"BGM %s 的 WAV 没有 smpl 循环块" % id
		).is_true()


func test_sfx_wavs_do_not_declare_loops() -> void:
	for id: StringName in Catalog.sfx_ids():
		var header := _read_wav_header(Catalog.sfx_path(id))
		assert_bool(header.get("has_smpl", false)).override_failure_message(
			"音效 %s 不该带循环块" % id
		).is_false()


# ---------------------------------------------------------------- 导入结果

func test_bgm_streams_loop_after_import() -> void:
	for id: StringName in Catalog.bgm_ids():
		var stream := load(Catalog.bgm_path(id)) as AudioStreamWAV
		assert_object(stream).override_failure_message("BGM %s 加载失败" % id).is_not_null()
		if stream == null:
			continue
		assert_int(stream.loop_mode).override_failure_message(
			"BGM %s 导入后没有循环（loop_mode=%d）" % [id, stream.loop_mode]
		).is_equal(AudioStreamWAV.LOOP_FORWARD)
		assert_int(stream.loop_end).override_failure_message(
			"BGM %s 的循环终点不合理（%d）" % [id, stream.loop_end]
		).is_greater(0)


func test_sfx_streams_are_short() -> void:
	for id: StringName in Catalog.sfx_ids():
		var stream := load(Catalog.sfx_path(id)) as AudioStreamWAV
		assert_object(stream).override_failure_message("音效 %s 加载失败" % id).is_not_null()
		if stream == null:
			continue
		assert_float(stream.get_length()).override_failure_message(
			"音效 %s 太长（%.2fs）" % [id, stream.get_length()]
		).is_less_equal(MAX_SFX_SECONDS)


# ---------------------------------------------------------------- 运行时

func test_audio_buses_exist() -> void:
	assert_int(AudioServer.get_bus_index(Audio.BGM_BUS)).override_failure_message(
		"缺少 BGM 总线"
	).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index(Audio.SFX_BUS)).override_failure_message(
		"缺少 SFX 总线"
	).is_greater_equal(0)


func test_bgm_volume_controls_bus() -> void:
	var original: float = Audio.bgm_volume
	Audio.set_bgm_volume(0.5)
	assert_float(Audio.bgm_volume).is_equal_approx(0.5, 0.001)
	assert_float(AudioServer.get_bus_volume_db(Audio._bgm_bus)).is_equal_approx(
		linear_to_db(0.5), 0.01
	)
	Audio.set_bgm_volume(original)
	assert_float(Audio.bgm_volume).is_equal_approx(original, 0.001)


func test_playing_bgm_remembers_track() -> void:
	Audio.play_bgm(Catalog.BGM_FARM)
	assert_str(String(Audio.current_bgm())).is_equal(String(Catalog.BGM_FARM))


# ---------------------------------------------------------------- 工具

## 读 WAV 头（只解析到第一个 data 块，足够核对格式）。
func _read_wav_header(path: String) -> Dictionary:
	var result := {"format": -1, "channels": -1, "sample_rate": -1, "bits": -1, "data_size": 0, "has_smpl": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		return result
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return result
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return result

	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		if chunk_id == "fmt ":
			result["format"] = bytes.decode_u16(offset + 8)
			result["channels"] = bytes.decode_u16(offset + 10)
			result["sample_rate"] = bytes.decode_u32(offset + 12)
			result["bits"] = bytes.decode_u16(offset + 22)
		elif chunk_id == "smpl":
			result["has_smpl"] = true
		elif chunk_id == "data":
			result["data_size"] = chunk_size
			break
		offset += 8 + chunk_size
	return result
