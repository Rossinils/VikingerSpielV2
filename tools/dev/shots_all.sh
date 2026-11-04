#!/usr/bin/env bash
# Fotografiert alle Bildschirme des Spiels mit den eingebauten Screenshot-Flags (Linux/Cloud) und sammelt TEXTCHECK-Meldungen.
# Aufruf: tools/dev/shots_all.sh <ausgabeordner> [Name ...]     ohne Namen: alle. Umgebung: GODOT, SHOT_JOBS (Standard 3)
set -u
OUT="${1:?Ausgabeordner}"; shift; mkdir -p "$OUT"
HERE="$(cd "$(dirname "$0")" && pwd)"; JOBS="${SHOT_JOBS:-3}"
declare -A S=(
	[karte]="3|--seed=3"
	[hafen]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotharbor"
	[werft]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotharbor --shopopen --giveloot"
	[ausruestung]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotgear --giveloot"
	[pfandflasche]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotharbor --shopopen --giveloot --givepfand"
	[werft_selten]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shoprare --giveloot"
	[schmiede]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotforge --giveloot"
	[ruestkammer]="4|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotarmory --giveloot"
	[taverne]="4|--seed=3 --shottavern"
	[lager]="4|--seed=3 --shotcamp"
	[crew]="3|--seed=3 --shotcrew"
	[stufenaufstieg]="3|--seed=3 --giveperk"
	[menue]="3|--seed=3 --menu"
	[einstellungen]="3|--seed=3 --menu --settingsopen"
	[begegnung]="3|--seed=3 --autoplay --timescale=15 --maxstage=3 --shotenc"
	[seeschlacht]="6|--seed=3 --forceenc=5 --shotbattle --autoplay"
	[aufstellung]="3|--seed=3 --shotfight"
	[kampf]="3|--seed=3 --shotfight2"
	[kampf_skill]="3|--seed=3 --shotfight3"
	[kraken]="3|--seed=3 --shotkraken"
	[kraken2]="3|--seed=3 --shotkraken2"
	[loadout]="3|--seed=3 --shotloadout"
	[fx_bogen]="3|--seed=3 --shotfx"
	[fx_hieb]="3|--seed=3 --shotfx2"
	[fx_muskete]="3|--seed=3 --shotfx3"
	[heldenmut]="3|--seed=3 --shotheroic"
	[zusammenbruch]="3|--seed=3 --shotsnap"
	[slot_dreh]="3|--seed=3 --shotslot=spin"
	[slot_gewinn]="3|--seed=3 --shotslot=win"
	[slot_lebt]="3|--seed=3 --shotslot=alive"
	[slot_frei]="3|--seed=3 --shotslot=free"
	[slot_jackpot]="3|--seed=3 --shotslot=jackpot"
	[loki]="3|--seed=3 --shotslot=loki"
	[loki_gewinn]="3|--seed=3 --shotslot=loki_win"
	[loki_fluch]="3|--seed=3 --shotslot=loki_curse"
)
names=("$@"); [ ${#names[@]} -eq 0 ] && names=($(printf '%s\n' "${!S[@]}" | sort))
one() { local n="$1"; local spec="${S[$n]}"; local sec="${spec%%|*}"; local fl="${spec#*|}"
	SHOT_TIMEOUT="${SHOT_TIMEOUT:-240}" "$HERE/shot.sh" "$OUT/$n.png" "$sec" $fl --hovermouse=1,1 --textcheck >"$OUT/$n.log" 2>&1
	[ -f "$OUT/$n.png" ] && echo "ok    $n" || echo "FEHLT $n"; }
i=0; for n in "${names[@]}"; do one "$n" & i=$((i+1)); [ $((i % JOBS)) -eq 0 ] && wait; done; wait
echo "--- TEXTCHECK (einmal je Text) ---"; cat "$OUT"/*.log | grep TEXTCHECK | sort -u
echo "--- Fehler ---"; cat "$OUT"/*.log | grep -E "SCRIPT ERROR|Parse Error|^ERROR" | grep -v 'status < 0\|Musik/\|set_use_vsync' | sort | uniq -c | head
