#!/usr/bin/env bash
# Alle Prüfungen nacheinander, ohne Fenster und ohne Ton. Ende-Code 0 nur, wenn alles grün ist.
# Aufruf: tools/dev/alltests.sh [--bots]      (--bots: zusätzlich zwei Bot-Fahrten, dauert einige Minuten)
# Umgebung: GODOT=/pfad/zu/godot (Standard: godot im PATH)
set -u
GODOT="${GODOT:-godot}"; PROJ="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$PROJ"
bad=0
run() { # Name, Skript
	local out; out="$(timeout "${RUN_TIMEOUT:-900}" "$GODOT" --headless --path . --script "$2" 2>&1)"
	local fl; fl="$(echo "$out" | grep -E '^FEHLER: ' | tail -1)"
	if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error'; then echo "FEHLER  $1: Skriptfehler"; echo "$out" | grep -E 'SCRIPT ERROR|Parse Error' | head -3; bad=$((bad+1))
	elif [ "$fl" = "FEHLER: 0" ]; then echo "ok      $1 $(echo "$out" | grep -E '^übersprungen' | head -1)"
	else echo "FEHLER  $1: ${fl:-keine Ergebnis-Zeile}"; echo "$out" | grep -E '^(FAIL|FEHLER)' | head -5; bad=$((bad+1)); fi; }
run selftest tools/selftest.gd
run sfxtest tools/sfxtest.gd
run musictest tools/musictest.gd
run eventtest tools/eventtest.gd
run figtest tools/figtest.gd
run directortest tools/directortest.gd
h="$(timeout 600 "$GODOT" --headless --path . --script tools/evhash.gd 2>&1 | grep -oE 'Logik-Prüfsumme: [0-9]+' | grep -oE '[0-9]+')"
if [ "$h" = "3356533480" ]; then echo "ok      evhash (Logik-Prüfsumme $h unverändert)"; else echo "FEHLER  evhash: Logik-Prüfsumme ${h:-?} statt 3356533480 (Kampfregeln verändert?)"; bad=$((bad+1)); fi
if [ "${1:-}" = "--bots" ]; then
	r="$("$PROJ/tools/dev/runbots.sh" --autoplay 8 1 2 2>&1 | tail -1)"; echo "$r"
	echo "$r" | grep -q "beendet 2/2.*Fehlerzeilen 0, Timeouts 0" || bad=$((bad+1))
fi
[ $bad -eq 0 ] && echo "ALLES GRÜN" || echo "$bad Prüfung(en) fehlgeschlagen"
exit $bad
