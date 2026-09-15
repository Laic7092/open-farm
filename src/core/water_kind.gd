class_name WaterKind
extends RefCounted
## 水域类型：钓点、鱼种与水面标记共用的一份定义。
##
## 和 [enum Weather.Type] / [enum Season.Type] 一样，它本身只是标签；
## "什么鱼出没在哪片水"写在 [FishingRules] 与 [code]data/fish/*.tres[/code] 里。

enum Kind {
	POND,   ## 池塘 / 河沟：村庄与集市里的那几片水
	OCEAN,  ## 海：海滩下方的开阔水面
}

## 全部取值（顺序 = 数据文件里的枚举下标）。
static func all() -> Array[int]:
	return [Kind.POND, Kind.OCEAN]

## 是否为合法取值。
static func is_valid(value: int) -> bool:
	return all().has(value)
