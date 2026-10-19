#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/dist/Field Notes.app"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
swiftc -O -parse-as-library -framework AppKit -framework SwiftUI "$ROOT_DIR"/Sources/FieldNotes/*.swift -o "$BUILD_DIR/FieldNotes"

if [[ "${1:-}" == "--open" ]]; then
  for pid in $(pgrep -x FieldNotes 2>/dev/null || true); do
    running_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$running_command" == "$APP_DIR/Contents/MacOS/FieldNotes" ]]; then
      kill "$pid"
    fi
  done
fi

cp "$BUILD_DIR/FieldNotes" "$APP_DIR/Contents/MacOS/FieldNotes"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built: $APP_DIR"
if [[ "${1:-}" == "--open" ]]; then
  open "$APP_DIR"
fi
