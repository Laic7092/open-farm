class_name Facing
extends RefCounted
## 四方向朝向工具集。
##
## 纯函数集合，方便单元测试；玩家、NPC 与工具瞄准共用同一套约定。

enum Direction {
	DOWN = 0,
	UP = 1,
	LEFT = 2,
	RIGHT = 3,
}


## 朝向对应的格子步进量（Y 轴向下为正）。
static func to_vector(direction: Direction) -> Vector2i:
	match direction:
		Direction.UP:
			return Vector2i(0, -1)
		Direction.LEFT:
			return Vector2i(-1, 0)
		Direction.RIGHT:
			return Vector2i(1, 0)
		_:
			return Vector2i(0, 1)


## 由输入向量推断朝向；优先保留水平分量，零向量时返回 [param fallback]。
##
## 牧场物语式的八向输入会被压平成四向：|x| >= |y| 时走水平。
static func from_vector(vector: Vector2, fallback: Direction = Direction.DOWN) -> Direction:
	if vector.is_zero_approx():
		return fallback
	if absf(vector.x) >= absf(vector.y):
		return Direction.RIGHT if vector.x > 0.0 else Direction.LEFT
	return Direction.DOWN if vector.y > 0.0 else Direction.UP


## 反方向。
static func opposite(direction: Direction) -> Direction:
	match direction:
		Direction.DOWN:
			return Direction.UP
		Direction.UP:
			return Direction.DOWN
		Direction.LEFT:
			return Direction.RIGHT
		_:
			return Direction.LEFT


## 动画名后缀：左右共用 "side"，配合 [code]flip_h[/code] 复用同一套帧。
static func animation_suffix(direction: Direction) -> StringName:
	match direction:
		Direction.UP:
			return &"up"
		Direction.LEFT, Direction.RIGHT:
			return &"side"
		_:
			return &"down"


## 该朝向是否需要水平翻转精灵。
static func flip_h(direction: Direction) -> bool:
	return direction == Direction.LEFT


## 存档编码。
static func to_key(direction: Direction) -> StringName:
	return StringName(String(Direction.keys()[direction]).to_lower())


## 存档解码。
static func from_key(key: String) -> Direction:
	var index: int = Direction.keys().find(key.to_upper())
	return (index if index >= 0 else 0) as Direction
