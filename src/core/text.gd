class_name Text
extends RefCounted
## 文本与本地化工具。
##
## 全局唯一的"翻译键 → 显示文本"入口，避免 [code]tr()[/code] 散落各处、
## 也避免逻辑层直接拼中文。
## 占位符统一使用 [code]{name}[/code] 具名形式，配合 [method String.format]，
## 这样翻译人员可以自由调整语序。

## 翻译一个键；空键返回空串。
static func key(text_key: StringName) -> String:
	if text_key == &"":
		return ""
	return TranslationServer.translate(text_key)


## 翻译并填充占位符。
static func format(text_key: StringName, args: Dictionary = {}) -> String:
	var template := key(text_key)
	if args.is_empty():
		return template
	return template.format(args)


## 道具显示名；[param item] 为 null 时返回空串。
static func item_name(item: ItemData) -> String:
	return key(item.display_name_key) if item != null else ""


## 工具显示名；[param tool] 为 null 时返回空串。
static func tool_name(tool: ToolData) -> String:
	return key(tool.display_name_key) if tool != null else ""


## 作物显示名；[param crop] 为 null 时返回空串。
static func crop_name(crop: CropData) -> String:
	return key(crop.display_name_key) if crop != null else ""


## 动物显示名；[param data] 为 null 时返回空串。
static func animal_name(data: AnimalData) -> String:
	return key(data.display_name_key) if data != null else ""


## 畜舍显示名；[param data] 为 null 时返回空串。
static func building_name(data: BuildingData) -> String:
	return key(data.display_name_key) if data != null else ""


## 季节显示名。
static func season_name(season: Season.Type) -> String:
	return key(Season.name_key(season))


## 天气显示名。
static func weather_name(weather: Weather.Type) -> String:
	return key(Weather.name_key(weather))


## 日期显示文本。
static func date_text(date: GameDate) -> String:
	return format(&"DATE_FORMAT", {
		"year": date.year,
		"season": season_name(date.season),
		"day": date.day,
	})
