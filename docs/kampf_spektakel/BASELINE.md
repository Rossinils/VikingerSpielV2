# BASELINE und Stand W1-01 (Fundament), 2026-11-04

Gemessen mit Godot 4.7.2 (Linux, headless), vor und nach dem Einspielen der Ereignisfelder.

| Messung | Vorher | Nachher |
|---|---|---|
| `selftest` | FEHLER: 0 | FEHLER: 0 |
| `sfxtest` | FEHLER: 0 | FEHLER: 0 |
| `musictest` | FEHLER: 1 ("erstes Stück wurde nicht geladen") | FEHLER: 1, unverändert; Umgebung (Linux ohne Audio), kein Codefehler |
| `evhash` Logik-Prüfsumme | 3356533480 | 3356533480 (gleich) |
| `evhash` Ereignis-Prüfsumme | 1343226653 | 309458424 (erwartet: neue Ereignisse) |
| `evtime` draugr, 400 Kämpfe | 6,48 ms je Kampf, 122 Ereignisse | 7,58 ms (+17 %), 200 Ereignisse |
| `evtime` kraken, 400 Kämpfe | 6,98 ms, 172 Ereignisse | 8,19 ms (+17 %), 264 Ereignisse |

`STAGE Messung` der Foto-Läufe fehlt: die Foto-Flags (`--shotfight2` usw.) und das Rendern gibt es in dieser Umgebung nicht. Wird nachgeholt, sobald es einen Rechner mit Fenster gibt.

## Geliefert
* `scripts/combat.gd`: Ereignisfelder nach SPEC 3.1 (`act`, `by`, `rank`, `round`, `tgts`, `tgt`, `hp0`, `hp1`, `lethal`, `door`, `resist`, `dot`, `turn`, `move`, `skip`, `wait`, `flee`).
* `scripts/voyage.gd`: `stage_t`, `combat_stage()`, Gegnerzug und Kampfende warten auf `stage_t`.
* `scripts/settings.gd`: `fight_view`, `shake`, `stage_fx`.
* `scripts/fight_level.gd`, `fight_geo.gd`, `fight_views.gd`: Vertragsdateien wortgleich aus SPEC 3.2.
* `tools/evhash.gd`, `evtime.gd`, `eventtest.gd` (200 Kämpfe, Ereignisfelder, FightLevel, FightGeo, `stage_t`).

## Befunde
1. **Rechenzeit +17 % statt +15 %.** Grund: rund 60 % mehr Ereignisse je Kampf. Betrifft nur den Schnellmodus; knapp über der Grenze, noch nicht optimiert.
2. **`layer_xf` bei Tiefe > 1** (Vordergrund) lässt bei extremem Schwenk (`center_x` am Rand) 1 bis 16 px Lücke, weil die Formel den Schwenk verstärkt. Für Tiefe ≤ 1 (Hintergründe) ist die Abdeckung vollständig. Vordergrundschichten müssen breiter als 480 px sein oder den Schwenk begrenzen (offen für W1-03).
3. Nicht gebaut: `lumcheck.py`, `contactsheet.py`, `fighttests.ps1` (Windows/PowerShell, Foto-Werkzeuge).
