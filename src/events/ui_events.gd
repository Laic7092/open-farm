class_name UiEvents
extends RefCounted
## UI / 交互域事件（由 [UiRoot] 持有）。
##
## UI 只订阅这里的事件，不反向持有玩法节点；请求类事件也通过同一对象发出，
## 保持单向广播。

## 玩家进入 / 离开可交互范围，[param prompt_key] 为空表示无提示。
signal interaction_prompt_changed(prompt_key: StringName)
## 请求 UI 播放一段对话。
signal dialogue_requested(dialogue: DialogueData)
## 对话开始 / 结束。
signal dialogue_started(dialogue: DialogueData)
signal dialogue_finished(dialogue: DialogueData)
## 对话翻到新的一句（逐字显示之前触发，供打字音效使用）。
signal dialogue_line_shown()
## 玩家在对话中做出了选择；副作用（好感 / 旗标）由发起方结算。
signal dialogue_choice_made(dialogue: DialogueData, choice: DialogueChoice)
## 请求打开商店。
signal shop_requested(shop_id: StringName)
## 商店开关。
signal shop_opened(shop: ShopData)
signal shop_closed()
## 一笔交易完成；[param is_purchase] 为 true 表示玩家买入。
signal transaction_completed(
item_id: StringName, count: int, total_price: int, is_purchase: bool
)
## 请求显示一条浮动提示。
signal notification_requested(text_key: StringName, args: Dictionary)
## 请求打开 / 关闭背包。
signal inventory_toggle_requested()
## 请求打开 / 关闭系统菜单。
signal pause_menu_toggle_requested()
## 触控控件（虚拟摇杆 / 屏幕按钮）开 / 关被改变。
signal touch_controls_toggled(enabled: bool)
## 请求打开博物馆图鉴。
signal museum_requested()
## 请求打开委托板。
signal commission_requested()
## 全局暂停状态变化（打开菜单 / 对话 / 商店时）。
signal game_paused_changed(paused: bool)
## 请求播放一条 UI 音效（UI 只发事件，由所在场景的 [SceneAudio] 订阅）。
signal ui_sound_requested(sound_id: StringName, pitch: float, volume_db: float)
