#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app_path="$PWD/build/Usage Bar.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/UsageBar" "$app_path/Contents/MacOS/UsageBar"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
ditto "$bin_dir/UsageBar_UsageBar.bundle" "$app_path/Contents/Resources/UsageBar_UsageBar.bundle"
swift scripts/make-icon.swift "$PWD/build/AppIcon.png"
iconset="$PWD/build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" build/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" build/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_path"
printf '\nBuilt %s\n' "$app_path"
