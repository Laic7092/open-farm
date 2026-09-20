#!/usr/bin/env bash
# 导出 Godot Web 版（GitHub Pages 站点的 /game）。
#
# 用法：
#   ./tools/build_web.sh                    # 输出到 target/web/
#   ./tools/build_web.sh .tmp/site/game     # 输出到站点子目录
#   GODOT_BIN=/path/to/godot GODOT_TIMEOUT=600 ./tools/build_web.sh
#
# 前置：已安装与引擎同版本的 export templates，默认路径
#   ~/.local/share/godot/export_templates/<版本>.stable/
# 产物在 target/ 或 .tmp/（均已 gitignore），不进版本库。
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR="${1:-target/web}"
GODOT_BIN="${GODOT_BIN:-./godot}"
LOG_DIR=".tmp/check/web"
LOG="$LOG_DIR/export.log"
TIMEOUT="${GODOT_TIMEOUT:-600}"

mkdir -p "$LOG_DIR" "$OUT_DIR"

if [ ! -x "$GODOT_BIN" ]; then
echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
exit 1
fi

# 没有 timeout（如 macOS 默认）时退化成直接执行，与 build_assets.sh 一致。
if ! command -v timeout >/dev/null 2>&1; then
timeout() { shift; "$@"; }
fi

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

run_godot() { timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . "$@"; }

echo "刷新导入缓存：$GODOT_BIN --headless --path . --import"
code=0
run_godot --import >"$LOG" 2>&1 || code=$?
if [ "$code" -ne 0 ]; then
echo "✗ 导入缓存失败（退出码 $code），日志末尾：" >&2
strip_ansi <"$LOG" | tail -15 | sed 's/^/    /' >&2
exit 1
fi

echo "导出 Web：$OUT_DIR/index.html"
code=0
run_godot --export-release Web "$OUT_DIR/index.html" >>"$LOG" 2>&1 || code=$?
if [ "$code" -ne 0 ]; then
echo "✗ Web 导出失败（退出码 $code，124 = 超时），日志末尾：" >&2
strip_ansi <"$LOG" | tail -25 | sed 's/^/    /' >&2
echo "  若提示缺少导出模板，请安装 Godot 同版本的 export templates。" >&2
exit 1
fi

missing=0
for f in index.html index.js index.wasm index.pck; do
if [ ! -f "$OUT_DIR/$f" ]; then
echo "✗ 缺少产物：$OUT_DIR/$f" >&2
missing=1
fi
done
if [ "$missing" -ne 0 ]; then
echo "  日志末尾：" >&2
strip_ansi <"$LOG" | tail -15 | sed 's/^/    /' >&2
exit 1
fi

echo "✓ web 已生成：$OUT_DIR/index.html"
