#!/bin/sh
set -e
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project VzheClip.xcodeproj -scheme VzheClip \
  -destination 'platform=macOS' -derivedDataPath build -quiet test "$@"
