#!/bin/bash
# Assembles the Mac app into a real .app bundle.
#
# A bare SwiftPM executable runs but has no bundle, so macOS gives it no Dock
# icon and no reliable way to focus its window. Wrapping it fixes that and lets
# `open` bring it to the front.

set -euo pipefail

PACKAGE="Packages/PianovaCore"
BUILD="$PACKAGE/.build/debug"
APP="build/Pianova.app"

swift build --package-path "$PACKAGE"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD/PianovaMac" "$APP/Contents/MacOS/Pianova"
cp -R "$BUILD/PianovaCore_PianovaUI.bundle" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Pianova</string>
  <key>CFBundleDisplayName</key>
  <string>Pianova</string>
  <key>CFBundleIdentifier</key>
  <string>com.pianova.app</string>
  <key>CFBundleExecutable</key>
  <string>Pianova</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "pronto: $APP"
