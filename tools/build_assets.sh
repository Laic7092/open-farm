#!/usr/bin/env bash
# 生成占位美术与资源，并刷新 Godot 导入缓存。
#
# 顺序很重要：
#   1. 用 Godot 画出 PNG（此时还没有 .import）
#   2. --import 让贴图进入导入管线
#   3. 把已导入的贴图组装成 TileSet / SpriteFrames 资源
#   4. 再 --import 一次，让新的 .tres 也被索引
#
# 用法：GODOT_BIN=/path/to/godot ./tools/build_assets.sh
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-./godot}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "找不到可执行的 Godot：$GODOT_BIN（可用 GODOT_BIN 环境变量指定）" >&2
	exit 1
fi

echo "==> 1/4 生成占位 PNG"
"$GODOT_BIN" --headless --path . -s res://tools/generate_placeholder_art.gd

echo "==> 2/4 导入贴图"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

echo "==> 3/4 组装 TileSet / SpriteFrames"
"$GODOT_BIN" --headless --path . -s res://tools/generate_placeholder_resources.gd

echo "==> 4/4 刷新导入缓存"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

echo "完成。"
