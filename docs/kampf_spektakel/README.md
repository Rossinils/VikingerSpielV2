# Kampf-Spektakel: Ergebnisse der Entwurfsrunde (Stand 2026-11-04)

**Stand 2026-11-04 (später, zweiter Teil):** Im Spiel sind jetzt außer der Bühne auch die **Körperfiguren** (W1-05, W1b, W1-06: alle 23
Menschen, Hund und Fangarm mit je 32 bzw. 21/23 Bildern, `assets/fig/`, `tools/make_fig_rig.py`) und die **Regie mit Kamerawucht**
(W1-02 und W2-01 in der Kurzfassung: `scripts/fight_director.gd`, `beat_planner.gd`, `fight_cam.gd`; Standbild, Zeitlupe, Kamerafahrt,
Wackeln, weißer Blitz, Rückstoß, Nachbilder, Stern am Einschlag, Licht je Rolle, Zeitbudget je Kampf, Kampfansicht voll/kurz). Geprüft
mit `tools/figtest.gd` und `tools/directortest.gd` sowie einem Dauertest (`--fightsoak`). Abweichungen von der SPEC: die Rig-Zelle ist
eingebaut in die vorhandene Bühne (Fußlinie 140 statt 172, `FightGeo` trägt die Maße des Spiels); die Anker stehen in `scripts/fig_atlas.gd`
statt in einer JSON-Datei je Figur (ein exportiertes Spiel enthält keine losen JSON-Dateien); die Streifen haben eine zweite, weiße
Zeile (Trefferblitz ohne Shader); der Kraken wird zur Laufzeit gestreckt und gesenkt, statt neue Bilder zu bekommen.
**Noch offen:** Wucht-Schrift und Zahlenarten (W1-07), Oberfläche mit Zugleiste, Fokusschild und Statussymbolen (W1-08), neue Klänge
(W1-09), `FightPresenter` als eigene Klasse (die Anbindung steckt noch in `hud.gd`), Spaltversatz bei schweren Treffern.

* `SPEC.md` : der gemeinsame Plan (Zielbild, Architektur, Schnittstellenverträge, Wellen und Aufgabenkarten, Pflichtprüfungen, Risiken). Die Prüfung durch einen kritischen Helfer steht noch aus.
* `D1_regie.md`, `D2_bild.md`, `D3_wucht.md` : die drei Entwürfe (Fokusführung, Bühne und Grafik, Effekte und Oberfläche).
* `R1_ablauf.md` bis `R5_oberflaeche.md` : die fünf Recherchen (Ablauf und Ereignisse, Figuren, Bühnentechnik mit Prototypen, Vorbild, Oberfläche).
* `img/` und die Prototyp-Dateien (`*.gd.txt`, `*.py`, `*.diff.txt`) : Belege und Vorarbeiten.
* Prototyp-Arbeitskopien liegen unter `..\..\..\_sandbox\` (ablauf, figuren, buehne, oberflaeche).

Weiter mit: SPEC.md lesen, optional Prüfung, dann Welle 1 (Bausteine), Welle 2 (Einbau in hud.gd), Welle 3 (Feinschliff).
