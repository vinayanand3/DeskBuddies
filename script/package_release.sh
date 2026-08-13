#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
DERIVED_DATA_PATH="$PROJECT_DIR/build/ReleaseDerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/DeskBuddies.app"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$PROJECT_DIR/build/DeskBuddies-dmg"
DMG_PATH="$DIST_DIR/DeskBuddies.dmg"
ZIP_PATH="$DIST_DIR/DeskBuddies.zip"

cd "$PROJECT_DIR"

rm -rf "$DERIVED_DATA_PATH" "$STAGING_DIR"
mkdir -p "$DIST_DIR" "$STAGING_DIR"
rm -f "$DMG_PATH" "$ZIP_PATH" "$DIST_DIR/SHA256SUMS.txt"

xcodebuild \
  -project "$PROJECT_DIR/DeskBuddies.xcodeproj" \
  -scheme DeskBuddies \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY='-' \
  CODE_SIGNING_REQUIRED=YES \
  build

test -d "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/DeskBuddies" -verify_arch arm64 x86_64

cp -R "$APP_PATH" "$STAGING_DIR/DeskBuddies.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "DeskBuddies $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

cd "$DIST_DIR"
shasum -a 256 DeskBuddies.dmg DeskBuddies.zip > SHA256SUMS.txt

echo "Created release artifacts:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $DIST_DIR/SHA256SUMS.txt"
