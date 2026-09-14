@tool
class_name NpcData
extends Resource
## NPC 的静态定义：身份、住处、常驻对白与商店关联。

## 唯一标识。
@export var id: StringName = &""
## 名字翻译键。
@export var display_name_key: StringName = &""
## 立绘 / 头像。
@export var portrait: Texture2D
## 默认对白。
@export var default_dialogue: DialogueData
## 按季节覆盖的对白（键为 [enum Season.Type] 的整数）。
@export var seasonal_dialogue: Dictionary = {}
## 该 NPC 经营的商店；留空表示不是商人。
@export var shop_id: StringName = &""
## 好感度上限。
@export_range(0, 255) var max_affection: int = 255
## 移动速度（像素/秒）。
@export_range(0.0, 200.0) var move_speed: float = 24.0


## 该 NPC 是否为商人。
func is_merchant() -> bool:
	return shop_id != &""


## 指定季节下应使用的对白。
func dialogue_for_season(season: Season.Type) -> DialogueData:
	var override: Variant = seasonal_dialogue.get(int(season), null)
	if override is DialogueData:
		return override
	return default_dialogue


## 数据自检；返回空数组表示通过。
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("id 不能为空")
	if display_name_key == &"":
		problems.append("display_name_key 不能为空")
	return problems


func _to_string() -> String:
	return "NpcData(%s)" % id
