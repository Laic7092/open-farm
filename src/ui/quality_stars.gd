class_name QualityStars
extends HBoxContainer
## 品质星级：按 [enum QualityRules.Grade] 在图标角上点几颗星；0 级时整排隐藏。
##
## 抽成一个独立控件，是因为 HUD 的 22×22 小格与背包的 100×28 大格没有共同基类，
## 但都要在图标上标出银 / 金品质。

const STAR_TEXTURE: Texture2D = preload("res://assets/ui/star.png")
## 单颗星的边长；贴图是 12×12，这里缩到角落刚好不盖住道具。
const STAR_SIZE: float = UiLayout.QUALITY_STAR_SIZE


func _ready() -> void:
	add_theme_constant_override(&"separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index: int in QualityRules.COUNT - 1:
		var star := TextureRect.new()
		star.texture = STAR_TEXTURE
		star.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
	set_grade(QualityRules.Grade.NORMAL)


## 显示 [param grade] 级品质；普通（0 星）时整排隐藏。
func set_grade(grade: int) -> void:
	var count: int = QualityRules.stars(grade)
	for index: int in get_child_count():
		(get_child(index) as TextureRect).visible = index < count
	visible = count > 0
