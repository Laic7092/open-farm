@tool
class_name TownGround
extends TileMapLayer
## 村庄地面：一条贯通东西的石板主街 + 南侧的广场、水塘、花园与牧场。
##
## 主街刻意压在地图的纵向中线上，宽三格：西口接农场、东口接集市，
## 从任意一端走进来，脚下的路与上一张地图的路在同一高度、同一宽度。
## 铺地手法全部来自 [GroundPainter]。

## 铺设区域（格子坐标）。
@export var ground_area: Rect2i = Rect2i(0, 0, 96, 60):
	set(value):
		ground_area = value
		if is_inside_tree():
			paint()


func _ready() -> void:
	paint()


## 用代码铺地。
func paint() -> void:
	clear()
	var origin := ground_area.position
	var center_row: int = origin.y + ground_area.size.y / 2

	GroundPainter.fill_grass(self, ground_area)

	# 主街：村里的房子全排在街北，街南留给广场与田地。
	GroundPainter.horizontal_road(
		self, origin.x, ground_area.end.x - 1, center_row, 1, GroundPainter.Style.STONE
	)

	# 南侧广场：石板铺开一片，水井与节日会场都在这里。
	GroundPainter.plaza(self, Rect2i(origin.x + 34, center_row + 6, 16, 8))
	# 南侧水塘。
	GroundPainter.water(self, Rect2i(origin.x + 21, center_row + 12, 7, 4), 2)

	# 从主街下到广场、花园、牧场、水塘的四条支路。
	GroundPainter.vertical_road(
		self, center_row + 2, center_row + 6, origin.x + 42, 1, GroundPainter.Style.STONE
	)
	GroundPainter.vertical_road(
		self, center_row + 2, center_row + 10, origin.x + 65, 1, GroundPainter.Style.STONE
	)
	GroundPainter.vertical_road(
		self, center_row + 2, center_row + 10, origin.x + 79, 1, GroundPainter.Style.STONE
	)
	GroundPainter.vertical_road(
		self, center_row + 2, center_row + 12, origin.x + 22, 0, GroundPainter.Style.STONE
	)

	# 花园：四垄花圃，垄间留草道，边上一片野花——花店门口的那片地。
	for row: int in 4:
		for column: int in 10:
			# 中间那条支路要从花园里穿过去，留给它一格宽的位置。
			if column >= 3 and column <= 5:
				continue
			if row % 2 == 1:
				# 垄间是草地，只在两头点缀野花。
				if column == 1 or column == 8:
					set_cell(
						Vector2i(origin.x + 61 + column, center_row + 7 + row * 2),
						FarmAtlas.SOURCE_ID,
						FarmAtlas.FLOWERS
					)
				continue
			var cell := Vector2i(origin.x + 61 + column, center_row + 7 + row * 2)
			var atlas: Vector2i = FarmAtlas.FLOWER_BED
			if (column * 3 + row) % 7 == 0:
				atlas = FarmAtlas.FLOWERS
			elif (column + row) % 5 == 0:
				atlas = FarmAtlas.FLOWER_RED
			set_cell(cell, FarmAtlas.SOURCE_ID, atlas)

	# 牧场：谷仓前踩秃的土场，只在边上掺一点碎石路。
	for cell: Vector2i in GridUtils.cells_in_area(
		Vector2i(origin.x + 76, center_row + 11), Vector2i(10, 7)
	):
		set_cell(cell, FarmAtlas.SOURCE_ID, FarmAtlas.DIRT)

	# 零散点缀：灌木、卵石与踩秃的草。
	GroundPainter.decorate(
		self,
		{
			Vector2i(origin.x + 6, center_row - 3): FarmAtlas.FLOWER_BED,
			Vector2i(origin.x + 7, center_row - 3): FarmAtlas.FLOWER_BED,
			Vector2i(origin.x + 88, center_row - 3): FarmAtlas.FLOWER_BED,
			Vector2i(origin.x + 89, center_row - 3): FarmAtlas.FLOWER_BED,
			Vector2i(origin.x + 20, center_row + 2): FarmAtlas.BUSH,
			Vector2i(origin.x + 52, center_row + 2): FarmAtlas.BUSH,
			Vector2i(origin.x + 92, center_row + 4): FarmAtlas.BUSH,
			Vector2i(origin.x + 30, center_row + 10): FarmAtlas.TALL_GRASS,
			Vector2i(origin.x + 18, center_row + 18): FarmAtlas.TALL_GRASS,
			Vector2i(origin.x + 56, center_row + 18): FarmAtlas.PEBBLE,
			Vector2i(origin.x + 70, center_row + 20): FarmAtlas.MUSHROOM,
			Vector2i(origin.x + 88, center_row + 20): FarmAtlas.PEBBLE,
			Vector2i(origin.x + 32, center_row + 16): FarmAtlas.FLOWERS,
			Vector2i(origin.x + 48, center_row + 14): FarmAtlas.FLOWER_RED,
			Vector2i(origin.x + 12, center_row + 22): FarmAtlas.STUMP_TILE,
			Vector2i(origin.x + 84, center_row + 22): FarmAtlas.BUSH,
		},
		ground_area
	)
	GroundPainter.transitions(self, ground_area)
