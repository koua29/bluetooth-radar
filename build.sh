#!/bin/bash
# Compile Bluetooth Radar (SwiftUI) sans Xcode, assemble le .app et le signe en ad-hoc.
# Usage :
#   ./build.sh              -> build arm64 (Apple Silicon)
#   ./build.sh --universal  -> build universel arm64 + x86_64 (portable Intel + Apple Silicon)
set -euo pipefail

APP_NAME="Bluetooth Radar"
EXEC="BluetoothRadar"
BUNDLE_ID="com.arnaud.bluetoothradar"
VERSION="1.0"
MIN_OS="13.0"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

UNIVERSAL=0
[[ "${1:-}" == "--universal" ]] && UNIVERSAL=1

echo "==> Nettoyage"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

SRCS=$(find "$ROOT/Sources" -name '*.swift')

compile() { # $1 = target triple, $2 = output binary
    swiftc -parse-as-library -O -swift-version 5 \
        -target "$1" \
        -o "$2" $SRCS
}

echo "==> Compilation"
if [[ $UNIVERSAL -eq 1 ]]; then
    compile "arm64-apple-macos$MIN_OS"  "$BUILD/$EXEC-arm64"
    compile "x86_64-apple-macos$MIN_OS" "$BUILD/$EXEC-x86_64"
    lipo -create -output "$MACOS/$EXEC" "$BUILD/$EXEC-arm64" "$BUILD/$EXEC-x86_64"
    rm -f "$BUILD/$EXEC-arm64" "$BUILD/$EXEC-x86_64"
    echo "    binaire universel: $(lipo -archs "$MACOS/$EXEC")"
else
    compile "arm64-apple-macos$MIN_OS" "$MACOS/$EXEC"
fi

echo "==> Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$EXEC</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Bluetooth Radar scanne les appareils Bluetooth à portée pour les afficher et déclencher vos alertes.</string>
</dict>
</plist>
PLIST

echo "==> Signature ad-hoc"
codesign --force --deep --sign - \
    --entitlements "$ROOT/BluetoothRadar.entitlements" \
    "$APP"

echo "==> OK : $APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|Signature' || true
