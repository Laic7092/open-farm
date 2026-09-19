class_name SeasonLook
extends Node
## 一张地图的季节外观服务：进图与跨季时把地面图集与树木贴图换成当季版本。
##
## 冬季"只换色盘、不换画法"（见 [SeasonPalette]）：地面换一张 [TileSet]、
## 树换一张 PNG，形状与碰撞完全不变，所以这里不重铺地板、不重建节点，
## 也不需要重新 [code]paint()[/code]——[code]TileMapLayer.tile_set[/code]
## 换掉后瓦片数据原样保留、当帧即可重绘，实测见
## [code]tests/unit/test_season_look.gd[/code]。
##
## [b]为什么挂在 [WorldScene] 上[/b]：世界场景会被缓存复用，
## [code]_ready()[/code] 一生只跑一次，所以"每次进图都要对齐季节"这件事
## 必须由 [method WorldScene.on_world_enter] 触发。
##
## [b]刷新时机[/b]
## [br]- 进图：[method refresh]（含从缓存挂回来的读档路径）；
## [br]- 跨季那天的日结转钩子：季节真的变了才刷（同一个季节内反复触发不做无用功）；
## [br]- 室内地图：[code]WorldScene.season_effects = false[/code] 时不挂本节点。

## 当前季节；[method refresh] 之后等于时钟的日期季节。
var _season: Season.Type = SeasonPalette.BASE_SEASON
## [method refresh] 被调用过几次；供测试确认"同季不重复刷"。
var refresh_count: int = 0

var _clock: GameDateClock


## 由 [WorldScene] 在世界进入树前下发组合根依赖。
func bind_dependencies(_profile: PlayerProfile, clock: GameDateClock) -> void:
	_clock = clock


## 注册日结转钩子放在 [code]_enter_tree()[/code]：
## 场景缓存复用后 [code]_ready()[/code] 不会再跑，钩子必须每次进出都重挂。
func _enter_tree() -> void:
	if _clock != null:
		_clock.register_day_hook(_on_day_rollover, DayPipeline.PRIORITY_WORLD)


func _exit_tree() -> void:
	if _clock != null:
		_clock.unregister_day_hook(_on_day_rollover)


## 当前季节。
func season() -> Season.Type:
	return _season


## 把这张地图的外观对齐到时钟当前季节；幂等，可反复调用。
func refresh() -> void:
	refresh_count += 1
	_season = _clock.date.season if _clock != null else SeasonPalette.BASE_SEASON
	_apply_tilesets()
	_apply_flora()
	_apply_props()


# ---------------------------------------------------------------- 内部

## 跨季那天刷一次；同一个季节内不重复。
func _on_day_rollover(date: GameDate) -> void:
	if date.season != _season:
		refresh()


## 本服务挂在 [WorldScene] 下，兄弟节点就是要处理的地图内容。
func _scene_root() -> Node:
	return get_parent()


## 把地面 / 土壤图层换成当季图集。
##
## 判定"这张图层用不用换"靠的是图集资源路径，而不是节点名：
## 新加一张地图只要用了同一份 [constant AtlasLayout.TILESET_RESOURCE_PATH]，
## 换季就自动成立。
func _apply_tilesets() -> void:
	var root := _scene_root()
	if root == null:
		return
	var desired := SeasonPalette.variant_path(AtlasLayout.TILESET_RESOURCE_PATH, _season)
	for node: Node in root.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var path := layer.tile_set.resource_path
		if not _is_season_tileset(path) or path == desired:
			continue
		var tileset := ResourceLoader.load(desired) as TileSet
		if tileset != null:
			layer.tile_set = tileset


## 这张图集是不是本系统的季节图集（基础图或任一季节变体）。
func _is_season_tileset(path: String) -> bool:
	if path == AtlasLayout.TILESET_RESOURCE_PATH:
		return true
	for season: Season.Type in Season.all():
		if not SeasonPalette.has_variant(season):
			continue
		if path == SeasonPalette.variant_suffix_path(AtlasLayout.TILESET_RESOURCE_PATH, season):
			return true
	return false


## 地图上的野生植被：所有节点都要换外观，不能只刷状态变了的格子。
func _apply_flora() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(FloraField.GROUP):
		var field := node as FloraField
		if field != null:
			field.apply_season(_season)


## 场景摆件：没有变体的贴图（房子 / 栅栏）由 [method WorldProp.apply_season]
## 原样保留，所以这里可以无脑遍历。
func _apply_props() -> void:
	var root := _scene_root()
	if root == null:
		return
	for node: Node in root.find_children("*", "WorldProp", true, false):
		var prop := node as WorldProp
		if prop != null:
			prop.apply_season(_season)
