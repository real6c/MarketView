#!/bin/bash
# Build Swift release and bundle MarketView.app (icon + signing).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MarketView"
BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "🔨  Building $APP_NAME (release)…"
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BINARY=".build/release/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
  echo "error: missing $BINARY" >&2
  exit 1
fi

echo "📦  Assembling $APP_NAME.app…"
rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BINARY" "$MACOS/$APP_NAME"

# ── App icon: icon.png → 1024px rounded (20pt corners, transparent) → AppIcon.icns
#    Iconset is built from the rounded master so all sizes stay consistent.
ICON_SRC="$SCRIPT_DIR/icon.png"
ICONSET_DIR="$SCRIPT_DIR/.build_AppIcon.iconset"
ICON_CORNER_PX=80
if [[ -f "$ICON_SRC" ]]; then
  mkdir -p "$SCRIPT_DIR/.build"
  ROUND_BIN="$SCRIPT_DIR/.build/round_icon"
  xcrun swiftc -O "$SCRIPT_DIR/Scripts/round_icon.swift" -o "$ROUND_BIN" -framework AppKit
  ICON_1024="$SCRIPT_DIR/.build/_icon_master_1024.png"
  ICON_ROUNDED="$SCRIPT_DIR/.build/_icon_master_1024_rounded.png"
  sips -z 1024 1024 "$ICON_SRC" --out "$ICON_1024" >/dev/null
  "$ROUND_BIN" "$ICON_1024" "$ICON_ROUNDED" 1024 "$ICON_CORNER_PX"

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  sips -z 16 16   "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_16x16.png"        >/dev/null
  sips -z 32 32   "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_16x16@2x.png"     >/dev/null
  sips -z 32 32   "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_32x32.png"        >/dev/null
  sips -z 64 64   "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_32x32@2x.png"     >/dev/null
  sips -z 128 128 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
  sips -z 256 256 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_128x128@2x.png"  >/dev/null
  sips -z 256 256 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_256x256.png"     >/dev/null
  sips -z 512 512 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_256x256@2x.png"   >/dev/null
  sips -z 512 512 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_512x512.png"     >/dev/null
  sips -z 1024 1024 "$ICON_ROUNDED" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
  echo "🖼   AppIcon.icns (from icon.png, ${ICON_CORNER_PX}px rounded corners, transparent)"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MarketView</string>
    <key>CFBundleIdentifier</key>
    <string>com.marketview.app</string>
    <key>CFBundleName</key>
    <string>MarketView</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

ENT="$SCRIPT_DIR/MarketView.entitlements"
if [[ -f "$ENT" ]]; then
  echo "✍️   codesign (ad-hoc) + entitlements…"
  codesign --force --sign - --entitlements "$ENT" "$BUNDLE" 2>&1
else
  echo "✍️   codesign (ad-hoc)…"
  codesign --force --sign - "$BUNDLE" 2>&1
fi

echo "✅  $BUNDLE"
echo "   (drag to /Applications or double-click to run)"
