# 美术资源规范：用脚本生成，而不是往仓库里塞二进制

> 一句话规则：**仓库里的每一个像素都必须能由 `tools/` 下的脚本重新生成。**
> 手工放进来的 PNG / 字体 / 图集数据，一律视为违规。

---

## 1. 为什么

常见的做法是把图直接丢进仓库，于是出现一堆来源不明、无法审查、无法调整的
二进制图片，最后没人敢删。

本项目不这么做：**把"像素长什么样"写成代码**，图片由脚本生成。

| | 手工素材 | 脚本生成 |
| --- | --- | --- |
| 改动成本 | 打开图像编辑器，改完导出，可能覆盖错文件 | 改一行颜色常量，重跑生成器 |
| 可审查性 | 二进制，git diff 只能看到"文件变了" | 代码 diff 就是画面 diff |
| 可复现性 | 依赖某个人手里的 .psd | 任何人 clone 后跑一次得到逐像素相同的结果 |
| 一致性 | 每张图各画各的，色调靠自觉 | 调色板集中在 `src/art/palette.gd` |

这不是"为了省事"，而是把美术资源变成**可维护的工程资产**。

---

## 2. 目录与职责

```
src/art/                        ← 生成器与运行时共用的"事实来源"
├── palette.gd                  ← 全部颜色常量（唯一调色板）
└── atlas_layout.gd             ← 全部图集坐标与尺寸（唯一排版表）

tools/art/                      ← 生成器（每个都能单独跑）
├── art_lib.gd                  ← 像素绘图基座：原语 / 确定性噪点 / 描边 / 投影
├── generate_font.gd            ← 像素中文字体（.fnt + PNG 子集）
├── generate_terrain.gd         ← 地形图集 tileset_farm.png
├── generate_props.gd           ← 建筑 / 家具 / 树木（一物一图）
├── generate_houses.gd          ← NPC 住宅：每个职业一栋，体量与屋顶各画各的
├── generate_actors.gd          ← 玩家与 NPC（共用一套角色画法）
├── generate_crops.gd           ← 每种作物一张生长图
├── generate_animals.gd         ← 每种牲畜一张状态表（幼崽 / 成年 / 可收）
├── generate_flora.gd           ← 每种野生植被一张阶段表（树 / 草 / 石）
├── generate_items.gd           ← 道具图标
├── generate_ui.gd              ← UI 九宫格与图标
├── generate_title.gd           ← 标题页背景与云
└── generate_weather.gd         ← 天气粒子贴图

tools/generate_resources.gd     ← 把 PNG 组装成 TileSet / SpriteFrames / Theme
tools/build_assets.sh           ← 唯一编排入口
assets/**                       ← 生成物（提交进仓库）
```

---

## 3. 五条硬性规则

### 3.1 颜色只能来自 `src/art/palette.gd`

生成器里**不允许**出现 `Color8(...)` 字面量。需要新颜色时先起个有意义的名字：

```gdscript
# ❌ 生成器里直接写死
Art.rect(image, area, Color8(150, 108, 72))

# ✅ 从调色板取
Art.rect(image, area, P.SOIL_LIGHT)
```

调色板按"材质 + 明暗三档"组织（`base / dark / light`），
这样 16×16 的小图在整数放大后依然有体积感。

### 3.2 图集坐标只能来自 `src/art/atlas_layout.gd`

生成器与运行时**引用同一批常量**，所以"排版改了但代码没跟着改"在结构上不可能发生：

```gdscript
# 生成器
Art.rect(image, Rect2i(Layout.GRASS * Layout.TILE, ...), ...)

# 运行时
const GRASS := AtlasLayout.GRASS          # FarmAtlas 里的一行别名
```

新增格子时，**只能往后追加**。已经发布过的坐标是存档与场景的隐式契约，
挪动它等于把玩家种好的地挪走。

### 3.3 生成必须确定性：用坐标哈希，不用 `RandomNumberGenerator`

```gdscript
# ❌ 每次重跑都得到不同的噪点，git 里全是无意义的二进制 diff
if rng.randf() < 0.2: ...

# ✅ 同样的坐标永远得到同样的值
if Art.noise(x, y, salt) < 0.2: ...
```

判断标准很简单：**连跑两次 `./tools/build_assets.sh`，`git status` 必须是干净的。**

### 3.4 数据与贴图分离，贴图通过 `Resource` 字段挂上去

贴图不写在场景里，而是写在数据资源上，由 `tools/generate_sample_data.gd` 挂载：

| 数据 | 字段 | 来源 |
| --- | --- | --- |
| `CropData` | `sprite_sheet` | `assets/sprites/crops/<crop_id>.png` |
| `AnimalData` | `sprite_sheet` | `assets/sprites/animals/<animal_id>.png` |
| `ItemData` | `icon` | `assets/sprites/items/<item_id>.png` |
| `NpcData` | `frames` | `assets/sprites/actors/npc_<npc_id>_frames.tres` |

于是"新增一种作物"= 加一行外观表 + 跑生成器，**场景与代码都不用动**。

### 3.5 生成物提交，脚本是唯一来源

生成出来的 PNG / `.tres` / `.fnt` 都提交进仓库：
CI 与玩家不需要跑生成器，也不需要本机装有中文字体。
但**永远不要直接编辑它们**——下一次跑生成器就会覆盖。

---

## 4. 怎么跑

```bash
./tools/build_assets.sh          # 全部重跑（17 步，约 15 秒）
```

顺序不能变，原因是 Godot 的导入管线：

```
1. 生成 PNG / .fnt / WAV  ← 此时还没有 .import
2. --import               ← 贴图、字体与音频进入导入管线
3. 组装 .tres             ← TileSet / SpriteFrames / Theme 引用已导入的资源
4. --import               ← 让新的 .tres 也被索引
```

单独跑某一个生成器也可以（例如只调了树的形状）：

```bash
timeout 60 ./godot --headless --path . --quit-after 3 -s res://tools/art/generate_props.gd
timeout 60 ./godot --headless --path . --import
```

改完美术想立刻看效果：

```bash
timeout 60 ./godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn
# → res://.tmp/screenshots/{title,shot_00,town,twon}.png
```

---

## 5. 像素中文字体

`tools/art/generate_font.gd` 不"下载一个现成字体"，而是**现场栅格化**：

1. 扫描 `assets/i18n`、`scenes/`、`data/`、`src/` 里所有会被显示的文本，
   收集真正用到的字符（当前约 1100 个，其中 CJK 约 950 个）。
2. 用 `TextServer` 在 **12px、关闭抗锯齿、关闭次像素定位** 下把每个字渲染成位图。
3. 阈值化成"全透明 / 全白"两种像素，打包成 BMFont（`.fnt` + PNG 图集）。
4. 图集外仍需要显示的字，由主题里的 `SystemFont` 兜底。

产出约 544×528 的图集，随项目提交，**运行时不需要系统里装有中文字体**。

源字体按 `FONT_CANDIDATES` 顺序查找（优先为屏幕小字号设计的黑体），
也可以用环境变量指定：

```bash
OPEN_FARM_FONT_SRC=/path/to/font.ttf timeout 60 ./godot --headless --path . --quit-after 3 \
    -s res://tools/art/generate_font.gd
```

> **加了新文案怎么办？** 直接重跑 `./tools/build_assets.sh`。
> `tests/unit/test_assets.gd` 会检查"翻译表里的字符是否都在字体子集里"，
> 漏了字会在测试阶段就报出来，而不是等玩家看到方块。

> **已知坑**：BMFont 导入出来的 `FontFile` 在 TextServer 侧取不到 ascent，
> 基线会贴在行顶，表现为**所有文字整体上移一个字高**（HUD 第一行被裁、标题盖到面板外）。
> 生成器把 `ascent` 预先折进每个字形的 `yoffset` 来抵消它——
> 因为 yoffset 与字号同比缩放，放大字号时依然对齐。

---

## 6. 修改与扩展美术

美术由脚本生成，所以调整画面 = 改代码后重跑：

1. 颜色改 `src/art/palette.gd`；尺寸 / 坐标改 `src/art/atlas_layout.gd`（已发布坐标只能追加）。
2. 画法改对应的 `tools/art/generate_*.gd`；需要新原语时加到 `tools/art/art_lib.gd`。
3. 跑 `./tools/build_assets.sh`，再跑 `./tools/check.sh` 确认规范未破。

生成物（PNG / `.tres` / `.fnt`）会被重新覆盖，**不要手改**。
因为运行时只认 `AtlasLayout` 的坐标与数据资源里的贴图字段，这些改动都不会波及玩法代码。

---

## 7. 规范如何被强制

规范写在文档里没人看，所以它同时是**可执行的测试**（`tests/unit/test_assets.gd`）：

| 检查 | 防止的问题 |
| --- | --- |
| 每张生成物都存在且尺寸与 `AtlasLayout` 一致 | 改了排版忘了重新生成 |
| TileSet 的瓦片数 ≥ 排版表声明的格数 | 图集与 TileSet 脱节 |
| 翻译表里的每个字符都在像素字体子集里 | 新文案显示成方块 |
| 每个 `ItemData.icon` / `CropData.sprite_sheet` / `AnimalData.sprite_sheet` / `NpcData.frames` 都挂上了 | 数据与美术脱节 |
| `palette.gd` 里的颜色不重复定义、可被生成器访问 | 调色板被绕过 |

跑 `./tools/check.sh` 就会执行。
