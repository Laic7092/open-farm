class_name FarmEvents
extends RefCounted
## 农场域事件（由组合根持有的生产 / 畜牧发布者使用）。
##
## 作物、农田、畜牧节点只通过这个对象广播状态变化；UI / 音频等观察者由节点
## 在 [code]_enter_tree()[/code] 连接、[code]_exit_tree()[/code] 断开，避免
## 资源对象持有场景节点造成生命周期泄漏。

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
## 使用了工具（含失败尝试，用于播放动画 / 音效反馈）。
signal tool_used(tool_id: StringName, cell: Vector2i, success: bool)
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
