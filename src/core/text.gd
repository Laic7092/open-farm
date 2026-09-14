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


## 道具显示名。
static func item_name(item_id: StringName) -> String:
	var item := Database.get_item(item_id)
	if item == null:
		return String(item_id)
	return key(item.display_name_key)


## 工具显示名。
static func tool_name(tool_id: StringName) -> String:
	var tool := Database.get_tool(tool_id)
	if tool == null:
		return String(tool_id)
	return key(tool.display_name_key)


## 作物显示名。
static func crop_name(crop_id: StringName) -> String:
	var crop := Database.get_crop(crop_id)
	if crop == null:
		return String(crop_id)
	return key(crop.display_name_key)


## 动物显示名。
static func animal_name(animal_id: StringName) -> String:
	var data := Database.get_animal(animal_id)
	if data == null:
		return String(animal_id)
	return key(data.display_name_key)


## 畜舍显示名。
static func building_name(building_id: StringName) -> String:
	var data := Database.get_building(building_id)
	if data == null:
		return String(building_id)
	return key(data.display_name_key)


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
