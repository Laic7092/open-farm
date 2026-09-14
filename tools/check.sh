#!/usr/bin/env bash
# 一键校验：刷新导入缓存 → 跑 gdUnit4 单元测试 → 跑端到端冒烟测试。
#
# 用法：
#   ./tools/check.sh              # 全部跑一遍
#   ./tools/check.sh unit         # 只跑单元测试
#   ./tools/check.sh smoke        # 只跑冒烟测试
#
# 可用 GODOT_BIN 指定 Godot 可执行文件，默认使用仓库根目录下的 ./godot。
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-./godot}"
TARGET="${1:-all}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
	exit 1
fi

run_import() {
	echo "==> 刷新 Godot 导入缓存"
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
}

run_unit() {
	echo "==> gdUnit4 单元测试"
	# --ignoreHeadlessMode：CI 里没有窗口，但本项目的测试不依赖真实输入事件。
	"$GODOT_BIN" --headless --path . \
		-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -a res://tests
}

run_smoke() {
	echo "==> 端到端冒烟测试（真的把游戏跑起来）"
	"$GODOT_BIN" --headless --path . res://tools/smoke_test.tscn
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
