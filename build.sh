#!/usr/bin/env bash
# Builds Skyline Swinger: a single-file Windows .exe (PCK embedded) and a Linux binary.
# Needs Godot 4.7.2 and its export templates in ~/.local/share/godot/export_templates/4.7.2.stable/
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"
mkdir -p build

# Import resources first so a fresh checkout (no .godot/ folder) exports cleanly
"$GODOT" --headless --import

"$GODOT" --headless --export-release "Windows Desktop" build/SkylineSwinger.exe
"$GODOT" --headless --export-release "Linux" build/SkylineSwinger.x86_64

ls -lh build/SkylineSwinger.exe build/SkylineSwinger.x86_64
