#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/PomodoroBar.app"

"$ROOT_DIR/scripts/build.sh"
open -n "$APP_DIR"

echo "Restarted $APP_DIR"
