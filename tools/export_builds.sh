#!/usr/bin/env bash
# Exports the release builds (needs the Godot 4.7 export templates installed).
#   tools/export_builds.sh /Applications/Godot.app/Contents/MacOS/Godot
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
mkdir -p builds/macos builds/windows
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "macOS" builds/macos/FlorenceValley.zip
"$GODOT" --headless --path . --export-release "Windows" builds/windows/FlorenceValley.exe
ls -lh builds/macos builds/windows
