#!/usr/bin/env bash
# 一键校验：刷新导入缓存 → 跑 gdUnit4 单元测试 → 跑端到端冒烟测试。
#
# 用法：
#   ./tools/check.sh              # 全部跑一遍
#   ./tools/check.sh unit         # 只跑单元测试
#   ./tools/check.sh smoke        # 只跑冒烟测试
#
# 输出约定：控制台只留每步一行结论与失败明细，完整 Godot 输出写进
# .tmp/check/*.log——逐条 PASSED 会刷出上千行，污染上下文（详见 AGENTS.md）。
# 开跑前会先执行 tools/outline.py lint：大文件规范体检，只提示不阻断。
# 可用 GODOT_BIN 指定 Godot 可执行文件，默认使用仓库根目录下的 ./godot。
set -euo pipefail

cd "$(dirname "$0")/.."

LOG_DIR=".tmp/check"
mkdir -p "$LOG_DIR"

# 大文件规范体检（详见 AGENTS.md）：只提示不阻断，缺 python3 时跳过。
if command -v python3 >/dev/null 2>&1; then
	python3 tools/outline.py lint --quiet || true
else
	echo "提示：未找到 python3，跳过 tools/outline.py lint" >&2
fi

GODOT_BIN="${GODOT_BIN:-./godot}"
TARGET="${1:-all}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
	exit 1
fi

# 每条 Godot 命令都套 timeout：脚本解析失败或测试挂死时不会无限等待。
# 默认 60 秒；慢机器可用 GODOT_TIMEOUT 覆盖。
TIMEOUT="${GODOT_TIMEOUT:-60}"
# 少数平台（如 macOS 默认）没有 timeout；退化成直接执行，避免脚本直接报错。
if ! command -v timeout >/dev/null 2>&1; then
	echo "警告：未找到 timeout，命令将不设超时（可安装 coreutils 或使用 gtimeout）。" >&2
	timeout() { shift; "$@"; }
fi

run_import() {
	echo "==> 刷新 Godot 导入缓存"
	timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
}

# 把 Godot 的 ANSI 彩色控制符去掉，便于在日志里 grep / tail。
strip_ansi() {
	sed 's/\x1b\[[0-9;]*m//g'
}

run_unit() {
	echo "==> gdUnit4 单元测试"
	local log="$LOG_DIR/unit.log"
	local report="$LOG_DIR/reports/report_1/results.xml"
	rm -rf "$LOG_DIR/reports"
	local code=0
	# -c：不 fail-fast，一轮跑完并报出全部失败。
	# --ignoreHeadlessMode：CI 里没有窗口，但本项目的测试不依赖真实输入事件。
	# 全部输出进日志，控制台只由 summarize_tests.py 打摘要。
	timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a res://tests \
		-rd res://.tmp/check/reports -rc 1 >"$log" 2>&1 || code=$?
	if [ -f "$report" ] && command -v python3 >/dev/null 2>&1; then
		local summary=0
		python3 tools/summarize_tests.py "$report" || summary=$?
		if [ "$summary" -ne 0 ]; then
			code=$summary
		fi
	elif [ "$code" -ne 0 ]; then
		echo "  gdUnit4 异常退出（$code），日志末尾："
		strip_ansi <"$log" | tail -20
	fi
	if [ "$code" -ne 0 ]; then
		echo "  完整日志：$log"
	fi
	return "$code"
}

run_smoke() {
	echo "==> 端到端冒烟测试"
	local log="$LOG_DIR/smoke.log"
	local code=0
	timeout "$TIMEOUT" "$GODOT_BIN" --headless --path . res://tools/smoke_test.tscn >"$log" 2>&1 || code=$?
	if grep -aqE '^SMOKE' "$log"; then
		grep -aE '^SMOKE|^  ✗ ' "$log"
	else
		echo "  冒烟测试未产出结果（退出码 $code），日志末尾："
		strip_ansi <"$log" | tail -20
	fi
	if [ "$code" -ne 0 ]; then
		echo "  完整日志：$log"
	fi
	return "$code"
}

case "$TARGET" in
	import) run_import ;;
	unit) run_unit ;;
	smoke) run_smoke ;;
	all)
		run_import
		run_unit
		run_smoke
		;;
	*)
		echo "未知目标：$TARGET（可选：all / import / unit / smoke）" >&2
		exit 2
		;;
esac

echo "校验通过。"
