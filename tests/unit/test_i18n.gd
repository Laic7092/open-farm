extends GdUnitTestSuite
## i18n 规范的可执行版本。
##
## 文案按域拆成 [code]ui / content / dialogue[/code] 三个 CSV（见
## [code]AGENTS.md[/code]），拆开之后最容易漏的东西全在这里兜底：
## [br]- 每个 CSV 都要登记进 [code]project.godot[/code]（漏登记 = 整片文案变回 key）；
## [br]- 三个 CSV 之间不能有重复键（重复时结果取决于加载顺序）；
## [br]- 每行都必须"键 + 全部 locale"，值里的逗号不加引号会静默截断；
## [br]- 每个 locale 都要给全部键配文案；
## [br]- 数据 / 对话里引用的每个键都要在翻译表里存在（填内容时打错大小写会红）。

const I18N_DIR: String = "res://assets/i18n"
const LOCALES: Array[String] = ["zh_CN", "en"]


# ---------------------------------------------------------------- 登记与结构

## 每个 CSV 导入出的 [code].translation[/code] 都必须在项目设置里登记。
##
## [code]--import[/code] 只生成文件、不会改 [code]project.godot[/code]，
## 所以新增一个翻译 CSV 时最容易漏的就是这一步。
func test_every_csv_is_registered_as_translation() -> void:
	var registered := PackedStringArray(
		ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	)
	for csv_path: String in _csv_paths():
		for locale: String in LOCALES:
			var expected: String = "%s.%s.translation" % [csv_path.get_basename(), locale]
			assert_bool(registered.has(expected)).override_failure_message(
				"翻译资源 %s 没有登记进 project.godot 的 locale/translations" % expected
			).is_true()


## 同一个键只能出现在一个 CSV 里；重复时 [TranslationServer] 的取值取决于加载顺序。
func test_no_duplicate_keys_across_csvs() -> void:
	var owner: Dictionary[String, String] = {}
	for csv_path: String in _csv_paths():
		for key: String in _keys_of(csv_path):
			assert_bool(owner.has(key)).override_failure_message(
				"翻译键 %s 同时出现在 %s 与 %s" % [key, owner.get(key, ""), csv_path]
			).is_false()
			owner[key] = csv_path


## 每行字段数必须等于"键 + locale 数"。
##
## 用 [method FileAccess.get_csv_line] 解析（它会识别双引号），所以值里未加引号的
## ASCII 逗号会多切出一列，在这里当场变红，而不是在游戏里静默截断。
func test_every_row_has_one_field_per_column() -> void:
	var expected: int = LOCALES.size() + 1
	for csv_path: String in _csv_paths():
		var file := FileAccess.open(csv_path, FileAccess.READ)
		assert_object(file).override_failure_message("打不开 %s" % csv_path).is_not_null()
		if file == null:
			continue
		var line_number: int = 0
		while not file.eof_reached():
			var row := file.get_csv_line()
			line_number += 1
			if row.size() == 1 and row[0] == "":
				continue
			assert_int(row.size()).override_failure_message(
				"%s 第 %d 行有 %d 列（应为 %d）：值里的逗号必须用双引号包起来"
				% [csv_path, line_number, row.size(), expected]
			).is_equal(expected)
		file.close()


## 每个 locale 都要给 CSV 里的全部键配好非空文案。
func test_every_locale_defines_every_key() -> void:
	for csv_path: String in _csv_paths():
		var keys := _keys_of(csv_path)
		for locale: String in LOCALES:
			var path: String = "%s.%s.translation" % [csv_path.get_basename(), locale]
			var translation := load(path) as Translation
			assert_object(translation).override_failure_message("缺少 %s" % path).is_not_null()
			if translation == null:
				continue
			for key: String in keys:
				assert_str(String(translation.get_message(key))).override_failure_message(
					"%s 缺少 %s 的文案（键 %s）" % [path, locale, key]
				).is_not_empty()


## 数据资源与对话里引用的每个翻译键都必须在翻译表里登记。
##
## 对话键有一部分是 [code]build_dialogues.gd[/code] 里字符串拼出来的，grep 查不全，
## 所以只能在运行时拿真实生成的资源来对账。
func test_every_referenced_key_is_defined() -> void:
	var defined: Dictionary[String, bool] = {}
	for csv_path: String in _csv_paths():
		for key: String in _keys_of(csv_path):
			defined[key] = true

	var missing := PackedStringArray()
	for key: StringName in _referenced_keys():
		if not defined.has(String(key)):
			missing.append(String(key))
	assert_array(missing).override_failure_message(
		"数据引用了 %d 个未登记的翻译键：%s（新增文案要写进 assets/i18n/*.csv）"
		% [missing.size(), ", ".join(missing)]
	).is_empty()


# ---------------------------------------------------------------- 内部

## 翻译目录下的所有 CSV（按名排序，报错顺序稳定）。
func _csv_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(I18N_DIR)
	if dir == null:
		return paths
	for file_name: String in dir.get_files():
		if file_name.get_extension().to_lower() == "csv":
			paths.append(I18N_DIR.path_join(file_name))
	paths.sort()
	return paths


## 一个 CSV 里除表头外的全部键。
func _keys_of(csv_path: String) -> Array[String]:
	var keys: Array[String] = []
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()  # 表头
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		if not row.is_empty() and not row[0].is_empty():
			keys.append(row[0])
	file.close()
	return keys


## 数据资源与对话引用的全部翻译键（空键不计）。
func _referenced_keys() -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for item_id: StringName in Database.items():
		var item := Database.get_item(item_id)
		seen[item.display_name_key] = true
		seen[item.description_key] = true
	for tool_id: StringName in Database.tools():
		seen[Database.get_tool(tool_id).display_name_key] = true
	for crop_id: StringName in Database.crops():
		seen[Database.get_crop(crop_id).display_name_key] = true
	for animal_id: StringName in Database.animals():
		seen[Database.get_animal(animal_id).display_name_key] = true
	for building_id: StringName in Database.buildings():
		seen[Database.get_building(building_id).display_name_key] = true
	for flora_id: StringName in Database.floras():
		seen[Database.get_flora(flora_id).display_name_key] = true
	for shop_id: StringName in Database.shops():
		seen[Database.get_shop(shop_id).display_name_key] = true
	for festival_id: StringName in Database.festivals():
		seen[Database.get_festival(festival_id).display_name_key] = true
	for npc_id: StringName in Database.npcs():
		seen[Database.get_npc(npc_id).display_name_key] = true
	for event_id: StringName in Database.events():
		var event := Database.get_event(event_id)
		seen[event.title_key] = true
		seen[event.message_key] = true
	for game_id: StringName in Database.festival_games():
		seen[Database.get_festival_game(game_id).display_name_key] = true
	for recipe_id: StringName in Database.recipes():
		seen[Database.get_recipe(recipe_id).display_name_key] = true
	for goal_id: StringName in Database.village_goals():
		var goal := Database.get_village_goal(goal_id)
		seen[goal.title_key] = true
		seen[goal.description_key] = true
	for dialogue_id: StringName in Database.dialogues():
		var dialogue := Database.get_dialogue(dialogue_id)
		seen[dialogue.speaker_key] = true
		for line: DialogueLine in dialogue.lines:
			seen[line.speaker_key] = true
			seen[line.text_key] = true
			for choice: DialogueChoice in line.choices:
				seen[choice.text_key] = true

	var keys: Array[StringName] = []
	for key: StringName in seen:
		if key != &"":
			keys.append(key)
	keys.sort()
	return keys
