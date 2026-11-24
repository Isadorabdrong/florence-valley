#!/usr/bin/env bash
# Regenerates all procedural art + the terrain TileSet, then reimports.
# Usage: tools/build_assets.sh [path/to/godot]
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --script res://tools/generate_assets.gd
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --script res://tools/build_tileset.gd
"$GODOT" --headless --path . --script res://tools/generate_audio.gd
"$GODOT" --headless --path . --script res://tools/generate_music.gd
"$GODOT" --headless --path . --import
echo "Assets rebuilt."
