# Auftragsblatt: Kampf-Spektakel für "Halt Kurs"

Alle Helfer lesen zuerst dieses Blatt. Es gilt für jede Teilaufgabe.

## Das Spiel

"Halt Kurs" ist ein düsteres Wikinger-Roguelike (Godot 4.7.2, GDScript, nur Deutsch, Windows). Man führt ein Langschiff über die See,
verwaltet eine Mannschaft und kämpft in **rundenbasierten Deckkämpfen** im Stil von Darkest Dungeon (vier Männer gegen bis zu vier
Gegner, Reihen 1 bis 4, sechs Fertigkeiten je Mann, Gegnerrollen, Kraken als Boss). Alle Bilder und Töne entstehen als Code
(Python-Skripte in `tools/`, Pixelart ohne Zeichenprogramm). Der Besitzer spielt auf einem 3120x2080-Bildschirm.

Projektordner: `C:\Users\trell\OneDrive\Coding\Spielmodding\Vikingerspiel_v2\` (kein Git, ein Backup liegt in
`..\_backup_vor_kampfspektakel\`). Spielfeld 480x320 Pixel, Stretch `canvas_items` fraktional, Nearest-Filter, `snap_2d_transforms_to_pixel`
und `snap_2d_vertices_to_pixel` sind AN (gedrehte oder skalierte Sprites werden auf Pixel gerastet: erst ausprobieren, dann verlassen).

## Der Auftrag des Besitzers (wörtlich)

"Mach die Kämpfe noch spannender, und intensiver, bei Darkest Dungeon sind die Charaktere, die einen Angriff machen z.B. richtig im Fokus
und so. Bohre auch gerne die Grafik deutlich auf, damit es mitreißender ist."

Gemeint: Wer angreift, steht im Rampenlicht (Kamera, Licht, Pose, Namensschild), Treffer haben Wucht, die Kampfbühne sieht
viel reicher aus (Hintergründe, Licht, Atmosphäre, größere und lebendigere Figuren, bessere Effekte). Der Besitzer entscheidet nichts
im Einzelnen; ihr entscheidet selbst, was am besten wirkt, und macht es.

## Was es schon gibt (Stand heute)

* Kampfregeln: `scripts/combat.gd` (Klasse `Combat`, innere Klasse `Fighter`). Zustände `state` = "hero" | "foe" | "done". `Combat.events`
  ist die Ereignisliste (Felder: `id`, `type` = attack | hit | miss | heal | die | overboard | spawn | text | heroic | snap, `who`, `sk`
  (Fertigkeit), `crit`, `n` (Schaden/Heilung), `text`). Diese Datei ist **Regelwerk, nicht anfassen** außer um Ereignisfelder zu ergänzen
  (dann alle Tests laufen lassen). Balance bleibt, wie sie ist.
* Anzeige: `scripts/hud.gd` (2991 Zeilen, `class_name Hud`, ein Control, zeichnet alles in `_draw`). Kampfteile: `fight_click` (~1729),
  `fight_key`, `_fight_events` (~1891, übersetzt Ereignisse in Animation, Zahlen, Klang, Effekte), `_fight_outro`, `_fx_go/_fx_hit/_fx_miss`,
  `_tick_fight`, `_draw_deck`, `_draw_fighter` (~2208), `_draw_fight_overlay`, `_draw_fight_texts` (Vignette, Blitz, Banner, große Ansage),
  `_draw_combat_view` (~2340: Zugleiste, Bühne, Meldungen, Fertigkeitskarten), `_draw_fight_prep` (Aufstellung).
* Effekte: `scripts/fight_fx.gd` (`FightFx`): Items (slash, bash, arrow, whip, bite, heal, notes, shield, ink, ring, dust, bullet, muzzle, spark),
  Cues (shake, flash, freeze, slowmo, zoom), Banner mit Fertigkeitsname und Symbol, große Ansage (HELDENMUT, ZUSAMMENBRUCH, SIEG ...).
* Figuren: `assets/combat.png` (erzeugt von `tools/make_combat_art.py`, Hilfsklasse `Img` aus `tools/make_art.py`): Zelle 44x56, Füße auf Zeile 52,
  Spalten = Posen (0 Stehen A, 1 Stehen B, 2 Angriff, 3 Treffer, 4 An der Schwelle), Zeilen = 5 Rollen der Männer (Schild, Axt, Bogen,
  Skalde, Musketier) dann die Gegner (`Foes.ROW`). Der Kraken ist ein Riese (`assets/kraken.png`, 88x88, `Foes.BIG`). Symbole der Fertigkeiten:
  `assets/skill_icons.png` (`scripts/skill_icons.gd`).
* Bühne heute: Planken-Deck bei `FIGHT_FEET = 120`, Figuren in einer Reihe (`FIGHT_HERO_X`, `FIGHT_FOE_X`), dunkler Hintergrund, Bühne nur
  y 0..166, darunter Meldungen (y 172..230) und sechs Fertigkeitskarten (y 242..300). Nur ein "Kameraschub" (`zoom`) und Wackeln, keine Fokusführung.
* Weitere Weltbilder (wiederverwendbar): Himmel, Wolken, Wasser, das Schiff der Männer (`assets/ship.png`), Gegnerschiffe (`assets/enemies.png`,
  Zellen 128x96), Küste, Möwen; Schichten in `scripts/*_layer.gd`, Wellen in `scripts/waves.gd`.
* Töne: `tools/make_sfx.py` (reines Python, 63 Klänge in `assets/sfx/`), Wiedergabe `scripts/sfx.gd` (`Sfx.play(name, db, delay, pitch)`, Tabelle `GAIN`).

## Regeln, die immer gelten

* **Keine sichtbaren Fenster, kein Ton in Tests.** Tests laufen `--headless`, Screenshots mit `--no-window`. Nie alle Godot-Prozesse beenden,
  höchstens den eigenen (die Hilfsskripte tun das richtig).
* Texte im Spiel nur Deutsch, Umlaute echt (UTF-8), kein Emoji. Code und Kommentare im Stil der Umgebung (deutsche Kommentare, Tabs, knapp).
* **Kein Absturz im Headless-Modus:** `Hud._draw` läuft dort nicht, Texturen nur laden, wenn `DisplayServer.get_name() != "headless"`.
* Kampfregeln, Balance, Speicherstände, Tests dürfen nicht kaputtgehen: `tools/dev/rungd.ps1 -Script tools/selftest.gd` muss `FEHLER: 0` melden,
  `tools/sfxtest.gd` und `tools/musictest.gd` ebenfalls, Bots (`tools/dev/runbots.ps1`) ohne Fehlerzeilen.
* Das schnelle Auflösen von Kämpfen (`voy.auto_combat`, Einstellung "schnell") und Bots dürfen durch Inszenierung nie langsamer oder blockiert
  werden. Inszenierung ist reine Anzeige und wartet nie auf Eingaben.
* Spielfluss bleibt klar: Zielwahl per Klick/Tasten (Q W E R), Fertigkeiten 1 bis 6, Leertaste wartet, Esc bricht ab, Tooltips bleiben.
* Pro Bild ein vernünftiges Budget: einige hundert Zeichenaufrufe sind ok, Tausende nicht.

## Werkzeuge (alle in `tools/dev/`, funktionieren in jeder Arbeitskopie)

* `rungd.ps1 -Script tools/selftest.gd -Tail 1500 -Timeout 900` : Skript headless starten; `-Script import` nach neuen PNG/WAV/`class_name`-Dateien.
  Parse-Fehler zeigt Godot nur dort (`SCRIPT ERROR`), also nach jeder Änderung einmal `import` oder einen Test laufen lassen.
* `shot.ps1 -Out C:\pfad\bild.png -Sec 3 -Flags "--shotfx --hovermouse=1,1"` : Screenshot (2881x1921). Flags für Kämpfe: `--shotfight` (Aufstellung),
  `--shotfight2` (Kampf, Mann am Zug), `--shotfight3` (mit gewählter Fertigkeit), `--shotfx` (Bogenschuss mitten im Flug), `--shotfx2` (Axthieb),
  `--shotfx3` (Musketenschuss), `--shotkraken`, `--shotkraken2`, `--shotheroic`, `--shotsnap`, `--shotloadout`, `--hovermouse=x,y`. Neue Flags
  dürft ihr in `scripts/main.gd` ergänzen (Block der `_shot_*`-Variablen und `_ready`), z. B. für bestimmte Szenen. Das Bild lesen mit dem Read-Werkzeug.
* `runbots.ps1 -Mode --autoplay -Seeds @(1,2,3)` und `-Mode --random`: ganze Fahrten durch Bots. `tools/combatsim.gd` rechnet Kämpfe durch.
* `make_sandbox.ps1 -Name x` legt eine **eigene Arbeitskopie** unter `..\_sandbox\x\` an (mit Importcache). `deliver.ps1 -Name x -Files a,b` kopiert
  fertige Dateien ins Hauptprojekt. **Parallele Helfer arbeiten nie am selben Ort**: wer im Auftrag "Arbeitskopie" liest, entwickelt und testet nur dort
  und liefert am Ende ausschließlich die Dateien, die ihm gehören.
* Python: `C:\Users\trell\AppData\Local\Programs\Python\Python313\python.exe -X utf8 -I tools/make_combat_art.py` (nur Standardbibliothek, kein PIL).
* Godot-Konsole: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.

## Fallen, in die schon jemand getappt ist

* PowerShell: Backticks in Doppelstrings sind Escapes (`t, `b, `a): Texte mit Backticks in einfache Anführungszeichen. `A + "`n" + B` in Befehlen immer klammern.
* GDScript: `var x := [1.0, 2.0][i]` lässt sich nicht typ-ableiten (Typ angeben); `for x in (a, b)` gibt es nicht (Array `[a, b]` nehmen); innerhalb einer Funktion
  keine Variable zweimal deklarieren (auch nicht in verschachtelten Blöcken); `%` in Formatstrings als `%%`; Engine-Fehler tauchen im Log als "SCRIPT ERROR" auf.
* `draw_*` nur innerhalb von `_draw` des jeweiligen CanvasItem (Hilfsklassen bekommen das Hud übergeben, wie `scripts/slot_view.gd`).
* `tools/selftest.gd` ist eine einzige große Funktion: eigene Variablen dort mit eindeutigem Präfix.
* Nach jeder neuen Datei mit `class_name` oder neuem PNG/WAV einmal importieren (`rungd.ps1 -Script import`).
* Die Auflösung der Screenshots ist 6,0x (2881x1921 für 480x320): Pixelkanten sind sichtbar, genau das ist gewollt.

## Ablieferung

Jeder Helfer schreibt am Ende eine kurze Meldung (was fertig ist, welche Dateien, welche Schnittstellen, was offen bleibt, wo Bilder liegen).
Lange Dokumente gehören in Dateien unter `docs/kampf_spektakel/`, nicht in die Antwort.
