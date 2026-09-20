class_name HeldToolView
extends Node2D
## 玩家手里那件工具：按当前手持工具换贴图，挥动时绕握柄转出一个弧线。
##
## 工具贴图竖直摆放（头朝上、握柄在底部中心），节点原点就是握柄，
## 所以"挥动"只是旋转本节点——不需要为每件工具画一套逐帧挥动图，
## 也天然支持[空挥]（有没有命中都照转）。
##
## 只在挥动期间显示：由 [PlayerStateUseItem] 在进入时 [method show_tool]、
## 离开时 [method hide_tool]；平时一直握着会挡住身体。

## 手持工具贴图目录（与 [constant AtlasLayout.TOOL_DIR] 同源）。
const TOOL_DIR: String = "res://assets/sprites/tools"
## 握柄相对节点原点的偏移：贴图 16×24，握柄在底部中心。
const GRIP_OFFSET := Vector2(0, -12)
## 手相对角色原点的基准位置。
const HAND_X: float = 4.0
const HAND_Y: float = -13.0
## 朝上时手略抬高，工具从肩后挥出。
const HAND_Y_UP: float = -15.0

## 贴图缓存：同一件工具只从磁盘读一次。
static var _cache: Dictionary[StringName, Texture2D] = {}

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.offset = GRIP_OFFSET
	add_child(_sprite)
	visible = false


## 换成 [param tool] 的贴图；找不到（或不是工具）时保持隐藏。
func show_tool(tool: ToolData) -> void:
	var texture: Texture2D = _texture_for(tool.id) if tool != null else null
	if texture == null or _sprite == null:
		hide_tool()
		return
	_sprite.texture = texture
	visible = true


## 收起来。
func hide_tool() -> void:
	visible = false


## 按挥动进度摆姿势。[param progress] 取 0~1，[param facing] 决定手在身体哪一侧。
func apply_swing(progress: float, facing: Facing.Direction) -> void:
	_pose(ToolSwing.angle_deg(progress), facing)


## 一直举着的姿势（钓竿等不需要挥动的道具），用起手角度。
func apply_hold(facing: Facing.Direction) -> void:
	_pose(ToolSwing.REST_DEG, facing)


## 工具尖端相对角色原点的位置；没举着工具时退回手的位置。
##
## 鱼线起点用它，于是"竿尖在哪鱼线就从哪出来"。
func tip_position() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return position
	var length: float = _sprite.texture.get_height()
	return position + Vector2(sin(rotation), -cos(rotation)) * length


func _pose(angle_deg: float, facing: Facing.Direction) -> void:
	# 左向由 scale.x = -1 镜像：位置、贴图、旋转方向一起翻过去。
	var side: float = -1.0 if Facing.flip_h(facing) else 1.0
	var hand_y: float = HAND_Y_UP if facing == Facing.Direction.UP else HAND_Y
	position = Vector2(HAND_X * side, hand_y)
	scale.x = side
	rotation = deg_to_rad(angle_deg * side)
	# 朝上时工具在角色身后，压在身体下面；其余朝向举在前面。
	z_index = -1 if facing == Facing.Direction.UP else 1


static func _texture_for(tool_id: StringName) -> Texture2D:
	if tool_id == &"":
		return null
	if _cache.has(tool_id):
		return _cache[tool_id]
	var path: String = TOOL_DIR.path_join("%s.png" % tool_id)
	if not ResourceLoader.exists(path):
		return null
	var texture := ResourceLoader.load(path) as Texture2D
	_cache[tool_id] = texture
	return texture
