#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PomodoroBar"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"

mkdir -p "$ROOT_DIR/dist" "$MODULE_CACHE"

if [[ -d "$APP_DIR" ]]; then
  BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$APP_DIR.$BACKUP_SUFFIX"
  cp -R "$APP_DIR" "$BACKUP_DIR"
  echo "Backed up $APP_DIR to $BACKUP_DIR"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -framework AppKit \
  "$ROOT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

touch "$APP_DIR" "$CONTENTS_DIR"

echo "Built $APP_DIR"
