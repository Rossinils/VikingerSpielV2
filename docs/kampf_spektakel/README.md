# Kampf-Spektakel: Ergebnisse der Entwurfsrunde (Stand 2026-11-04)

**Stand 2026-11-04 (später):** Ein erster sichtbarer Teil ist im Spiel (vereinfacht, ohne die Architektur aus `SPEC.md`):
die Bühne mit fünf Orten und Licht (`scripts/fight_stage.gd`, `tools/make_stage_art.py`), die doppelt gezeichneten Kampffiguren
(das "2x-Gerüst" der SPEC), das Fokus-Licht auf den Handelnden und die Ziele, mitwachsende Kampfeffekte, die Einstellung
"Kampfbild: voll/schlicht". Ebenfalls fertig: das Fundament W1-01 (Ereignisfelder, `stage_t`, Verträge, `eventtest`).
**Noch offen:** Körper-Rig mit Posen (W1-05 und W1b), Regie mit Beats und Kamera (W1-02), Wucht-Schrift und Zahlen (W1-07),
Oberfläche mit Zugleiste und Fokusschild (W1-08), neue Klänge (W1-09). Das Spiel ist sonst unverändert.

* `SPEC.md` : der gemeinsame Plan (Zielbild, Architektur, Schnittstellenverträge, Wellen und Aufgabenkarten, Pflichtprüfungen, Risiken). Die Prüfung durch einen kritischen Helfer steht noch aus.
* `D1_regie.md`, `D2_bild.md`, `D3_wucht.md` : die drei Entwürfe (Fokusführung, Bühne und Grafik, Effekte und Oberfläche).
* `R1_ablauf.md` bis `R5_oberflaeche.md` : die fünf Recherchen (Ablauf und Ereignisse, Figuren, Bühnentechnik mit Prototypen, Vorbild, Oberfläche).
* `img/` und die Prototyp-Dateien (`*.gd.txt`, `*.py`, `*.diff.txt`) : Belege und Vorarbeiten.
* Prototyp-Arbeitskopien liegen unter `..\..\..\_sandbox\` (ablauf, figuren, buehne, oberflaeche).

Weiter mit: SPEC.md lesen, optional Prüfung, dann Welle 1 (Bausteine), Welle 2 (Einbau in hud.gd), Welle 3 (Feinschliff).
