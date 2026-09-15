extends "res://tools/sample/sample_base.gd"
## animals：由 tools/generate_sample_data.gd 调用；公共工具在 sample_base.gd。

## 可畜养的动物 + 畜舍。
##
## 数值调法：
## [br]- [code]mature_days[/code] = 幼崽到成年需要喂几天
## [br]- [code]produce_days[/code] = 成年后每隔几天产出一次
## [br]- 不喂食不会死，只会掉好感度并停止产出
func build() -> void:
	# 鸡：3 天成年，之后每天一个鸡蛋，入门牲畜。
	var chicken := AnimalData.new()
	chicken.id = &"chicken"
	chicken.display_name_key = &"ANIMAL_CHICKEN"
	chicken.species = &"chicken"
	chicken.mature_days = 3
	chicken.produce_days = 1
	chicken.product_item_id = &"egg"
	chicken.product_amount = 1
	chicken.feed_item_id = &"hay"
	chicken.sprite_sheet = _animal_sheet(&"chicken")
	_save(chicken, ANIMAL_DIR.path_join("chicken.tres"))

	# 牛：更贵、更慢，但牛奶收益高，且高好感时更容易多产一瓶。
	var cow := AnimalData.new()
	cow.id = &"cow"
	cow.display_name_key = &"ANIMAL_COW"
	cow.species = &"cow"
	cow.mature_days = 5
	cow.produce_days = 2
	cow.product_item_id = &"milk"
	cow.product_amount = 1
	cow.feed_item_id = &"hay"
	cow.affection_per_pet = 3
	cow.bonus_product_chance = 0.35
	cow.sprite_sheet = _animal_sheet(&"cow")
	_save(cow, ANIMAL_DIR.path_join("cow.tres"))


## 取牲畜状态表。
func _animal_sheet(animal_id: StringName) -> Texture2D:
	return _texture(ANIMAL_SHEET_DIR.path_join("%s.png" % animal_id))
