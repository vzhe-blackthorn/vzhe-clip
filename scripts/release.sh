#!/bin/sh
# Builds a Release VzheClip.app, signs it, packages build/release/VzheClip-<version>.dmg,
# and (when a Developer ID certificate + notarytool profile exist) notarizes and staples it.
#
# One-time setup for a notarized release:
#   1. Xcode → Settings → Accounts → Manage Certificates → + → "Developer ID Application"
#   2. xcrun notarytool store-credentials vzheclip \
#        --apple-id <your Apple ID> --team-id H5U9AQK47X --password <app-specific password>
# Without them the DMG is signed with "Apple Development" and users must use "Open Anyway".
set -e
cd "$(dirname "$0")/.."

TEAM_ID=H5U9AQK47X
NOTARY_PROFILE=${NOTARY_PROFILE:-vzheclip}
VERSION=$(sed -n 's/.*CFBundleShortVersionString: "\(.*\)"/\1/p' project.yml)
OUT=build/release
APP="$OUT/VzheClip.app"
DMG="$OUT/VzheClip-$VERSION.dmg"

DEV_ID=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*('"$TEAM_ID"')\)"/\1/p' | head -1)

xcodegen generate --quiet
rm -rf "$OUT"
mkdir -p "$OUT"

build_release() {
  xcodebuild -project VzheClip.xcodeproj -scheme VzheClip -configuration Release \
    -destination 'platform=macOS' -derivedDataPath build -quiet build "$@"
}

if [ -n "$DEV_ID" ]; then
  echo "Signing with: $DEV_ID"
  # Overrides apply to every target, including SwiftPM resource bundles, so pass the team too.
  build_release CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" OTHER_CODE_SIGN_FLAGS=--timestamp \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO  # no get-task-allow: notarization rejects it
else
  echo "warning: no Developer ID Application certificate for team $TEAM_ID — signing with Apple Development (not notarizable)"
  build_release
fi
cp -R build/Build/Products/Release/VzheClip.app "$APP"
codesign --verify --deep --strict "$APP"
if [ -n "$DEV_ID" ] && codesign -d --entitlements - "$APP" 2>/dev/null | grep -q get-task-allow; then
  echo "error: app still has the get-task-allow entitlement; notarization would reject it" >&2
  exit 1
fi

# DMG: the app plus an /Applications shortcut to drag it onto.
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "VzheClip $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" -quiet
rm -rf "$STAGING"

if [ -n "$DEV_ID" ]; then
  codesign --sign "$DEV_ID" --timestamp "$DMG"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
  else
    echo "warning: notarytool profile '$NOTARY_PROFILE' not found — DMG is signed but NOT notarized"
  fi
fi

echo "Release artifact: $DMG"
