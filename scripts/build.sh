#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PomodoroBar"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE"

swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -framework AppKit \
  "$ROOT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

touch "$APP_DIR" "$CONTENTS_DIR"

echo "Built $APP_DIR"
