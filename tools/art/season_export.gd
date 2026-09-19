extends RefCounted
## 季节变体的落盘规则（生成器共用）。
##
## 基础图写到基础路径；变体只在"与基础图逐像素不同"时才写变体路径——
## 这就是"没有覆盖的季节不产生重复素材"的唯一实现，
## 三个生成器不再各写一遍这段循环。
##
## 用法：
## [codeblock]
## const SeasonExport := preload("res://tools/art/season_export.gd")
## SeasonExport.write(path, _build_atlas)        # func(season) -> Image
## SeasonExport.write(path, _build_for.bind(id)) # 额外参数用 bind 绑在后面
## [/codeblock]

const Art := preload("res://tools/art/art_lib.gd")
const SeasonPalette := preload("res://src/art/season_palette.gd")


## 用 [param build] 画出各季节的图并落盘。
##
## [param build] 签名必须是 [code]func(season: Season.Type) -> Image[/code]：
## 基础一遍与变体一遍走同一段画法，形状因此逐像素一致。
static func write(base_path: String, build: Callable) -> void:
	var base_image: Image = build.call(SeasonPalette.BASE_SEASON)
	if base_image == null:
		return
	Art.save_png(base_image, base_path)
	for season: Season.Type in SeasonPalette.seasons_to_build():
		if season == SeasonPalette.BASE_SEASON:
			continue
		var image: Image = build.call(season)
		if image == null or image.get_data() == base_image.get_data():
			continue
		Art.save_png(image, SeasonPalette.variant_suffix_path(base_path, season))
