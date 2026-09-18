class_name WaterLayout
extends RefCounted
## 每张地图的水体清单：形状 + 水域类型 + 碰撞要挖掉的通道。
##
## 这里是水面的[b]唯一事实来源[/b]：
## [br]- 构建期 [code]tools/art/generate_water.gd[/code] 按它烘水体贴图
## [br]- 运行期 [class WaterField] 按它建碰撞、判"哪一格是水"、画波光
##
## 地图脚本因此不再自己铺水面瓦片——只要在这里登记一片水，图上就有一片水；
## 想改岸线就改形状，想加一张有水的地图就在这里加一条。多片水（池塘 + 海）
## 各自带自己的 [enum WaterKind.Kind]，钓鱼按格取类型，天生支持一图多水域。

## 水体贴图目录。文件名 = [code]<map>_<下标>.png[/code]。
const DIR: String = "res://assets/sprites/water"
## 贴图四周的留白（像素）：给岸边浪花留画布，免得贴图把水边裁掉。
const MARGIN: int = 4

## 海滩木栈桥的落脚范围（世界像素）：桥面架在水上，碰撞要在这里挖空。
## 高度故意超出海面下缘，让"海减栈桥"切得干净（否则切口悬在水中间）。
const BEACH_PIER := Rect2(288.0, 288.0, 64.0, 240.0)


## 一片水：一条闭合折线 + 它是什么水。
class Body extends RefCounted:
	## 水域类型；见 [enum WaterKind.Kind]。
	var kind: int = WaterKind.Kind.POND
	## 闭合折线（世界坐标、像素），见 [WaterShape]。
	var outline: PackedVector2Array = PackedVector2Array()
	## 碰撞要挖掉的矩形（栈桥 / 码头）；只影响碰撞，不影响外观。
	var walkways: Array[Rect2] = []

	func _init(
		p_outline: PackedVector2Array, p_kind: int, p_walkways: Array[Rect2] = []
	) -> void:
		outline = p_outline
		kind = p_kind
		walkways = p_walkways

	## 贴图覆盖的整数像素范围（含 [constant WaterLayout.MARGIN]）。
	func pixel_bounds() -> Rect2i:
		return WaterShape.pixel_bounds(outline, MARGIN)


## 有水域的地图；[code]tests/unit/test_assets.gd[/code] 与生成器都按它遍历。
static func worlds() -> Array[StringName]:
	return [&"town", &"twon", &"beach"]


## 这张地图有没有水面。
static func has_water(world_id: StringName) -> bool:
	return worlds().has(world_id)


## 这张地图上的全部水体。
static func bodies_for(world_id: StringName) -> Array[Body]:
	match world_id:
		&"town":
			return [_market_pond()]
		&"twon":
			return [_village_pond()]
		&"beach":
			return [_ocean()]
	return []


## 水体贴图路径；[param index] 是 [method bodies_for] 里的下标。
static func sprite_path(world_id: StringName, index: int) -> String:
	return DIR.path_join("%s_%d.png" % [world_id, index])


# ---------------------------------------------------------------- 各图水体

## 集市（[code]town.tscn[/code]）南侧的水塘。
##
## 旧版是 (4,19) 起 7×4 格的方池；这里把它换成同样落位的自然水塘，
## 外接范围不变，所以周围的广场、支路都不用挪。
static func _market_pond() -> Body:
	var center := Vector2(120.0, 336.0)
	return Body.new(
		WaterShape.blob(center, 50.0, 27.0, 0.09, 11), WaterKind.Kind.POND
	)


## 村庄（[code]twon.tscn[/code]）南侧的河沟水塘，旧版是 (21,42) 起 7×4 格。
static func _village_pond() -> Body:
	var center := Vector2(392.0, 704.0)
	return Body.new(
		WaterShape.blob(center, 50.0, 27.0, 0.09, 23), WaterKind.Kind.POND
	)


## 海滩下方的开阔海面：横贯整张图的最下 8 行，上缘就是浪线。
##
## 形状故意向左右下三面伸出地图外：那三面是"水继续淌下去"，
## 不该被画成岸（否则地图边缘会冒出一圈浪花与浅滩）。
## 木栈桥在水上，所以碰撞要在桥面处挖空——不开这条通道，玩家会被海拦住上不了桥。
static func _ocean() -> Body:
	var shore := Rect2(-48.0, 288.0, 736.0, 224.0)
	var walkways: Array[Rect2] = [BEACH_PIER]
	return Body.new(WaterShape.rectangle(shore), WaterKind.Kind.OCEAN, walkways)
