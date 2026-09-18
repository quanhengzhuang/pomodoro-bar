#!/usr/bin/env bash
# 构建并启动一个新的 Mac App 实例，便于本地开发验证。
set -euo pipefail

# 根据脚本自身位置计算仓库根目录，因此可从任意目录调用。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/PomodoroBar.app"

# 先复用正式构建脚本；其中任一步失败时，本脚本会因 `set -e` 停止，不会启动旧产物。
"$ROOT_DIR/scripts/build.sh"
# `-n` 要求 macOS 启动一个新实例。App 启动后会自行结束同 Bundle Identifier 的旧实例。
open -n "$APP_DIR"

echo "Restarted $APP_DIR"
