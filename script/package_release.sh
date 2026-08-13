#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Vinay Bhaskarla (5J2B4ZDMXV)}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-5J2B4ZDMXV}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DeskBuddies-notary}"
DERIVED_DATA_PATH="$PROJECT_DIR/build/ReleaseDerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/DeskBuddies.app"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$PROJECT_DIR/build/DeskBuddies-dmg"
DMG_PATH="$DIST_DIR/DeskBuddies.dmg"
ZIP_PATH="$DIST_DIR/DeskBuddies.zip"

notarize() {
  local artifact_path="$1"
  local result
  local notarization_status
  local submission_id

  result="$(xcrun notarytool submit "$artifact_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --output-format json)"
  print -r -- "$result"

  notarization_status="$(print -r -- "$result" | plutil -extract status raw -o - -- -)"
  if [[ "$notarization_status" != "Accepted" ]]; then
    submission_id="$(print -r -- "$result" | plutil -extract id raw -o - -- -)"
    xcrun notarytool log "$submission_id" --keychain-profile "$NOTARY_PROFILE"
    return 1
  fi
}

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
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS='--timestamp' \
  build

test -d "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/DeskBuddies" -verify_arch arm64 x86_64

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

notarize "$ZIP_PATH"

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

# Recreate the ZIP so users receive the app with its stapled ticket.
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

ditto "$APP_PATH" "$STAGING_DIR/DeskBuddies.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "DeskBuddies $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
notarize "$DMG_PATH"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

cd "$DIST_DIR"
shasum -a 256 DeskBuddies.dmg DeskBuddies.zip > SHA256SUMS.txt

echo "Created release artifacts:"
echo "  $DMG_PATH"
echo "  $ZIP_PATH"
echo "  $DIST_DIR/SHA256SUMS.txt"
echo "Developer ID signing, notarization, stapling, and Gatekeeper validation passed."
