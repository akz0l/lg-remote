#!/usr/bin/env bash
# Builds LG Remote.app (release) into mac/build/ and signs it ad hoc.
# Usage: scripts/build-app.sh [--install]   (--install copies it to /Applications)
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release --product LGRemote

APP="build/LG Remote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/LGRemote" "$APP/Contents/MacOS/LGRemote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built: $(pwd)/$APP"
if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/LG Remote.app"
  cp -R "$APP" /Applications/
  echo "Installed: /Applications/LG Remote.app"
fi
