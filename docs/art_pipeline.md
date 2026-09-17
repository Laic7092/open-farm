# 美术资源规范

> 仓库里的每个像素都必须能由 `tools/` 下的脚本重新生成；手工放进来的 PNG / 字体 / 图集数据一律违规。

## 1. 目录与职责

| 路径 | 职责 |
| --- | --- |
| `src/art/palette.gd` | 唯一调色板：全部颜色常量，按材质 + 明暗三档（`base / dark / light`）组织 |
| `src/art/atlas_layout.gd` | 唯一排版表：全部图集坐标与尺寸 |
| `tools/art/art_lib.gd` | 像素绘图基座：原语 / 确定性噪点 / 描边 / 投影 |
| `tools/art/generate_*.gd` | 各域生成器，可单独运行（分工见下） |
| `tools/generate_resources.gd` | 把 PNG 组装成 TileSet / SpriteFrames / Theme |
| `tools/generate_sample_data.gd` | 把贴图挂到 `data/**/*.tres` 的 `Resource` 字段上 |
| `tools/build_assets.sh` | 唯一编排入口 |
| `assets/**` | 生成物（提交进仓库） |

| 生成器 | 产出 |
| --- | --- |
| `generate_font.gd` | 像素中文字体（`.fnt` + PNG 子集） |
| `generate_terrain.gd` | 地形图集 `tileset_farm.png` + 透明装饰 `assets/sprites/decor/*.png` |
| `generate_props.gd` | 建筑 / 家具 / 树木（一物一图） |
| `generate_houses.gd` | NPC 住宅：每个职业一栋，体量与屋顶各画各的 |
| `generate_actors.gd` | 玩家与 NPC（共用一套角色画法） |
| `generate_crops.gd` | 每种作物一张生长图 |
| `generate_animals.gd` | 每种牲畜一张状态表（幼崽 / 成年 / 可收） |
| `generate_flora.gd` | 每种野生植被一张阶段表（树 / 草 / 石） |
| `generate_items.gd` | 道具图标 |
| `generate_ui.gd` | UI 九宫格与图标 |
| `generate_title.gd` | 标题页背景与云 |
| `generate_weather.gd` | 天气粒子贴图 |

## 2. 硬性规则

### 2.1 颜色只能来自 `src/art/palette.gd`

生成器里**不允许**出现 `Color8(...)` 字面量；需要新颜色时先起名：

```gdscript
# ❌ Art.rect(image, area, Color8(150, 108, 72))
# ✅ Art.rect(image, area, P.SOIL_LIGHT)
```

调色板按「材质 + 明暗三档」组织，保证 16×16 小图在整数放大后仍有体积感。

### 2.2 图集坐标只能来自 `src/art/atlas_layout.gd`

生成器与运行时引用同一批常量，「排版改了但代码没跟着改」在结构上不可能发生：

```gdscript
# 生成器：Art.rect(image, Rect2i(Layout.GRASS * Layout.TILE, ...), ...)
# 运行时：const GRASS := AtlasLayout.GRASS
```

**新增格子只能往后追加**：已发布坐标是存档与场景的隐式契约，挪动等于把玩家种好的地挪走。

### 2.3 生成必须确定性：用坐标哈希，不用 `RandomNumberGenerator`

```gdscript
# ❌ if rng.randf() < 0.2: ...
# ✅ if Art.noise(x, y, salt) < 0.2: ...
```

判据：**连跑两次 `./tools/build_assets.sh`，`git status` 必须干净。**

### 2.4 数据与贴图分离

贴图写在数据资源的 `Resource` 字段上，由 `tools/generate_sample_data.gd` 挂载：

| 数据 | 字段 | 来源 |
| --- | --- | --- |
| `CropData` | `sprite_sheet` | `assets/sprites/crops/<crop_id>.png` |
| `AnimalData` | `sprite_sheet` | `assets/sprites/animals/<animal_id>.png` |
| `ItemData` | `icon` | `assets/sprites/items/<item_id>.png` |
| `NpcData` | `frames` | `assets/sprites/actors/npc_<npc_id>_frames.tres` |

于是「新增一种作物」= 加一行外观表 + 跑生成器，场景与代码都不用动。

### 2.5 生成物提交，永不手改

PNG / `.tres` / `.fnt` 都提交进仓库（CI 与玩家不必跑生成器，也不必装有中文字体），但**永远不要直接编辑**——
下次生成会覆盖。改画面 = 改 `palette.gd` / `atlas_layout.gd` / 对应 `generate_*.gd`，然后重跑 `build_assets.sh`。

### 2.6 遮挡：建筑身后淡出

可通行区域不能被整张贴图挡住。采用「身后淡出」一起处理，不再做局部 overlay：

- 只对 **`building` 组里的实心建筑**生效（`WorldProp.BUILDING_GROUP` 且
  `passable == false`）：`WorldProp._process` 判断玩家是否落在它的纵向投影内、
  且在它北侧（身后），是则 `modulate.a → behind_alpha`，离开恢复。
- 建筑以外的高实心件（树 / 栅栏 / 柜台 / 石头）暂时不淡出，避免小件在玩家经过时
  频繁闪动；开放范围后续再按视觉反馈扩。
- 保留正常 Y 排序：正面时玩家完整在前；身后被贴图挡住时才透出来。
- 碰撞盒与 `LightOccluder2D` 都按完整底图计算，地面阴影不会跟着淡。
- 建筑逐件微调：`fade_when_behind` 可关；`behind_alpha` / `fade_speed` 控制深度与速度。

场景里的建筑节点要带 `groups=["building"]`；`WorldProp._ready()` 只给组内实心件
注册 `_process`。

早期版本给树冠 / 屋檐做过 `fg_<名字>.png` 前景 overlay，但局部遮挡会出现
「身体在前、头被盖住」的割裂感，已整体移除；现在没有 `fg_` 素材与约定。

### 2.7 默认实心，牧草才可穿过

世界里的实体默认应当挡路，可穿过是显式例外：

- `WorldProp.passable = false` 为默认值；没有填 `solid_size` 时，`WorldProp`
  会按贴图底部自动生成脚印碰撞盒。只有牧草这类低矮摆件才设 `passable = true`。
- `FloraData.passable = false` 为默认值，且 `solid_from_stage` 默认从 `0`
  开始。树、石头一落地就挡路；杂草 / 野花 / 蘑菇等低矮地被显式 `passable = true`。
- 地面 [code]TileMapLayer[/code] 只画地板（草 / 路 / 水 / 沙 / 石 / 木）。
  花、蘑菇、栅栏、牌子这类装饰不再写进地板图层，改由
  [code]src/world/decor_painter.gd[/code] 生成透明 [WorldProp]；
  这样每一件装饰都能参与 Y 排序和独立碰撞；身后淡出只留给 `building` 组建筑。
- 仍留在 TileMap 里的建筑 / 崖壁等结构瓦片，按
  [code]src/world/tile_collision.gd[/code] 写碰撞：
  [code]SOLID_TILES[/code] 生成满格物理碰撞；栅栏门 / 门洞等
  [code]PASSABLE_TILES[/code] 保持无碰撞。
- 装饰贴图由 `generate_terrain.gd` 从同一套像素画函数导出到
  `assets/sprites/decor/*.png`，不带草底 / 沙底，摆在任何地板上都不会露底色。
- 规范由 `tests/unit/test_world_prop.gd`、`test_flora_growth.gd` 与
  `test_assets.gd` 的可执行断言守住。

## 3. 怎么跑

```bash
./tools/build_assets.sh          # 全部重跑
```

顺序不能变，原因是 Godot 的导入管线：

```
1. 生成 PNG / .fnt / WAV  ← 此时还没有 .import
2. --import               ← 贴图、字体与音频进入导入管线
3. 组装 .tres             ← TileSet / SpriteFrames / Theme 引用已导入的资源
4. --import               ← 让新的 .tres 也被索引
```

单跑一个生成器（例：只调树）：

```bash
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/art/generate_props.gd
timeout 60 ./godot --headless --path . --import
timeout 60 ./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn
# → res://.tmp/screenshots/{title,shot_00,town,twon}.png
```

## 4. 像素中文字体

`tools/art/generate_font.gd` 现场栅格化：只扫 `assets/i18n/strings.csv` 的翻译表收集字符 → 用 `TextServer` 在关闭抗锯齿、关闭次像素定位下
渲染成位图 → 阈值化成「全透明 / 全白」→ 打包成 BMFont（`.fnt` + PNG 图集）。图集外仍需要的字由主题里的 `SystemFont` 兜底。
源字体按 `FONT_CANDIDATES` 查找，也可用环境变量指定：

```bash
OPEN_FARM_FONT_SRC=/path/to/font.ttf timeout 60 ./godot --headless --path . --quit-after 3 \
    -s res://tools/art/generate_font.gd
```

> 新增文案必须先登记进 `strings.csv`，再重跑 `build_assets.sh`；`test_assets.gd` 会检查翻译表字符是否都在字体子集里。
> 字体生成器不再扫 `.gd` / `.tscn` 全文，注释和报错文本不会影响字形子集。

> **已知坑**：BMFont 导入出的 `FontFile` 在 TextServer 侧取不到 ascent，基线会贴在行顶，
> 表现为所有文字整体上移一个字高（HUD 第一行被裁、标题盖到面板外）。生成器把 `ascent` 折进每个字形的
> `yoffset` 抵消它——yoffset 与字号同比缩放，放大字号时依然对齐。

## 5. 规范如何被强制

`tests/unit/test_assets.gd` 是规范的可执行版本，`./tools/check.sh` 会执行：

| 检查 | 防止的问题 |
| --- | --- |
| 每张生成物存在且尺寸与 `AtlasLayout` 一致 | 改了排版忘了重新生成 |
| TileSet 瓦片数 ≥ 排版表声明的格数 | 图集与 TileSet 脱节 |
| 翻译表每个字符都在像素字体子集里 | 新文案显示成方块 |
| 每个 `ItemData.icon` / `CropData.sprite_sheet` / `AnimalData.sprite_sheet` / `NpcData.frames` 都已挂上 | 数据与美术脱节 |
| `palette.gd` 颜色不重复定义、可被生成器访问 | 调色板被绕过 |

