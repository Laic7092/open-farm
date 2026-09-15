#!/usr/bin/env bash
# 一键重新生成全部美术、音频与字体资源，并刷新 Godot 导入缓存。
#
# 规范（详见 docs/art_pipeline.md 与 docs/audio_pipeline.md）：
#   仓库里不放手工二进制素材，所有 PNG / 字体 / WAV 都由 tools/ 下的脚本生成。
#   本脚本是唯一的编排入口，顺序不可随意调换：
#     1. 生成 PNG / .fnt / WAV（此时还没有 .import）
#     2. --import 让贴图、字体与音频进入导入管线
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

# 每条 Godot 命令都套 timeout：脚本解析失败时不会调用 quit()，Godot 会一直挂在主循环里。
# 默认 60 秒；慢机器可用 GODOT_TIMEOUT 覆盖。
TIMEOUT="${GODOT_TIMEOUT:-60}"
# 少数平台（如 macOS 默认）没有 timeout；退化成直接执行，避免脚本直接报错。
if ! command -v timeout >/dev/null 2>&1; then
	echo "警告：未找到 timeout，命令将不设超时（可安装 coreutils 或使用 gtimeout）。" >&2
	timeout() { shift; "$@"; }
fi

# 依次执行的生成器；顺序 = 依赖顺序。
GENERATORS=(
	"tools/art/generate_font.gd"      # 像素中文字体（.fnt + PNG 子集）
	"tools/art/generate_terrain.gd"   # 地形图集
	"tools/art/generate_props.gd"     # 建筑 / 家具 / 树木
	"tools/art/generate_houses.gd"    # NPC 住宅：按角色换造型（杂货铺 / 铁匠铺 / 图书馆……）
	"tools/art/generate_actors.gd"    # 玩家与 NPC
	"tools/art/generate_crops.gd"     # 每种作物一张生长图
	"tools/art/generate_animals.gd"   # 每种牲畜一张状态表
	"tools/art/generate_flora.gd"     # 每种野生植被一张阶段表（树 / 草 / 石）
	"tools/art/generate_items.gd"     # 道具图标
	"tools/art/generate_ui.gd"        # UI 九宫格与图标
	"tools/art/generate_title.gd"     # 标题页背景与云
	"tools/art/generate_weather.gd"   # 天气粒子贴图
	"tools/audio/generate_sfx.gd"     # 音效（振荡器 + 噪声合成）
	"tools/audio/generate_bgm.gd"     # BGM（和弦 + 旋律 + 鼓组）
)

step=0
total=$(( ${#GENERATORS[@]} + 3 ))

for generator in "${GENERATORS[@]}"; do
	step=$(( step + 1 ))
	echo "==> [$step/$total] 生成 $generator"
	# timeout 是外部兜底（卡在 _initialize 时连主循环都到不了），--quit-after 让 Godot 自己收尾。
	timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --quit-after 3 -s "res://$generator"
done

step=$(( step + 1 ))
echo "==> [$step/$total] 导入贴图、字体与音频"
timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

step=$(( step + 1 ))
echo "==> [$step/$total] 组装 TileSet / SpriteFrames / Theme"
timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --quit-after 3 -s res://tools/generate_resources.gd

step=$(( step + 1 ))
echo "==> [$step/$total] 刷新导入缓存"
timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

echo "完成。"
