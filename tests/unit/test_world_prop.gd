extends GdUnitTestSuite
## [WorldProp] 的身后淡出：所有实心摆件（房子 / 树 / 柜台）通用。
##
## 只测纯几何判定，不把节点挂进场景树——挂进去会真的建碰撞 / 注册 _process，
## 反而把"这条规则是否成立"和"节点能不能跑"混在一起。

const HOUSE_TEXTURE: String = "res://assets/sprites/props/house.png"


func _prop(solid: Vector2) -> WorldProp:
	var prop := WorldProp.new()
	prop.texture = load(HOUSE_TEXTURE)
	prop.solid_size = solid
	prop.solid_offset = Vector2(0, 24)
	prop.position = Vector2(100, 66)
	return prop


## 实心就淡出：房子和树都走同一条路，显式 passable 的装饰不处理。
func test_all_solid_props_fade_behind() -> void:
	var house := _prop(Vector2(58, 14))
	assert_bool(house._should_fade_behind()).is_true()
	var tree := _prop(Vector2(18, 8))
	assert_bool(tree._should_fade_behind()).is_true()
	var decoration := _prop(Vector2.ZERO)
	decoration.passable = true
	assert_bool(decoration._should_fade_behind()).is_false()
	house.free()
	tree.free()
	decoration.free()


## 没有显式 solid_size 时，默认按贴图自动生成脚印，不能继续被当成可穿过。
func test_unconfigured_props_are_solid_by_default() -> void:
	var prop := WorldProp.new()
	prop.texture = load(HOUSE_TEXTURE)
	assert_bool(prop.passable).is_false()
	assert_bool(prop._effective_solid_size() != Vector2.ZERO).is_true()
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


## fade_when_behind 关掉后，宽件也不再淡出。
func test_fade_can_be_disabled_per_prop() -> void:
	var house := _prop(Vector2(58, 14))
	house.fade_when_behind = false
	assert_bool(house._should_fade_behind()).is_false()
	house.free()
