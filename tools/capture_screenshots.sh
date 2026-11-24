#!/usr/bin/env bash
# Regenerates every screenshot used by the README (opens a window per shot).
#   tools/capture_screenshots.sh /Applications/Godot.app/Contents/MacOS/Godot
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
OUT="$PWD/docs/screenshots"
FARM=res://scenes/farm/farm.tscn
MAP=res://scenes/world/map_scene.tscn
shot() { # name scene args...
	local name="$1" scene="$2"; shift 2
	"$GODOT" --path . $scene -- "$@" --capture="$OUT/$name.png" --capture-frames="${FRAMES:-300}" >/dev/null 2>&1
	echo "  $name.png"
}
shot main_menu "" 
shot character_creation res://scenes/main/character_creation.tscn
shot farm $FARM --demo=farming --demo-time=960
shot farming $FARM --demo=farming
shot evening_rain $FARM --demo=farming --demo-weather=1 --demo-time=1110
shot night_lights $FARM --demo=farming --demo-time=1290
shot autumn $FARM --demo=farming --demo-season=2 --demo-time=960
shot winter $FARM --demo=farming --demo-season=3 --demo-time=720
shot shop $FARM --demo=farming --demo-ui=shop
shot chest $FARM --demo=farming --demo-ui=chest
shot world_map $FARM --demo=farming --demo-ui=map
shot dialogue $FARM --demo=farming --demo-ui=dialogue
shot journal $FARM --demo=farming --demo-ui=diary
shot villagers $FARM --demo=farming --demo-ui=journal
shot achievements $FARM --demo=farming --demo-ui=progress
shot workbench $FARM --demo=florist --demo-ui=workbench
shot florist_panel $FARM --demo=florist --demo-ui=florist
shot builds $FARM --demo=builds
shot greenhouse $MAP --demo=greenhouse --demo-map=greenhouse
shot florist_shop $MAP --demo=florist --demo-map=florist_shop
for m in village cherry_forest lavender_mountains rare_grove house; do
	shot "map_$m" $MAP --demo-map=$m --demo-time=660
done
echo "Screenshots updated in docs/screenshots/"
