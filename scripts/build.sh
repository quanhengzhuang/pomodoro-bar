#!/usr/bin/env bash
# 构建 macOS 菜单栏 App 的最小脚本。
#
# 本项目没有使用 Xcode 工程打包 Mac 版，而是直接用 swiftc 编译单文件源码，然后手工组装
# 标准的 .app 目录结构。任何命令失败都会立即中止，避免留下看似成功但内容不完整的 App。
set -euo pipefail

# 无论从哪个工作目录调用脚本，都先定位到仓库根目录。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Pomodoro"
# macOS 应用包本质上是一个有固定目录结构的文件夹。
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
# 把 Swift/Clang 模块缓存放在仓库的 .build 中，避免每次从头编译系统模块。
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"

mkdir -p "$ROOT_DIR/dist" "$MODULE_CACHE"

# 覆盖现有构建前先按时间戳完整备份，方便构建失败或新版本异常时手动恢复。
if [[ -d "$APP_DIR" ]]; then
  BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$APP_DIR.$BACKUP_SUFFIX"
  cp -R "$APP_DIR" "$BACKUP_DIR"
  echo "Backed up $APP_DIR to $BACKUP_DIR"
fi

# 创建可执行文件和资源文件的标准落点。
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 直接编译 AppKit 程序。main.swift 自己创建 NSApplication 并启动事件循环。
swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -framework AppKit \
  "$ROOT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

# Info.plist 描述应用名称、Bundle Identifier 等元数据；icns 是 Finder 和提醒框使用的图标。
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# 更新目录时间戳，帮助 Finder/LaunchServices 感知这是一次新构建。
touch "$APP_DIR" "$CONTENTS_DIR"

echo "Built $APP_DIR"
