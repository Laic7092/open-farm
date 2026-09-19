class_name QualityRules
extends RefCounted
## 产物品质规则（纯静态函数）。
##
## 和 [CropGrowth] / [AnimalHusbandry] 一样不依赖场景树与 [Database]，
## 因此可以直接用最朴素的方式单测：给定概率，断言抽出的等级与价格倍率。
##
## [b]为什么品质是"每格物品"而不是"每种物品"[/b]：
## 同一个萝卜可以有普通 / 银 / 金三种，它们共用一条 [ItemData]，
## 只是 [InventorySlot.quality] 不同。于是"新增一条物品"和"品质分级"
## 两件事互不干扰——想给某种作物加金品质，只需改它的概率字段。

## 品质等级，数值即 [member InventorySlot.quality] 与存档里的整数。
enum Grade {
	NORMAL,  ## 普通
	SILVER,  ## 银
	GOLD,    ## 金
}

## 等级数量。
const COUNT: int = 3

## 各等级的售价倍率，下标即 [enum Grade]。
const MULTIPLIERS: Array[float] = [1.0, 1.25, 1.6]

## 各等级的翻译键，下标即 [enum Grade]。
const LABEL_KEYS: Array[StringName] = [
	&"QUALITY_NORMAL", &"QUALITY_SILVER", &"QUALITY_GOLD"
]

## 图标上显示的星数（0 颗不画）。
const STARS: Array[int] = [0, 1, 2]


## 把任意整数收敛到合法等级。
static func clamp_grade(value: int) -> int:
	return clampi(value, 0, COUNT - 1)


## 某等级的售价倍率。
static func price_multiplier(grade: int) -> float:
	return MULTIPLIERS[clamp_grade(grade)]


## 某等级的翻译键。
static func label_key(grade: int) -> StringName:
	return LABEL_KEYS[clamp_grade(grade)]


## 某等级在图标上画的星数。
static func stars(grade: int) -> int:
	return STARS[clamp_grade(grade)]


## 把基础价按品质放大；结果至少为 1（免得出现 0 元商品）。
static func adjusted_price(base_price: int, grade: int) -> int:
	if base_price <= 0:
		return 0
	return maxi(int(round(float(base_price) * price_multiplier(grade))), 1)


## 抽一次品质。
##
## [param silver_chance] 是"至少银"的概率，[param gold_chance] 是"金"的概率；
## 两者都由数据提供（作物写在 [CropData]，矿石写在 [FloraData]）。
## 先判金再判银，于是 gold_chance 更小时也不会被银抢先。
static func roll(
	rng: RandomNumberGenerator, silver_chance: float, gold_chance: float
) -> int:
	var chance: float = rng.randf() if rng != null else randf()
	if gold_chance > 0.0 and chance < gold_chance:
		return Grade.GOLD
	if silver_chance > 0.0 and chance < silver_chance:
		return Grade.SILVER
	return Grade.NORMAL


## 取两个等级里更好的那个（多件产物合并时用）。
static func best(a: int, b: int) -> int:
	return maxi(clamp_grade(a), clamp_grade(b))
