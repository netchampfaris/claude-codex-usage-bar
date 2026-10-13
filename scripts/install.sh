#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
install_path="$HOME/Applications/Usage Bar.app"
if [[ -d "$install_path" ]] && ! /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$install_path/Contents/Info.plist" | /usr/bin/grep -qx 'dev.netchamp.usage-bar'; then
    printf 'An unrelated app already exists at %s. Choose another location.\n' "$install_path" >&2
    exit 1
fi
if pgrep -f "$install_path/Contents/MacOS/UsageBar" >/dev/null; then
    printf 'Quit Usage Bar before installing an update.\n' >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
ditto "build/Usage Bar.app" "$install_path"
open "$install_path"
printf 'Installed %s\n' "$install_path"
