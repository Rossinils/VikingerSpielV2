#!/usr/bin/env bash
# Lässt Bots komplette Fahrten spielen (headless, schnell), Gegenstück zu tools/dev/runbots.ps1.
# Aufruf: tools/dev/runbots.sh [--autoplay|--random] [maxstage] [seed ...]      Standard: --autoplay 8 1 2 3
# Zeigt je Seed die ENDE-Zeile und am Schluss: beendet x/n, mittlere Etappe, Fehlerzeilen, Timeouts.
# Umgebung: GODOT=/pfad/zu/godot, BOT_JOBS=<parallele Läufe, Standard 3>
set -u
MODE="${1:---autoplay}"; MAXST="${2:-8}"; shift 2 2>/dev/null || shift $#
SEEDS=("$@"); [ ${#SEEDS[@]} -eq 0 ] && SEEDS=(1 2 3)
GODOT="${GODOT:-godot}"; PROJ="$(cd "$(dirname "$0")/../.." && pwd)"; JOBS="${BOT_JOBS:-3}"
TMP="$(mktemp -d)"
run() { local sd="$1"
	timeout "${BOT_TIMEOUT:-600}" "$GODOT" --headless --path "$PROJ" -- "$MODE" --log --timescale=25 --seed="$sd" --maxstage="$MAXST" --nosave \
		>"$TMP/out_$sd.txt" 2>"$TMP/err_$sd.txt"; echo $? >"$TMP/rc_$sd.txt"; }
n=0; for sd in "${SEEDS[@]}"; do run "$sd" & n=$((n+1)); if [ $((n % JOBS)) -eq 0 ]; then wait; fi; done; wait
ended=0; errs=0; to=0; sum=0
for sd in "${SEEDS[@]}"; do
	end="$(grep -m1 '^ENDE' "$TMP/out_$sd.txt" || true)"
	[ "$(cat "$TMP/rc_$sd.txt")" = "124" ] && { to=$((to+1)); echo "Seed $sd : TIMEOUT"; }
	if [ -n "$end" ]; then ended=$((ended+1)); e="$(echo "$end" | sed -n 's/.*Etappe \([0-9]*\).*/\1/p')"; [ -n "$e" ] && sum=$((sum+e)); fi
	k="$(grep -cE 'ERROR|SCRIPT' "$TMP/err_$sd.txt" || true)"; errs=$((errs+k))
	echo "Seed $sd: ${end:-(kein ENDE)}"
	[ "$k" -gt 0 ] && grep -E 'ERROR|SCRIPT' "$TMP/err_$sd.txt" | head -5
done
echo "$MODE: beendet $ended/${#SEEDS[@]}, Etappen-Summe $sum, Fehlerzeilen $errs, Timeouts $to"
rm -rf "$TMP"
