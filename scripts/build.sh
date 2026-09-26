#!/bin/sh
set -e
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project VzheClip.xcodeproj -scheme VzheClip -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build -quiet build "$@"
echo "Built: build/Build/Products/Debug/VzheClip.app"
