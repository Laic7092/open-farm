class_name MineStratumData
extends Resource
## 矿洞矿层：把 1–100 层切成若干「有名字、有颜色、掉落偏好不同」的区段。
##
## 纯数据；[MineFloor] 按当前深度从 [Database] 取所属矿层，用它给画面调色、
## 调整矿石数量与深层掉落。加一层矿层只是往 [code]res://data/mine/[/code]
## 丢一个资源，不需要改脚本。

## 矿层标识（[Database] 索引键）。
@export var id: StringName = &""
## 名称翻译键，例如 [code]MINE_STRATUM_IRON[/code]（见 [code]assets/i18n/content.csv[/code]）。
@export var display_name_key: StringName = &""
## 起始深度（含）。
@export_range(1, 200) var depth_min: int = 1
## 结束深度（含）。
@export_range(1, 200) var depth_max: int = 1
## 环境光染色（与昼夜 / 天气相乘）；越深越暗、越偏冷或偏红。
@export var tint: Color = Color(1, 1, 1)
## 深层矿石的权重加成，见 [method MineRules.pick_ore] 的 [code]loot_bias[/code]。
@export_range(0.0, 8.0, 0.1) var loot_bias: float = 1.0
## 每层在 [method MineRules.ore_budget] 之上额外生成的矿石数量。
@export_range(0, 60) var ore_bonus: int = 0
## 品质概率的额外加成（叠加在 [method MineRules.quality_bonus] 上）。
@export_range(0.0, 1.0, 0.01) var quality_bonus: float = 0.0


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	if depth_min < 1 or depth_max < depth_min:
		problems.append("需要 depth_min >= 1 且 depth_max >= depth_min")
	if loot_bias < 0.0:
		problems.append("loot_bias 不能为负")
	return problems


## 这一层是否在矿层覆盖的深度范围内。
func covers(depth: int) -> bool:
	return depth >= depth_min and depth <= depth_max
