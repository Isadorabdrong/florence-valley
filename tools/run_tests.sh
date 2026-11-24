#!/usr/bin/env bash
# Runs the automated test suite headless. Exit code 0 = all tests passed.
# Usage: tools/run_tests.sh [path/to/godot]
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd
