class_name DecorPainter
extends RefCounted
## 独立的场景装饰生成器：花、蘑菇、栅栏、牌子这类"站在地板上的东西"。
##
## [b]为什么不再写进 Ground TileMap[/b]：
## [br]- Ground 只回答"脚下是什么地板"，野生植被判定、道路过渡都只读地板；
## [br]- 装饰是独立 CanvasItem，才能和玩家逐件 Y 排序、走 [WorldProp] 的碰撞；
## [br]- 身后淡出暂时只开放给 building 组建筑，装饰保持完整可读；
## [br]- 透明贴图不带草底，摆在沙地 / 砾石 / 室内地板上不会露出绿色方块方框。
##
## 贴图由 [code]tools/art/generate_terrain.gd[/code] 从同一套像素画函数导出；
## 场景脚本只传"哪一格放哪个 id"。编辑器预览不生成节点，游戏运行时才实例化。

## 运行时生成的装饰节点都会加入这个分组；[FloraField] 靠它避免植被长到摆件上。
const GROUP: StringName = &"decor_props"
## 装饰节点 meta：所在格子。
const CELL_META: StringName = &"decor_cell"

## 装饰 id → 透明贴图路径。
const TEXTURES: Dictionary = {
	&"flowers": "res://assets/sprites/decor/flowers.png",
	&"flower_red": "res://assets/sprites/decor/flower_red.png",
	&"flower_blue": "res://assets/sprites/decor/flower_blue.png",
	&"flower_bed": "res://assets/sprites/decor/flower_bed.png",
	&"bush": "res://assets/sprites/decor/bush.png",
	&"tall_grass": "res://assets/sprites/decor/tall_grass.png",
	&"mushroom": "res://assets/sprites/decor/mushroom.png",
	&"pebble": "res://assets/sprites/decor/pebble.png",
	&"sand_pebble": "res://assets/sprites/decor/sand_pebble.png",
	&"gravel_ore": "res://assets/sprites/decor/gravel_ore.png",
	&"stump_tile": "res://assets/sprites/decor/stump_tile.png",
	&"hay": "res://assets/sprites/decor/hay.png",
	&"crate": "res://assets/sprites/decor/crate.png",
	&"well_top": "res://assets/sprites/decor/well_top.png",
	&"fence": "res://assets/sprites/decor/fence.png",
	&"fence_gate": "res://assets/sprites/decor/fence_gate.png",
	&"sign": "res://assets/sprites/decor/sign.png",
}

## id → 是否允许穿过。默认 true：绝大多数装饰是低矮地被。
const PASSABLE: Dictionary = {
	&"flower_bed": false,
	&"bush": false,
	&"stump_tile": false,
	&"hay": false,
	&"crate": false,
	&"well_top": false,
	&"fence": false,
	&"sign": false,
	&"fence_gate": true,
}

## 实心装饰的脚印碰撞盒；没有的条目让 [WorldProp] 按贴图自动算。
const SOLID_SIZES: Dictionary = {
	&"flower_bed": Vector2(14, 8),
	&"bush": Vector2(14, 8),
	&"stump_tile": Vector2(14, 8),
	&"hay": Vector2(14, 8),
	&"crate": Vector2(14, 10),
	&"well_top": Vector2(14, 8),
	&"fence": Vector2(16, 6),
	&"sign": Vector2(12, 7),
}

## 脚印相对贴图中心的纵向偏移：所有装饰的碰撞盒都贴到格子底部。
const SOLID_OFFSETS: Dictionary = {
	&"flower_bed": Vector2(0, 4),
	&"bush": Vector2(0, 4),
	&"stump_tile": Vector2(0, 4),
	&"hay": Vector2(0, 4),
	&"crate": Vector2(0, 3),
	&"well_top": Vector2(0, 4),
	&"fence": Vector2(0, 5),
	&"sign": Vector2(0, 4),
}


## 按格子表批量生成装饰。[param entries] 形如 [code]{ Vector2i: &"flowers" }[/code]。
##
## [param clip] 非空时只在矩形内的格子生成；[param skip] 里的格子跳过，
## 便于场景脚本沿用"先铺大片、再挖门口"的写法。
static func spawn_many(
	root: Node2D,
	entries: Dictionary,
	clip: Rect2i = Rect2i(),
	skip: Array[Vector2i] = []
) -> Array[WorldProp]:
	var spawned: Array[WorldProp] = []
	if root == null:
		return spawned
	for cell_variant: Variant in entries:
		var cell: Vector2i = cell_variant
		if clip.size != Vector2i.ZERO and not clip.has_point(cell):
			continue
		if skip.has(cell):
			continue
		var prop := spawn(root, cell, StringName(entries[cell_variant]))
		if prop != null:
			spawned.append(prop)
	return spawned


## 生成单个装饰；[param decor_id] 必须在 [constant TEXTURES] 里。
static func spawn(root: Node2D, cell: Vector2i, decor_id: StringName) -> WorldProp:
	if root == null or not TEXTURES.has(decor_id):
		return null
	# 编辑器里的 [code]@tool[/code] 地面脚本只负责画地板，不要把运行时装饰写进场景。
	if Engine.is_editor_hint():
		return null
	var texture := load(TEXTURES[decor_id]) as Texture2D
	if texture == null:
		return null

	var prop := WorldProp.new()
	prop.name = "Decor_%d_%d_%s" % [cell.x, cell.y, String(decor_id)]
	prop.texture = texture
	prop.position = GridUtils.cell_to_world(cell)
	prop.passable = bool(PASSABLE.get(decor_id, true))
	if SOLID_SIZES.has(decor_id):
		prop.solid_size = SOLID_SIZES[decor_id]
	if SOLID_OFFSETS.has(decor_id):
		prop.solid_offset = SOLID_OFFSETS[decor_id]
	prop.add_to_group(GROUP)
	prop.set_meta(CELL_META, cell)
	root.add_child(prop)
	return prop
