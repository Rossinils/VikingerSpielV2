#!/usr/bin/env bash
# Startet "Halt Kurs" (Linux/macOS). Godot 4.7.2 wird über die Umgebungsvariable GODOT gefunden, sonst als "godot" im PATH.
# Weitere Schalter gehen an das Spiel, z. B.:  ./start.sh --seed=3 --nohelp
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || { echo "Godot 4.7.2 nicht gefunden. Installieren (https://godotengine.org/download/archive/4.7.2-stable/) und GODOT=/pfad/zu/godot setzen." >&2; exit 1; }
exec "$GODOT" --path . -- "$@"
