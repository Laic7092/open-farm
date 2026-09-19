extends "res://tools/sample/sample_base.gd"
## mine_strata：矿洞矿层数据（由 tools/generate_sample_data.gd 调用）。
##
## 把 1–100 层切成 5 段。越深环境光越暗、越偏冷（到深渊偏紫黑），
## 同时深层矿石权重 / 数量 / 品质加成越高，让「越深越好」不只是数值上的一行注释。
##
## 调法：改这里的深度区间与 [member MineStratumData.tint]，
## 再跑 [code]godot --headless --path . -s res://tools/generate_sample_data.gd[/code]。


func build() -> void:
	_stratum(&"moss", &"MINE_STRATUM_MOSS", 1, 19, Color(0.94, 0.98, 0.94), 1.0, 0, 0.0)
	_stratum(&"iron", &"MINE_STRATUM_IRON", 20, 39, Color(0.88, 0.84, 0.78), 2.0, 4, 0.02)
	_stratum(
		&"crystal", &"MINE_STRATUM_CRYSTAL", 40, 59, Color(0.76, 0.82, 0.98), 3.0, 8, 0.05
	)
	_stratum(&"magma", &"MINE_STRATUM_MAGMA", 60, 79, Color(0.98, 0.78, 0.70), 4.0, 12, 0.08)
	_stratum(&"abyss", &"MINE_STRATUM_ABYSS", 80, 100, Color(0.68, 0.68, 0.86), 5.0, 16, 0.12)


func _stratum(
	stratum_id: StringName,
	name_key: StringName,
	min_depth: int,
	max_depth: int,
	tint: Color,
	loot_bias: float,
	ore_bonus: int,
	quality_bonus: float
) -> void:
	var data := MineStratumData.new()
	data.id = stratum_id
	data.display_name_key = name_key
	data.depth_min = min_depth
	data.depth_max = max_depth
	data.tint = tint
	data.loot_bias = loot_bias
	data.ore_bonus = ore_bonus
	data.quality_bonus = quality_bonus
	_save(data, MINE_DIR.path_join("%s.tres" % stratum_id))
