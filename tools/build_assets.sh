#!/usr/bin/env bash
# 一键重新生成全部美术、音频与字体资源，并刷新 Godot 导入缓存。
#
# 规范（详见 AGENTS.md）：
#   仓库里不放手工二进制素材，所有 PNG / 字体 / WAV 都由 tools/ 下的脚本生成。
#   本脚本是唯一的编排入口，顺序不可随意调换：
#     1. 生成 PNG / .fnt / WAV（此时还没有 .import）
#     2. --import 让贴图、字体与音频进入导入管线
#     3. 把已导入的资源组装成 TileSet / SpriteFrames / Theme
#     4. 再 --import 一次，让新的 .tres 也被索引
#
# 用法：GODOT_BIN=/path/to/godot ./tools/build_assets.sh
#
# 输出约定：控制台打 6 行左右——阶段小结 + 失败明细 + 结尾统计；终端里另有一行原地刷新的
# 当前步骤。完整 Godot 输出写进 .tmp/check/build/*.log（逐张图的 INFO 行上千行，会污染
# 上下文，详见 AGENTS.md）。
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-./godot}"

LOG_DIR=".tmp/check/build"
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

# 把 Godot 的 ANSI 彩色控制符去掉，便于在日志里 grep / tail。
strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

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
	"tools/art/generate_water.gd"     # 水体贴图（按 WaterLayout 的形状逐像素烘）
	"tools/art/generate_props.gd"     # 建筑 / 家具 / 树木
	"tools/art/generate_houses.gd"    # NPC 住宅：按角色换造型（杂货铺 / 铁匠铺 / 图书馆……）
	"tools/art/generate_actors.gd"    # 玩家与 NPC
	"tools/art/generate_crops.gd"     # 每种作物一张生长图
	"tools/art/generate_animals.gd"   # 每种牲畜一张状态表
	"tools/art/generate_flora.gd"     # 每种野生植被一张阶段表（树 / 草 / 石）
	"tools/art/generate_items.gd"     # 道具图标
	"tools/art/generate_tools.gd"     # 手持工具（16×24 大图）
	"tools/art/generate_ui.gd"        # UI 九宫格与图标
	"tools/art/generate_title.gd"     # 标题页背景与云
	"tools/art/generate_weather.gd"   # 天气粒子贴图
	"tools/audio/generate_sfx.gd"     # 音效（振荡器 + 噪声合成）
	"tools/audio/generate_bgm.gd"     # BGM（和弦 + 旋律 + 鼓组）
)

step=0
total=$(( ${#GENERATORS[@]} + 3 ))
started=$SECONDS
echo "重建资源：${#GENERATORS[@]} 个生成器 + 导入 + 组装"

# 进度只占一行：终端里原地刷新，重定向到文件时完全不动。
progress() {
	[ -t 1 ] || return 0
	printf '\r  [%d/%d] %s\033[K' "$step" "$total" "$1"
}
done_line() {
	[ -t 1 ] || return 0
	printf '\r\033[K'
}

# 阶段小结：清掉进度行，报该阶段用了几秒。
phase() {
	done_line
	echo "  ✓ $1（$((SECONDS - $2))s）"
}

# 全部 Godot 输出进日志；控制台只在失败时补日志末尾。
# 返回 Godot 的退出码，配合 set -e 保持原来的“失败即中止”语义。
run_quiet() {
	local label="$1"; shift
	local log="$LOG_DIR/$(printf '%s' "$label" | tr '/ ' '__').log"
	local code=0
	progress "$label"
	set +e
	timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . "$@" >"$log" 2>&1
	code=$?
	set -e
	if [ "$code" -ne 0 ]; then
		done_line
		echo "✗ $label 退出码 $code（124 = 超时 $TIMEOUT s），日志末尾：" >&2
		strip_ansi <"$log" | tail -15 | sed 's/^/    /' >&2
		echo "  完整日志：$log" >&2
	fi
	return "$code"
}

# --import 在 Godot 里偶有非零退出但缓存已刷新，按原行为只记日志不中断。
run_quiet_soft() {
	run_quiet "$@" || true
}

# timeout 是外部兜底（卡在 _initialize 时连主循环都到不了），--quit-after 让 Godot 自己收尾。
phase_start=$SECONDS
for generator in "${GENERATORS[@]}"; do
	step=$(( step + 1 ))
	run_quiet "$generator" --quit-after 3 -s "res://$generator"
done
phase "生成美术与音频（${#GENERATORS[@]} 项）" "$phase_start"

step=$(( step + 1 ))
phase_start=$SECONDS
run_quiet_soft "import-assets" --import
phase "导入贴图 / 字体 / 音频" "$phase_start"

step=$(( step + 1 ))
phase_start=$SECONDS
run_quiet "generate_resources" --quit-after 3 -s res://tools/generate_resources.gd
phase "组装 TileSet / SpriteFrames / Theme" "$phase_start"

step=$(( step + 1 ))
phase_start=$SECONDS
run_quiet_soft "import-cache" --import
phase "刷新导入缓存" "$phase_start"

echo "完成：$total 步 / $(( SECONDS - started ))s，日志 $LOG_DIR"
