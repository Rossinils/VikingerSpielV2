#!/usr/bin/env bash
# Baut die Windows-Fassung (eine .exe mit eingebettetem Paket) und packt sie mit LIES MICH.txt in build/Halt_Kurs_Windows.zip.
# Läuft unter Linux/macOS/Git Bash. Voraussetzung: Godot 4.7.2 und die Exportvorlagen 4.7.2 (Windows x86_64):
#   Linux: ~/.local/share/godot/export_templates/4.7.2.stable/windows_release_x86_64.exe (+ version.txt)
#   Editor: Projekt -> Exportieren -> Exportvorlagen verwalten -> Herunterladen
# Musik: die zehn Hintergrundstücke ohne Gesang werden bei Bedarf erzeugt (tools/make_music.py --missing). Die Lieder mit Gesang
# kommen nur mit, wenn sie in Musik/ liegen (sie sind nicht im Repository): für die volle Fassung dort bauen, wo Musik/ liegt.
# Aufruf: tools/dev/export_windows.sh          Umgebung: GODOT=/pfad/zu/godot
set -eu
GODOT="${GODOT:-godot}"; PROJ="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$PROJ"
echo "Hintergrundmusik: fehlende Stücke werden erzeugt (je Stück einige Sekunden) ..."
python3 -X utf8 -I tools/make_music.py --missing
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
mkdir -p build
rm -f "build/Halt Kurs.exe" build/Halt_Kurs_Windows.zip
"$GODOT" --headless --path . --export-release "Windows Desktop" "build/Halt Kurs.exe" 2>&1 | grep -vE "^Godot Engine|^$" || true
[ -f "build/Halt Kurs.exe" ] || { echo "FEHLER: build/Halt Kurs.exe wurde nicht erzeugt (fehlen die Exportvorlagen?)"; exit 1; }
cp tools/dev/LIES_MICH_Windows.txt "build/LIES MICH.txt"
(cd build && python3 - <<'PY'
import zipfile
with zipfile.ZipFile("Halt_Kurs_Windows.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    z.write("Halt Kurs.exe")
    z.write("LIES MICH.txt")
PY
)
ls -la build | awk '{print $5, $9}' | tail -n +4
