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
## 行走 / 待机动画：[code]assets/sprites/actors/npc_<id>_frames.tres[/code]。
##
## 放在数据里而不是场景里，是为了让"这个 NPC 长什么样"跟着身份走——
## 同一个 [code]npc.tscn[/code] 实例换一个 [member id] 就换一张脸。
@export var frames: SpriteFrames
## 默认对白。
@export var default_dialogue: DialogueData
## 按季节覆盖的对白（键为 [enum Season.Type] 的整数）。
@export var seasonal_dialogue: Dictionary = {}
## 每日日程；留空表示原地站桩（旧数据 / 特殊 NPC）。
@export var schedule: NpcSchedule
## 该 NPC 经营的商店；留空表示不是商人。
@export var shop_id: StringName = &""
## 好感度上限。
@export_range(0, 255) var max_affection: int = 255
## 移动速度（像素/秒）。
@export_range(0.0, 200.0) var move_speed: float = 24.0

# ---------------------------------------------------------------- 恋爱 / 婚姻

## 是否可以作为恋爱与结婚对象（小孩、纯商人不填）。
@export var romanceable: bool = false
## 可以表白所需的好感度。
@export_range(0, 255) var confession_affection: int = 200
## 可以结婚所需的好感度。
@export_range(0, 255) var marriage_affection: int = 250
## 最爱的礼物（好感度收益最高）。
@export var loved_gifts: Array[StringName] = []
## 喜欢的礼物。
@export var liked_gifts: Array[StringName] = []
## 讨厌的礼物（送礼会掉好感）。
@export var disliked_gifts: Array[StringName] = []
## 好感度达到朋友档后使用的对白。
@export var friend_dialogue: DialogueData
## 交往期间使用的对白。
@export var lover_dialogue: DialogueData
## 婚后使用的对白。
@export var married_dialogue: DialogueData
## 表白时播放的对白（播放结束后正式交往）。
@export var confession_dialogue: DialogueData
## 求婚时播放的对白（播放结束后正式结婚并消耗信物）。
@export var proposal_dialogue: DialogueData


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
	if schedule != null:
		for problem: String in schedule.validate():
			problems.append("schedule：%s" % problem)
	if romanceable:
		if confession_affection > marriage_affection:
			problems.append("表白门槛不能高于结婚门槛")
		if marriage_affection > max_affection:
			problems.append("结婚门槛不能高于好感度上限")
		if (
			confession_dialogue == null
			or proposal_dialogue == null
			or lover_dialogue == null
			or married_dialogue == null
		):
			problems.append("可攻略 NPC 必须填写表白 / 求婚 / 恋人 / 婚后对白")
	if friend_dialogue != null and friend_dialogue.is_empty():
		problems.append("朋友对白不能为空")
	_check_gift_lists(problems)
	return problems


## 同一个礼物不能同时出现在两个偏好列表里，否则收益取决于判定顺序。
func _check_gift_lists(problems: PackedStringArray) -> void:
	for item_id: StringName in loved_gifts:
		if liked_gifts.has(item_id) or disliked_gifts.has(item_id):
			problems.append("礼物 %s 同时出现在多个偏好列表" % item_id)
	for item_id: StringName in liked_gifts:
		if disliked_gifts.has(item_id):
			problems.append("礼物 %s 同时出现在多个偏好列表" % item_id)


func _to_string() -> String:
	return "NpcData(%s)" % id
