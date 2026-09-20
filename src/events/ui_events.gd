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
## 请求显示一条浮动提示。
signal notification_requested(text_key: StringName, args: Dictionary)
## 请求打开 / 关闭背包。
signal inventory_toggle_requested()
## 请求打开 / 关闭系统菜单。
signal pause_menu_toggle_requested()
## 系统菜单（暂停菜单）开 / 关。
## [br]与 [signal game_paused_changed] 不同：对话 / 商店等"世界内"模态也算暂停，
## 但只有系统菜单是真正的"挂起整局"，所以音频域只据此把 BGM 冻住。
signal pause_menu_toggled(opened: bool)
## 触控控件（虚拟摇杆 / 屏幕按钮）开 / 关被改变。
signal touch_controls_toggled(enabled: bool)
## 触控控件占用的左右两侧宽度（虚拟画布坐标；[code]x[/code] 左、[code]y[/code] 右），
## 关闭触控时为零向量。贴边 / 贴底的模态界面据此给内容让位，
## 避免被左下摇杆与右下 ABXY 压住。
signal touch_insets_changed(insets: Vector2)
## 相机缩放（画面大小）被改变；系统菜单发出，相机的主人（玩家）应用。
signal view_zoom_changed(zoom: float)
## 常驻 UI（HUD / 触控控件）缩放被改变；系统菜单发出，各自的界面主人应用。
signal ui_scale_changed(scale: float)
## 请求打开博物馆图鉴。
signal museum_requested()
## 请求打开委托板。
signal commission_requested()
## 请求打开料理台。
signal cooking_requested()
## 请求打开某个节日的小游戏（[param festival_id] 为正在进行的节日）。
signal festival_game_requested(festival_id: StringName)
## 请求打开长期村庄目标板。
signal village_goals_requested()
## 全局暂停状态变化（打开菜单 / 对话 / 商店时）。
signal game_paused_changed(paused: bool)
