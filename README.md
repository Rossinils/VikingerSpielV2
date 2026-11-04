# Halt Kurs

Düsteres Wikinger-Roguelike (Godot 4.7.2, GDScript, 2D-Pixelart, 480×320, nur Deutsch): ein Langschiff, eine Mannschaft,
eine endlose Fahrt über eine immer rauere Nordsee. Das Spiel und seine Regeln stehen in [`KONZEPT.md`](KONZEPT.md).

## Schnellstart

**Voraussetzung:** Godot **4.7.2** (Standardversion, nicht „.NET“): <https://godotengine.org/download/archive/4.7.2-stable/>
oder unter Windows `winget install GodotEngine.GodotEngine`.

| System | Starten |
|---|---|
| Windows | `start.bat` doppelklicken |
| Linux / macOS | `./start.sh` (Godot im `PATH` oder `GODOT=/pfad/zu/godot ./start.sh`) |
| Godot-Editor | Projekt-Manager → *Importieren* → `project.godot` → F5 |

Beim **ersten Start** importiert Godot alle Bilder und Töne (auf einem schnellen Rechner etwa zehn Sekunden, auf langsamen bis zu
einer Minute; das Fenster bleibt so lange leer). Danach startet das Spiel sofort. Weitere Schalter gehen an das Spiel, z. B. `start.bat --seed=3 --nohelp`.

Bedienung: siehe Tabelle in `KONZEPT.md` (Abschnitt *Bedienung*); H öffnet die Hilfe im Spiel.
Spielstand, Gedenkstein und Einstellungen liegen in `%APPDATA%\Halt Kurs v2` (Windows) bzw. `~/.local/share/Halt Kurs v2` (Linux).

## Musik (nicht im Repository)

Der Ordner `Musik/` (214 MB) steht in `.gitignore`. Fehlen Stücke, bleibt das Spiel in der Musik stumm (Effekte gibt es trotzdem) und
meldet beim Start einmal, wie viele fehlen.

* Die vier **Hintergrundstücke** ohne Gesang erzeugt `python tools/make_music.py` (nur Standardbibliothek) nach `Musik/Hintergrund/`.
* Die **Lieder mit Gesang** kommen nicht aus den Skripten und müssen von Hand in `Musik/` liegen (Dateinamen: siehe
  `scripts/music.gd`, Tabelle `TRACKS`).
* Danach Godot einmal öffnen oder `tools/dev/rungd.sh import` ausführen, damit die neuen Dateien importiert werden.

## Prüfen

Alles läuft ohne Fenster und ohne Ton:

```
godot --headless --path . --script tools/selftest.gd     # Regeln und Oberfläche, Ende: "FEHLER: 0"
godot --headless --path . --script tools/sfxtest.gd      # Klänge
godot --headless --path . --script tools/musictest.gd    # Musikregie (übersprungen, solange nicht alle 8 Stücke da sind)
godot --headless --path . --script tools/eventtest.gd    # Ereignisfelder des Deckkampfs (200 Kämpfe)
godot --headless --path . --script tools/evhash.gd       # Logik-Prüfsumme der Kämpfe; muss 3356533480 bleiben
godot --headless --path . -- --autoplay --log --timescale=25 --seed=3 --maxstage=8 --nosave    # ein Bot spielt eine Fahrt
```

Alles zusammen: `tools/dev/alltests.sh` (Linux/macOS/Git Bash). Unter Windows gibt es PowerShell-Hilfen in `tools/dev/`
(`rungd.ps1`, `runbots.ps1`, `shot.ps1`); sie finden Godot über die Umgebungsvariable `GODOT`, sonst im winget-Ordner.

### Screenshots ohne sichtbares Fenster

Das Spiel hat eingebaute Screenshot-Schalter (`--shot=bild.png@3` plus z. B. `--shotfight2`, `--shotslot=win`, `--shotcrew`;
alle stehen im Kopf von `scripts/main.gd` und in `KONZEPT.md`):

* Windows: `tools\dev\shot.ps1 -Out C:\temp\a.png -Sec 3 -Flags "--seed=3 --shotfight2"`
* Linux / Cloud (virtueller Bildschirm Xvfb, Software-Rendering): `tools/dev/shot.sh /tmp/a.png 3 --seed=3 --shotfight2`
* Alle Bildschirme auf einmal: `tools/dev/shots_all.sh /tmp/bilder`. Der Schalter `--textcheck` meldet dabei Text, der
  breiter ist als sein Feld (so ein Text wird sonst am Rand hart abgeschnitten).

Unter Linux rendert Godot mit OpenGL (`gl_compatibility`); Farben und Schatten können von der Windows-Darstellung leicht abweichen.

## Grafik und Klänge neu erzeugen

Alle Bilder und Töne kommen aus Python-Skripten in `tools/` (nur Standardbibliothek, kein Pillow nötig). Die Ergebnisse
liegen eingecheckt in `assets/`; neu erzeugen muss man nur nach einer Änderung am Skript (ein Lauf aller Skripte dauert
unter einer Minute und liefert byteweise dieselben Dateien wie die eingecheckten):

| Skript | Ergebnis |
|---|---|
| `tools/make_art.py` | `ship.png`, `crew.png` (Schiff, Mannschaftsgesichter) |
| `tools/make_combat_art.py` | `combat.png` (Kampffiguren: Männer und Gegner), `kraken.png` |
| `tools/make_enemies.py` | `enemies.png` (Kulissen der Begegnungen) |
| `tools/make_sky.py` | `coast.png`, `gulls.png`, `cloud_noise.png` |
| `tools/make_ui.py` | `ui.png`, `vignette.png` und `scripts/ui_atlas.gd` (Rahmen, Knöpfe, Karte) |
| `tools/make_skill_icons.py` | `skill_icons.png` |
| `tools/make_slot_art.py` | `slots.png` (Walzensymbole) |
| `tools/make_item_icons.py` | `item_icons.png` (36 Gegenstands-Symbole x 4 Seltenheiten), `perk_emblems.png` (14 Segen-Embleme) und `scripts/item_icons.gd`; Übersicht: `docs/grafik/` |
| `tools/make_sfx.py` | `assets/sfx/*.wav` (Klänge; „It's alive!“ nutzt die Rohstimmen aus `tools/voice/`) |
| `tools/make_music.py` | `Musik/Hintergrund/*.wav` |

Aufruf: `python -X utf8 -I tools/make_art.py`. Danach `tools/dev/rungd.sh import` (bzw. Godot öffnen).

## Wo liegt was

| Ordner / Datei | Inhalt |
|---|---|
| `scripts/voyage.gd` | der Spielzustand und die Regeln der Fahrt (kennt keine Anzeige) |
| `scripts/hud.gd` | die gesamte Oberfläche (zeichnet in `_draw`, Klickflächen über `_register`) |
| `scripts/main.gd` | Start, Eingaben, Testschalter und Screenshot-Abläufe |
| `scripts/combat.gd`, `roles.gd`, `foes.gd` | Deckkampf: Regeln, Rollen und Fertigkeiten, Gegner |
| `scripts/battle.gd`, `encounters.gd` | Seeschlacht, Begegnungen |
| `scripts/slots.gd`, `slot_view.gd` | Spielautomaten: Regeln und Anzeige (siehe `AUTOMATEN.md`) |
| `scripts/items.gd`, `gear.gd`, `perks.gd` | Schiffsgegenstände, Ausrüstung der Männer, Segen (je mit Seltenheiten) |
| `scripts/fight_*.gd` | Grundlagen für das Kampf-Spektakel (siehe unten) |
| `tools/` | Tests (`*test.gd`, `selftest.gd`), Asset-Skripte (`make_*.py`), Entwicklungshilfen (`tools/dev/`) |
| `docs/kampf_spektakel/` | Entwurf und Plan für die überarbeitete Kampfansicht (`SPEC.md`, `BASELINE.md`) |

## Weitere Dokumente

`KONZEPT.md` (Spiel und Regeln) · `KAMPFSYSTEM.md` (Deckkampf, Zahlen) · `BESATZUNG_UND_LAGER.md` · `AUTOMATEN.md` ·
`IDEEN.md` (Rückstellungen) · `docs/kampf_spektakel/README.md` (Stand des Kampf-Spektakels).

## Windows-Export

`export_presets.cfg` enthält das Preset „Windows Desktop“ (eine `Halt Kurs.exe` mit eingebettetem Paket, Ziel `build/`).
Es braucht die Godot-Exportvorlagen 4.7.2 (Editor → *Projekt → Exportieren*, oder
`godot --headless --path . --export-release "Windows Desktop"`). Die Datei ist nicht signiert; Windows warnt beim ersten Start.
