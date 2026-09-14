class_name AtlasLayout
extends RefCounted
## 图集排版的[b]唯一事实来源[/b]。
##
## 生成脚本与运行时代码都引用这里的常量：
## [code]tools/art/generate_terrain.gd[/code] 按这些坐标画图，
## [code]FarmAtlas[/code] / [code]Crop[/code] / [code]ItemSlot[/code] 按同样的坐标取图。
## 于是"图集排版变了但代码没跟着改"这类问题在结构上就不可能发生。
##
## [b]规范[/b]：
## [br]1. 坐标常量只允许定义在本文件，其它脚本一律 [code]const X := AtlasLayout.Y[/code]。
## [br]2. 新增或调整排版后，跑一次 [code]./tools/build_assets.sh[/code]。
## [br]3. [code]tests/unit/test_assets.gd[/code] 会校验 PNG 尺寸与这里的常量一致。

# ---------------------------------------------------------------- 通用

## 地形格子边长（像素）。
const TILE: int = 16

# ---------------------------------------------------------------- 地形图集

## [code]assets/sprites/tileset_farm.png[/code]
const TILESET_PATH: String = "res://assets/sprites/tileset_farm.png"
const TILESET_COLUMNS: int = 8
const TILESET_ROWS: int = 4
const TILESET_SIZE := Vector2i(TILE * TILESET_COLUMNS, TILE * TILESET_ROWS)

# 第 0 行：骨架阶段就存在的 8 格。坐标永不改变，旧场景 / 存档不受影响。
const GRASS := Vector2i(0, 0)
const GRASS_ALT := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const SOIL_DRY := Vector2i(3, 0)
const SOIL_WET := Vector2i(4, 0)
const WATER := Vector2i(5, 0)
const STONE := Vector2i(6, 0)
const WOOD := Vector2i(7, 0)

# 第 1 行：装饰与新地表。
const FLOWERS := Vector2i(0, 1)
const FENCE := Vector2i(1, 1)
const BUSH := Vector2i(2, 1)
const SIGN := Vector2i(3, 1)
const TALL_GRASS := Vector2i(4, 1)
const DIRT := Vector2i(5, 1)
const GRAVEL := Vector2i(6, 1)
const SAND := Vector2i(7, 1)

# 第 2 行：建筑构件与水岸。
const WATER_EDGE := Vector2i(0, 2)
const PATH_STONE := Vector2i(1, 2)
const ROOF := Vector2i(2, 2)
const WALL := Vector2i(3, 2)
const WINDOW := Vector2i(4, 2)
const DOORWAY := Vector2i(5, 2)
const FENCE_GATE := Vector2i(6, 2)
const FLOWER_BED := Vector2i(7, 2)

# 第 3 行：细碎点缀。
const FLOWER_RED := Vector2i(0, 3)
const FLOWER_BLUE := Vector2i(1, 3)
const MUSHROOM := Vector2i(2, 3)
const PEBBLE := Vector2i(3, 3)
const STUMP_TILE := Vector2i(4, 3)
const HAY := Vector2i(5, 3)
const CRATE := Vector2i(6, 3)
const WELL_TOP := Vector2i(7, 3)

# ---------------------------------------------------------------- 作物图集

## 每种作物一张 [code]assets/sprites/crops/<crop_id>.png[/code]：
## 5 列（4 个生长阶段 + 1 个枯死形态）× 1 行。
const CROP_COLUMNS: int = 5
const CROP_ROWS: int = 1
const CROP_WITHERED_COLUMN: int = 4
const CROP_SIZE := Vector2i(TILE * CROP_COLUMNS, TILE * CROP_ROWS)


## 作物图集里某个阶段的坐标。
static func crop_cell(stage: int) -> Vector2i:
	return Vector2i(clampi(stage, 0, CROP_COLUMNS - 1), 0)


# ---------------------------------------------------------------- 角色图集

## 玩家图集：[code]assets/sprites/actors/player.png[/code]
## 列：0/1 = 走路两帧、2 = 待机、3 = 挥动工具
## 行：0 = 朝下、1 = 朝上、2 = 朝侧面（左向由 [code]flip_h[/code] 复用）
const ACTOR_COLUMNS: int = 4
const ACTOR_ROWS: int = 3
const ACTOR_SIZE := Vector2i(TILE * ACTOR_COLUMNS, TILE * ACTOR_ROWS)
const ACTOR_IDLE_COLUMN: int = 2
const ACTOR_USE_COLUMN: int = 3
const ACTOR_WALK_COLUMNS: Array[int] = [0, 1]
const ACTOR_ROW_DOWN: int = 0
const ACTOR_ROW_UP: int = 1
const ACTOR_ROW_SIDE: int = 2
const ACTOR_ROW_NAMES: Array[StringName] = [&"down", &"up", &"side"]

## 每个 NPC 两帧（站立 / 呼吸）。
const NPC_COLUMNS: int = 2
const NPC_SIZE := Vector2i(TILE * NPC_COLUMNS, TILE)


# ---------------------------------------------------------------- 道具图标

## [code]assets/sprites/items/<item_id>.png[/code]，一格 16×16。
const ITEM_ICON_SIZE := Vector2i(16, 16)

# ---------------------------------------------------------------- UI 九宫格

## 九宫格的切片边距（像素）：面板 / 按钮 / 槽位都用同一套圆角半径。
const UI_PATCH_MARGIN: int = 4
const UI_SLOT_SIZE := Vector2i(22, 22)
const UI_PANEL_SIZE := Vector2i(24, 24)
const UI_BUTTON_SIZE := Vector2i(20, 20)
const UI_BAR_SIZE := Vector2i(8, 8)
const UI_ICON_SIZE := Vector2i(12, 12)

# ---------------------------------------------------------------- 标题页

## 标题背景按逻辑分辨率 1:1 生成，正好铺满 640×360 的视口。
const TITLE_VIEWPORT := Vector2i(640, 360)
const TITLE_BACKDROP_PATH: String = "res://assets/title/backdrop.png"
const TITLE_BANNER_SIZE := Vector2i(24, 24)
