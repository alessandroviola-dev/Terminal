#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift build -c release
APP="Terminal.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp .build/release/Terminal "$APP/Contents/MacOS/Terminal"
# Bind Info.plist and resources to a consistent local application signature.
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Built $PWD/$APP"
