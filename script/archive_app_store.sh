#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${TEAM_ID:-5J2B4ZDMXV}"
ARCHIVE_PATH="$PROJECT_DIR/build/AppStore/DeskBuddies.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/AppStore/Upload"
EXPORT_OPTIONS="$PROJECT_DIR/AppStore/ExportOptions.plist"

cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/build/AppStore"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

xcodebuild \
  -project "$PROJECT_DIR/DeskBuddies.xcodeproj" \
  -scheme DeskBuddies \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="DeskBuddies Mac App Store 1.0" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "Uploaded DeskBuddies to App Store Connect."
