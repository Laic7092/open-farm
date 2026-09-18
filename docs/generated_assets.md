# 生成物规范（美术 / 音频）

> **一条 invariant**：仓库里的每个像素与每个采样都必须能由 `tools/` 下的脚本重新生成；
> 手工放进的 PNG / WAV / MP3 / OGG / 字体一律违规。美术与音频只是这条 invariant 的两个域。

## 1. 通则

- **唯一编排入口**：`./tools/build_assets.sh`。顺序不能变，原因是 Godot 的导入管线：

  ```
  1. 生成 PNG / .fnt / WAV   ← 此时还没有 .import
  2. --import                ← 贴图、字体与音频进入导入管线
  3. 组装 .tres              ← TileSet / SpriteFrames / Theme 引用已导入的资源
  4. --import                ← 让新的 .tres 也被索引
  ```

- **必须确定性**：用坐标哈希，不用 `RandomNumberGenerator`。判据：**连跑两次 `build_assets.sh`，`git status` 必须干净**。
- **生成物提交，永不手改**：生成物（PNG / WAV / `.fnt` / `.import` / `.tres`）与代码一起提交，CI 与玩家不必跑生成器；
  改动一律走生成器后重跑，手改会被下次生成覆盖。
- **新增汉字 / 文案必须先登记 `assets/i18n/*.csv` 再重跑 `build_assets.sh`**，否则像素字体缺字。
- **内容只认 id**：运行时按 id 取资源，生成器按同一批 id 写文件，「改了文件名却忘了改播放代码」在结构上不可能发生。

单跑一个生成器（例：只调树 / 只调一首曲子）：

```bash
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/art/generate_props.gd
timeout 60 ./godot --headless --path . --import
timeout 60 ./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn
# → res://.tmp/screenshots/{title,shot_00,town,twon}.png
```

## 2. 美术

### 2.1 职责

生成器都在 `tools/art/generate_*.gd`，产出 `assets/**`，可单独运行；`tools/generate_resources.gd` 把 PNG
组装成 TileSet / SpriteFrames / Theme，`tools/generate_sample_data.gd` 把贴图挂到 `data/**/*.tres` 的
`Resource` 字段。颜色与排版各自只有一处来源：`src/art/palette.gd`、`src/art/atlas_layout.gd`。

### 2.2 硬性规则

- **颜色只能来自 `src/art/palette.gd`**：生成器里不允许 `Color8(...)` 字面量；新颜色先起名。
- **图集坐标只能来自 `src/art/atlas_layout.gd`**：生成器与运行时引用同一批常量。
  **新增格子只能往后追加**——已发布坐标是存档与场景的隐式契约。
- **数据与贴图分离**：贴图写在数据资源的 `Resource` 字段上，由 `tools/generate_sample_data.gd` 挂载：

  | 数据 | 字段 | 来源 |
  | --- | --- | --- |
  | `CropData` | `sprite_sheet` | `assets/sprites/crops/<crop_id>.png` |
  | `AnimalData` | `sprite_sheet` | `assets/sprites/animals/<animal_id>.png` |
  | `ItemData` | `icon` | `assets/sprites/items/<item_id>.png` |
  | `NpcData` | `frames` | `assets/sprites/actors/npc_<npc_id>_frames.tres` |

### 2.3 遮挡：建筑身后淡出

可通行区域不能被整张贴图挡住。只对 **`building` 组里的实心建筑**生效
（`WorldProp.BUILDING_GROUP` 且 `passable == false`）：`WorldProp._process` 判断玩家是否落在它的
纵向投影内、且在它北侧（身后），是则 `modulate.a → behind_alpha`（默认 0.42），离开恢复。

- 树 / 栅栏 / 柜台 / 石头**不淡出**，避免小件频繁闪动；保留正常 Y 排序，正面时玩家完整在前。
- 脚下影子由 `WorldProp` 的软椭圆假影子画：Godot 2D 的 `DirectionalLight2D` 阴影永远无限长，所以方向光只做平行光、不开阴影。
- 逐件微调：`fade_when_behind` 可关；`behind_alpha` / `fade_speed` 控制深度与速度。
- 早期给树冠 / 屋檐做过 `fg_<名字>.png` 前景 overlay，会出现「身体在前、头被盖住」的割裂感，已整体移除。

### 2.4 默认实心，牧草才可穿过

- `WorldProp.passable = false` 为默认值；没有 `solid_size` 时，按贴图底部自动生成脚印碰撞盒。只有牧草这类低矮摆件设 `passable = true`。
- `FloraData.passable = false` 为默认值；树、石头一落地就挡路，杂草 / 野花 / 蘑菇显式 `passable = true`。
- 地面 `TileMapLayer` 只画地板（草 / 路 / 沙 / 石 / 木）；水面**不在地面层里**（见 §2.5）；
  花、蘑菇、栅栏、牌子等装饰改由 `src/world/decor_painter.gd` 生成透明 `WorldProp`，从而参与 Y 排序与独立碰撞。
- 仍在 TileMap 里的建筑 / 崖壁等结构瓦片，按 `src/world/tile_collision.gd` 写碰撞：
  `SOLID_TILES` 生成满格物理碰撞，`PASSABLE_TILES`（栅栏门 / 门洞）保持无碰撞。
- 装饰贴图由 `generate_terrain.gd` 导出到 `assets/sprites/decor/*.png`，不带草底 / 沙底。

### 2.5 水域：形状 → 贴图 → 碰撞

| 环节 | 入口 | 说什么 |
| --- | --- | --- |
| 形状 | `src/world/water_shape.gd` | 圆角矩形 / 椭圆 / 有机水塘的闭合折线，纯静态、可单测 |
| 登记 | `src/world/water_layout.gd` | 每张地图有哪些水体（形状 + 水域类型 + 栈桥通道），唯一事实来源 |
| 烘图 | `tools/art/generate_water.gd` | 按"到岸线的距离"逐像素上色：深浅三档 + 岸沿暗带 + 岸边浪花 |
| 运行 | `src/world/water_field.gd` | 放贴图、建 `CollisionPolygon2D`、逐帧画浪花 / 水波 / 碎光、回答 `is_water(cell)` |

16×16 的瓦片只能拼出 45° 台阶，拼不出圆润岸线与俯视深浅，所以水面改成形状。
代价是「水下那几格」不再是水面瓦片，`FloraField` 要单独问一次 `WaterField.is_water()`。
木栈桥这类水上通道：外观铺在单独的 `TileMapLayer`（z 高于水面），碰撞在
`WaterLayout.Body.walkways` 声明，由 `WaterShape.collision_polygons()` 从水面多边形里减掉。

### 2.6 像素中文字体

`tools/art/generate_font.gd` 现场栅格化：扫 `assets/i18n/` 下全部 `*.csv` 收集字符 → 用 `TextServer` 在关闭抗锯齿、
关闭次像素定位下渲染成位图 → 阈值化成「全透明 / 全白」→ 打包成 BMFont（`.fnt` + PNG 图集）。
图集外仍需要的字由主题里的 `SystemFont` 兜底；源字体按 `FONT_CANDIDATES` 查找，也可用环境变量指定：

```bash
OPEN_FARM_FONT_SRC=/path/to/font.ttf timeout 60 ./godot --headless --path . --quit-after 3 \
    -s res://tools/art/generate_font.gd
```

> **已知坑**：BMFont 导入出的 `FontFile` 在 TextServer 侧取不到 ascent，基线会贴在行顶，表现为所有文字整体上移一个字高。
> 生成器把 `ascent` 折进每个字形的 `yoffset` 抵消它（yoffset 与字号同比缩放，放大字号依然对齐）。

### 2.7 视觉方向：3/4 斜俯视

世界（TileMap + Y 排序 + 方向光）已是斜俯视，但大量素材曾是**正面立面**（建筑只有正面、树冠是正圆色块）。
缺的不是分辨率或配色，而是**体积感**与**分层关系**。

**已拍板**：继续全脚本生成，不走手绘位图；维持 16 像素网格与明度分层调色板。

1. **每个大件都要有第二个体面**：房子看到正面 + 右侧面，树冠看到受光顶面与背光下缘，栅栏看到柱顶，崖壁看到上缘。
   统一光照方向：**左上受光、右下投影**。
2. **可通行区域不能被整张贴图挡住**：建筑统一走 §2.3 的身后淡出。

已否决：手绘替换 PNG（不可复现）；给整张素材加描边 / 投影冒充体积；旋转整张建筑贴图做 3/4（像素会糊、碰撞对不上）；
第二套图集 / source（排版是单一事实来源）；局部前景 overlay（「身体在前、头被盖住」）。

## 3. 音频

### 3.1 职责

`src/audio/audio_catalog.gd` 是全部音频 id 与路径的唯一来源（生成器与运行时共用）；
`tools/audio/synth.gd` 是合成基座，`generate_sfx.gd` / `generate_bgm.gd` 是配方，产出 `assets/audio/{sfx,bgm}/*.wav`。

### 3.2 硬性规则

- **格式统一**：22050 Hz / 16 bit / 单声道 PCM。常量只在 `AudioCatalog.SAMPLE_RATE` 与 `Synth.SR` 各写一次。
- **声音只能来自 `Synth` 的原语**：`tone` / `sweep` / `noise_burst` / `kick` / `snare` / `hat` / `melody` /
  `chord_sequence` / `arpeggio`。新音色先在基座里加一个有名字的原语，不手搓 PCM 循环。
- **噪声用位置哈希**：`Synth.noise_at(index, salt)`，不用 `RandomNumberGenerator`（判据同 §1）。
- **BGM 写循环块，音效不写**：BGM 的 WAV 带标准 `smpl` 循环块，Godot 按「从 WAV 检测循环」导入即可无缝循环；
  渲染时多留一段尾巴绕回开头截成整圈，接缝做极短淡化。

运行时由场景里的 `SceneAudio` 节点读 `WorldScene` / 自身的导出字段决定放什么，加一张地图只需在场景里填字段；
细节见 `scene_audio.gd` 与 `world_scene.gd` 顶部 `##`。

---

本规范的可执行版本是 `tests/unit/test_assets.gd` / `test_audio.gd`，它们顶部 `##` 逐条列出了会拦下的错误；
`./tools/check.sh` 会执行。
