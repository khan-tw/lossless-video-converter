#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Lossless Video Converter.app"
SOURCE_APP="$ROOT_DIR/dist-native/$APP_NAME"
TARGET_APP="/Applications/$APP_NAME"

"$ROOT_DIR/script/build_and_run.sh" verify

rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

echo "Installed: $TARGET_APP"
