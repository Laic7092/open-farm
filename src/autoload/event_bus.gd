extends Node
## 全局事件总线（Autoload：`EventBus`）。
##
## [b]为什么需要它[/b]：Godot 最佳实践建议"用信号而不是硬引用"，
## 但把信号连到[code]get_node("../../../HUD")[/code]这类长路径上同样脆弱。
## 事件总线把"谁发出"和"谁关心"彻底解耦：生产者只 emit，消费者只 connect，
## 双方都不需要知道对方是否存在。
##
## [b]使用约定[/b]
## [br]- 本脚本[b]只允许声明信号[/b]，不写任何逻辑与状态；
## [br]- 一对一的父子通信仍然直接用节点信号，不要绕道 EventBus；
## [br]- 需要"确定性执行顺序"的模拟逻辑请用 [method GameClock.register_day_hook]，
##   不要依赖信号连接顺序（信号回调顺序在 Godot 中不作保证）。

# ---------------------------------------------------------------- 时间 / 日历

## 游戏内分钟推进（用于时钟 UI 刷新）。
signal minute_changed(hour: int, minute: int)
## 整点。
signal hour_changed(hour: int)
## 日期推进（季节 / 年份变化时也会先发对应信号再发本信号）。
signal day_changed(date: GameDate)
## 季节变化。
signal season_changed(season: Season.Type)
## 年份变化。
signal year_changed(year: int)
## 天气变化。
signal weather_changed(weather: Weather.Type)

# ---------------------------------------------------------------- 玩家

## 体力变化。
signal stamina_changed(current: int, maximum: int)
## 体力归零（需要昏倒 / 强制回家）。
signal stamina_depleted()
## 金钱变化；[param delta] 为本次增量。
signal money_changed(money: int, delta: int)
## 背包内容变化。
signal inventory_changed()
## 背包已满，新物品放不下。
signal inventory_full(item_id: StringName)
## 当前手持工具切换。
signal tool_changed(tool_id: StringName, index: int)
## 玩家朝向变化。
signal player_facing_changed(direction: Facing.Direction)

# ---------------------------------------------------------------- 农场

## 成功翻地。
signal tile_tilled(cell: Vector2i)
## 成功浇水。
signal tile_watered(cell: Vector2i)
## 播种成功。
signal crop_planted(cell: Vector2i, crop_id: StringName)
## 作物生长阶段变化。
signal crop_stage_changed(cell: Vector2i, stage: int)
## 收获成功。
signal crop_harvested(cell: Vector2i, item_id: StringName, amount: int)
## 作物枯死。
signal crop_died(cell: Vector2i)
## 使用了工具（含失败尝试，用于播放动画/音效反馈）。
signal tool_used(tool_id: StringName, cell: Vector2i, success: bool)

# ---------------------------------------------------------------- 畜牧

## 一头牲畜被安置进畜舍。
signal animal_placed(building_id: StringName, animal_id: StringName)
## 畜舍被喂食，[param count] 为吃上饭的牲畜数。
signal animal_fed(building_id: StringName, count: int)
## 牲畜被抚摸，[param affection] 为抚摸后的好感度。
signal animal_petted(building_id: StringName, animal_id: StringName, affection: int)
## 收到畜产品。
signal animal_product_collected(
	building_id: StringName, animal_id: StringName, item_id: StringName, amount: int
)
## 牲畜长大成年。
signal animal_matured(building_id: StringName, animal_id: StringName)

# ---------------------------------------------------------------- 好感度 / 恋爱

## NPC 好感度变化；[param delta] 为本次增量。
signal npc_affection_changed(npc_id: StringName, affection: int, delta: int)
## NPC 关系阶段变化（单身的 [enum AffectionRules.Status] 数值）。
signal npc_relationship_changed(npc_id: StringName, status: int)
## 向 NPC 送出礼物（[param gain] 为好感度收益，可能为负）。
signal npc_gift_given(npc_id: StringName, item_id: StringName, gain: int)
## 玩家结婚。
signal player_married(spouse_id: StringName)
## 孩子出生。
signal child_born(child_id: StringName)

# ---------------------------------------------------------------- 节日 / 事件

## 今天要办某个节日（日结转播报，HUD 据此挂"今日节日"横幅）。
signal festival_day_started(festival_id: StringName)
## 玩家参加了某节日；[param affection] 为每位到场 NPC 得到的好感度。
signal festival_attended(festival_id: StringName, affection: int)
## 一次性事件被触发（[code]Calendar[/code] 判定命中并结算完效果后发出）。
signal calendar_event_triggered(event_id: StringName)

# ---------------------------------------------------------------- 野生植被

## 世界各处自然冒出了一株新芽。
signal flora_spawned(cell: Vector2i, flora_id: StringName)
## 野生植被长到了新的阶段。
signal flora_grown(cell: Vector2i, stage: int)
## 野生植被被清除（[param amount] 为 0 表示这次什么也没掉）。
signal flora_cleared(
	cell: Vector2i, flora_id: StringName, item_id: StringName, amount: int
)

# ---------------------------------------------------------------- 交互 / 对话 / 商店

## 玩家进入 / 离开可交互范围，[param prompt_key] 为空表示无提示。
signal interaction_prompt_changed(prompt_key: StringName)
## 请求 UI 播放一段对话。
signal dialogue_requested(dialogue: DialogueData)
## 对话开始 / 结束。
signal dialogue_started(dialogue: DialogueData)
signal dialogue_finished(dialogue: DialogueData)
## 对话翻到新的一句（逐字显示之前触发，供打字音效使用）。
signal dialogue_line_shown()
## 请求打开商店。
signal shop_requested(shop_id: StringName)
## 商店开关。
signal shop_opened(shop: ShopData)
signal shop_closed()
## 一笔交易完成；[param is_purchase] 为 true 表示玩家买入。
signal transaction_completed(
	item_id: StringName, count: int, total_price: int, is_purchase: bool
)

# ---------------------------------------------------------------- 存档 / 场景

## 存档 / 读档完成。
signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
## 场景切换开始 / 结束。
signal scene_transition_started(target: StringName)
signal scene_transition_finished(target: StringName)
## 进入某个世界场景（包括从缓存里重新挂载）。音频等"按地图切换"的系统订阅它。
signal world_entered(world_id: StringName)

# ---------------------------------------------------------------- UI / 系统

## 请求显示一条浮动提示。
##
## [param args] 为具名占位符表，会交给 [method String.format] 填充，
## 例如 [code]{"item": "萝卜", "count": 3}[/code] 对应文案 "收获了 {item} ×{count}"。
signal notification_requested(text_key: StringName, args: Dictionary)
## 请求打开 / 关闭背包。
signal inventory_toggle_requested()
## 请求打开 / 关闭系统菜单。
signal pause_menu_toggle_requested()
## 全局暂停状态变化（打开菜单 / 对话 / 商店时）。
signal game_paused_changed(paused: bool)
