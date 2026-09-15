extends "res://tools/smoke/smoke_base.gd"
## 端到端冒烟测试：真的把游戏跑起来，再断言关键行为。
##
## [b]调度地图[/b]（加 / 改检查项前先看这里，别只搜 _run_checks）：
## [br]- 农场内检查：由 _run_checks() 顺序调用（日历 / 数据 / 世界 / 出生点 / 时钟 / 昼夜 / 农场 / 植被 / 畜牧 / 商店 / 存档 / UI / 音频）。
## [br]- 跨地图巡游：_process() 相位机（编号手工编排）：1 存档锚点 → 2 集市 _check_twon → 5 NPC 走动 → 6 村庄 _check_town → 7 海滩 + 开始钓鱼 → 11 钓鱼推进 → 8 矿洞 _check_mine → 9 图书馆 _check_library（含关系）→ 4 回农场 + 走出边缘 → 10 边缘传送 _check_edge_travel → _report()。
## [br]- 新增检查项：验证农场 → 加进 _run_checks()；验证别的图 → 在对应相位调用。
##
## 单元测试（gdUnit4）覆盖纯逻辑，但"场景能不能加载、autoload 有没有接错线、
## 存档写不写得进去"这类问题只有把游戏跑起来才暴露得出来。
## 这个脚本就是干这个的，也方便在没有显示器的机器上做 CI。
##
## 注意：这里必须用[b]场景[/b]而不是 [code]-s[/code] 脚本启动。

const ChecksWorld := preload("res://tools/smoke/checks_world.gd")
const ChecksFarm := preload("res://tools/smoke/checks_farm.gd")
const ChecksTravel := preload("res://tools/smoke/checks_travel.gd")
const ChecksFishing := preload("res://tools/smoke/checks_fishing.gd")

var _world_checks: ChecksWorld
var _farm_checks: ChecksFarm
var _travel_checks: ChecksTravel
var _fishing_checks: ChecksFishing

func _ready() -> void:
	SaveManager.save_root = TEST_SAVE_ROOT
	_cleanup_saves()
	var scene: PackedScene = load("res://scenes/main/main.tscn")
	if scene == null:
		_fail("无法加载 main.tscn")
		_report()
		return
	_main = scene.instantiate() as Main
	if _main == null:
		_fail("main.tscn 根节点不是 Main")
		_report()
		return
	_profile = _main.player_profile
	_clock = _main.clock_state
	add_child(_main)
	_weather = _main.weather_service
	_relationships = _main.relationship_service
	_calendar = _main.calendar_service
	_setup_checkers()

## 创建各域检查器并把根节点的运行时引用分给它们（在 _ready() 末尾调用一次）。
func _setup_checkers() -> void:
	_world_checks = ChecksWorld.new()
	_farm_checks = ChecksFarm.new()
	_travel_checks = ChecksTravel.new()
	_fishing_checks = ChecksFishing.new()
	for checker in [_world_checks, _farm_checks, _travel_checks, _fishing_checks]:
		add_child(checker)
		checker.share_state_from(self)



func _process(_delta: float) -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		_fail("超时：%d 帧内仍未完成（当前阶段 %d）" % [MAX_FRAMES, _phase])
		_report()
		return

	# 巡游顺序 = 世界拓扑顺序：农场 → 村庄 → 集市 → 海滩 → 矿洞 → 图书馆 → 农场。
	# 每一站都用"上一站走过来的那个出生点"落地，于是这条路径同时验证了
	# 世界是真的连成一条能走通的路，而不是互不相干的几张地图。
	match _phase:
		0:
			if not _is_transitioning() and _world() != null:
				_phase = 1
		1:
			_run_checks()
			_farm_checks._prepare_persistence_anchor()
			_phase = 2
			SceneRouter.change_scene_to(_world_host(), TWON_SCENE, &"from_farm")
		2:
			if _is_transitioning():
				return
			_travel_checks._check_twon()
			_travel_checks._record_npc_positions()
			_twon_wait = 0
			_phase = 5
		# 等几帧，验证 NPC 真的按日程走起来了，再依次巡游其余地图。
		5:
			if _is_transitioning():
				return
			_twon_wait += 1
			if _twon_wait < 30:
				return
			_travel_checks._check_npcs_moved()
			_phase = 6
			SceneRouter.change_scene_to(_world_host(), TOWN_SCENE, &"from_twon")
		6:
			if _is_transitioning():
				return
			_travel_checks._check_town()
			_phase = 7
			SceneRouter.change_scene_to(_world_host(), BEACH_SCENE, &"from_town")
		7:
			if _is_transitioning():
				return
			_travel_checks._check_beach()
			_fishing_checks._start_fishing_check()
			# 钓鱼是多帧时序，切到独立阶段推进，出了结果再继续巡游。
			_phase = 11
		11:
			if _fishing_checks._advance_fishing_check():
				_phase = 8
				SceneRouter.change_scene_to(_world_host(), MINE_SCENE, &"from_beach")
		8:
			if _is_transitioning():
				return
			_travel_checks._check_mine()
			_phase = 9
			SceneRouter.change_scene_to(_world_host(), LIBRARY_SCENE, &"from_twon")
		9:
			if _is_transitioning():
				return
			_travel_checks._check_library()
			_phase = 4
			SceneRouter.change_scene_to(_world_host(), FARM_SCENE, &"from_twon")
		4:
			if _is_transitioning():
				return
			_farm_checks._check_farm_state_survived()
			# 最后一步：不按键，直接站进农场东口，验证"走到地图边缘就换图"。
			_phase = 10
			_edge_wait = 0
			_travel_checks._walk_into_exit()
		10:
			if _is_transitioning():
				_edge_wait = 0
				return
			# 切换结束再多等几帧，避免"传送还没开始就下结论"。
			_edge_wait += 1
			if _edge_wait < 20:
				return
			_travel_checks._check_edge_travel()
			_report()

func _run_checks() -> void:
	_world_checks._check_calendar()
	_world_checks._check_database()
	_world_checks._check_world()
	_world_checks._check_spawn()
	_world_checks._check_clock()
	_world_checks._check_day_night()
	_farm_checks._check_farming()
	_farm_checks._check_flora()
	_farm_checks._check_livestock()
	_world_checks._check_shop()
	_world_checks._check_save_load()
	_world_checks._check_ui()
	_world_checks._check_audio()
