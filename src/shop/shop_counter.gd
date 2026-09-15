class_name ShopCounter
extends Interactable
## 商店柜台：老板到岗时，站在柜台前按 E 直接开店。
##
## 把"买东西"和"聊天"拆成两个交互面：
## [br]- 柜台区域（本节点）→ 开店；
## [br]- 老板本体（[Npc]）→ 普通对白。
## 于是玩家绕开柜台、从侧面或背后走到老板身边，仍然能正常交谈，
## 不会像以前那样"想说话却先被拉进商店"。
##
## 柜台只在[b]老板真的在岗[/b]时可用：日程 [code]activity == "shop"[/code]、
## 已经走到岗位、且人就在柜台附近。老板去吃饭或参加节日时柜台自动打烊。

## 本柜台卖的是哪家店（[ShopData.id]）。
@export var shop_id: StringName = &""
## 站在柜台后面的老板（[NpcData.id]）；用 id 关联，场景重排不用改引用。
@export var clerk_id: StringName = &""
## 老板离柜台多远以内算"在岗"（像素）。
@export_range(0.0, 200.0) var max_distance: float = 48.0


func _ready() -> void:
	if prompt_key == &"PROMPT_INTERACT":
		prompt_key = &"PROMPT_SHOP"


## 老板是否在岗：上班 + 已到岗 + 站在柜台附近。
func is_staffed() -> bool:
	var clerk := _find_clerk()
	if clerk == null:
		return false
	return is_staffed_at(
		clerk.is_working(),
		clerk.is_moving(),
		clerk.global_position.distance_to(global_position),
		max_distance
	)


## 纯规则：上班中、没在路上、且在柜台附近，三件事都满足才算开张。
##
## 抽成静态函数是为了让"打烊条件"能脱离场景树被单元测试直接覆盖。
static func is_staffed_at(
	on_shift: bool, moving: bool, distance: float, max_distance: float
) -> bool:
	if not on_shift or moving:
		return false
	return distance <= max_distance


func can_interact() -> bool:
	if not super.can_interact() or shop_id == &"":
		return false
	return is_staffed()


func interact(actor: Node2D) -> void:
	if not can_interact():
		return
	super.interact(actor)
	EventBus.ui.shop_requested.emit(shop_id)


## 找到当值老板；找不到（或换到没有他的地图）时返回 null。
func _find_clerk() -> Npc:
	if clerk_id == &"" or not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.is_inside_tree() and npc.npc_id == clerk_id:
			return npc
	return null
