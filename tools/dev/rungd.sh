#!/usr/bin/env bash
# Führt ein GDScript (--script) oder den Import ("import") headless aus (Gegenstück zu tools/dev/rungd.ps1).
# Aufruf: tools/dev/rungd.sh tools/selftest.gd [Zeilen am Ende, Standard 40]   |   tools/dev/rungd.sh import
# Umgebung: GODOT=/pfad/zu/godot (Standard: godot im PATH)
set -u
S="${1:?Skript oder import}"; TAIL="${2:-40}"
GODOT="${GODOT:-godot}"; PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "$S" = "import" ]; then timeout 600 "$GODOT" --headless --path "$PROJ" --import 2>&1 | tail -n "$TAIL"
else timeout "${RUN_TIMEOUT:-900}" "$GODOT" --headless --path "$PROJ" --script "$S" 2>&1 | tail -n "$TAIL"; fi
