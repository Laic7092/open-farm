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
## [br]2. [code]tileset_farm.png[/code] [b]只放地板[/b]：花木 / 栅栏 / 墙面这类
## "站在地板上的东西"一律导出成独立透明 PNG，由 [code]DecorPainter[/code]
## 或 [code]InteriorWalls[/code] 生成节点，不再占图集格子。
## [br]3. 新增或调整排版后，跑一次 [code]./tools/build_assets.sh[/code]。
## [br]4. [code]tests/unit/test_assets.gd[/code] 会校验 PNG 尺寸、
## "每格都有像素"、以及 TileSet 里的瓦片与这里的常量一致。
##
## 坐标是 [code]AtlasLayout[/code] 的内部约定：场景里没有烘死的瓦片数据
## （TileMapLayer 全靠脚本铺），存档只存农场格状态，都不引用它们。
## 所以调整网格只需要重跑构建，不涉及兼容。

# ---------------------------------------------------------------- 通用

## 地形格子边长（像素）。
const TILE: int = 16

# ---------------------------------------------------------------- 地形图集

## [code]assets/sprites/tileset_farm.png[/code]
const TILESET_PATH: String = "res://assets/sprites/tileset_farm.png"
## 由 [code]tools/generate_resources.gd[/code] 组装出的 TileSet；
## 季节变体是 [code]farm_tileset_<key>.tres[/code]（见 [code]SeasonPalette[/code]）。
## 放在这里是因为生成器与运行时 [code]SeasonLook[/code] 都要用同一份路径。
const TILESET_RESOURCE_PATH: String = "res://assets/tilesets/farm_tileset.tres"
## 从地形图集抽出的独立装饰贴图目录。
##
## Ground TileMap 只画地板；花、蘑菇、栅栏这类摆件由
## [code]DecorPainter[/code] 生成 [WorldProp] / [Sprite2D]，
## 贴图就从这个目录读取。
const DECOR_DIR: String = "res://assets/sprites/decor"
## 装饰贴图的统一格子尺寸。
const DECOR_SPRITE_SIZE := Vector2i(TILE, TILE)
## 全部装饰 id；生成器与 [code]DecorPainter[/code] 共同引用这一份名单。
const DECOR_SPRITES: Array[String] = [
	"flowers", "flower_red", "flower_blue", "flower_bed",
	"bush", "tall_grass", "mushroom", "pebble",
	"sand_pebble", "gravel_ore", "stump_tile", "hay",
	"crate", "well_top", "fence", "fence_gate", "sign",
]

## 室内墙面构件的贴图目录。
##
## 屋顶压顶 / 白墙 / 窗 / 门廊由 [code]InteriorWalls[/code] 摆成 [Sprite2D]，
## 碰撞由它自己的 [StaticBody2D] 提供，同样不占图集格子。
const INTERIOR_DIR: String = "res://assets/sprites/interior"
## 全部室内构件 id；生成器与 [code]InteriorWalls[/code] 共同引用这一份名单。
const INTERIOR_SPRITES: Array[String] = ["roof", "wall", "window", "doorway"]

# 网格正好被内容填满：64 格过渡块 + 17 格地面单格 = 9×9，没有空备用格。
const TILESET_COLUMNS: int = 9
const TILESET_ROWS: int = 9
const TILESET_SIZE := Vector2i(TILE * TILESET_COLUMNS, TILE * TILESET_ROWS)

# ---- 地面单格：0~7 列被过渡块占满，单格排在最后一列与最后一行（L 形）。
const GRASS := Vector2i(8, 0)
const GRASS_ALT := Vector2i(8, 1)
const PATH := Vector2i(8, 2)
const SOIL_DRY := Vector2i(8, 3)
const SOIL_WET := Vector2i(8, 4)
const STONE := Vector2i(8, 5)
const WOOD := Vector2i(8, 6)
const CLIFF := Vector2i(8, 7)

const DIRT := Vector2i(0, 8)
const GRAVEL := Vector2i(1, 8)
const SAND := Vector2i(2, 8)
const PATH_STONE := Vector2i(3, 8)
const PATH_STONE_ALT := Vector2i(4, 8)

# ---- 草地变体：用低频噪声按「片」选，而不是相邻格交替，地图里才会出现
# 大块明暗与色相变化；再加一层高频细节决定单片里的具体形态。
const GRASS_LUSH := Vector2i(5, 8)
const GRASS_DRY := Vector2i(6, 8)
const GRASS_DAPPLED := Vector2i(7, 8)
const GRASS_MEADOW := Vector2i(8, 8)

# ---------------------------------------------------------------- 地表过渡与变体
#
# 16 向「草缘」过渡：一块 4×4 的瓦片矩阵，按 4 邻边是否是草地编码成 mask。
# 生成器把基底材质画好后，再按 mask 在对应边压上参差的草缘；
# GroundPainter.transitions() 在铺完地后按同样的规则替换边界格。
const TRANSITION_N: int = 1
const TRANSITION_E: int = 2
const TRANSITION_S: int = 4
const TRANSITION_W: int = 8

## 四种可过渡基底的 4×4 块：左上方 8×8 铺满，正好占掉网格的一半。
const PATH_TRANSITION_BLOCK := Vector2i(0, 0)
const STONE_TRANSITION_BLOCK := Vector2i(4, 0)
const SAND_TRANSITION_BLOCK := Vector2i(0, 4)
const DIRT_TRANSITION_BLOCK := Vector2i(4, 4)

## 过渡块内的第 [param mask] 格（mask 0~15，位含义见 TRANSITION_N/E/S/W）。
static func transition_cell(block: Vector2i, mask: int) -> Vector2i:
	return block + Vector2i(mask & 0b0011, (mask >> 2) & 0b0011)

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

## 角色单元格大小：宽 1 格、高 2 格。
##
## 占地（碰撞 / 寻路 / 落点）仍然只占底下一格，这里加高的是[b]视觉[/b]：
## 角色比地砖高一个格子头，站在场景里才像个人而不是一块地砖。
## 脚底对齐格子底边，节点原点仍在格子中心，Y-sort 不需要特殊处理。
const ACTOR_CELL := Vector2i(TILE, TILE * 2)

## 玩家图集：[code]assets/sprites/actors/player.png[/code]
## 列：0/1 = 走路两帧、2 = 待机、3 = 挥动工具
## 行：0 = 朝下、1 = 朝上、2 = 朝侧面（左向由 [code]flip_h[/code] 复用）
const ACTOR_COLUMNS: int = 4
const ACTOR_ROWS: int = 3
const ACTOR_SIZE := Vector2i(ACTOR_CELL.x * ACTOR_COLUMNS, ACTOR_CELL.y * ACTOR_ROWS)
const ACTOR_IDLE_COLUMN: int = 2
const ACTOR_USE_COLUMN: int = 3
const ACTOR_WALK_COLUMNS: Array[int] = [0, 1]
const ACTOR_ROW_DOWN: int = 0
const ACTOR_ROW_UP: int = 1
const ACTOR_ROW_SIDE: int = 2
const ACTOR_ROW_NAMES: Array[StringName] = [&"down", &"up", &"side"]

## 每个 NPC 与玩家同构：4 列 × 3 行。
##
## 列：0/1 = 走路两帧、2 = 待机、3 = 待机呼吸。
## 行：0 = 朝下、1 = 朝上、2 = 朝侧面（左向由 flip_h 复用）。
const NPC_COLUMNS: int = 4
const NPC_ROWS: int = 3
const NPC_SIZE := Vector2i(ACTOR_CELL.x * NPC_COLUMNS, ACTOR_CELL.y * NPC_ROWS)
const NPC_IDLE_COLUMN: int = 2
const NPC_IDLE_BOB_COLUMN: int = 3
const NPC_WALK_COLUMNS: Array[int] = [0, 1]


# ---------------------------------------------------------------- 道具图标

## [code]assets/sprites/items/<item_id>.png[/code]，一格 16×16。
const ITEM_ICON_SIZE := Vector2i(16, 16)

# ---------------------------------------------------------------- 牲畜

## [code]assets/sprites/animals/<id>.png[/code] 固定 3 列。
##
## 列 0 = 幼崽、列 1 = 成年、列 2 = 成年且有产出可收。
const ANIMAL_COLUMNS: int = 3
## 单格边长。
const ANIMAL_CELL: int = 16

# ---------------------------------------------------------------- 野生植被

## [code]assets/sprites/flora/<id>.png[/code] 固定 4 列。
##
## 用不到的列留空，而不是让每种植物各有一个列数：这样 [Flora] 只管
## [code]frame = 阶段下标[/code]，不需要知道"这种草一共有几个阶段"。
const FLORA_COLUMNS: int = 4

## 树的单元格（树苗 / 小树 / 成树 / 老树）。
const FLORA_TREE_CELL := Vector2i(32, 48)
## 杂草 / 野花 / 蘑菇的单元格。
const FLORA_SMALL_CELL := Vector2i(16, 16)
## 大石头的单元格。
const FLORA_ROCK_CELL := Vector2i(32, 24)


## 某个体积的阶段表应有的尺寸。
static func flora_sheet_size(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * FLORA_COLUMNS, cell.y)

# ---------------------------------------------------------------- UI 九宫格

## 九宫格的切片边距（像素）：面板 / 按钮 / 槽位都用同一套圆角半径。
const UI_PATCH_MARGIN: int = 4
const UI_SLOT_SIZE := Vector2i(22, 22)
const UI_PANEL_SIZE := Vector2i(24, 24)
const UI_BUTTON_SIZE := Vector2i(20, 20)
const UI_BAR_SIZE := Vector2i(8, 8)
const UI_ICON_SIZE := Vector2i(12, 12)

# ---------------------------------------------------------------- 钓鱼小游戏

## 拉扯小游戏的竖直水槽与标记尺寸（生成器 [code]generate_ui.gd[/code]，
## 运行时 [code]src/fishing/fishing_ui.gd[/code]）。
const UI_FISH_TRACK_SIZE := Vector2i(18, 88)
const UI_FISH_ZONE_SIZE := Vector2i(18, 14)
const UI_FISH_MARK_SIZE := Vector2i(12, 10)
const UI_HOOK_MARK_SIZE := Vector2i(8, 8)

# ---------------------------------------------------------------- 世界浮标

## [code]assets/sprites/props/bobber.png[/code] / [code]ripple.png[/code]。
const BOBBER_SIZE := Vector2i(8, 8)
const RIPPLE_SIZE := Vector2i(16, 16)

# ---------------------------------------------------------------- 标题页

## 标题背景按逻辑分辨率 1:1 生成，正好铺满 640×360 的视口。
const TITLE_VIEWPORT := Vector2i(640, 360)
const TITLE_BACKDROP_PATH: String = "res://assets/title/backdrop.png"
const TITLE_BANNER_SIZE := Vector2i(24, 24)

# ---------------------------------------------------------------- 场景建筑

## 房子 / 谷仓这类摆件是"一物一图"，尺寸只由生成器决定，不占图集坐标。
## 但房子是[code].tscn[/code] 里靠坐标直接摆的：
## [code]WorldProp[/code] 的碰撞盒（[code]solid_offset[/code]）按 64×64 的落地线标定，
## 所以所有 NPC 住宅都必须生成这个尺寸，换贴图才不会同时挪碰撞。
## 生成器见 [code]tools/art/generate_houses.gd[/code]。
const HOUSE_SIZE := Vector2i(64, 64)
