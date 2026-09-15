class_name WorldEvents
extends RefCounted
## 世界域事件（由 [WorldHost] 持有）。
##
## 天气、节日、事件与野生植被都属于“世界 / 日历”域；世界场景缓存复用后，
## 事件对象随宿主常驻，节点重新进入时再连接。

## 天气变化。
signal weather_changed(weather: Weather.Type)
## 今天要办某个节日（日结转播报，HUD 据此挂“今日节日”横幅）。
signal festival_day_started(festival_id: StringName)
## 玩家参加了某节日；[param affection] 为每位到场 NPC 得到的好感度。
signal festival_attended(festival_id: StringName, affection: int)
## 一次性事件被触发（[code]CalendarService[/code] 判定命中并结算完效果后发出）。
signal calendar_event_triggered(event_id: StringName)
## 世界各处自然冒出了一株新芽。
signal flora_spawned(cell: Vector2i, flora_id: StringName)
## 野生植被长到了新的阶段。
signal flora_grown(cell: Vector2i, stage: int)
## 野生植被被清除（[param amount] 为 0 表示这次什么也没掉）。
signal flora_cleared(
cell: Vector2i, flora_id: StringName, item_id: StringName, amount: int
)
