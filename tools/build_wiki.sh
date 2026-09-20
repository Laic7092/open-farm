#!/usr/bin/env bash
# 生成「游戏内容 wiki」：手机优先的多页静态 HTML，用浏览器审阅全部 data/**/*.tres 与文案。
#
# 两段式（详见 tools/build_wiki.py 顶部说明）：
#   1. Godot 无头导出 .tmp/wiki/data.json（引擎侧解析引用、对齐切图常量）
#   2. Python + Jinja2 铺页面（概览 / 每类列表 / 每条详情）并复制贴图与静态资源
#
# 用法：
#   ./tools/build_wiki.sh              # 生成并打印路径
#   ./tools/build_wiki.sh --open       # 顺手用浏览器打开
#   ./tools/build_wiki.sh --serve 8000 # 起本地静态服务
#   ./tools/build_wiki.sh --serve 8000 --host 0.0.0.0   # 手机同网访问
#   ./tools/build_wiki.sh --strict     # 有缺译 / 悬空引用时非零退出（可接 CI）
#   ./tools/build_wiki.sh --out .tmp/site/wiki --data .tmp/wiki/data.json
#                                       # 输出到站点子目录（Pages 的 /wiki）
#   GODOT_BIN=/path/to/godot ./tools/build_wiki.sh
#
# 产物在 .tmp/（已 gitignore），不进版本库。
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-./godot}"
LOG_DIR=".tmp/check/wiki"
DUMP_LOG="$LOG_DIR/dump.log"
TIMEOUT="${GODOT_TIMEOUT:-60}"

mkdir -p "$LOG_DIR" .tmp/wiki

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
	exit 1
fi

# 没有 timeout（如 macOS 默认）时退化成直接执行，与 build_assets.sh 一致。
if ! command -v timeout >/dev/null 2>&1; then
	timeout() { shift; "$@"; }
fi

echo "导出数据：$GODOT_BIN --headless res://tools/wiki_dump.tscn"
if ! timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --quit-after 5 \
	res://tools/wiki_dump.tscn >"$DUMP_LOG" 2>&1; then
	echo "✗ 数据导出失败（退出码 $?，124 = 超时），日志末尾：" >&2
	sed 's/\x1b\[[0-9;]*m//g' <"$DUMP_LOG" | tail -15 | sed 's/^/    /' >&2
	echo "  完整日志：$DUMP_LOG" >&2
	exit 1
fi

# 引擎内的 push_error / push_warning 只在日志里，别静默吞掉。
if grep -qE "SCRIPT ERROR|Cannot open|无法写入" "$DUMP_LOG"; then
	echo "✗ 导出日志里有引擎错误：" >&2
	grep -nE "SCRIPT ERROR|Cannot open|无法写入" "$DUMP_LOG" | tail -5 | sed 's/^/    /' >&2
	exit 1
fi

python3 tools/build_wiki.py "$@"
