#!/usr/bin/env bash
# Screenshot unter Linux (auch in der Cloud): virtueller Bildschirm (Xvfb) + Software-Rendering, kein Fenster, kein Ton.
# Gegenstück zu tools/dev/shot.ps1. Aufruf: tools/dev/shot.sh <ausgabe.png> [sekunden] [flags...]
# Beispiel:  tools/dev/shot.sh /tmp/a.png 3 --shotfight2 --hovermouse=1,1
# Umgebung:  GODOT=/pfad/zu/godot (Standard: godot im PATH), SHOT_RES=1920x1280 (Spielfeld 480x320, Faktor 4)
set -u
OUT="${1:?Ausgabedatei fehlt}"; SEC="${2:-3}"; shift 2 2>/dev/null || shift $#
GODOT="${GODOT:-godot}"; RES="${SHOT_RES:-1920x1280}"
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
export LIBGL_ALWAYS_SOFTWARE=1
LOG="$(mktemp)"
timeout "${SHOT_TIMEOUT:-180}" xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --rendering-driver opengl3 --rendering-method gl_compatibility \
	--resolution "$RES" --path "$PROJ" -- "--shot=$OUT@$SEC" --nohelp --nosave "$@" >"$LOG" 2>&1
grep -E "Screenshot|STAGE Messung" "$LOG" | tail -3
grep -E "TEXTCHECK" "$LOG" | sort -u | head -30
grep -E "SCRIPT ERROR|^ERROR|Parse Error|WARNING: .*\.gd" "$LOG" | grep -v 'status < 0\|set_use_vsync\|audio_server\|Musik/' | head -15
rm -f "$LOG"
