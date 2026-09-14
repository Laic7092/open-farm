#!/usr/bin/env bash
# 一键重新生成全部美术与字体资源，并刷新 Godot 导入缓存。
#
# 规范（详见 docs/art_pipeline.md）：
#   仓库里不放手工二进制素材，所有 PNG / 字体都由 tools/art/*.gd 生成。
#   本脚本是唯一的编排入口，顺序不可随意调换：
#     1. 生成 PNG / .fnt（此时还没有 .import）
#     2. --import 让贴图与字体进入导入管线
#     3. 把已导入的资源组装成 TileSet / SpriteFrames / Theme
#     4. 再 --import 一次，让新的 .tres 也被索引
#
# 用法：GODOT_BIN=/path/to/godot ./tools/build_assets.sh
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-./godot}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
	exit 1
fi

# 依次执行的生成器；顺序 = 依赖顺序。
GENERATORS=(
	"tools/art/generate_font.gd"      # 像素中文字体（.fnt + PNG 子集）
	"tools/art/generate_terrain.gd"   # 地形图集
	"tools/art/generate_props.gd"     # 建筑 / 家具 / 树木
	"tools/art/generate_actors.gd"    # 玩家与 NPC
	"tools/art/generate_crops.gd"     # 每种作物一张生长图
	"tools/art/generate_animals.gd"   # 每种牲畜一张状态表
	"tools/art/generate_flora.gd"     # 每种野生植被一张阶段表（树 / 草 / 石）
	"tools/art/generate_items.gd"     # 道具图标
	"tools/art/generate_ui.gd"        # UI 九宫格与图标
	"tools/art/generate_title.gd"     # 标题页背景与云
	"tools/art/generate_weather.gd"   # 天气粒子贴图
)

step=0
total=$(( ${#GENERATORS[@]} + 3 ))

for generator in "${GENERATORS[@]}"; do
	step=$(( step + 1 ))
	echo "==> [$step/$total] 生成 $generator"
	"$GODOT_BIN" --headless --path . -s "res://$generator"
done

step=$(( step + 1 ))
echo "==> [$step/$total] 导入贴图与字体"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

step=$(( step + 1 ))
echo "==> [$step/$total] 组装 TileSet / SpriteFrames / Theme"
"$GODOT_BIN" --headless --path . -s res://tools/generate_resources.gd

step=$(( step + 1 ))
echo "==> [$step/$total] 刷新导入缓存"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

echo "完成。"
