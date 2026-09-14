class_name Season
extends RefCounted
## 季节规则。
##
## 牧场物语中一年四季、每季固定天数。本类只承载[b]规则与数据[/b]，
## 不包含任何翻译或 UI 逻辑：显示文本由 UI 层通过 [method name_key]
## 取得翻译键后再调用 [code]tr()[/code]。

enum Type {
	SPRING = 0,
	SUMMER = 1,
	FALL = 2,
	WINTER = 3,
}

## 每个季节的天数。
const DAYS_PER_SEASON: int = 28
## 季节总数。
const COUNT: int = 4


## 把任意整数安全地折叠为合法季节。
static func from_index(index: int) -> Type:
	return wrapi(index, 0, COUNT) as Type


## 判断原始整数是否为合法季节值。
static func is_valid(value: int) -> bool:
	return value >= 0 and value < COUNT


## 返回该季节的翻译键。
static func name_key(season: Type) -> StringName:
	match season:
		Type.SPRING:
			return &"SEASON_SPRING"
		Type.SUMMER:
			return &"SEASON_SUMMER"
		Type.FALL:
			return &"SEASON_FALL"
		_:
			return &"SEASON_WINTER"


## 下一个季节。
static func next(season: Type) -> Type:
	return from_index(int(season) + 1)


## 所有季节，按一年中的顺序。
static func all() -> Array[Type]:
	var result: Array[Type] = [Type.SPRING, Type.SUMMER, Type.FALL, Type.WINTER]
	return result


## 便于存档的字符串编码。
static func to_key(season: Type) -> StringName:
	match season:
		Type.SPRING:
			return &"spring"
		Type.SUMMER:
			return &"summer"
		Type.FALL:
			return &"fall"
		_:
			return &"winter"


## [method to_key] 的逆运算，未知输入回退到春天。
static func from_key(key: String) -> Type:
	match key:
		"summer":
			return Type.SUMMER
		"fall":
			return Type.FALL
		"winter":
			return Type.WINTER
		_:
			return Type.SPRING
