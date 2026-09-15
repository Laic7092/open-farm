extends GdUnitTestSuite
## 存档系统测试：写入 / 读回 / 版本校验 / 坏文件容错。
##
## 存档统一写到工作区内的临时目录，既不会污染真实的 user:// 目录，
## 也让测试之间互不干扰。

const TEST_ROOT: String = "res://.tmp/gdunit_saves"

var _profile: PlayerProfile
var _clock: GameDateClock
var _weather: WeatherService


func before_test() -> void:
	SaveManager.save_root = TEST_ROOT
	_cleanup()
	_profile = PlayerProfile.new()
	_clock = GameDateClock.new()
	_weather = WeatherService.new()
	Persistence.register_core_resource(_clock, &"GameClock", 10)
	Persistence.register_core_resource(_profile, &"GameState", 20)
	Persistence.register_core_resource(_weather, &"WeatherSystem", 30)


func after_test() -> void:
	Persistence.unregister_core_resource(_weather)
	Persistence.unregister_core_resource(_clock)
	Persistence.unregister_core_resource(_profile)
	_weather.free()
	_weather = null
	_profile = null
	_clock = null
	_cleanup()
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT


# ---------------------------------------------------------------- 基础

func test_slot_path_is_stable() -> void:
	assert_str(SaveManager.slot_path(0)).is_equal("%s/slot_0.json" % TEST_ROOT)


func test_no_save_before_writing() -> void:
	assert_bool(SaveManager.has_save(0)).is_false()
	assert_array(SaveManager.existing_slots()).is_empty()


func test_save_then_has_save() -> void:
	assert_bool(SaveManager.save_game(0)).is_true()
	assert_bool(SaveManager.has_save(0)).is_true()
	assert_array(SaveManager.existing_slots()).contains_exactly([0])


func test_save_rejects_invalid_slot() -> void:
	assert_bool(SaveManager.save_game(-1)).is_false()
	assert_bool(SaveManager.save_game(SaveManager.SLOT_COUNT)).is_false()


func test_delete_save() -> void:
	SaveManager.save_game(1)
	assert_bool(SaveManager.delete_save(1)).is_true()
	assert_bool(SaveManager.has_save(1)).is_false()


# ---------------------------------------------------------------- 往返

func test_roundtrip_restores_core_state() -> void:
	_clock.set_date(GameDate.new(2, Season.Type.SUMMER, 9))
	_clock.set_time(14, 25)
	_profile.set_money(1234)
	_profile.set_player_name("小明")
	_profile.set_flag(&"met_mayor", 3)

	assert_bool(SaveManager.save_game(0)).is_true()

	# 把运行时状态全部打乱。
	_clock.reset()
	_profile.reset()
	assert_int(_profile.money).is_equal(PlayerProfile.STARTING_MONEY)

	assert_bool(SaveManager.load_game(0)).is_true()
	assert_int(_clock.date.year).is_equal(2)
	assert_int(_clock.date.season).is_equal(Season.Type.SUMMER)
	assert_int(_clock.date.day).is_equal(9)
	assert_int(_clock.hour()).is_equal(14)
	assert_int(_clock.minute()).is_equal(25)
	assert_int(_profile.money).is_equal(1234)
	assert_str(_profile.player_name).is_equal("小明")
	assert_int(_profile.get_flag(&"met_mayor")).is_equal(3)


func test_roundtrip_restores_weather() -> void:
	_weather.set_weather(Weather.Type.STORMY)
	SaveManager.save_game(0)
	_weather.set_weather(Weather.Type.SUNNY)

	assert_bool(SaveManager.load_game(0)).is_true()
	assert_int(_weather.current).is_equal(Weather.Type.STORMY)


func test_meta_summary_matches_the_save() -> void:
	_clock.set_date(GameDate.new(4, Season.Type.WINTER, 21))
	_profile.set_money(777)
	_profile.set_player_name("阿花")
	SaveManager.save_game(0)

	var meta := SaveManager.read_meta(0)
	assert_int(int(meta.get("version", 0))).is_equal(SaveManager.SAVE_VERSION)
	assert_int(int(meta.get("money", 0))).is_equal(777)
	assert_str(str(meta.get("player_name", ""))).is_equal("阿花")
	var date: GameDate = meta.get("date")
	assert_int(date.year).is_equal(4)
	assert_int(date.day).is_equal(21)


func test_collect_contains_every_expected_section() -> void:
	var payload := SaveManager.collect()
	assert_dict(payload).contains_keys(
		"version", "saved_at", "GameClock", "GameState", "WeatherSystem", "nodes"
	)


# ---------------------------------------------------------------- 容错

func test_load_missing_slot_fails_cleanly() -> void:
	assert_bool(SaveManager.load_game(2)).is_false()


func test_read_meta_of_missing_slot_is_empty() -> void:
	assert_dict(SaveManager.read_meta(2)).is_empty()


func test_load_rejects_a_newer_save_version() -> void:
	var payload := {
		"version": SaveManager.SAVE_VERSION + 1,
		"GameClock": {},
	}
	assert_bool(SaveManager.apply(payload)).is_false()


func test_load_rejects_a_save_without_version() -> void:
	assert_bool(SaveManager.apply({"GameClock": {}})).is_false()


func test_corrupt_file_is_reported_not_crashed() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	var file := FileAccess.open(SaveManager.slot_path(0), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()

	assert_bool(SaveManager.has_save(0)).is_true()
	assert_dict(SaveManager.read_meta(0)).is_empty()
	assert_bool(SaveManager.load_game(0)).is_false()


func test_apply_ignores_unknown_sections() -> void:
	var payload := {
		"version": SaveManager.SAVE_VERSION,
		"GameClock": _clock.to_dict(),
		"SomethingElse": {"whatever": true},
		"nodes": {},
	}
	assert_bool(SaveManager.apply(payload)).is_true()


# ---------------------------------------------------------------- 工具

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
