#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$PROJECT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/DeskBuddies.app"

cd "$PROJECT_DIR"

xcodebuild \
  -project "$PROJECT_DIR/DeskBuddies.xcodeproj" \
  -scheme DeskBuddies \
  -destination 'platform=macOS,name=My Mac' \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

open "$APP_PATH"
echo "Launched $APP_PATH"
