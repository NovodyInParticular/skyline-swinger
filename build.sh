#!/usr/bin/env bash
# Builds Skyline Swinger: a single-file Windows .exe (PCK embedded), a Linux binary and an Android APK.
# Needs Godot 4.7.2 and its export templates in ~/.local/share/godot/export_templates/4.7.2.stable/
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-godot}"
mkdir -p build

# Import resources first so a fresh checkout (no .godot/ folder) exports cleanly
"$GODOT" --headless --import

"$GODOT" --headless --export-release "Windows Desktop" build/SkylineSwinger.exe
"$GODOT" --headless --export-release "Linux" build/SkylineSwinger.x86_64

# The APK is signed with a release key kept outside the repo; keep that key, or phones
# that have the game installed refuse updates signed with a different one.
KEYSTORE_DIR="${KEYSTORE_DIR:-$HOME/.local/share/godot/keystores}"
if [[ -f "$KEYSTORE_DIR/skyline-release.keystore" ]]; then
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE_DIR/skyline-release.keystore" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER=skyline \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$KEYSTORE_DIR/skyline-release.pass")" \
		"$GODOT" --headless --export-release "Android" build/SkylineSwinger.apk
else
	echo "No release keystore in $KEYSTORE_DIR, skipping the APK" >&2
fi

ls -lh build/SkylineSwinger.*
