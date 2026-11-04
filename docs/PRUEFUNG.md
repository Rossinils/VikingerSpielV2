# Prüfung des Spiels (4. November 2026)

Geprüft wurde der Stand von `main` plus Kampf-Fundament (Branch `kampf-spektakel-w1-01`) mit Godot 4.7.2 unter Linux:
headless für die Logik, mit virtuellem Bildschirm (Xvfb, OpenGL-Software-Rendering) für echte Screenshots aller Bildschirme.
Die Darstellung unter Windows (Vulkan) kann in Farbe und Schatten leicht abweichen; die Layout-Befunde gelten für beide.

## Kurzfassung

* **Struktur: tragfähig.** Regeln (`Voyage`, `Combat`, `Battle`, `Slots`) kennen die Anzeige nicht (`Voyage` verweist nirgends auf `Hud`);
  Klickflächen entstehen beim Zeichnen (`_register`), nicht in einer zweiten, abweichenden Rechnung; alle Zahlen stehen an einer Stelle
  (`strategy.gd`, `roles.gd`, `items.gd`, `gear.gd`). Die Asset-Skripte liefern byteweise dieselben Dateien wie die eingecheckten.
* **Funktion: keine Abstürze, keine Hänger.** Sieben Bot-Fahrten (4 kluge, 3 zufällige) enden regulär, null Fehlerzeilen. Kluger Bot im
  Mittel Etappe 5,25 (Konzept: etwa 5). `selftest`, `sfxtest`, `eventtest` grün, Logik-Prüfsumme der Kämpfe unverändert (3356533480).
* **Hauptfehlerklasse: abgeschnittener Text** (das hatte der Besitzer gemeldet). Sie ist jetzt in der Oberfläche abgesichert und mit
  `--textcheck` prüfbar. Dazu zwei Fehler im Speichern und mehrere kleine Layout-Fehler (unten).

## Gefundene und behobene Fehler

| # | Fehler | Wirkung | Behebung |
|---|---|---|---|
| 1 | `draw_string` mit Breite **schneidet Text hart ab**; viele Aufrufe gaben eine zu kleine Breite | Aufstellung: „…wählt die Ferti“; Seeschlacht-Karten: „Gegnerbesatzun“, „Verluste möglicl“; Rettung: „…wechseln.“ fehlt | `Hud._t` verkleinert zu breiten Text bis Größe 6, dann „…“; Karten bekommen ihre Breite; Texte gekürzt (`hud.gd`) |
| 2 | Vorschau links: Zeilen ohne Breite | „Kurs wählen: Knoten rechts anklicken“ ragte aus dem Kasten | `_fit_lines` bricht an Wortgrenzen um, der Kasten wächst mit |
| 3 | `Tips.skill_short`: Kriegslied zeigte „alle, “ ohne Rundenzahl; Heilsegen/Trostlied eine leere Zeile; Fallback schnitt bei 18 Zeichen mitten im Wort | Kampfkarten unvollständig | Rundenzahl, „für einen Mann“, Umbruch an Wortgrenzen (`tips.gd`) |
| 4 | `Persist` schrieb direkt in die Zieldatei | Abbruch beim Schreiben (Fenster zu, Absturz) = abgeschnittene Datei = Fahrt weg; beim **Gedenkstein** würde die ganze Historie mit einer leeren Liste überschrieben | `write_json_safe`: erst `.tmp`, dann austauschen, vorige gute Fassung als `.bak`; Laden fällt auf `.bak` zurück; Tests in `selftest.gd` |
| 5 | `main.gd` prüfte vor dem Fortsetzen nur 3 Schlüssel | Spielstand ohne die übrigen Kernschlüssel: Absturz im Laden | `Persist.resumable()` prüft alle zwölf, sonst neue Fahrt |
| 6 | Pfandflaschen-Hinweis lag in der Werft **über dem Hinweistext** | Text unleserlich | Hinweis unten rechts |
| 7 | Werft/Rüstkammer-Angebote: vierte Werte-Zeile ragte über den Kartenrand; Titel „Rüstkammer“ stieß an die Reiter | Layout | Karten 58 statt 56 hoch, Titel mit Breite |
| 8 | Ohne `Musik/` (steht in `.gitignore`) 8 Fehlermeldungen beim Start, `musictest` rot | frisch geklontes Projekt wirkt kaputt | `MusicDirector` prüft `ResourceLoader.exists`, meldet einmal; `musictest` überspringt, solange nicht alle acht Stücke da sind (`make_music.py` erzeugt vier in 30 s) |
| 9 | PowerShell-Hilfen mit festem winget-Pfad; kein README, keine Startdatei | lokal schwer zu starten | Umgebungsvariable `GODOT`, `README.md`, `start.bat`, `start.sh`, Linux-Gegenstücke in `tools/dev/` |

## Beobachtungen ohne Änderung

* **Größe:** `voyage.gd` 3404 Zeilen/210 Funktionen, `hud.gd` 3038 Zeilen/108 Funktionen, `main.gd::_ready` 370 Zeilen (Start vermischt mit
  Test- und Screenshot-Schaltern). Kein Fehler, aber das größte Wartungsrisiko. Naheliegende Schnitte, wenn es sich lohnt: Automaten-Anbindung
  und Werft/Schmiede aus `voyage.gd`; Screenshot-Abläufe aus `main.gd`; die Reiter der Werft aus `hud.gd`.
* **Toter Code** (Funktion kommt nirgends vor): `CrewMember.trait_names`, `Hud.strategy_rect`, `Tips.fatigue`, `Voyage.capacity`,
  `Voyage.is_brother_of`. Ungefährlich, nicht entfernt (könnten lokal in unveröffentlichten Änderungen gebraucht werden).
* **Lint** (Warnungen als Fehler in einer Kopie): nur Harmloses. 22 Ganzzahl-Divisionen (beabsichtigt), ungenutzte Parameter in `tips.gd`,
  `Combat.snapped` überdeckt die eingebaute Funktion `snapped()` (funktioniert), `main.gd:488` Coroutine ohne `await` (Screenshot-Pfad).
* **Rechenzeit der Kämpfe** im Schnellmodus +17 % durch die neuen Ereignisfelder (Vorgabe der SPEC: +15 %). Nicht optimiert.
* **Kampf-Spektakel:** `FightGeo.layer_xf` lässt bei Vordergrundschichten (Tiefe > 1) und extremem Schwenk 1 bis 16 px Lücke am Bildrand
  (Formel aus der SPEC). Für Hintergründe gilt die Abdeckung vollständig.
* **Nicht geprüft:** Klang und Musik nach Gehör, Spielgefühl und Balance, `start.bat` und die `.ps1`-Änderungen (kein Windows hier),
  der Windows-Export.

## Neue Grafik

Gegenstände, Ausrüstung und Segen hatten kein einziges Bild (reiner Text in Werft, Ausrüstung, Rüstkammer und beim Stufenaufstieg). Neu, aus
`tools/make_item_icons.py` (reproduzierbar, nur Standardbibliothek): 36 Symbole für alle Schiffsgegenstände, Ausrüstungsstücke und die
Pfandflasche, je in den vier Seltenheiten mit eingebranntem Rand (20×20), und 14 Medaillon-Embleme für die Segen (32×32).
Bilder dazu in `docs/grafik/` (Vorher/Nachher von Werft und Segen, Übersichten aller Symbole).

## Werkzeuge, die dabei entstanden sind

| Werkzeug | Zweck |
|---|---|
| `tools/dev/alltests.sh [--bots]` | alle Tests nacheinander, Ende-Code ≠ 0 bei Fehlern (~15 s ohne Bots) |
| `tools/dev/shot.sh`, `shots_all.sh` | Screenshots unter Linux/Cloud (Xvfb) von 35 Bildschirmen; `shots_all.sh` sammelt die `--textcheck`-Meldungen |
| `tools/dev/runbots.sh`, `rungd.sh` | Gegenstücke zu den `.ps1`-Hilfen |
| `--textcheck` (Spielschalter) | meldet Text, der breiter als sein Feld ist; ohne Sicherheitsnetz wäre er abgeschnitten |
| `tools/eventtest.gd` | 200 Kämpfe: Ereignisfelder, `FightLevel`, `FightGeo`, `stage_t` |

## Bekannte Meldungen von `--textcheck`

Lauf über alle 35 Bildschirme (`tools/dev/shots_all.sh`). Diese Texte setzt das Sicherheitsnetz heute eine Stufe kleiner oder kürzt sie;
lesbar, aber ein Hinweis, sie bei Gelegenheit zu kürzen (Breite in Klammern):

* Kartentexte, 54 px: „Nornenwalzen“, „Rauferei? 15 %“, „Gegnerzug ×0,4“, „Gegnerbesatzung“ (Größe 6), „Verluste möglich“ (Größe 6),
  „keine Kanonen“, „gibt es welche“
* Kartentexte, 98 px: „Funde: Proviant, Beute, Holz“, „Proviant +3 wahrscheinlich“
* Werft: „Rammschaden +13 · eigener Rammschaden −66 % · Rumpf +10“ (192 px, Größe 6; epische und legendäre Gegenstände haben oft drei Werte)
* Titel „Rüstkammer“ (Größe 15 statt 16), Hinweiszeile der Schmiede (Größe 6 statt 7)

Das Bild „Kraken“ beendet sich mit der Engine-Meldung „1 resources still in use at exit“ (harmlos, nur beim Beenden).
