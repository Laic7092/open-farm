class_name UpgradeBench
extends Interactable
## 铁匠铺的升级台：把手持工具升到下一级（铜 → 铁……）。
##
## 升级链与材料完全写在 [ToolData]（[member ToolData.next_id] /
## [member ToolData.upgrade_cost]），这里只做"查、扣、换"三件事，
## 因此新增一级工具不用改这个脚本。

var _profile: PlayerProfile


func bind_dependencies(profile: PlayerProfile, _clock: GameDateClock) -> void:
	_profile = profile


func _ready() -> void:
	prompt_key = &"PROMPT_UPGRADE"


func interact(actor: Node2D) -> void:
	super.interact(actor)
	var player := actor as Player
	if player == null or _profile == null:
		return

	var held: StringName = player.item_bar.selected_item_id()
	var item := Database.get_item(held)
	if item == null or item.category != ItemData.Category.TOOL:
		_notify(&"NOTIFY_UPGRADE_NEED_TOOL")
		return

	var tool := Database.get_tool(item.tool_id)
	var next_item := Database.get_item(tool.next_id) if tool != null else null
	if tool == null or tool.next_id == &"" or next_item == null:
		_notify(&"NOTIFY_TOOL_MAXED")
		return

	var cost: Dictionary = tool.upgrade_cost
	for key: Variant in cost:
		if not player.inventory.has(StringName(str(key)), int(cost[key])):
			_notify(&"NOTIFY_UPGRADE_MATERIALS")
			return
	if tool.upgrade_money > 0 and not _profile.spend(tool.upgrade_money):
		_notify(&"NOTIFY_UPGRADE_MONEY", {"amount": tool.upgrade_money})
		return

	for key: Variant in cost:
		player.inventory.remove(StringName(str(key)), int(cost[key]))
	player.inventory.remove(held, 1)
	player.inventory.add(tool.next_id, 1)
	var index: int = player.inventory.find_slot(tool.next_id)
	if index >= 0:
		player.item_bar.select(index)

	_notify(&"NOTIFY_TOOL_UPGRADED", {"tool": Text.item_name(next_item)})


func _notify(text_key: StringName, args: Dictionary = {}) -> void:
	EventBus.ui.notification_requested.emit(text_key, args)
