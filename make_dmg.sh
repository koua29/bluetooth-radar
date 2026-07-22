#!/bin/bash
# Construit l'app en universel puis un DMG installable (glisser vers Applications).
set -euo pipefail
APP_NAME="Bluetooth Radar"
VERSION="1.0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
DMG="$BUILD/BluetoothRadar-$VERSION.dmg"
STAGE="$BUILD/dmg-stage"

"$ROOT/build.sh" --universal

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$BUILD/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "DMG: $DMG"
ls -lh "$DMG"
