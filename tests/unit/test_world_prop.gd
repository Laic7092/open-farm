extends GdUnitTestSuite
## [WorldProp] 的身后淡出：暂时只对 [constant WorldProp.BUILDING_GROUP] 里的建筑生效。
##
## 只测纯几何判定，不把节点挂进场景树——挂进去会真的建碰撞 / 注册 _process，
## 反而把"这条规则是否成立"和"节点能不能跑"混在一起。

const HOUSE_TEXTURE: String = "res://assets/sprites/props/house.png"


func _prop(solid: Vector2, building: bool = true) -> WorldProp:
	var prop := WorldProp.new()
	prop.texture = load(HOUSE_TEXTURE)
	prop.solid_size = solid
	prop.solid_offset = Vector2(0, 24)
	prop.position = Vector2(100, 66)
	if building:
		prop.add_to_group(WorldProp.BUILDING_GROUP)
	return prop


## 只有 building 组的实心摆件淡出；实心树木 / 石头 / 柜台不处理。
func test_only_buildings_fade_behind() -> void:
	var building := _prop(Vector2(58, 14))
	assert_bool(building._should_fade_behind()).is_true()
	var tree := _prop(Vector2(18, 8), false)
	assert_bool(tree._should_fade_behind()).is_false()
	var passable_building := _prop(Vector2(58, 14))
	passable_building.passable = true
	assert_bool(passable_building._should_fade_behind()).is_false()
	building.free()
	tree.free()
	passable_building.free()


## 没有显式 solid_size 时，默认按贴图自动生成脚印，不能继续被当成可穿过。
func test_unconfigured_props_are_solid_by_default() -> void:
	var prop := WorldProp.new()
	prop.texture = load(HOUSE_TEXTURE)
	assert_bool(prop.passable).is_false()
	assert_bool(prop._effective_solid_size() != Vector2.ZERO).is_true()
	assert_bool(prop._should_fade_behind()).is_false()
	prop.add_to_group(WorldProp.BUILDING_GROUP)
	assert_bool(prop._should_fade_behind()).is_true()
	prop.passable = true
	assert_bool(prop._effective_solid_size() == Vector2.ZERO).is_true()
	assert_bool(prop._should_fade_behind()).is_false()
	prop.free()


## 只有玩家落在纵向投影内、且在摆件北侧时才算"走到身后"。
func test_player_behind_within_footprint_fades() -> void:
	var house := _prop(Vector2(58, 14))
	var player := Node2D.new()
	house._player = player

	player.position = Vector2(100, 70)   # 北侧、纵向投影内
	assert_bool(house._player_is_behind()).is_true()

	player.position = Vector2(100, 100)  # 门前（南侧）
	assert_bool(house._player_is_behind()).is_false()

	player.position = Vector2(200, 70)   # 横向在房子外
	assert_bool(house._player_is_behind()).is_false()

	player.position = Vector2(100, 20)   # 北得太远，画面上根本不重叠
	assert_bool(house._player_is_behind()).is_false()

	player.free()
	house.free()


## fade_when_behind 关掉后，建筑也不再淡出。
func test_fade_can_be_disabled_per_building() -> void:
	var house := _prop(Vector2(58, 14))
	house.fade_when_behind = false
	assert_bool(house._should_fade_behind()).is_false()
	house.free()
