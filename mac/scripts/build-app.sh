#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) LG Remote.app into mac/build/ and signs it ad hoc.
# Usage: scripts/build-app.sh [--install|--zip]
#   --install  copies it to /Applications
#   --zip      also writes build/LG-Remote-<version>.zip for a GitHub release
set -euo pipefail

cd "$(dirname "$0")/.."
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}" --product LGRemote

APP="build/LG Remote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release "${ARCHS[@]}" --show-bin-path)/LGRemote" "$APP/Contents/MacOS/LGRemote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built: $(pwd)/$APP"
if [[ "${1:-}" == "--zip" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
  ZIP="build/LG-Remote-$VERSION.zip"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  echo "Zipped: $(pwd)/$ZIP"
  shasum -a 256 "$ZIP"
fi
if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/LG Remote.app"
  cp -R "$APP" /Applications/
  echo "Installed: /Applications/LG Remote.app"
fi
