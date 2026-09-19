class_name SeasonPalette
extends RefCounted
## 季节外观的颜色与路径映射表。
##
## 生成脚本（[code]tools/art/generate_*.gd[/code]）按季节重画同一套像素画，
## 运行时（[code]SeasonLook[/code] / [code]Flora[/code] / [code]WorldProp[/code]）
## 按季节换贴图，两边都从这里取色 / 取路径，
## 于是"冬季是什么颜色、哪些季节有变体"只有一处定义。
##
## [b]基础季[/b]：春 / 夏 / 秋目前都没有覆盖，一律回退到 [constant BASE_SEASON]
## 的那套颜色，因此它们不产生任何新素材文件（这就是"占位语义"）。
## 新增一个季节的换色时：先在 [ArtPalette] 里起颜色常量，再往 [constant OVERRIDES]
## 填表，最后重跑 [code]./tools/build_assets.sh[/code]。
##
## [b]规范[/b]：本文件只做映射，不出现任何颜色字面量；颜色一律来自 [ArtPalette]。
## 材质名与画法一一对应，生成器里把 [code]P.X[/code] 换成 [code]_mat(&"x")[/code]
## 时不能取到表里没有的名字。

## 基础贴图用哪一遍画：春 / 夏 / 秋都没有覆盖，所以三者共用基础图。
const BASE_SEASON: Season.Type = Season.Type.SPRING

## 材质名 → [base, dark, light] 三档颜色。
##
## 基础一遍的取色就来自这里，所以"基础季的输出与改动前逐像素相同"
## 是由这张表保证的，而不是靠生成器碰巧写对。
const MATERIALS: Dictionary = {
	&"grass": [ArtPalette.GRASS, ArtPalette.GRASS_DARK, ArtPalette.GRASS_LIGHT],
	&"leaf": [ArtPalette.LEAF, ArtPalette.LEAF_DARK, ArtPalette.LEAF_LIGHT],
	&"dirt": [ArtPalette.DIRT, ArtPalette.DIRT_DARK, ArtPalette.SAND],
	&"sand": [ArtPalette.SAND, ArtPalette.SAND_DARK, ArtPalette.PATH_LIGHT],
	&"gravel": [ArtPalette.GRAVEL, ArtPalette.GRAVEL_DARK, ArtPalette.STONE_LIGHT],
	&"path": [ArtPalette.PATH, ArtPalette.PATH_DARK, ArtPalette.PATH_LIGHT],
	&"path_stone": [ArtPalette.PATH, ArtPalette.PATH_DARK, ArtPalette.GRAVEL],
	&"stone": [ArtPalette.STONE, ArtPalette.STONE_DARK, ArtPalette.STONE_LIGHT],
	&"cliff": [ArtPalette.STONE_DARK, ArtPalette.STONE, ArtPalette.STONE_LIGHT],
	&"soil": [ArtPalette.SOIL, ArtPalette.SOIL_DARK, ArtPalette.SOIL_LIGHT],
	&"soil_wet": [
		ArtPalette.SOIL_WET, ArtPalette.SOIL_WET_DARK, ArtPalette.SOIL_WET_LIGHT
	],
}

## 季节 → { 材质名 → [base, dark, light] }。
##
## 没有覆盖（空字典）的季节 = 与基础图逐像素相同：不产文件、运行时回退基础图。
## 冬季只换色，不换画法，所以形状与透明度掩码与基础图完全一致。
const OVERRIDES: Dictionary = {
	Season.Type.SPRING: {},
	Season.Type.SUMMER: {},
	Season.Type.FALL: {},
	Season.Type.WINTER: {
		&"grass": [
			ArtPalette.WINTER_GRASS, ArtPalette.WINTER_GRASS_DARK,
			ArtPalette.WINTER_GRASS_LIGHT
		],
		&"leaf": [
			ArtPalette.WINTER_LEAF, ArtPalette.WINTER_LEAF_DARK,
			ArtPalette.WINTER_LEAF_LIGHT
		],
		&"dirt": [
			ArtPalette.WINTER_DIRT, ArtPalette.WINTER_DIRT_DARK,
			ArtPalette.WINTER_DIRT_LIGHT
		],
		&"sand": [
			ArtPalette.WINTER_SAND, ArtPalette.WINTER_SAND_DARK,
			ArtPalette.WINTER_SAND_LIGHT
		],
		&"gravel": [
			ArtPalette.WINTER_GRAVEL, ArtPalette.WINTER_GRAVEL_DARK,
			ArtPalette.WINTER_GRAVEL_LIGHT
		],
		&"path": [
			ArtPalette.WINTER_PATH, ArtPalette.WINTER_PATH_DARK,
			ArtPalette.WINTER_PATH_LIGHT
		],
		&"path_stone": [
			ArtPalette.WINTER_PATH_STONE, ArtPalette.WINTER_PATH_STONE_DARK,
			ArtPalette.WINTER_PATH_STONE_LIGHT
		],
		&"stone": [
			ArtPalette.WINTER_STONE, ArtPalette.WINTER_STONE_DARK,
			ArtPalette.WINTER_STONE_LIGHT
		],
		&"cliff": [
			ArtPalette.WINTER_CLIFF, ArtPalette.WINTER_STONE,
			ArtPalette.WINTER_STONE_LIGHT
		],
		&"soil": [
			ArtPalette.WINTER_SOIL, ArtPalette.WINTER_SOIL_DARK,
			ArtPalette.WINTER_SOIL_LIGHT
		],
		&"soil_wet": [
			ArtPalette.WINTER_SOIL_WET, ArtPalette.WINTER_SOIL_WET_DARK,
			ArtPalette.WINTER_SOIL_WET_LIGHT
		],
	},
}

## [method variant_path] 的存在性查询结果缓存；键是 [code]"季节键|基础路径"[/code]。
static var _path_cache: Dictionary = {}


## 这个季节有没有独立素材。基础季与非覆盖季都返回 [code]false[/code]。
static func has_variant(season: Season.Type) -> bool:
	if season == BASE_SEASON:
		return false
	var override: Dictionary = OVERRIDES.get(season, {})
	return not override.is_empty()


## 生成顺序：基础一遍 + 所有有覆盖的季节。生成器直接遍历它。
static func seasons_to_build() -> Array[Season.Type]:
	var result: Array[Season.Type] = [BASE_SEASON]
	for season: Season.Type in Season.all():
		if has_variant(season):
			result.append(season)
	return result


## 全部材质名，供测试断言"覆盖表不漏材质"。
static func material_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for name: StringName in MATERIALS:
		names.append(name)
	return names


## 某个季节某个材质的三档颜色；未覆盖时回退基础色（保证基础一遍逐像素不变）。
static func material(season: Season.Type, name: StringName) -> PackedColorArray:
	var result := PackedColorArray()
	var triple: Variant = (OVERRIDES.get(season, {}) as Dictionary).get(name)
	if triple == null:
		triple = MATERIALS.get(name)
	if triple == null:
		return result
	var colors: Array = triple
	for color: Color in colors:
		result.append(color)
	return result


## 基础材质色的全集，供素材测试扫描"冬季图里不该再出现基础色"。
static func base_colors() -> Array[Color]:
	var result: Array[Color] = []
	for name: StringName in MATERIALS:
		var colors: Array = MATERIALS[name]
		for color: Color in colors:
			result.append(color)
	return result


## 变体文件的后缀：[code]""[/code] 或 [code]"_winter"[/code]（来自 [method Season.to_key]）。
static func file_suffix(season: Season.Type) -> String:
	if not has_variant(season):
		return ""
	return "_%s" % Season.to_key(season)


## 不做存在性检查的变体路径。生成器用它决定"往哪写"。
static func variant_suffix_path(base_path: String, season: Season.Type) -> String:
	var suffix := file_suffix(season)
	if suffix.is_empty():
		return base_path
	var dot := base_path.rfind(".")
	if dot <= base_path.rfind("/"):
		return base_path + suffix
	return "%s%s%s" % [base_path.substr(0, dot), suffix, base_path.substr(dot)]


## 变体路径；文件不存在时回退 [param base_path]。结果缓存，避免每帧 IO。
static func variant_path(base_path: String, season: Season.Type) -> String:
	var candidate := variant_suffix_path(base_path, season)
	if candidate == base_path:
		return base_path
	var key := "%s|%s" % [Season.to_key(season), base_path]
	if _path_cache.has(key):
		return _path_cache[key]
	var resolved: String = candidate if ResourceLoader.exists(candidate) else base_path
	_path_cache[key] = resolved
	return resolved


## 变体贴图；没有变体、或变体加载失败时回退 [param base]。
static func variant_texture(base: Texture2D, season: Season.Type) -> Texture2D:
	if base == null:
		return null
	var path := base.resource_path
	if path.is_empty():
		return base
	var resolved := variant_path(path, season)
	if resolved == path:
		return base
	var texture := ResourceLoader.load(resolved) as Texture2D
	return texture if texture != null else base
