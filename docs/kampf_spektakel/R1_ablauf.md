# R1: Ablauf und Ereignismodell des Deckkampfs

Stand: 3. November 2026. Grundlage: `scripts/combat.gd`, `scripts/voyage.gd`, `scripts/hud.gd`, `scripts/main.gd`, `scripts/fight_fx.gd`,
`scripts/roles.gd`, `scripts/foes.gd`, `scripts/sfx.gd`, `tools/combatsim.gd`, `tools/selftest.gd` (alles gelesen, Zeilennummern beziehen sich auf den Stand
vom 3. November, Hauptprojekt unverändert).

**Messweise.** Alles, was als *gemessen* bezeichnet ist, stammt aus Skripten, die in der Arbeitskopie `..\_sandbox\ablauf\` liefen (Kopien in
`docs/kampf_spektakel/R1_werkzeuge/*.gd.txt`, zum Benutzen nach `tools/` kopieren und `.txt` entfernen). Alles andere ist aus dem Quelltext gelesen.
Das Hauptprojekt wurde nicht verändert. Der Vorschlag aus Abschnitt 3 wurde als Prototyp in der Arbeitskopie gebaut und geprüft (Ergebnis in 3.5);
der Unterschied zum Hauptprojekt liegt als `R1_werkzeuge/R1_combat_ereignisfelder.diff.txt` bei.

---

## 0. Kurzfassung: die zehn Befunde, auf die eine Regie bauen muss

1. **Die Regeln sind atomar und sofort.** `hero_act()` / `act_foe()` würfeln Treffer, rechnen Schaden, Tod, Stress, Heldenmut und Reihenwechsel
   vollständig in *einem* Aufruf, dann rückt `_next_actor()` schon zum Nächsten vor. Die Anzeige spielt die Ereignisse erst danach mit Verzögerung
   ab (erster Treffer 0,2 s, jeder weitere +0,13 s). Alles, was die Anzeige aus dem Zustand liest (Kraft-Balken, Reihen, Zustandsbuchstaben,
   Zugleiste, `c.actor`), zeigt deshalb immer schon die Welt **nach** der Aktion.
2. **`c.actor` ist nach einer Aktion bereits der nächste Akteur.** Das goldene Rampenlicht (Lichtkegel, Dreieck) und die Fertigkeitskarten springen im
   selben Bild auf den Nächsten, während der Angreifer noch ausholt. Beleg: `img/R1_beleg_marker_springt.png` (Screenshot `--shotfx2` in der Arbeitskopie, Anzeige dort unverändert; Olaf schlägt gerade, Banner
   "Olaf: Hieb", Zahl "−14" schwebt, aber Marker und Karten gehören schon Vidar). Eine Fokuskamera darf sich nicht an `c.actor` orientieren, sondern
   an einem eigenen "Fokus-Akteur" aus den Ereignissen.
3. **Drei Uhren laufen nebeneinander und passen nicht zusammen:** (a) echte Zeit für den Takt der Regeln (`voy._combat_t`, `_outro_t`) und für
   Klänge (`Sfx.play(..., delay)` über `create_timer`), (b) Anzeigezeit mit Einfrieren und Zeitlupe (`FightFx.tick`, `_tick_fight`), (c) Wanduhr
   (`Time.get_ticks_msec()` für das Atmen der Ruhepose). Folgen: Klänge eilen der Zeitlupe voraus; die Schlussansage "SIEG" wird nach einem
   Zeitlupen-Tod nur zu 59 % gezeigt (gemessen, 4.3).
4. **Takt der Züge:** Mann auf Mann und Gegner auf Mann: *kein* Warten (die Karten des Nächsten sind sofort klickbar, auch mitten im Hieb des
   Vorgängers). Mann oder Gegner auf Gegner: mindestens `COMBAT_PACE` = 0,9 s. Die Zeitlupen-Zuschläge (`_slow`) gehen verloren, wenn gleich danach ein
   Mann handelt, weil `combat_act()` den Takt hart auf 0,9 zurücksetzt (4.3).
5. **Das Ereignismodell hat 10 Typen** (`attack, hit, miss, heal, die, overboard, spawn, text, heroic, snap`; Blutung läuft als `hit` ohne
   Fertigkeit). **Kein Ereignis** gibt es für: Reihentausch (Platztausch, Ansturm, Rückzugsschuss, Haken, Rammstoß, Vorrücken, Nachrücken nach Tod),
   Warten, Überspringen (betäubt, Schreck, verzagt, im Griff), Flucht eines Gegners, Rundenwechsel, Zustände (Schutz, Stärkung, Markierung, Betäubung,
   Blutung), und für **die Ziele** aller Fertigkeiten ohne Schaden und ohne Heilung (Lieder, Schildwall, Deckung, Hohnlied, Totenklage, Wut, Nachladen).
6. **Der Ausgang einer Aktion ist der Anzeige im Voraus bekannt**, weil alle Ereignisse einer Aktion schon in `events` stehen, wenn das erste gezeichnet wird.
   Es fehlt nur die Gliederung: Ereignisse tragen keine Nummer der Handlung und keinen Verursacher, die Grenze zwischen zwei Aktionen ist nur an einem
   neuen `attack` erkennbar (und gar nicht, wenn eine Aktion ohne `attack` oder mit angehängten Blutungstreffern des Nächsten kommt).
7. **Reihen sind im Ereignis nicht festgehalten.** `who` ist ein lebendes `Fighter`-Objekt; `who.rank` ist beim Lesen schon der Wert *nach* der Aktion
   (gemessen bei `a_ansturm`: Reihe vorher 2, im Ereignis gelesen 1). Alle Figuren springen deshalb zum Zeitpunkt der Regelrechnung auf ihren neuen
   Platz; gleitende Bewegung ist heute nicht möglich.
8. **Der Schnellmodus läuft komplett an der Anzeige vorbei** (`Voyage.start_fight` löst synchron auf, 3 bis 4 ms je Kampf, gemessen). Alles in `hud.gd`
   und in neuen Anzeige-Modulen kostet Bots und Schnellmodus nichts. Gefährlich ist nur, was in `Combat` oder `Voyage` hinzukommt.
9. **Klickflächen und Tooltips der Figuren werden in Bühnenkoordinaten eingetragen**, aber unter `draw_set_transform` (Wackeln, Zoom) gezeichnet.
   Heute fällt das nicht auf (Zoom höchstens +11 %, kurz). Mit einer gehaltenen Fokuskamera stimmt die Klickkarte nicht mehr (Risiko R4 in Abschnitt 6).
10. **Der vorgeschlagene minimale Erweiterungssatz (Abschnitt 3.4) ist erprobt:** Logik-Prüfsumme über 200 Kämpfe unverändert, `selftest.gd` meldet
    `FEHLER: 0`, die Anzeige läuft unverändert weiter (Screenshot), Rechenzeit +13 %, Ereignisse je Kampf +64 %.

---

## 1. Zeitachse einer Heldenaktion und einer Gegneraktion

### 1.1 Wer treibt was an

| Ebene | Wo | Takt |
|---|---|---|
| Regeln | `Combat` (`combat.gd`): `begin()`, `hero_act/move/pass/flee`, `act_foe`, `_execute`, `_strike`, `_next_actor`, `finish()` | keine Zeit, jede Handlung ist ein Funktionsaufruf |
| Takt und Übergänge | `Voyage` (`voyage.gd`): `start_fight`, `fight_begin`, `combat_act/move/pass/flee`, `_tick_combat`, `_end_fight`; `Voyage._process` ruft `_tick_combat` nur bei `phase == COMBAT` | echte Zeit (`delta`), Takt `_combat_t` und `_outro_t` |
| Eingabe | `Main._unhandled_input` (Zeile 577) und `Main._click` (743) leiten in der Phase `COMBAT` an `Hud.fight_key` / `Hud.fight_click` weiter | Ereignisse der Maus und Tasten |
| Anzeige | `Hud._draw` -> `_draw_combat_view` (hud.gd 215/2340) -> `_fight_events` (verarbeitet **in `_draw`**, einmal je Bild) | Anzeigezeit: `Hud._process` -> `_tick_fight` (162) -> `FightFx.tick` |

Zustandsmaschine in `Combat.state`: `idle` -> `hero` (ein Mann entscheidet) | `foe` (ein Gegner ist dran) -> `done` (`result` = win, lose, flee). Eine Runde
besteht aus `order` (alle Lebenden nach `speed + randf()*4`, absteigend, am Rundenbeginn gebaut). Neu Beschworene stehen in `foes`, aber erst ab der
nächsten Runde in `order`; Nachwachsende Fangarme (`_regrow_tentacles`, im `_new_round` vor dem Bau von `order`) handeln dagegen sofort in der neuen Runde.
Heldenmut "Kampfrausch" setzt den Mann ein zweites Mal direkt hinter den aktuellen Akteur (`order.insert(cursor+1, f)`).

### 1.2 Alle Zeitkonstanten

**Takt (voyage.gd, echte Zeit):**

| Konstante | Wert | Stelle | Bedeutung |
|---|---|---|---|
| `COMBAT_PACE` | 0,9 s | voyage.gd 104 | Mindestabstand bis zum nächsten Gegnerzug; `selftest` verlangt `>= 0.8` |
| `_combat_t` nach `fight_begin` | `COMBAT_PACE + 0.2` = 1,1 s | 2846 | erste Wartezeit, falls ein Gegner anfängt |
| `_combat_t` nach `combat_act/move/pass` | 0,9 s (hart gesetzt, `=`, nicht `max`) | 2884/2891/2898 | |
| `_combat_t` nach `act_foe` im Takt | 0,9 s | 2923 | |
| `combat_flee()` | setzt `_combat_t` nicht | 2902 | Kampf ist sofort `done` |
| `combat_outro` | 1,9 s, nur wenn `_bot == "" und nicht headless` (main.gd 196/197; gilt auch für `--shot`, weil dort kein Bot läuft); sonst 0 | | Wartezeit nach `done`, bevor `_end_fight` aufräumt |
| Nach `_end_fight` (Begegnung) | 0,8 s bis `_apply_outcome`, weitere 1,2 s bis `_after_encounter` | 2986 | Phase `RESOLVE`, Weltansicht |
| Nach `_end_fight` (Seeschlacht, `source == "board"`) | 0,8 s bis `Battle.enemy`, 1,0 s bis `Battle.after` | 2977 | |

`_combat_t` zählt **nur** herunter, solange `combat.state == "foe"` (`_tick_combat`, 2919 bis 2923). Solange ein Mann dran ist, steht es still.

**Anzeige (hud.gd, Anzeigezeit außer wo vermerkt):**

| Ding | Dauer | Beginn (ab Eintreffen der Ereignisse) | Stelle |
|---|---|---|---|
| Angriffsanimation (Pose 2, Ausfall) | 0,42 s | sofort; Ausfall `9 px * mv * sin(pi*p)`, `mv` = 1 (Nahkampf), −0,3 (Pfeil, Kugel, Fangarm: kleiner Rückstoß), 0 sonst | 1930/1931, 2226 |
| Treffer-Wartezeit `hw` | `0,2 + 0,13 * k` s, k = laufende Nummer des Treffers oder Fehlschlags dieser Handlung | | 1924 |
| Trefferpose (Pose 3, rot getönt, Zittern ±1 px) | 0,42 s | ab `hw` | 1941 |
| Ausweichen | 0,3 s, 5 px zurück | ab `hw` | 1950 |
| Schadenszahl | 1,0 s, steigt 16 px/s, blendet in den letzten 0,5 s aus; "verfehlt" 0,9 s; Heilung 1,0 s ab 0,25 s | ab `hw` | 1942, 1951, 1957, 2295 |
| Banner (Symbol, "Name: Fertigkeit") | 1,25 s, blendet in den letzten 0,3 s aus; fest bei Rect2(236, 4, 172, 18) | sofort mit `attack` | `FightFx.show_banner`, hud 2319 |
| Gefallener (Geist) | `hold + 0,7` s (Kraken `hold + 1,2`), `hold` = `hw` des tödlichen Treffers | | 1964 |
| Einleitung "KAMPF" / "DER KRAKEN" | 1,5 s / 1,9 s, Schwarzblende 0,5 über 0,7 s, `_slow(1.8)` | erstes Bild des Kampfes, nur Runde 1 | 1909 bis 1915 |
| "GEFALLEN" (Mann stirbt) | 1,7 s, `_slow(1.9)` | bei `die` eines Mannes | 1976 bis 1978 |
| "HELDENMUT" / "ZUSAMMENBRUCH" | je 2,3 s, `_slow(2.4)`; Heldenmut: Blitz 0,55, zwei Ringe; Bruch: Blitz 0,6, Wackeln 4/0,5 | sofort | 2005 bis 2019 |
| Schlussansage "SIEG" / "NIEDERLAGE" / "RÜCKZUG" | `voy.combat_outro` = 1,9 s | im selben Bild, in dem `state == "done"` erkannt wird | 2023 bis 2036 |

**Wirkungen (`FightFx`, Dauer in Anzeigezeit, "bei" = Verzögerung):**

| Wirkung | Dauer / Einsatz | Stelle |
|---|---|---|
| Hiebbogen `slash` 0,28 s (`chop` 0,34 s), `bash` 0,3 s, `bite` 0,4 s, Funken 0,5 s (4, 6 oder 9 Splitter), Ring 0,2 s | bei `hw` | `_fx_hit` |
| Pfeil 0,2 s (Start bei `hw − 0,2`), Kugel 0,09 s (Start `hw − 0,09`), Fangarmpeitsche 0,45 s (Start `hw − 0,22`), vorbei fliegend 0,3 s / 0,2 s | | `_fx_hit`, `_fx_miss` |
| **Krit:** Blitz 0,2 s (Gold, a=0,3), Wackeln 2,5 px / 0,25 s, **Einfrieren 0,07 s**, Zoom +0,05 über 0,3 s, **Zeitlupe 0,5 über 0,25 s**, `_slow(1.1)` | bei `hw` | 2138 bis 2144 |
| Schaden >= 24: Wackeln 1,5 px / 0,18 s | bei `hw` | 2145 |
| **Tod eines Gegners:** Wackeln 3 px / 0,3 s (Kraken 7 px / 0,7 s), Einfrieren 0,09 s, `_slow(1.2)`; Kraken zusätzlich Blitz 0,6 s | bei `hold` | 1962 bis 1971 |
| **Tod eines Mannes:** zusätzlich Zeitlupe 0,35 über 0,8 s, Zoom +0,08 über 0,8 s | bei `hold` | 1973 bis 1978 |
| **Letzter Gegner fällt:** Zeitlupe 0,3 über 1,0 s, Zoom +0,11 über 1,0 s | bei `hold` | 1979 bis 1981 |
| Zerquetschen (`crush`): Blitz 0,6 s (dunkelrot), Wackeln 6 px / 0,7 s bei 0,3 s, `_slow(1.5)` | | 2073 bis 2076 |
| Tinte 1,3 s, Schild 0,7 s, Lied 1,1 s, Kriegslied: Lied + vier Ringe, Totenklage: drei Ringe r=90, Horn: drei Ringe r=70, Beschwörung: zwei Ringe + Wackeln 2/0,3 | beim Ausholen | `_fx_go` |
| Mündungsfeuer 0,9 s, Blitz 0,12 s, Wackeln 2 px / 0,18 s | beim Ausholen (`bullet`) | 2095 bis 2099 |

Einfrieren: `FightFx.freeze` stoppt `_tick_fight` ganz (auch `_anim`, `_floats`, `_ghosts`), nicht aber den Takt der Regeln (`_combat_t`) und die Klänge. Zeitlupe:
`time_scale()` skaliert nur die Anzeigezeit; `_slow_t` selbst läuft in echter Zeit ab.

**Klänge:** `Sfx.play(name, db, delay, pitch)`; `delay` > 0 läuft über `get_tree().create_timer` in echter Zeit. Treffer: `Sfx.skill_sound(sk, "hit")` bei `hw` (Krit +2 dB und
zusätzlich "clash" −6 dB), Fehlschlag "whiff" bei `hw`, Ausholen sofort, Heilung bei 0,25 s, Tod bei `hold + 0,1`. Gleicher Klang frühestens nach 0,12 s wieder (`MIN_GAP`):
die 0,13 s Treffer-Staffelung liegt knapp darüber.

### 1.3 Heldenaktion: Einzelziel, Nahkampf, kein Krit, nächster Akteur ist ein Gegner

| t (s) | Ebene | Ereignis |
|---|---|---|
| unbegrenzt | Eingabe | `state == "hero"`: Karten 1 bis 6 (`fs0` bis `fs5`), "Abwarten" (`fwait`). Zielwahl (`ft<Seite>_<Reihe>` oder Q W E R): gültige Ziele pulsieren; Tooltip des Ziels zeigt Trefferchance und Schaden (`Tips.fighter` mit `_fight_skill`). Hat die Fertigkeit nur ein mögliches Ziel, geht sie sofort los. |
| 0,000 | Regeln (`hero_act` -> `_execute`) | alles gewürfelt und angewendet; Ereignisse stehen in `events`; `_next_actor()` hat `actor` und `state` schon auf den Nächsten gesetzt (Blutungstreffer, Betäubung, Rundenwechsel dabei abgewickelt); `voy._combat_t = 0.9` |
| 0,000 bis 0,017 | Anzeige | nächstes `_draw`: `_fight_events` erzeugt `_anim`, Klang "swing", `_fx_go`, Banner; Treffer, Zahl, Klang, Hiebbogen mit Wartezeit `hw` |
| 0,00 | | Angriffsanimation beginnt (0,42 s) |
| 0,20 | | **Treffer landet**: Trefferpose, Hiebbogen, Funken, Klang "slash/chop", Zahl beginnt zu schweben |
| 0,42 | | Angriffsanimation endet |
| 0,62 | | Trefferpose endet (bei vier Zielen: 1,01 s) |
| 0,90 | Takt | `_combat_t` abgelaufen: ist ein Gegner dran, ruft `_tick_combat` `act_foe()` auf (Beginn der Gegneraktion, Tabelle 1.4) |
| 1,20 | | Zahl des ersten Ziels ist weg; Banner endet bei 1,25 s |

Freies Zeitfenster innerhalb des Taktes: bei Einzelziel 0,9 − 0,62 = **0,28 s**, bei vier Zielen **0 s**. Jede Regie, die vor dem Treffer etwas voranstellt
(Kamerafahrt, Ankündigung), oder danach etwas hält, muss über dieses Fenster hinaus entweder Zeit zukaufen (4.4) oder mit dem Gegnerzug überlappen.

Abweichungen:

* **Krit:** Wirkungen bei 0,2 s (Einfrieren 0,07, Zeitlupe 0,5 für 0,25 s), `_slow(1.1)` hebt den Takt auf mindestens 1,1 s.
* **Gegner fällt:** `_slow(1.2)`; **Mann fällt** (nur bei Treffern der Gegner): `_slow(1.9)`, "GEFALLEN" 1,7 s, Zeitlupe 0,35 für 0,8 s.
* **Flächenfertigkeit** (z. B. Wirbelhieb auf zwei, Pfeilregen auf vier Ziele): Treffer bei 0,20 / 0,33 / 0,46 / 0,59 s, ein `attack`.
* **Pfeil, Kugel, Fangarm:** der Angreifer bleibt stehen (Rückstoß −0,3·9 px), das Geschoss fliegt ab 0,0 s (Pfeil) bzw. 0,11 s (Kugel) zum Ziel und landet bei 0,2 s.
* **Nächster Akteur ist ein Mann:** Takt hat keine Wirkung. Die Karten des Nächsten erscheinen im selben Bild, der Spieler kann sofort handeln; seine Aktion setzt `_combat_t` wieder auf 0,9
  (und löscht damit einen etwaigen `_slow`-Zuschlag, 4.3).
* **Aktion beendet den Kampf:** `_check_end()` setzt `state = "done"` schon in `_next_actor`; im nächsten `_draw` laufen `_fight_events` (letzte Treffer, `die`)
  und gleich danach `_fight_outro` ("SIEG" 1,9 s) **im selben Bild**, der tödliche Treffer ist dann noch gar nicht gelandet (0,2 s). Nach 1,9 s echter Zeit ruft
  `_tick_combat` `_end_fight()` auf.

### 1.4 Gegneraktion

| t (s, ab Aufruf) | Ereignis |
|---|---|
| vor 0 | `_tick_combat`: `combat.state == "foe"`, `_combat_t -= delta`; bei 0 oder weniger folgt `combat.act_foe()` |
| 0,000 | `act_foe`: Flucht (`_foe_flees`) -> Haltezug des Fangarms (`_hold_turn`) -> Kraken (`_boss_turn`: Ankündigung oder Zerquetschen) -> sonst gewichtete Wahl der Fertigkeit, Ziel (`_pick_hero_target`: Schildwall zählt dreifach, Herausforderung achtfach, Fangarm sucht Freie) -> `_execute` -> `_next_actor`. Danach `_combat_t = 0.9`. |
| 0,00 bis 0,62 | wie 1.3; Banner mit dem **Kurznamen** des Gegners (`Foes.info(kind).short`), roter Rand |
| 0,90 | nächster Gegner (wenn Gegner dran) |

Zwischen zwei Gegnern vergehen also **mindestens 0,9 s**, auch bei völlig stillen Zügen: ein Gegner, der nichts tun kann, rückt vor oder wartet (ohne Ereignis, 4.1), kostet trotzdem 0,9 s
Takt. Dasselbe gilt für Gegnerzüge, die der Anzeige als "nichts" erscheinen (Flucht).

Der Gegner **kündigt nichts an**: Wahl und Ausführung geschehen in einem Aufruf. Eine Ankündigung ist nur als Anzeige möglich (die Ereignisse sind beim Zeichnen schon bekannt, 3.2).

Besonderheit Kraken: erst `text "spannt sich!"` (kein `attack`), im nächsten Zug des Körpers `f_kr_quetsch` auf alle Männer (`acc 100`, also nur `hit`, nie `miss`); ein betäubter
Kraken verliert die Spannung (`text "unterbrochen!"` in `_next_actor`).

### 1.5 Kampfbeginn und Kampfende

```
Voyage.start_fight(formation, ctx, count, hp_scale)      voyage.gd 2811
  phase = COMBAT, fight_prep = {formation, units, party (auto_party), pool, ctx, hp_scale}, Sfx "kraken_roar"/"sting"
  auto_combat?  ja -> fight_begin(); combat.auto_play(); _end_fight()          (synchron, keine Anzeige)
                nein -> Aufstellung (hud: _draw_fight_prep, Loadout) bis "Kampf!" (fgo / Enter) -> fight_begin()
fight_begin(): Combat.create, combat.begin() (-> _new_round, _next_actor), _combat_t = 1.1
  Hud, erstes Bild: _fight_events erkennt neuen Combat (_ev_combat), leert alles, _intro_pending
    -> "KAMPF"/"DER KRAKEN" 1,5/1,9 s, Schwarzblende, _slow(1.8)   (nur wenn c.round_no <= 1 und nicht zu viele Ereignisse)
    Ist ein Mann der Erste: Einleitung läuft, blockiert ihn aber nicht. Ist ein Gegner der Erste: er wartet ~1,8 s.
... Runden ...
Combat._check_end() -> state "done", result win|lose (hero_flee -> "flee")
Voyage._tick_combat: state "done" -> (combat_outro > 0: _outro_t = combat_outro, herunterzählen) -> _end_fight()
_end_fight(): combat.finish() (Kraft zurück, Schwelle = 10 Kraft), Gefallene -> _combat_casualty, Über-Bord -> _throw_overboard,
  phase = RESOLVE, Beute/Fund, _steps = [{0.8: _apply_outcome|Battle.enemy}, {1.2|1.0: _after_encounter|Battle.after}]
```

Mit dem Wechsel `phase = RESOLVE` zeichnet `Hud._draw` die Kampfansicht nicht mehr: laufende Wirkungen sind sofort weg. Einzige Gnadenfrist ist die Schlussansage.

### 1.6 Wie lange dauert ein ganzer Kampf, und was kommt je Kampf vor (gemessen)

80 Kämpfe je Zeile mit `auto_play` (`R1_evdump5.gd.txt`), vier Männer (Schild, Axt, Bogen, Skalde), Etappe 3, nur die letzte Zeile Etappe 5. Männer- und Gegnerzüge = Aufrufe von `auto_hero` bzw. `act_foe`; Tode und Treffer sind Mittelwerte je Kampf.

| Aufstellung | Kraft | Runden | Männerzüge | Gegnerzüge | Treffer M->G (Krit) | Treffer G->M (Krit) | verfehlt | Tode Gegner / Männer | Heldenmut / Bruch | Ereignisse (Alt) |
|---|---|---|---|---|---|---|---|---|---|---|
| Draugr | 100 | 9,8 | 36,1 | 26,6 | 28,3 (0,8) | 12,2 (0,7) | 10,8 | 3,1 / 0,36 | 0,13 / 0,25 | 126 |
| Räuber | 100 | 7,7 | 27,6 | 20,0 | 19,7 (0,5) | 13,1 (0,5) | 10,8 | 3,1 / 0,16 | 0 / 0 | 107 |
| Handelswachen | 100 | 7,0 | 26,6 | 16,8 | 19,7 (0,4) | 11,3 (0,6) | 9,1 | 3,3 / 0,07 | 0 / 0,04 | 96 |
| Dorf | 100 | 6,1 | 23,2 | 13,4 | 18,3 (0,5) | 6,1 (0,2) | 7,1 | 3,1 / 0,01 | 0 / 0 | 76 |
| Kraken | 100 | 14,4 | 51,4 | 20,7 | 32,1 (1,3) | 17,0 (0,3) | 13,7 | 6,7 / 0,20 | 0,06 / 0,09 | 174 |
| Draugr | 60 | 12,2 | 42,6 | 34,7 | 31,8 (0,9) | 16,0 (1,3) | 14,5 | 2,5 / 1,09 | 0,47 / 0,80 | 162 |
| Kraken (Etappe 5) | 60 | 27,6 | 89,9 | 46,4 | 48,0 (1,7) | 38,7 (1,0) | 26,4 | 8,2 / 2,01 | 0,78 / 1,51 | 340 |

Folgerungen:

* **Pflichtwartezeit** (nur Gegnerzüge mal 0,9 s): Draugr 24 s, Räuber 18 s, Handelswachen 15 s, Dorf 12 s, Kraken 19 s, Kraken Etappe 5 und Kraft 60 bis zu 42 s. Dazu die Bedenkzeit der Männer
  (23 bis 90 Entscheidungen je Kampf) und die Zuschläge.
* **Große Ereignisse sind selten:** je Kampf rund 1 bis 2 Krits, 3 Gegnertode, selten 0,1 bis 1 Männertod, Heldenmut oder Zusammenbruch meist unter 0,5. Der Normalfall ist ein gewöhnlicher Treffer
  (20 bis 30 je Kampf). Eine Stufenleiter, die erst bei Krit und Tod laut wird, kann großzügig sein; der gewöhnliche Treffer entscheidet über das Tempo.
* Ein Zuschlag von 0,5 s je Männerzug und 0,3 s je Gegnerzug kostet im Draugr-Kampf 26 s, im Kraken-Kampf 32 s; bei +1 s je Aktion sind es 63 s bzw. 72 s. Zum Vergleich: der Takt allein fordert heute 24 s bzw. 19 s.
* Stille Züge (kein Ereignis): Männer 0,2 bis 1,9 je Kampf (Warten, Platztausch), Gegner 0 bis 2,6 (Dorf: Vorrücken).
* Aktionen **ohne Zielereignis** (Lieder, Schutz, Wut, Klage, Hohn, Nachladen): 2,4 bis 9,6 je Kampf; Flächenfertigkeiten 1,8 bis 4,6 mit im Mittel 2,9 bis 3,9 Zielen.

---

## 2. Katalog der Ereignisse

### 2.1 Form und Ablage

`Combat.events: Array[Dictionary]`, höchstens 150 Einträge (`pop_front`, combat.gd 179 bis 183). Erzeugt nur von `Combat._event(type, who, n, crit, text)`. Felder:

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | int | fortlaufend (`_ev_id`), die Anzeige merkt sich den letzten gesehenen (`_ev_seen`) |
| `type` | String | siehe 2.2 |
| `who` | `Fighter` (lebendes Objekt!) | siehe 2.2: je nach Typ der Angreifer, das Ziel oder der Betroffene |
| `n` | int | Schaden (`hit`), Heilmenge (`heal`), sonst 0 |
| `crit` | bool | nur bei `hit` möglich |
| `sk` | String | `_cur_sid`: Id der Fertigkeit, solange `_execute`, `_hold_turn` oder `_rage` laufen; sonst "" |
| `text` | String | nur `text`, `spawn`, `heroic`, `snap` |

Die Ereignisse einer Aktion stehen alle schon in der Liste, wenn die Anzeige das erste zeichnet. `Combat` kennt die Anzeige nicht (`voy` kann null sein, Tests rufen `_execute` direkt).

### 2.2 Typen

| Typ | Wann | `who` | `n` / `crit` / `sk` / `text` | Anmerkung |
|---|---|---|---|---|
| `attack` | Beginn von `_execute`, `_hold_turn`, `_rage` | Angreifer | `sk` = Fertigkeit; sonst leer | **Nicht** bei: Kraken-Ankündigung, Platztausch, Warten, Überspringen, Flucht. Vor dem ersten `hit`/`miss`. |
| `hit` | `_strike`: Treffer mit Schaden > 0; `_hold_turn`: Pressen; `_next_actor`: Blutung | Ziel | `n` Schaden (>= 1), `crit`; `sk` Fertigkeit, bei Blutung "" | kommt **vor** `_hurt`; bei einem Mann an der Schwelle steht `n` trotzdem da, auch wenn er standhält (kein Ereignis dafür) |
| `miss` | `_strike`: Trefferwurf misslungen | Ziel | `sk` | nie bei `acc 100` (Zerquetschen, Klage, Tinte) |
| `heal` | `_support` mit `fx.heal` (Heilsegen, Gegner-Heilen) | Empfänger | `n` = **nominal** (nicht auf Maximalkraft gekappt) | bei Gegnern `heal * _hp_scale` (22 statt 16 in Etappe 1) |
| `die` | `_kill_foe`, `_kill_hero`; beim Tod des Kraken zusätzlich für jeden anderen Gegner | Gefallener | `sk` der tötenden Fertigkeit, bei Blutung "" | folgt **unmittelbar** auf das `hit`; `who.gone` ist schon wahr, `who.rank` noch die alte Reihe |
| `overboard` | `_drag_overboard` (Haltezug, dritte Runde) | Mann | `sk` "" | folgt auf das `attack` (`f_kr_wuerg`) des Fangarms |
| `spawn` | `_summon` (`text` "beschworen") und `_regrow_tentacles` (`text` ""; am Rundenbeginn) | neuer Gegner | | steht schon auf Reihe 0, alle anderen Gegner sind dadurch eine Reihe nach hinten gerückt (ohne Ereignis) |
| `text` | siehe unten | Betroffener | `text` | |
| `heroic` | `_heroic` (Heldenmut bei 100 Verzweiflung) | der Mann | `text` = "Kampfrausch", "Eiserner Wille", "Mitreißend" | kann mitten in einer Fremdhandlung entstehen (Stress durch Treffer, Rundenende); `sk` dann die der laufenden Aktion oder "" |
| `snap` | `_break`, `_panic` | der Mann | `text` = "Berserker", "verzagt", "Panik" | wie `heroic` |

`text`-Ereignisse: "spannt sich!" (Kraken kündigt an, **kein** `attack`), "unterbrochen!" (betäubter Kraken im `_next_actor`), "gepackt!" (nach dem `hit` von `f_kr_griff`),
"geblendet" (Tinte, einmal je Mann), "frei!" (Griff gelöst: Fangarm gefällt oder lässt los), "rastet aus!" (Berserker, vor seinem `attack`), "Rache!" (Bruder fällt).

### 2.3 Reihenfolge, Mehrfachtreffer, Fläche

* Innerhalb einer Aktion: `attack`, dann je Ziel `hit` oder `miss` in **Reihenfolge der Ziele** (aufsteigende Reihe; `targets()`/`heroes.duplicate()`), nach jedem `hit` sofort seine Folgen:
  `die` (bei Tod), `text "frei!"` (hielt der Gefallene einen Mann), `snap`/`heroic` (Stress durch Krit, Schwelle, Tod), `text "Rache!"`.
* **Flächenfertigkeiten** (`foes`, `heroes`): ein `attack`, dann n x (`hit`|`miss`). Wirbelhieb, Rundumschlag, Pfeilregen, Streuschuss: Reihen nach `to`, nur erreichbare.
  Kraken: `f_kr_quetsch` trifft alle Männer (nur `hit`). **Ohne Schaden** (Totenklage, Tintenwolke, Hohnlied) gibt es für die Ziele **kein** Ereignis (Tinte: je Mann `text "geblendet"`).
* **Bewegung während der Aktion** (Ansturm, Rückzugsschuss, Enterhaken-Zerren, Rammstoß): nach der Wirkung, ohne Ereignis; beim Lesen stehen alle `rank`-Werte schon auf dem Endstand.
* **Blutung des Nächsten:** `_next_actor` läuft **am Ende** der Handlung des Vorgängers. Der Blutungstreffer (`hit`, `sk == ""`) des nächsten Akteurs steht darum **hinter** den Ereignissen
  des Vorgängers im selben Paket, obwohl er fachlich zum Zug des Nächsten gehört; ein Tod durch Blutung folgt als `die`. Mehrere Blutungen und Betäubungen hintereinander ergeben mehrere solche Anhängsel.
* **Rundenwechsel:** `_end_round` (Heilung durch Ausrüstung, Stress `+2` für Schwerverwundete -> `snap`/`heroic` möglich) und `_new_round` (nachwachsende Fangarme -> `spawn`) hängen sich ebenfalls
  an das Paket der letzten Handlung der alten Runde.
* **Größe eines Pakets** (gemessen): meist 2 bis 4, größter beobachteter Zug 6 bis 8 (Kraken 10, Etappe 5). Die Anzeige schaltet bei mehr als 24 frischen Ereignissen die Klänge ab (`loud`).

### 2.4 Folgen je Handlungsart (gemessen mit `R1_evdump.gd.txt`)

| Handlung | Ereignisfolge |
|---|---|
| Einzelschlag, Treffer | `attack(Axt, a_hieb)`, `hit(Gegner, 9)` |
| Einzelschlag, tödlich | `attack`, `hit(n=11)`, `die(Gegner)`; Nachrücken ohne Ereignis |
| Fläche, vier Ziele | `attack(b_regen)`, `hit`, `hit`, `miss`, `hit` |
| Heilen | `attack(k_heil)`, `heal(Mann, 18)` |
| Kriegslied, Hohnlied, Schildwall, Deckung, Wut, Nachladen | **nur** `attack` (Ziele und Wirkung nur im Journal-Text) |
| Gegner heilt | `attack(f_heilen)`, `heal(Verbündeter, 22)` |
| Gegner beschwört | `attack(f_beschwoeren)`, `spawn(Skelett, "beschworen")` |
| Fangarm greift, gelingt | `attack(f_kr_griff)`, `hit(Mann, 5)`, `text(Mann, "gepackt!")` |
| Fangarm greift, misslingt | `attack(f_kr_griff)`, `miss(Mann)` |
| Haltezug (erste/zweite Runde) | `attack(Fangarm, f_kr_wuerg)`, `hit(Mann, 6, sk f_kr_wuerg)` |
| Haltezug (dritte Runde) | `attack(Fangarm, f_kr_wuerg)`, `overboard(Mann)` (oder, wenn schon zwei über Bord: nur `text "frei!"`) |
| Fangarm mit Gefangenem fällt | `die(Fangarm)`, `text(Mann, "frei!")` |
| Kraken stirbt | `die(Kraken)`, `die(Fangarm)`, `die(Fangarm)` (jeder übrige Gegner) |
| Kraken kündigt an | `text(Kraken, "spannt sich!")` (kein `attack`) |
| Kraken zerquetscht | `attack(f_kr_quetsch)`, `hit` x 4 |
| Kraken-Tinte | `attack(f_kr_tinte)`, `text(Mann, "geblendet")` x 4 |
| Berserker rastet aus | `text(Berserker, "rastet aus!")`, `attack(Berserker, Heldenfertigkeit)`, `hit|miss(Kamerad)` (Freundbeschuss: `who.side == 0` auf beiden Seiten) |
| Heldenmut / Zusammenbruch | `heroic(Mann, "Kampfrausch")` bzw. `snap(Mann, "verzagt")`, eingeschoben in die Handlung, die den Stress ausgelöst hat |
| Blutung | `hit(Betroffener, 4, sk "")`, ggf. `die` |

### 2.5 Was KEIN Ereignis bekommt (gemessen: null neue Ereignisse für Platztausch, Warten, Schreck, Vorrücken, Flucht; Betäubung, Verzagen und "im Griff" aus dem Quelltext)

Platztausch der Männer (`hero_move`), Warten (`hero_pass`, "X wartet"), Betäubung überspringen, Schreck überspringen ("vor Schreck gelähmt"), Verzagen überspringen, "im Griff" überspringen,
Vorrücken oder Warten eines Gegners ohne Möglichkeit, **Flucht eines Gegners** (`_foe_flees`; der Gegner ist danach weg, `gone`, ohne Ereignis), Nachrücken nach Tod, Zustandsänderungen
(Betäubung, Blutung, Markierung, Schutz, Stärkung, Herausforderung, Reinigung, Nachladen, Verzweiflungswechsel), Rundenwechsel, die Wahl des Kraken, sich zu spannen oder ein Opfer zu greifen
(nur das Ergebnis), das **Standhalten** eines Mannes an der Schwelle ("hält noch durch", nur Journal), der Beginn eines Zuges.

### 2.6 Eigenheiten, die man kennen muss

* `sk` kann falsch oder zufällig sein: `heroic`/`snap`/`die`/`text` tragen die Fertigkeit der **gerade laufenden** Aktion (nicht ihre eigene), Blutung und `overboard` tragen "". Die Anzeige nutzt `sk` nur bei `attack`, `hit`, `miss`.
* `Combat.events` ist nirgends begrenzt außer durch die 150; der Kommentar an der Deklaration (combat.gd 94) nennt `heroic` und `snap` nicht (nachführen).
* Jede Anzeige-Schleife (`_fight_events`) liest `who` **vor** dem `match` und ruft `_fig_x(who)`: ein Ereignis mit `who == null` stürzt sie ab (Risiko R11).
* `Fighter`-Objekte bleiben in `events` und in `Hud._anim` erreichbar, bis der nächste Kampf beginnt (`Hud._ev_combat` hält den letzten `Combat`).

---

## 3. Was die Fokuskamera im Augenblick eines Angriffs weiß, und was fehlt

### 3.1 Vor der Ausführung (Eingabephase, nur Männer)

Verfügbar ohne neue Felder: `c.actor` (der Mann), gewählte Fertigkeit (`_fight_skill`), gültige Ziele (`c.targets(actor, sid)`), Ziel unter der Maus (`valid` und Maus über `_register`-Fläche
`ft<Seite>_<Reihe>`), Trefferchance und Schadensspanne (`c.hit_chance`, `c.damage_range`, `Tips.fighter` nutzt sie schon), `c.eff_skill`. Damit lässt sich eine **Zielvorschau** (Kamera schwenkt
zum überfahrenen Ziel, Zugleiste hebt es hervor) rein in der Anzeige bauen. Für Gegner gibt es **keine** Vorschau: Wahl und Ausführung geschehen in `act_foe` (siehe 1.4).

### 3.2 Im Augenblick des Angriffs (Ereignisse liegen vor, Anzeige hat noch nichts gezeigt)

Spielt die Anzeige das Paket erst ab, sind Ausgang, Ziele, Krit und Tod **bereits entschieden**. Das ist ein Vorteil: Zeitlupe und Zoom können *vor* dem Kontakt beginnen
("Todesstoß ankündigen"), die Kamera kann schon zum Ziel schwenken.

| Information | Heute | Woher / wie | Zuverlässig? |
|---|---|---|---|
| Angreifer | ja | `attack.who` (`c.actor` ist schon der Nächste!) | ja |
| Fertigkeit, Name, Symbol | ja | `attack.sk` -> `Roles.skill`, `Roles.icon_of`, `FightFx.go_fx/hit_fx` | ja |
| Zielart (Einzel, Fläche, Verbündete) | indirekt | `Roles.skill(sk)["tgt"]` | ja |
| Ziele mit Schaden: Treffer, Fehlschlag, Krit, Schaden | ja | die folgenden `hit`/`miss`; Paketende nur an nächstem `attack`/`text` erkennbar | ja, mit Einschränkung (Blutungsanhängsel des Nächsten) |
| Ziele **ohne** Schaden (Lied, Schild, Klage, Hohn, Tinte außer "geblendet") | **nein** | nur Journaltext | nein |
| Verbündeter als Ziel (Deckung, Heilen) | Heilen ja (`heal.who`), Deckung nein | | nein |
| Tödlich? | ja | folgt `die` auf `hit` | ja, aber erst beim Durchlesen |
| Letzter Gegner? | indirekt | `die` und nach dem Paket `c.foes.is_empty()` bzw. `c.state == "done"` | ja |
| Kraft vor/nach dem Treffer | **nein** | `who.hp` ist schon der Wert danach; vorher = `hp + n` (nur bei `hit` an Gegnern und nicht an der Schwelle) | nein |
| Mann nun an der Schwelle / hat Todesstoß überstanden | **nein** | `door` ist schon gesetzt, Standhalten nur im Journal | nein |
| Reihen von Angreifer und Zielen im Augenblick der Aktion | **nein** | `who.rank` ist der Endstand | nein (bei Bewegungsfertigkeiten falsch) |
| Reihenwechsel, Platztausch, Nachrücken, Flucht, Überspringen, Warten | **nein** | | nein |
| Wer ist nun am Zug | ja | `c.actor`, `c.state` (nach der Aktion) | ja |
| Welche Zustände das Ziel bekam | **nein** | nur Journal; `_status_text` zeigt Buchstaben als Endstand | nein |
| Seite, Rolle, Art | ja | `who.side`, `who.role`, `who.kind`, `_is_big`, `_fig_row` | ja |
| Runde | indirekt | `c.round_no` (Endstand) | nein |

### 3.3 Eine Anzeige-seitige Notlösung ohne Eingriff in `Combat`

Eine Hilfsfunktion `_batch_of(c, index)` kann ab einem `attack` alle folgenden `hit|miss|heal|die|text|spawn|overboard|heroic|snap` einsammeln, bis das nächste `attack` oder ein
`text` ohne vorangegangenes `attack` kommt. Blutungsanhängsel (`hit` mit `sk == ""`) und Rundenwechsel-Ereignisse gehören dem **nächsten** Akteur; sie sind an `sk == ""` zu erkennen. Das trägt
Einzelziel- und Flächenangriffe, aber weder Ziele ohne Schaden noch Reihenwechsel noch Kraft vorher/nachher. Für eine Fokuskamera mit Zielschwenk reicht das nicht ganz.

### 3.4 Vorschlag: neue Ereignisfelder, minimal und rückwärtsverträglich

Alle bestehenden Schlüssel (`id, type, who, n, crit, sk, text`) und ihre Bedeutung bleiben. `Combat._event` bekommt einen optionalen Parameter und gibt das Ereignis zurück; alle bisherigen Aufrufe
bleiben gültig. Es gibt **keinen** neuen Zufallsaufruf und keine Änderung an Regeln, Reihenfolge der Würfe oder Zuständen.

**Priorität 1 (ohne sie lohnt sich keine Regie):**

| Feld / Ereignis | Wo | Inhalt und Zweck |
|---|---|---|
| `act` (int) | alle Ereignisse | Nummer der Handlung, zählt in `_begin_act(by)` hoch (am Anfang von `_execute`, `_hold_turn`, `_rage`, Kraken-Ankündigung, Platztausch, Warten, Flucht, Vorrücken, Blutung, Rundenende, Nachwachsen). Gliedert die Liste in Pakete; Blutung gehört dann zu eigener Nummer. |
| `by` (Fighter oder null) | alle Ereignisse | Verursacher der Handlung (null: Blutung, Rundenwechsel). Ersetzt das Suchen nach dem letzten `attack` (`Hud._ev_actor`). |
| `rank` (int) | alle Ereignisse | Reihe von `who` im Augenblick der Meldung (also **vor** der anschließenden Bewegung). Behebt falsche Ursprungsorte für Pfeile, Hiebe und Fangarme. |
| `round` (int) | alle Ereignisse | `round_no` zum Zeitpunkt |
| `tgts` (Array von Fighter), `tgt` (String) | `attack` | alle anvisierten Ziele in Reihenfolge, auch bei Lied, Schild, Hohn, Klage, Tinte; `tgt` = `Roles.skill(sk)["tgt"]` (`foe`, `foes`, `ally`, `allies`, `self`, ...). Für `_rage`: `friendly = true`. |
| `hp0`, `hp1` (float) | `hit`, `heal` | Kraft des Betroffenen unmittelbar vor und nach der Wirkung. Ermöglicht **gezeigte** Kraft-Balken, die erst beim Treffer fallen. (Für `hit` wird das Ereignis nach `_hurt` ergänzt: `_event` liefert das Wörterbuch zurück.) |
| `lethal` (bool) | `hit` | der Treffer hat getötet (`def.gone`). Erlaubt Zeitlupe/Zoom **vor** dem Kontakt, ohne `die` abzuwarten. |
| `door`, `resist` (bool) | `hit` | Mann steht nun an der Schwelle; Mann an der Schwelle hat den Todesstoß überstanden. |
| `turn` (neuer Typ) | in `_next_actor`, wenn ein Akteur endgültig dran ist | `who` = Akteur, `n` = Runde, `text` = `"hero"`/`"foe"`, `row_h`, `row_f` = Kopien von `heroes` und `foes` (Aufstellung nach Reihe). Markiert das **Paketende** der vorangegangenen Handlung und liefert den **Endstand der Reihen**, aus dem jede Verschiebung abzulesen ist. |
| `move` (neuer Typ) | in `_swap` | je Beteiligtem: `who`, `rank` = alte Reihe, `n` = neue Reihe, `text` = Anlass (`tausch`, `vorrücken`, `vor`, `zurück`, `pull`, `push`). Zeitpunkt in der Folge stimmt (z. B. nach dem `hit` bei `pull`). |

**Priorität 2:**

| Feld / Ereignis | Wo | Inhalt |
|---|---|---|
| `skip` (neuer Typ) | `_next_actor` | `who` überspringt: `text` = `betäubt`, `Schreck`, `verzagt`, `Griff` |
| `wait` (neuer Typ) | `hero_pass`, `act_foe` (nichts zu tun) | `who` wartet |
| `flee` (neuer Typ) | `act_foe` | `who` flieht (vor `erase`, damit `rank` stimmt) |
| `dot` (bool) | Blutungs-`hit` | der Treffer ist Blutung, nicht Angriff (statt `sk == ""` zu raten) |

**Priorität 3 (nicht erprobt, nur vorgeschlagen):** `status`-Ereignisse (`who`, `text` = `guard|buff|taunt|cleanse|mark|stun|bleed|reload`, `n` = Runden) aus `_support`
und `_strike`, damit Zustandssymbole genau beim Treffer aufpoppen; Feld `st` (Array von Strings) auf `hit` für Zustände, die der Treffer anrichtet; Ereignis `round`.

**Regeln, damit der Anzeigecode heil bleibt:**

* Jedes neue Ereignis hat ein `who` ungleich null (der Anzeige-Schleife `_fight_events` fehlt ein Standardzweig; unbekannte Typen werden heute **still ignoriert**, was gewollt ist).
* Neue Ereignisse dürfen die Reihenfolge der bestehenden nicht verändern (nur dazwischen oder dahinter treten).
* `n`, `crit`, `sk`, `text` behalten ihre Bedeutung.

### 3.5 Erprobung des Vorschlags (Arbeitskopie `ablauf`, Prioritäten 1 und 2 außer `status`)

Umfang: rund 70 geänderte Zeilen in `combat.gd` (`R1_werkzeuge/R1_combat_ereignisfelder.diff.txt`). Ergebnisse:

| Prüfung | Ergebnis |
|---|---|
| Parse, Import | fehlerfrei |
| **Logik-Prüfsumme** über 200 Kämpfe mit festen Seeds (5 Aufstellungen x 40; Ergebnis, Runden, Tote, Geflohene, Über-Bord, Brüche, Kraft aller Männer) | **vorher 3356533480, nachher 3356533480 (unverändert)** |
| Ereignis-Prüfsumme (Typen und Reihenfolge) | 1343226653 -> 309458424 (ändert sich erwartungsgemäß: neue Typen) |
| `tools/selftest.gd` | `FEHLER: 0` |
| Anzeige (`shot.ps1 --shotfx2`, Sandbox, Bild gelesen) | zeigt wie zuvor, keine Fehlerzeilen; neue Typen werden ignoriert |
| Rechenzeit Schnellmodus | Draugr 3,26 -> 3,68 ms je Kampf (+13 %), Kraken 3,85 -> 4,44 ms (+15 %) |
| Ereignisse je Kampf | Draugr 122 -> 200, Kraken 172 -> 264 (+64 % bzw. +54 %); die Obergrenze 150 des Puffers bleibt unkritisch, weil die Anzeige jedes Bild abholt |

Beispielausgabe (Axt, Ansturm von Reihe 2; die Reihe in `rank` ist die im Augenblick der Meldung):

```
#16 attack who=HH2 rank=2 act=7 by=HH2 tgts=[Frost] tgt=foe
#17 hit    who=Frost rank=0 act=7 hp0=36 hp1=21 lethal=false door=false resist=false
#18 move   who=HH2  rank=2 n=1 text='vor'  act=7        (HH2 rückt von Reihe 2 auf 1)
#19 move   who=HH1  rank=1 n=2 text='vor'  act=7        (der Verdrängte geht von 1 auf 2)
#20 turn   who=Frost n=1 text='foe' row_h=[HH0,HH2,HH1,HH3] row_f=[Frost,Frost,Fbogner,Ftotenwart]
```

Offen bleibt: ob die Anzeige mit `row_h/row_f` allein auskommt oder zusätzlich `move` braucht (gleitende Bewegung zum Zeitpunkt des Anlasses braucht `move`).

---

## 4. `_combat_t`, `Settings.auto_combat`, `voy.auto_combat`: wie sie zusammenspielen

### 4.1 Die Variablen

| Variable | Art | Gesetzt von | Gelesen von | Wirkung |
|---|---|---|---|---|
| `Settings.auto_combat` | statisch, gespeichert (`user://settings.cfg`, `play/auto_combat`) | `Settings.load_all`; Umschalten in den Einstellungen (`Main._setting_click("tfight")`) | `Main._ready` (156), `Hud` Einstellungszeile "Kämpfe: schnell / von Hand" (1186) | Wunsch des Spielers. Wirkt nur über `voy.auto_combat`. |
| `voy.auto_combat` | bool in `Voyage` | `Main._ready`: `_bot != "" or (_persist and Settings.auto_combat)`; `_setting_click`; Tests und `--shot*`-Abläufe setzen es von Hand auf `false` | **nur `start_fight`** (voyage.gd 2828) | `true`: `fight_begin(); combat.auto_play(); _end_fight()` hintereinander, ohne Anzeige, ohne Takt |
| `voy._combat_t` | float, "privat" | `fight_begin` (1,1), `combat_act/move/pass` (0,9), `_tick_combat` (0,9 nach Gegnerzug), **`Hud._slow()` (`max`)**, `main.gd` setzt für Screenshots 9999 | `_tick_combat` (zählt nur bei `state == "foe"` herunter) | Mindestabstand bis zum nächsten Gegnerzug |
| `voy.combat_outro` | float | `Main._ready` (1,9, nur `_bot == "" und nicht headless`); `selftest` 0,5 | `_tick_combat`, `Hud._fight_outro` (Dauer des Banners), `Hud._draw_combat_view` (2367) | Wartezeit nach `done` und Dauer der Schlussansage |
| `voy._outro_t` | float, -1 = nicht gestartet | `_tick_combat`, `_end_fight` | `_tick_combat` | |

`Settings.auto_combat` wird **nach** dem Start nirgends mehr gelesen; die Einstellung lässt sich nur aus dem Hauptmenü ändern (Esc im Kampf bricht nur eine Zielwahl ab, `Main` öffnet das Menü nur in `PLAN` und `ENCOUNTER`). `auto_combat`
kann also nicht mitten in einem Kampf kippen.

### 4.2 Die Wege je Betriebsart

| Betrieb | `voy.auto_combat` | `combat_outro` | `Hud._draw` läuft | Weg |
|---|---|---|---|---|
| Bot (`--autoplay`, `--random`, headless oder mit Fenster) | `true` (immer) | 0 | headless: nein | `start_fight` löst synchron, `phase` bleibt nicht auf `COMBAT` stehen |
| `selftest.gd`, `combatsim.gd` | `new_voyage` setzt `true`; einzelne Tests `false` und rufen `fight_begin`, `_tick_combat(delta)`, `_process` von Hand; `combatsim` benutzt nur `Combat` | 0 (Test mit 0,5) | nein | |
| Spiel, Einstellung "schnell" | `true` | 1,9 (wirkt nicht: `_end_fight` wird direkt gerufen) | nie in der Kampfansicht | Kein Aufstellungsbild, kein Banner; der Spieler sieht nur das Ergebnis im Journal (`_fact`) |
| Spiel, Einstellung "von Hand" | `false` | 1,9 | ja | Aufstellung, Kampfansicht, `_tick_combat` taktet Gegner, Schlussansage |
| Screenshot (`--shot=`, `--shotfx` ...) | `false` (explizit, `_persist` ist aus) | 1,9 (nicht headless, kein Bot) | ja | `main.gd` 242 bis 342 baut den Zustand in `_ready`; `_voy._combat_t = 9999` hält die Gegner an; der Screenshot kommt bei `Waves.time >= Sec` |

Die Zeit im Schnellmodus: gemessen 3,3 ms (Draugr) bis 3,9 ms (Kraken) je Kampf (`Combat.create` bis `finish`, 400 Kämpfe).

### 4.3 Stolperstellen des heutigen Taktes

1. **`combat_act` überschreibt `_slow`.** Beispiel: ein Gegner tötet einen Mann; `_fight_events` ruft `_slow(1.9)` auf, `_combat_t` steht auf 1,9. Ist der nächste Akteur ein Mann und handelt er, setzt
   `combat_act` `_combat_t = 0.9`; der folgende Gegner schlägt nach 0,9 s statt nach dem Rest der Ansage (aus dem Quelltext: `=` statt `max`; der Zusatzwert, im Beispiel 2,4, wird zu 0,9, nachgespielt in `evdump4`). Heldenmut und Zusammenbruch (2,4 s) sind ebenso betroffen.
2. **`_slow` schreibt in eine private Variable von `Voyage`** (`voy._combat_t`), aus `_draw` heraus. Jede Umstrukturierung von `_combat_t` muss `Hud._slow` mitnehmen.
3. **Takt und Anzeige laufen auseinander:** Einfrieren und Zeitlupe verlängern die Anzeigezeit, aber nicht `_combat_t` und nicht `_outro_t`. Gemessen (Nachbau der Uhren mit `R1_evdump3.gd.txt`, Banner 1,9 s):
   ohne Zeitlupe 100 % der Schlussansage sichtbar; nach Tod des letzten Gegners (Zeitlupe 0,3 für 1,0 s, Einfrieren 0,09) nur **59 %** (Anzeigezeit 1,12 s), mit Krit auf den letzten Gegner **90 %**. Der Kampf endet nach 1,9 s echter Zeit,
   gleich ob die Ansage fertig ist.
4. **Klänge sind in echter Zeit:** In der Zeitlupe (Faktor 0,3 bis 0,5) kommt der Trefferklang `hw` echte Sekunden nach dem Beginn, die Anzeige aber erst nach `hw / Faktor`. Heute fällt das wegen der kurzen Dauer kaum auf.
5. **Der Takt wird auch von Stille verbraucht:** Gegner, die nichts tun, kosten 0,9 s (1.4). Der Takt ist ein Mindestabstand, kein Spiegel der Animationslänge.
6. **Die Ansage erscheint im selben Bild wie der tödliche Treffer** (1.3), noch bevor dieser landet.
7. **Mann nach Mann, Mann nach Gegner:** keine Pause, die Karten stehen sofort. Das ist beabsichtigt (schnelles Spiel), macht aber überlappende Pakete möglich: Der Spieler kann mitten in der Animation des Vorgängers wählen.

### 4.4 Wo Inszenierungszeit eingefügt werden kann, ohne Schnellmodus und Bots zu bremsen

**Grundsatz:** Inszenierung ist Anzeige. Sie darf nur in Code stehen, der in `start_fight(auto_combat = true)` nie läuft. Das ist alles, was in `hud.gd` und neuen Anzeigemodulen steht; `Combat` und `Voyage` nur dort, wo es billig ist und an `not auto_combat` hängt.

**Empfohlene Stelle: eine eigene Inszenierungsuhr in `Voyage`**, die nur ein laufender, gezeigter Kampf benutzt:

```gdscript
# voyage.gd (Vorschlag)
var stage_t := 0.0  # Sekunden Inszenierung, die der Kampf noch abwartet; nur in der Anzeige gesetzt, läuft in echter Zeit ab

## Vom Hud: der Kampf soll noch mindestens so lange warten (größter Wert gewinnt). Wirkt nur im gezeigten Kampf.
func combat_stage(seconds: float) -> void:
	if combat != null and not auto_combat:
		stage_t = maxf(stage_t, seconds)

func _tick_combat(delta: float) -> void:
	stage_t = maxf(stage_t - delta, 0.0)
	...
	if combat.state == "foe":
		_combat_t -= delta
		if _combat_t <= 0.0 and stage_t <= 0.0:   # beide Uhren abwarten
			combat.act_foe()
			_combat_t = COMBAT_PACE
	# state == "done": _outro_t erst starten (und _end_fight erst rufen), wenn auch stage_t <= 0 ist, also das Todesbild zu Ende ist
```

Das behebt Stolperstelle 1 (ein `combat_act` löscht `stage_t` nicht), lässt `COMBAT_PACE` (>= 0,8, vom `selftest` verlangt) und die Semantik von `_tick_combat(delta)` für den bestehenden Schlussansage-Test (`t3_o`) unberührt
und ersetzt `Hud._slow()` durch `voy.combat_stage()`. `Hud` darf `combat_stage` auch gestaffelt aufrufen (Beat-Schlange, 4.5).

**Weitere Stellen:**

* **Anzeige-Warteschlange im `Hud`/Director** ("Beats"): jedes Paket (3.4, nach `act`) wird zu einem Beat mit Dauer; die Anzeige spielt Beats nacheinander ab und ruft `voy.combat_stage(Restdauer)`. Der Spieler kann dann schon klicken, die Regeln laufen voraus, die
  Anzeige holt auf. Das ist die robusteste Form, weil Pakete nie überlappen müssen.
* **Eingabesperre für Männer** (optional, einziger Teil, der "wartet"): `fight_click` ignoriert Fertigkeitswahl, solange `voy.stage_t` über einer kleinen Schwelle liegt (Vorschlag: 0,35 s, höchstens 0,6 s je Aktion); ein Klick auf eine freie
  Fläche oder die Leertaste überspringt den Rest (`stage_t = 0`). **Inszenierung wartet nie auf Eingaben**: die Sperre ist zeitbegrenzt und überspringbar.
* **Schlussansage:** der Beat des letzten Treffers soll die Ansage **auslösen**, statt dass `_draw_combat_view` sie im selben Bild startet (2367). Dann beginnt der Takt `combat_outro` erst nach dem Todesbild.
* **Neues Tempo-Setting** (falls gewünscht): statt zweier Zustände drei: "voll" (Inszenierung, 1,0), "kurz" (Anzeige mit 0,5 Zeitfaktor ohne Zoom und Zeitlupe, wie R4 Abschnitt 7 vorschlägt), "schnell" (heutiges `auto_combat`). Dazu `Settings.combat_view` einführen und
  `auto_combat` und `stage_scale` daraus ableiten; `Settings.auto_combat` bliebe als Alias für die dritte Stufe.

**Was nicht geschehen darf:** `await`/Timer in `Combat` oder `Voyage` für Inszenierung; neue Wartezeiten in `_end_fight`, `_steps` oder `start_fight`; Wartezeit bei `auto_combat`; Anfassen von `combat_outro` (bleibt 0 für Bots und Tests).

### 4.5 Zeitbudget

Pflichtwartezeit heute: nur Gegnerzüge x 0,9 s (1.6). Es gibt bei Einzelzielen 0,28 s freies Fenster je Aktion. Vorschlag für die **Obergrenze der Inszenierung** im Normalbetrieb (Empfehlung, nicht gemessen):

| Aktion | Zuschlag über die vorhandenen 0,9 s |
|---|---|
| gewöhnlicher Treffer oder Fehlschlag | 0 bis 0,3 s (Fokus-Eintritt nutzt das freie Fenster) |
| Hilfsfertigkeit, Heilung, Lied | 0 bis 0,3 s |
| Krit, Schwelle erreicht, Fangarm greift | bis +0,5 s |
| Tod eines Gegners | bis +0,6 s |
| Tod eines Mannes, letzter Gegner, Heldenmut, Zusammenbruch, Kraken-Zerquetschen | bis 1,5 bis 2,4 s (wie heute) |

Bei 0,3 s je Aktion kostet das im Draugr-Kampf rund 19 s (63 Aktionen), bei Krit und Todesstößen kommen etwa 4 bis 8 s dazu. Zum Vergleich: die heutige Pflichtwartezeit dieses Kampfes beträgt 24 s, die Bedenkzeit der Männer kommt noch dazu.

---

## 5. Inventar: alles in `hud.gd`, was den Kampf berührt

Legende der Kopplung: **Z** liest `Combat`-Zustand (`c.*`), **E** liest `events`, **V** liest oder schreibt `Voyage`, **S** liest oder schreibt Hud-Zustand, **D** zeichnet, **R** trägt Klickflächen/Tooltips ein, **X** nutzt `FightFx`, **K** Klang.

### 5.1 Variablen und Konstanten (hud.gd 1702 bis 1725)

| Name | Zeile | Inhalt | Schreiber | Leser | Auslagerbar mit |
|---|---|---|---|---|---|
| `FIGHT_HERO_X`, `FIGHT_FOE_X` | 1702/1703 | Mitte je Reihe: Männer 206/152/98/44, Gegner 274/328/382/436 | Konstante | `_fig_x`, `_fighter_rect`, `_fx_go` (Beschwören nutzt `FIGHT_FOE_X[0]`) | Bühne |
| `FIGHT_FEET` | 1704 | 120 (Fußzeile); `FightFx.FEET` wiederholt 120 | Konstante | fast alle Kampfteile (Schatten, Zahlen, Banner, Funken); `_draw_deck` | Bühne; Doppelung mit `FightFx.FEET` |
| `FIG_W`, `FIG_H` | 1705/1706 | Zelle 44 x 56 | Konstante | `_draw_fighter`, `_draw_fight_overlay` | Figuren |
| `_fight_skill` | 1708 | gewählte Fertigkeit, wartet auf Ziel | `fight_click`, `fight_key`, `_draw_combat_view` (Zurücksetzen bei Akteurswechsel); **`main.gd` (`--shotfight3`) setzt es von außen** | `_draw_combat_view`, `_draw_fighter` (Tooltip `Tips.fighter`), `fight_key` | Eingabe/UI |
| `_fight_move` | 1709 | Platztausch gewählt | `fight_click`, `fight_key`, `_draw_combat_view` | `_draw_combat_view`, `fight_key` | Eingabe/UI |
| `_fight_actor` | 1710 | zuletzt gesehener `c.actor` (erkennt Wechsel) | `_draw_combat_view` | `_draw_combat_view` | Eingabe/UI |
| `_combat_tex`, `_big_tex` | 1711/1712 | Bildspeicher (`load` nur wenn nicht headless; `_draw` läuft dort nicht) | `_draw_fighter`, `_big_texture` | `_draw_fighter`, `_draw_fight_overlay` | Figuren |
| `_anim` | 1713 | Kämpfer -> `{kind: attack/hit/dodge, t, wait, mv}` | `_fight_events` | `_draw_fighter`; `_tick_fight` zählt herunter | Figuren (Pose, Ausfall) |
| `_floats` | 1714 | schwebende Zahlen und Texte | `_fight_events` | `_draw_fight_overlay`; `_tick_fight` | Zahlen |
| `_ghosts` | 1715 | Gefallene, die ausblenden | `_fight_events` | `_draw_fight_overlay`; `_tick_fight` | Figuren |
| `_ev_seen`, `_ev_combat` | 1716/1717 | Lesezeiger und welcher `Combat` | `_fight_events` | `_fight_events` | Ereignisleser |
| `_ev_stagger` | 1718 | laufende Trefferzahl des Zuges (bestimmt `hw`) | `_fight_events` | `_fight_events` | Ereignisleser |
| `_ev_actor`, `_ev_sk` | 1723/1724 | letzter Angreifer und Fertigkeit (Startpunkt für Pfeile, Kugeln, Fangarme) | `_fight_events` (`attack`) | `_fx_hit`, `_fx_miss` | Ereignisleser (mit `by` überflüssig) |
| `_outro_for`, `_intro_pending` | 1719/1720 | Einmalmarken für Schlussansage und Einleitung | `_fight_events`, `_draw_combat_view` | dito | Ereignisleser |
| `_fx` | 1725 | `FightFx`-Instanz | `_fight_events`, `_fx_go/_hit/_miss`, `_fight_outro` | `_tick_fight`, `_draw_fight_overlay`, `_draw_fight_texts`, `_draw_combat_view` (`offset`, `zoom_scale`, `zoom_offset`) | bleibt/Regie |
| `_loadout_man` | 1722 | Aufstellung: wessen Fertigkeiten gewählt werden | `fight_click`, `fight_key`, `_loadout_toggle`; **`main.gd` (`--shotloadout`) setzt es** | `_draw_fight_prep`, `_draw_loadout` | Aufstellung |
| `_forge_man` | 1721 | gehört zur Schmiede, steht nur im Block | | | nicht Kampf |
| `_btns`, `_tips` | 63/68 | **gemeinsame** Klick- und Tooltip-Listen der ganzen Anzeige | `_draw` und `_draw_combat_view` löschen sie; `_register`, `_tip` tragen ein | `button_at` (Main -> `fight_click`), `_draw_tip` | bleibt im Hud |
| `_ui`, `_lore` | 60/61 | Schriften | `_ready` | `_t`, Aufstellung | bleibt im Hud |
| `debug_mouse` | 65 | Screenshot: feste Mausstelle | `main.gd` | `_draw` -> `mouse` | bleibt |

### 5.2 Funktionen

| Funktion | Zeile | Aufgabe | Liest | Schreibt / ruft | Kopplung |
|---|---|---|---|---|---|
| `_process` | 161 | ruft `_tick_fight(delta)` jedes Bild, auch außerhalb des Kampfes; `queue_redraw` | | `_tick_fight` | läuft auch headless (Bots) |
| `_draw` | 199 | bei `phase == COMBAT` nur `_draw_combat_view` | `voy.phase` | | |
| `fight_click(id)` | 1729 | Klick in Aufstellung und Kampf: `fp/fu/fd/fl/fauto/fgo/lo*`, `fs0..5`, `ft<s>_<r>`, `fwait` | `c.state`, `_fight_options`, `c.targets`, `c.needs_target`, `c.can_use` | `_fight_skill`, `_fight_move`, `_loadout_man`; `voy.combat_act/move/pass/flee`, `voy.fight_toggle/shift/auto_party/begin` | **Main ruft es öffentlich**; Ids kommen aus `_register` in `_draw_*` |
| `fight_key(key)` | 1804 | Tasten 1 bis 6, Leertaste, Esc, Q W E R, Enter, A | wie oben | ruft `fight_click` | **Main ruft es öffentlich**; die Zielseite (`heroes_side`) hängt an `Roles.skill(..)["tgt"]` |
| `_fight_options(c)` | 1828 | Fertigkeiten des Akteurs + "move" + "flee" | `c.actor` | | `fight_click`, `_draw_combat_view` |
| `_is_big`, `_big_texture` | 1838/1842 | Kraken-Riese | `Foes.is_big/BIG` | `_big_tex` | Figuren |
| `_fig_x(f)` | 1849 | x der Figur nach `rank` (Riesen immer ganz rechts) | `f.rank`, `f.side` | | **liest den Live-Rang**: springt zur Regelzeit (R2) |
| `_fighter_rect(f)` | 1855 | Klickfläche, 44x52 oder 76x80 | `_fig_x` | | Klickkarte (R4) |
| `_fig_row(f)` | 1861 | Zeile in `combat.png` | `f.role`, `Foes.ROW` | | Figuren |
| `_status_text(f)` | 1867 | Zustandsbuchstaben `! G T Z B b M S +` | `f.door/held_by/blind/charge/stun/bleed_turns/mark/guard/buff` | | liest den **Endstand** (R1) |
| `_fight_events(c)` | 1891 | **übersetzt Ereignisse in Animation, Zahlen, Klang, Wirkung**; Einleitung; `loud`-Schwelle 24 | `c.events`, `c.round_no`, `c.formation`, `c.foes/heroes` | `_anim`, `_floats`, `_ghosts`, `_ev_*`, `_fx`; `Sfx.play`; `_slow` | läuft **in `_draw`**; herz der Regie; ruft `_fx_go/_fx_hit/_fx_miss/_slow/_skill_label` |
| `_fight_outro(c)` | 2023 | Schlussansage nach Ergebnis | `c.result`, `c.formation`, `c.killed`, `voy.combat_outro` | `_fx.show_big/flash`, `Sfx` | wird in `_draw_combat_view` ausgelöst (2367) |
| `_slow(seconds)` | 2039 | hebt `voy._combat_t` auf mindestens `seconds` | | **schreibt `voy._combat_t` (privat)** | Kopplung R5 (4.3) |
| `_skill_label(sk)` | 2045 | Name der Fertigkeit fürs Banner ("Würgen" für `f_kr_wuerg`) | `Roles.SKILLS` | | |
| `_fx_go(c, who, sk)` | 2054 | Wirkung beim Ausholen (Lied, Schild, Klage, Tinte, Zerquetschen, Schuss ...) | `c.heroes` (Kriegslied: Ringe auf allen **jetzigen** Männern), `FightFx.go_fx`, `_fig_x` | `_fx.add/cue`, `_slow` | Ziele nur aus dem Zustand abgeleitet (3.2) |
| `_fx_hit(who, sk, hw, crit, dmg)` | 2103 | Wirkung am Ziel; Geschoss vom Angreifer | `_ev_actor`, `_ev_sk`, `_fig_x` | `_fx.add/cue`, `_slow` | bündelt Krit-, Schaden- und Todeswucht |
| `_fx_miss(who, sk, hw)` | 2150 | vorbeifliegender Pfeil/Kugel, leerer Hieb | dito | `_fx.add` | |
| `_tick_fight(delta)` | 2165 | Zeit vergeht: `_fx.tick` (Einfrieren hält alles an), Zeitlupe, `_anim`, `_floats`, `_ghosts` | `_fx.time_scale` | | **Anzeigezeit** (nicht `_combat_t`) |
| `_draw_deck()` | 2189 | Planken, Kante, Reling x 239 | `FIGHT_FEET` | | Bühne; Maße fest (y 114..160) |
| `_draw_fighter(c, f, mouse, valid)` | 2208 | Figur, Pose, Schatten, **Lichtkegel für `c.actor`**, Dreieck, Zielmarke, Name, Kraft- und Verzweiflungsbalken, Zustandsbuchstaben, "geschützt/offen!" | `c.actor`, `c.state`, `_anim`, `f.*`, `Time.get_ticks_msec()` (Ruhepose 520 ms), `_big_texture` | `_register("ft<s>_<r>")`, `_tip(Tips.fighter)`, `_t`, `_bar`, `UiSkin.mini_bar` | **zeichnet Figur und Beschriftung in einem; zweimal Rampenlicht an `c.actor`** (R1); Klickfläche in Bühnenkoordinaten (R4) |
| `_draw_fight_overlay()` | 2280 | Gefallene (Geister), `_fx.draw`, schwebende Zahlen | `_ghosts`, `_floats`, `_fx` | | |
| `_draw_fight_texts()` | 2305 | Vignette (fest 166 hoch), Blitz, Banner (fest Rect2(236,4,172,18)), große Ansage (Band y 58..110) | `_fx.banner`, `_fx.big`, `_fx.flash_color` | | Bühnenhöhe **166** an mehreren Stellen fest |
| `_draw_combat_view(mouse)` | 2340 | Kopf (Titel, Runde), Zugleiste (`c.upcoming(10)`), ruft `_fight_events`, Schlussansage, **Bühne unter `draw_set_transform(offset + zoom_offset, 0, zoom)`**, Gegnerzeilen, Griffbogen des Fangarms, Overlay, Texte, Journal (6 Zeilen ab y 172), Fertigkeitskarten (y 242), "Abwarten", "X ist am Zug …", Tooltip | fast alles aus `Combat`, `voy.combat`, `voy.combat_outro`, `_fx` | `_btns`/`_tips` (löscht und füllt), `_fight_actor`, `_fight_skill`, `_fight_move`, `_outro_for` | **zentraler Knoten**; mischt Bühne und Bedienung; Rect und Karten dort fest (Karten: 74 x 58 ab x 6, Schritt 78) |
| `_draw_fight_prep(mouse)` | 2469 | Aufstellung | `voy.fight_prep`, `Foes`, `Combat.FOE_HP`, `Combat.STAGE_HP`, `Tips.*` | `_register(fp/fu/fd/fl/fauto/fgo)` | eigenständig; nur `fight_click` und `_loadout_man` koppeln |
| `_draw_loadout(mouse)`, `_loadout_toggle(sid)` | 2555/2592 | Fertigkeitswahl in der Aufstellung | `Roles`, `_loadout_man` | `_loadout_man.loadout` | eigenständig |
| Verweise außerhalb | 948, 1186 | Begegnungskarte "fight" färbt Siegchance; Einstellungszeile "Kämpfe: schnell/von Hand" | `Encounters.chance`, `Settings.auto_combat` | | nicht Kampfansicht |

**Gemeinsame Helfer** (nicht auslagern, übergeben): `_t`, `_bar`, `_register`, `_tip`, `_draw_tip` (+ `_wrap`, `_tip_height`), `_card`, `_small_button`, `_kraft_col`, `_name_color`, `UiSkin.panel/bar/mini_bar/rule/portrait/State/BRONZE`, `SkillIcons.draw`, `Tips.fighter/skill/skill_short/fight_man/fight_auto/loadout`,
Farbkonstanten (`GOLD, RED, GREEN, VIOLET, DIM, PAPER, INK`), `Waves.VIEW_W/VIEW_H`. Zeichenbefehle brauchen das `Hud` als `CanvasItem` (wie `FightFx.draw(ci)` und `SlotView.draw(hud, mouse)`).

### 5.3 Kopplungen von außen

* `main.gd`: `_hud.fight_key` (577), `_hud.fight_click` (743), `_hud.button_at`, `_hud._fight_skill` (261), `_hud._loadout_man` (299), `_voy._combat_t = 9999.0` (286, 325, 342; hält die Gegner für Bilder an), `_voy.fight_begin()`, `_voy.combat_act("b_schuss"|"a_hieb"|"m_schuss", ...)` (324), `_voy.combat.act_foe/hero_pass/auto_hero` (252 bis 258), `kc._hurt(...)`, `snap_force`. Die `--shot*`-Abläufe bauen den Zustand in `_ready` und zeichnen im ersten Bild; neue Bühnenzustände brauchen ihre Flags dort.
* `voyage.gd`: `combat`, `combat_ctx`, `fight_prep`, `auto_combat`, `_combat_t`, `combat_outro`, `_outro_t`, `COMBAT_PACE`, `combat_act/move/pass/flee`, `fight_begin/toggle/shift/auto_party`, `_tick_combat`, `_end_fight`.
* `tips.gd`: `Tips.fighter/skill/skill_short` lesen `Combat` (`c._tentacles()`, `eff_skill`, `damage_range`, `hit_chance`); `fight_man`, `fight_auto`, `loadout` für die Aufstellung.
* `fight_fx.gd`: `SKILL_FX` (jede Fertigkeit **muss** einen Eintrag haben, `selftest`), `go_fx/hit_fx/is_flight/lunges`, `FEET`, Zeichenmethoden mit festen Koordinaten (`_ink` zeichnet fest in 22..237 x 62..118).
* `sfx.gd`: `SKILL_SND` (jede Fertigkeit muss einen Eintrag haben, `selftest`), `GAIN`.

### 5.4 Vorschlag für den Schnitt

| Modul | Inhalt | Nimmt aus `hud.gd` |
|---|---|---|
| **FightStage** (Bühne) | Geometrie (Reihen-x, `FIGHT_FEET`, Deck, Reling, Hintergrund), Kamera (Position, Zoom, Wackeln), Umrechnung Bühne <-> Bild | `FIGHT_*`, `_fig_x`, `_fighter_rect`, `_draw_deck`, `draw_set_transform`-Block |
| **FighterView** (Figuren) | Pose, Ausfall, Schatten, Rampenlicht, Name, Balken, Zustandsbuchstaben (angezeigte Kraft aus `hp0/hp1`) | `_anim`, `_ghosts`, `_combat_tex`, `_big_tex`, `_draw_fighter`, `_status_text`, `_fig_row`, `_is_big`, `_big_texture`, `_draw_fight_overlay` (Geister) |
| **FightDirector** (Regie) | liest Ereignisse, bildet Beats, hält Fokus-Akteur, Kamera, Dimmung, Banner, Zeitlupe; ruft `voy.combat_stage()` | `_fight_events`, `_ev_*`, `_intro_pending`, `_outro_for`, `_fight_outro`, `_slow`, `_fx_go/_fx_hit/_fx_miss`, `_skill_label`, `_draw_fight_texts` |
| **FightFx** (bleibt) | Einzelwirkungen | wie bisher, um Kamera- und Dimm-Teile erweitert |
| **FightPanel** (Bedienung) | Kopf, Zugleiste, Journal, Karten, Hinweis, "Abwarten", `fight_click/fight_key` | `fight_click`, `fight_key`, `_fight_options`, `_fight_skill`, `_fight_move`, `_fight_actor`, Teile von `_draw_combat_view`, `_floats` (bei Bedarf bei der Regie) |
| **FightPrep** (Aufstellung) | Aufstellung und Fertigkeitswahl | `_draw_fight_prep`, `_draw_loadout`, `_loadout_toggle`, `_loadout_man` |

Reihenfolge, die sich bewährt: erst `FightPrep` (hat fast keine Kopplung), dann `FightPanel` (Eingabe und Karten), dann die Teilung von `_draw_fighter` in Figur und Beschriftung, dann Regie. Die Schnittstellen zu `Main` (`fight_click`, `fight_key`, `_fight_skill`, `_loadout_man`) bleiben
am `Hud` als dünne Weiterleitungen, sonst bricht `main.gd` (Screenshot-Flags).

---

## 6. Risiken beim Umbau

| # | Risiko | Auswirkung | Gegenmittel / Prüfung |
|---|---|---|---|
| R1 | **Zustand eilt der Anzeige voraus** (Kraft, Reihen, Zustandsbuchstaben, Zugleiste, `c.actor`) | Wer die Aktion verzögert, zeigt Ergebnis vor dem Treffer (Balken sinkt vor dem Hieb) und das Rampenlicht beim Falschen (Beleg: `img/R1_beleg_marker_springt.png`) | `hp0/hp1`, `by`, `turn` (3.4); gezeigte Kraft und gezeigter Fokus als eigene Anzeigewerte; Marker nach Fokus-Akteur, nicht nach `c.actor` |
| R2 | **Reihenwechsel ohne Ereignis; `rank` im Ereignis ist der Endstand** | Figuren springen zur Regelzeit; Fangarm, Pfeil und Hieb starten am falschen Ort (nach Ansturm, Rückzugsschuss, Haken, Rammstoß) | `rank` im Ereignis, `move`, `row_h/row_f` im `turn`; sonst gleitende Bewegung unmöglich |
| R3 | **Pakete überlappen**, weil Mann->Mann und Gegner->Mann nicht warten | Zwei Beats gleichzeitig: Kamera springt, Banner wird überschrieben, Zahlen und Treffer vermischen sich | Beat-Schlange im Director; `voy.stage_t` (4.4); Eingabesperre nur kurz und überspringbar |
| R4 | **Klickkarte stimmt nicht mehr unter der Kamera** (`_register`/`_tip` in Bühnenkoordinaten, gezeichnet unter `draw_set_transform`) | bei gehaltenem Zoom 1,12 und Schwenk treffen Klicks das Nachbarziel oder nichts; Tooltips sitzen falsch | Klickflächen über dieselbe Abbildung wie die Zeichnung eintragen (`FightStage.to_screen`), oder beim Zielwählen zurück in die Totale |
| R5 | `Hud._slow` schreibt in `voy._combat_t`; `combat_act` überschreibt es | verlorene Zuschläge (aus dem Quelltext), jede Änderung am Takt bricht Anzeige und Tests unbemerkt | `stage_t` einführen (4.4), `_slow` entfernen; `COMBAT_PACE >= 0.8` (selftest) und `_tick_combat`-Test (`t3_o`) bleiben grün |
| R6 | **Drei Uhren** (echte Zeit, Anzeigezeit, Wanduhr) | Ansage läuft in Zeitlupe nur zu 59 % (gemessen); Klänge eilen vor; `col` der Ruhepose wechselt nach Wanduhr (Screenshots ungleich) | eine "Bühnenuhr" für Anzeige **und** Klänge; `Sfx`-Verzögerungen durch Zeitfaktor teilen; Ende des Kampfes erst nach dem Todesbild (`stage_t`); Ruhepose nach `Waves.time` oder Debug-Schalter |
| R7 | **Ereignisse werden in `_draw` abgeholt** | Läuft `_draw` nicht (headless, verdeckt), bleiben Ereignisse liegen; Klänge, `_slow` und Zustand hängen am Zeichnen; Schleife in `_draw` zu verschieben, ohne headless abzufangen, lässt Bots Anzeige rechnen | Abholung an einer Stelle halten; bei Verlegung in `_process` `DisplayServer.get_name() != "headless"` und `voy.combat != null` prüfen |
| R8 | **Schnellmodus und Bots** laufen nur durch `Combat` und `Voyage` | Jede neue Rechnung dort kostet Bots Zeit (Prototyp: +13 %) und kann die Spielwerte ändern | nur additive Felder; **Logik-Prüfsumme (3356533480) darf sich nie ändern**, Ereignis-Prüfsumme darf sich ändern; `evtime` vor und nach vergleichen; kein neuer `randf/randi` in `Combat` |
| R9 | Ereignis-Pufferobergrenze 150 | stockt die Anzeige (Fenster verschoben, lange Einfrierzeit), gehen alte Ereignisse verloren; mit neuen Typen füllt sich der Puffer 1,6-mal so schnell | Anzeige abholt jedes Bild; bei `fresh > 24` gibt es die stille Fallback-Verarbeitung (`loud`): beim neuen Leser denselben Schutz einbauen |
| R10 | Tests, die fest an Ereignissen und Zeiten hängen | `selftest` prüft: Ereignistypen `attack/hit/die` vorhanden; jeder `attack` trägt ein `sk` mit Eintrag in `Sfx.SKILL_SND` (auch `f_kr_wuerg`); `SKILL_FX` und `SKILL_SND` vollständig; `FightFx`-Semantik (`cue`, `tick`, `freeze`, `offset`); `COMBAT_PACE >= 0.8`; `_tick_combat(0.2)` mit `combat_outro = 0.5` | vor und nach jedem Schritt `selftest.gd` (`FEHLER: 0`), `sfxtest`, `musictest`, `runbots` (`--autoplay` und `--random`); keine neue Fertigkeit ohne Eintrag in beiden Tabellen |
| R11 | `_fight_events` setzt `who != null` voraus und hat keinen `match`-Standardzweig | Ein Ereignis ohne `who` stürzt die Kampfansicht ab; neue Typen laufen sonst still ins Leere | neue Typen immer mit `who`; beim Umbau Schleife absichern (`if who == null: continue`) |
| R12 | Zeichenkosten | Pro Bild heute einige hundert Aufrufe; Abdunkeln, Lichtkegel, Kamera, Nachbilder und gedoppelte Figuren treiben es hoch; `_ink` zeichnet 16 Kreise | Dimmung als ein Rechteck plus Lichtkegel aus 3 bis 4 Stufen; Aufrufe zählen (Spielfeld 480 x 320) |
| R13 | **Pixelraster:** `snap_2d_transforms_to_pixel` und `snap_2d_vertices_to_pixel` an; `draw_set_transform` mit Bruchzoom skaliert Zellen 44 x 56 und Beschriftung ungleichmäßig | flimmernde Pixelbreiten, unscharfe Namen und Balken, die in `_draw_fighter` mit der Bühne zoomen | Zoomstufen mit regelmäßigem Muster (1,125 / 1,25) und Ausprobieren im Screenshot; Beschriftung (Name, Balken, Buchstaben) in eigene, nicht gezoomte Ebene |
| R14 | Feste Maße der Bühne | Bühnenhöhe 166 an mindestens drei Stellen (Vignette, Blitz, Texte), Banner fest bei (236, 4, 172, 18), Band der Ansage y 58..110, Journal ab y 172, Karten ab y 242, `FightFx._ink` fest 22..237 x 62..118, `FightFx.FEET` doppelt | Maße in `FightStage` bündeln; eine neue Bühne (größere Figuren, andere Höhen) muss alle diese Stellen anfassen |
| R15 | **Screenshot-Abläufe** (`main.gd` 242 bis 342) setzen Zustand von Hand, nutzen `_hud._fight_skill`, `_hud._loadout_man`, `_voy._combat_t = 9999` und zeichnen im ersten Bild | Umbenennung oder Verlagerung dieser Dinge bricht die Bilder (lautlos: das Bild zeigt nur etwas anderes); `Sec` ist ungenau (erstes Bild lädt Texturen) | Namen am `Hud` als Weiterleitungen halten; neue Flags (z. B. `--shotfocus`) in `main.gd` für jede neue Szene; `stage_t` in den Flags einfrieren wie `_combat_t` |
| R16 | **Blutung, Rundenwechsel, Heldenmut** hängen als Anhängsel am Paket des Vorgängers; Reihenfolge der Ereignisse ist nicht fachlich geordnet | Eine Regie, die Pakete nur an `attack` trennt, hängt den Blutungstreffer des Nächsten an die Kamera des Vorgängers | `act` und `dot` (3.4) oder `sk == ""` als Trennung (3.3) |
| R17 | `attack.sk` und `hit.sk` laufen weiter für Fremdereignisse (`heroic`, `snap`, `die`, `text`) | falsche Banner oder Klänge, wenn die Regie `sk` für alles nutzt | `sk` nur bei `attack/hit/miss` verwenden (wie heute) |
| R18 | **Ziele ohne Schaden unbekannt** (Lieder, Schild, Klage, Hohn) | Kamera weiß nicht, auf wen sie schwenken soll; Zustandssymbole können nicht am Ziel erscheinen | `tgts` im `attack` (3.4) |
| R19 | Kraken: Riese (88 x 88) steht immer ganz rechts hinter den Fangarmen; Griffbogen und Zerquetschen sind Zustand, nicht Ereignis (der Bogen erscheint zur Regelzeit, die Peitsche braucht 0,45 s) | Zoom oder Schwenk auf Reihen passt für den Riesen nicht; Griff erscheint vor der Peitsche | Brennpunkt je Figur (`_fighter_rect`), Griff erst mit `text "gepackt!"` zeigen |
| R20 | `_ev_combat` hält den letzten `Combat` samt Fighter, Männern, `voy` | kleines Leck bis zum nächsten Kampf; Dictionary mit Fighter-Schlüsseln (`_anim`) hält Objekte gefallener Gegner | bei Kampfende leeren (`_fx.clear()` und Verweise null) |
| R21 | `Kampfrausch` setzt den Mann ein zweites Mal in `order`; summoned Gegner stehen nicht in `order` | Zugleiste und Fokus-Reihenfolge weichen von der Erwartung ab (der Mann hat zwei Züge in Folge) | `turn`-Ereignis als Wahrheit der Reihenfolge nehmen, nicht die Zugleiste |
| R22 | `Hud._draw_combat_view` malt als Erstes ein Rechteck mit Alpha 0,9 über die ganze Welt | die Welt (Schiff, Meer) scheint zu 10 % durch (im Bild sichtbar); jede neue Hintergrundbühne muss das berücksichtigen | Rechteck ersetzen oder Alpha bewusst setzen |

**Empfohlene Reihenfolge der Umbauschritte** (jeder Schritt einzeln testbar):

1. Messnetz in der Arbeitskopie: `evhash` (Prüfsummen), `evtime`, `selftest`, `runbots` einmal laufen lassen und die Ausgangswerte notieren (Anhang A).
2. Ereignisfelder Priorität 1 und 2 in `Combat`; Logik-Prüfsumme muss 3356533480 bleiben, `selftest` `FEHLER: 0`.
3. Im `Hud` einen **Schattenleser** neben `_fight_events` laufen lassen, der Pakete bildet und nur protokolliert (Beats stimmen? `act` lückenlos? `turn` je Wechsel?), ohne etwas zu verändern.
4. `Voyage.stage_t` mit `combat_stage()`; `Hud._slow` darauf umstellen; `selftest` und Screenshots prüfen.
5. Director und Kamera in einem eigenen Modul; Klickkarte über die Bühnenabbildung; `main.gd`-Flags ergänzen.
6. Erst danach Figuren, Bühne und Bedienung auslagern (5.4).

---

## Anhang A: Werkzeuge und Ausgangswerte

Alle Skripte laufen mit `tools\dev\rungd.ps1 -Script tools/<name>.gd -Tail 100` (in der Arbeitskopie; sie ändern nichts am Spiel). Kopien liegen als `.gd.txt` in `docs/kampf_spektakel/R1_werkzeuge/`.

| Skript | Zweck | Ausgangswert (Stand 3. November 2026, unverändertes `combat.gd`) |
|---|---|---|
| `R1_evhash.gd.txt` (`evhash.gd`) | Prüfsummen über 200 Kämpfe mit festem Seed (5 Aufstellungen x 40) | Logik **3356533480**, Ereignisse **1343226653** (Textlänge 221103) |
| `R1_evtime.gd.txt` (`evtime.gd`) | Rechenzeit des Schnellmodus (400 Kämpfe je Zeile) | Draugr 3,26 ms und 122 Ereignisse je Kampf, Kraken 3,85 ms und 172 |
| `R1_evdump.gd.txt` (`evdump.gd`) | Ereignisse einzelner Handlungen: Einzelziel, Fläche, Heilen, Lieder, Tod, Blutung, Heldenmut, Berserker, Kraken, Beschwören, Platztausch, Warten, Flucht (Katalog 2.4) | Ausgabe siehe 2.4 |
| `R1_evdump2.gd.txt` (`evdump2.gd`) | Griff, Haltezüge, Überbordgehen, Tod des Kraken, Tod des Fangarms mit Gefangenem, Zug- und Ereigniszahlen je Kampf | Tabelle 2.4 und 1.6 (erste Fassung) |
| `R1_evdump3.gd.txt` (`evdump3.gd`) | Wie viel der Schlussansage (1,9 s) läuft nach einem Tod in Zeitlupe ab (Nachbau der Uhren) | 100 % / 59 % / 90 % (4.3) |
| `R1_evdump4.gd.txt` (`evdump4.gd`) | Züge ohne Ereignis, Reihe im Ereignis gegen Reihe danach (Ansturm), Takt von `Voyage` im Handbetrieb, Verlust des `_slow`-Zuschlags | Abschnitte 2.5, 1.3, 4.3: Takt 0,90 s, `_combat_t` nach `fight_begin` 1,10 s (gemessen); Verlust des Zuschlags nur als Rechenbeispiel |
| `R1_evdump5.gd.txt` (`evdump5.gd`) | Häufigkeiten je Kampf (Tabelle 1.6) | Tabelle 1.6 |
| `R1_evdump6.gd.txt` (`evdump6.gd`) | zeigt die neuen Felder (nur in der Arbeitskopie mit Prototyp sinnvoll) | Auszug 3.5 |

Das Skript `evdump4.gd` und `evdump6.gd` setzen auf `Voyage`/`Combat` des jeweiligen Projekts auf; `evdump6.gd` läuft nur mit dem Prototyp-Diff.

Prototyp-Unterschied zum Hauptprojekt: `docs/kampf_spektakel/R1_werkzeuge/R1_combat_ereignisfelder.diff.txt` (`diff -u`; auf `scripts/combat.gd` des Hauptprojekts anwendbar). Beleg-Bild: `docs/kampf_spektakel/img/R1_beleg_marker_springt.png`.
