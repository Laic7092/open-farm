class_name WeatherState
extends Resource
## 天气状态（Resource）。
##
## 只存放可存档的当日 / 明日天气；掷天气规则仍在纯静态的 [Weather]，
## 事件订阅与日结转仍由 [WeatherSystem] 服务负责。资源不认识 Autoload，
## 便于由 [Main] 持有或测试里单独 new。

## 今天的天气。
var current: Weather.Type = Weather.Type.SUNNY
## 明天的天气预报。
var forecast: Weather.Type = Weather.Type.SUNNY


func to_dict() -> Dictionary:
	return {
		"current": Weather.to_key(current),
		"forecast": Weather.to_key(forecast),
	}


func from_dict(data: Dictionary) -> void:
	current = Weather.from_key(str(data.get("current", "sunny")))
	forecast = Weather.from_key(str(data.get("forecast", "sunny")))
