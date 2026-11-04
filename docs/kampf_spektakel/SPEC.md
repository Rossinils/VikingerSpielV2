# SPEC: Kampf-Spektakel für "Halt Kurs" (verbindlicher Gesamtplan)

Stand: 4. November 2026. Chefplaner-Fassung aus den Berichten `R1_ablauf.md` bis `R5_oberflaeche.md` und den Entwürfen `D1_regie.md` (Regie), `D2_bild.md` (Bild), `D3_wucht.md` (Wucht).
Es wurde keine Spieldatei angefasst. Dieses Blatt ist **ein** widerspruchsfreier Plan: mehrere Helfer bauen parallel daraus, ohne Rückfrage.

## 0. Geltung und Spielregeln der Parallelarbeit

1. **Rangfolge:** `tools/dev/BRIEF.md` (Regeln, Werkzeuge, Fallen) gilt immer. Darunter gilt **dieses Blatt**. Wo es schweigt, gilt der Entwurf (D1, D2, D3) bzw. der Bericht (R1 bis R5), den die Karte als Quelle nennt. Wo SPEC und Entwurf sich widersprechen, gewinnt SPEC (Begründungen in 1.3). Alle Zahlen aus den Entwürfen sind **Ausgangswerte zum Abstimmen am Bild**, außer sie stehen hier als "verbindlich".
2. **Jede Karte = eine Arbeitskopie:** `tools\dev\make_sandbox.ps1 -Name <Karten-ID ohne Bindestrich, klein>` (z. B. `w103`). Dort wird entwickelt, getestet, fotografiert. **Ausgeliefert** wird nur, was in "Besitzer-Dateien" der Karte steht (`deliver.ps1 -Name w103 -Files a,b`). Fremde Dateien (auch aus fremden Arbeitskopien) darf man **lesen und kopieren**, nie liefern.
3. **Vertragsdateien** (3.2) sind der einzige Ort, an dem mehrere Karten dasselbe brauchen: jede Karte legt sie in der eigenen Arbeitskopie **wortgleich aus diesem Blatt** an (als Stub) und liefert sie nicht, außer sie gehört der Karte (W1-01). Spätere Lieferung durch W1-01 ist dann byteweise gleich bis auf Kommentare.
4. In der eigenen Arbeitskopie darf `main.gd`/`hud.gd` für Prüfstände beliebig verändert werden; geliefert wird davon nichts (außer in W2-01). Prüfstand-Skripte sind nur lieferbar, wenn die Karte sie nennt.
5. Jede Karte schließt mit der Meldung nach BRIEF ("Ablieferung") und legt Beweisbilder unter `docs/kampf_spektakel/img/<Karten-ID>_<name>.png` ab. **Jedes Bild wird mit dem Read-Werkzeug angesehen und beurteilt**; "nicht geprüft" muss in der Meldung stehen, wenn etwas nicht geprüft wurde (Bewegung kann niemand außer dem Besitzer beurteilen).
6. Nach jeder neuen `class_name`-Datei, jedem PNG/WAV: `rungd.ps1 -Script import`; Parse-Fehler zeigt Godot nur dort.
7. Nichts in diesem Plan wartet auf Eingaben oder macht den Schnellmodus, Bots oder Headless-Läufe langsamer (BRIEF). Jede Karte nennt ihr **Rückfallverhalten** und prüft es.

---

## 1. Zielbild, Rangfolge, Entscheidungen

### 1.1 Zielbild in zehn Sätzen

1. **Wer handelt, tritt ins Licht:** Das Deck ist ein dunkler Ort mit wenigen Lichtern (Ortslicht, Lampen, Randlicht); die Unbeteiligten versinken, der Handelnde (beim Gegnerzug das Opfer) ist die hellste Figur im Bild.
2. **Die Kamera hält einen ruhigen Zoom** (Stufen 1,0 / 1,125 / 1,25 / 1,375, nur Achtel) auf Handelnden und Ziel, schwenkt beim nächsten Akteur weiter statt zurückzufahren und steht bei der Zielwahl auf 1,0, damit jedes Ziel klickbar bleibt.
3. **Die Bühne wächst auf y 0..215, die Figuren auf rund 65 Pixel Körper** (Körper-Rig, 31 Posen: Ausholen, Zuschlagen, Nachschwung, Block, Zaubern, Fallen); bis das Rig steht, läuft ein ganzzahliges 2x-Gerüst auf dem alten Atlas.
4. **Jeder Kampfort ist ein eigener Ort** (Gegnerschiff, eigenes Deck, Requisiten, Lampen, Wetter): Geisterschiff im Nebel, Räuber bei Fackeln, Händler in der Dämmerung, Dorfsteg bei Abendrot, Kraken im Sturm.
5. **Jeder Treffer ist ein Satz kleiner Antworten innerhalb von 100 ms** (weißer Frame, Standbild, Wirkungsbild je Fertigkeit, Rückstoß, Teilchen, Zahl in eigener Wucht-Schrift, Klangschichten), in fünf Stufen bis zum Todesstoß; Zeitlupe und Vollbild-Ansagen bleiben den seltenen Augenblicken.
6. **Die Anzeige kennt den Ausgang vorab** und baut davor Spannung auf: eine Handlung = ein *Beat*, Beats laufen nacheinander, und gezeigt werden **Anzeigewerte** (Kraft, Reihe, Zustände), nie der vorauseilende Spielstand.
7. **Fokus kostet kein Tempo:** ein gewöhnlicher Treffer dauert genau den Takt (0,9 s, also +0 s); nur Krit, Tod, Schwelle, Heldenmut, Kraken und Flächenangriffe dürfen länger, und ein ganzer Kampf wird um höchstens 0,5 s länger.
8. **Die Oberfläche trägt die Information:** Schild unter den Füßen (Name, Kraft, Verzweiflung, Zustandssymbole statt Buchstaben), Zugleiste mit Porträts, Fokusschild über dem Handelnden, niedrigere Leiste mit Karten, Bildunterschrift, Chronik.
9. **Schnellmodus, Bots, Headless und Regelwerk bleiben unberührt:** kein Director, keine Bühne, `stage_t = 0`; Logik-Prüfsumme 3356533480, Balance, Speicherstände, Tests.
10. **Alles ist reine Anzeige in neuen Dateien**; `hud.gd` bekommt nur dünne Anschlüsse durch **einen** Besitzer, der alte Pfad bleibt als Rückfall erhalten.

### 1.2 Rangfolge der Wirkungen (was bringt am meisten für "Figur im Fokus" und "mitreißende Grafik")

| Rang | Wirkung | Warum | Kosten | Karte |
|---|---|---|---|---|
| 1 | **Licht: Dimmung, Rampenlicht, Randlicht, Ortsfarbe** | wirkt bei jedem Abstand, kostet fast nichts; größter Einzelhebel für "im Rampenlicht" (R4 Technik 1, D2 3) | gering | W1-02, W1-03 |
| 2 | **Größere Bühne (215) mit Ort**: Himmel, Meer, Gegnerschiff, Deck, Reling, Lampen | macht aus dem dunklen Streifen einen Ort; "mitreißend" | mittel (viel Pixelkunst) | W1-03, W1-04a/b |
| 3 | **Figuren groß mit Ausholen, Zuschlagen, Halten** | ohne Anlauf kein Schlag (R2 3.4) | hoch (Rig, 23 Figuren) | W1-05, W1b-A/B/C, W1-06 |
| 4 | **Kontakt-Wucht**: weißer Frame, Standbild, Rückstoß, gerichtetes Wackeln, Wirkungsbild, Zahl, Klangschichten | "Treffer haben Gewicht" | mittel | W1-07, W1-09 |
| 5 | **Gehaltene Kamera mit Übergabe** | Fokus als Raumgefühl; nur mit Regie sinnvoll | mittel | W1-02 |
| 6 | **Lesbarkeit**: Fokusschild parallel zur Aktion, Zustandssymbole, Schilder, Zugleiste | Information ohne Tempoverlust | mittel | W1-08 |
| 7 | **Eskalation**: Krit, Todesstoß, Todesbilder, Heldenmut/Zusammenbruch inszeniert | Höhepunkte sind selten und tragen die Erinnerung | mittel | W1-02, W1-07 |
| 8 | **Atmosphäre**: Nebel, Partikel, Regen, Blitz, Requisiten-Leben | Stimmung | gering bis mittel | W1-03 |
| 9 | **Töne**: 15 neue Klänge, Schichtung | Wucht fürs Ohr | gering | W1-09 |
| 10 | **Schmuck**: Nachbilder, geworfener Schatten, Spiegelung | Politur; jederzeit abschaltbar | gering | W1-03 |

### 1.3 Konfliktauflösungen (SPEC überstimmt die Entwürfe)

| # | Konflikt | Entscheidung | Grund |
|---|---|---|---|
| K1 | R5: alte Figuren 2x (88x112) als Endzustand; D2: Rig 1x (65 px) | **Rig 1x ist Ziel; 2x-Gerüst nur Übergang.** Eine Pixelgröße im ganzen Bild | 2x-Pixel neben 1x-Himmel/Schrift = Stilbruch (D2 5.1); R5-Layout hängt nur an `FEET` und Figurhöhe, trägt also beides |
| K2 | `FightGeo` (D1) gegen `StageGeo` (D2) | **Eine** Klasse `FightGeo` | doppelte Wahrheit vermeiden |
| K3 | Kamera: D1 `FightCam` im Director, D2/R3 glättet die Bühne selbst | **Kamera gehört dem Director** (deterministisch, headless testbar, eigene Uhr). Die Bühne ist ein zustandsloser Zeichner: `render(zoom, center_x, shake, light, views)` | eine Quelle der Wahrheit; `focus()/release()/set_pose()` der Bühne entfallen |
| K4 | Zoomstufen 1/16 (D1) gegen 1/8 (R3) | **Nur Vielfache von 1/8**; normal 1,125; Hilfe, Fehlschlag, Fläche ab 3 Ziele, Kraken 1,0; Krit 1,25; Todesstoß 1,375 (begrenzt) | Stufe 1,0625 ist kaum sichtbar, regelmäßigeres Pixelmuster |
| K5 | Zoom-Drehpunkt: Bühnenunterkante (R4), 215 (R5) oder Bodenlinie (R3, D1) | **Bodenlinie `FEET = 172`** | Füße bleiben auf ihrer Zeile, Schilder (y 177..212) wandern nur in x |
| K6 | Dimm-Doppelung: D1 "Unbeteiligte 0,55" gegen D2 "Ortslicht dunkelt schon" | Figuren tragen **`lit` (0..1)**: 0 = Ortslicht `amb`, 1 = Schlüssellicht; D1-Helligkeiten sind in `lit` umgerechnet (3.9). Hintergrund `bg` ist **relativ zum Ortswert** (Ruhe 1,0) | D2 maß: erster Versuch war zu dunkel |
| K7 | Stufentabellen D1 gegen D3 | **Standbild, Wackeln, Zoom, Zeitlupe, Takt nach D1/R4; Wirkungsbilder, Teilchen, Sterne, Rückstoß, Zahlen nach D3; weißer Frame nach D2** (3.9) | D1 ist an R4 und der Taktbilanz geprüft, D3 am Bild |
| K8 | Vollbildblitze | **Keine**, außer Kraken-Tod, Zerquetschen, Heldenmut (Alpha höchstens 0,3, höchstens 3 je Sekunde, abschaltbar). Krit/Todesstoß blitzen nur auf Sprite und Halo | R4 (Schutzregel), D2 |
| K9 | Banner oben rechts (heute) gegen Fokusschild (R5, D1) | **Fokusschild**; `FightFx.show_banner` wird in der neuen Ansicht nicht gerufen | eigener Auftritt am Handelnden |
| K10 | Zahlen: `Hud._floats` / D1-Cue `float` / D3 `FightNumbers` | **`FightNumbers` (D3)**, gezeichnet im Hud-Layer mit der Bühnenmatrix, nicht gezoomt; Start **nach** dem Standbild | R4 Technik 9 |
| K11 | D3 `FightAnim` (gezeigte Kraft, Zustandsvergleich) gegen D1 `FigView` | **`FightAnim` entfällt**; `FigView` (Director) trägt `shown_hp`, `trail_hp`, `status`, `hit_*`, `death_*`. `FightMarks` (D3) bleibt als Zeichner | gleiche Daten nicht doppelt führen |
| K12 | R1 Priorität 3 (`status`-Ereignisse in `combat.gd`) | **Nein.** Director nimmt am Kontakt eines Beats einen Zustands-Schnappschuss | kleinere Änderung am Regelwerk |
| K13 | Töne: D1 sieben, D2 eins, D3 zehn (Dopplungen `thud`/`hit_sub`, `exhale`, `round_tick`/`round_drum`) | **15 neue Klänge** (3.10); `thud` entfällt (= `hit_sub`), `exhale` einmal, Rundenwechsel nur `round_tick` (leise) | Tempo und Ermüdung |
| K14 | Selbsttest: jeder will Blöcke in `tools/selftest.gd` | **Niemand außer W2-01 fasst `selftest.gd` an**; jede Karte liefert ein eigenes Testskript, `tools/dev/fighttests.ps1` (W1-01) ruft alle | eine große Funktion, Konfliktquelle |
| K15 | `lumcheck.py` (D1) = `luma.py` (D2) | **eine** Datei `tools/dev/lumcheck.py` (W1-01) | |
| K16 | Zelle 112x104 (R2) gegen 116x108 (D2) | **116x108** (2 px Rand für Umriss und Randlicht), Anker (42, 101) | Shader braucht den Rand |
| K17 | Anker-Datei: eine große `anker.json` | **je Figur** `assets/fig/<id>.json` | keine Merge-Konflikte zwischen Gegner-Karten |
| K18 | Hund/Fangarm: Weg offen | **Streifen im 116x108-Raster** (alte Zeichnung umgerastert plus Zusatzposen), Kraken bleibt 88x88 plus `kraken_ex.png` | D2 |
| K19 | Figuren zeichnen: `Sprite2D` (D2) gegen `draw_texture_rect_region` (D3 `FxPose.crumble/fall`) | **`FighterNode` zeichnet selbst (`_draw`) mit `ShaderMaterial`**, Kinder nur für Schatten/Spiegelung | Todesbilder und Spalt-Versatz brauchen Zeichenaufrufe; ein Material für alles |
| K20 | Alter Pfad: löschen oder halten (D2 löscht `_draw_deck`) | **Halten.** Der neue Kampfbildschirm lebt in neuen Dateien (`FightPresenter`, `FightUi`); `hud.gd` bekommt Haken, der alte Pfad bleibt hinter `USE_FIGHT_V2` und `--oldfight` unverändert | Rückfall, kein Doppelumbau der 3000-Zeilen-Datei |
| K21 | Einstellungen: drei neue | `fight_view` (voll/kurz), `shake` (aus/schwach/normal), `stage_fx` (voll/schlicht), eine Gruppe "Kampfansicht" | |
| K22 | Zeichenbudget: D2 gesamt ≤ 340, D3 Wirkungen ≤ 350 *zusätzlich* | **gesamt ≤ 420 im Normalbild, ≤ 520 im schlimmsten Bild** (Kraken-Quetschen + Krit), Primitive ≤ 6000 | BRIEF: "einige hundert"; beide Entwürfe lagen sonst unvereinbar |
| K23 | Aufstellung/Fertigkeitenwahl (R5 B7/B8) | **Nachrangig** (W3-D, nur wenn Zeit): beeinflusst den Kampf nicht | |

### 1.4 Was bewusst **nicht** gebaut wird

Impact-Frames, Smear, Letterbox, Kamera-Roll, Zoom unter 1,0, Eingabesperre/Eingabepuffer, Zielvorschau-Zoom, Dauergeräusche je Ort, Musik-Absenkung (`MusicDirector.duck`), größeres Rig (90 px), Tageszeiten, eigene Gesichter für Entsetzen, SubViewport für Kamera oder Abstufung, Bewegtbild-Prüfung durch Helfer (nur durch den Besitzer).

---

## 2. Architektur

### 2.1 Module und Dateien

Alle neu, `RefCounted` oder `Node`, **reine Anzeige**. "Besitzer" = Karte, die die Datei schreibt und liefert (Kapitel 4).

| Modul | Datei(en) | Art | Besitzer | Aufgabe |
|---|---|---|---|---|
| Geometrie, Stufen, Datenklassen (Verträge) | `scripts/fight_geo.gd`, `fight_level.gd`, `fight_views.gd` | statisch / Daten | W1-01 | `FightGeo`, `FightLevel`, `FightViews` (3.2) |
| Ereignisfelder, Takt, Einstellungen | `scripts/combat.gd`, `voyage.gd`, `settings.gd` | geändert | W1-01 | R1 3.4 Priorität 1+2, `stage_t`, drei Settings |
| **Regie** | `scripts/beat_planner.gd`, `fight_cam.gd`, `fight_director.gd` | `RefCounted` | W1-02 | Beats, Uhren, Kamera, Licht, Figurenwerte, Cues, Warteschlange |
| **Bühne** | `scripts/fight_stage.gd`, `fighter_node.gd`, `stage_light.gd`, `stage_particles.gd`, `stage_themes.gd`, `fig_art.gd`; `shaders/stage_grade.gdshader`, `stage_fog.gdshader`, `fighter_lit.gdshader`; geändert `sky_layer.gd`, `ocean_layer.gd`, `rain_layer.gd`, `sky.gdshader`, `ocean.gdshader` | `Control`/`Node2D` | W1-03 | Schichten, Licht, Orte, Figurenknoten, Laden |
| Kulissenbilder | `tools/make_stage_art.py` + `assets/stage_{deck,props,lamps,own,far,sky_extra}.png` + `scripts/stage_atlas.gd` (erzeugt) | Python/PNG | W1-04a | Deck, Requisiten, Lampen, eigenes Schiff, Ferne, Himmelszutaten |
| Kulissenbilder groß | `tools/make_stage_art2.py` + `assets/stage_{foe_draugr,foe_raeuber,foe_haendler,village,kraken_front,splash}.png`, `stage_front_{draugr,raeuber,haendler,dorf,kraken}.png` + `scripts/stage_atlas_big.gd` (erzeugt) | Python/PNG | W1-04b | Gegnerschiffe, Dorf, Kraken-Vordergrund, Vordergründe |
| Rig | `tools/rig_core.py`, `tools/make_fig_rig.py`, `assets/fig/<id>.png/.json` (5 Männer) | Python/PNG | W1-05 | Körper-Rig, Waffen/Köpfe, Männer |
| Gegner-Rig | `tools/rig_foes_a.py`, `rig_foes_b.py`, `rig_foes_c.py`, `tools/rig_ext_a|b|c.py`, `assets/fig/<id>.png/.json` (18 Gegner) | Python/PNG | W1b-A/B/C | Beschreibungen der Gegner |
| Tierfiguren | `tools/make_fig_tier.py`, `assets/fig/hund.*`, `tentakel.*`, `assets/kraken_ex.png` | Python/PNG | W1-06 | Hund, Fangarm, Kraken-Zusatzposen |
| **Wucht** | `scripts/fx_kinds.gd`, `fx_particles.gd`, `fx_pose.gd`, `fight_font.gd`, `fight_numbers.gd`, `fight_impact.gd`, `fight_marks.gd`, `fight_fx.gd` (geändert), `fx_sheet.gd`; `tools/make_fight_font.py`, `assets/fight_font.png` | statisch/`RefCounted` | W1-07 | Wirkungsbilder, Teilchen, Trefferpose, Schrift, Zahlen, Marken |
| **Oberfläche** | `scripts/fight_ui.gd`, `status_icons.gd`, `tips.gd` (geändert); `tools/make_status_icons.py`, `assets/status_icons.png` | statisch | W1-08 | Layout, Schilder, Zugleiste, Leiste, Kurzkarte, Chronik, Fokusschild, große Ansage |
| Töne | `scripts/sfx.gd`, `tools/make_sfx.py`, `tools/sfxtest.gd`, `assets/sfx/*.wav` (15 neue) | Python/WAV | W1-09 | Klänge und `GAIN` |
| **Integration** | `scripts/fight_presenter.gd` (neu), `scripts/hud.gd`, `scripts/main.gd`, `tools/selftest.gd` (nur Ergänzungen), `tools/dev/shots_fight.ps1` | Glue | W2-01 | `FightPresenter` verbindet alles; dünne Haken in Hud und Main |

### 2.2 Datenfluss aus `Combat.events`

```
Combat (Regeln, atomar, unverändert bis auf additive Ereignisfelder)
  events[]  ──────────────────────────────────────────────┐
                                                           ▼
Hud._process(delta)  ──►  FightPresenter.tick(delta)       (nur wenn Hud sichtbar im Kampf, nicht headless, nicht voy.auto_combat)
                              │
                              ├─ FightDirector.feed(c)      Ereignisse (id > gesehen) nach `act` zu Beats schneiden, BeatPlanner.plan()
                              ├─ FightDirector.tick(dt)     Uhren (Bühnenzeit/Echtzeit), Kamera, Licht, FigViews, UiState; sendet Signale cue(kind, data)
                              │        └─ Presenter._on_cue: go / impact / number / miss / heal / die / word / sfx / halo / mood / lamps / lightning /
                              │                              stage_flash / status_pop / turn_pulse / round  ──►  FightImpact, FightNumbers, FightFx, Sfx, FightStage, FightUi
                              ├─ FightFx.tick(stage_dt), FightNumbers.tick(stage_dt)
                              ├─ voy.combat_stage(dir.pending_s())          der Kampf wartet auf die Anzeige, nie umgekehrt
                              └─ FightStage.render(cam.zoom, cam.center_x, cam.shake, dir.light(), dir.figs())     (nur wenn Stage gebaut)

Hud._draw_combat_view(mouse) ──► FightPresenter.draw(hud, mouse)       Hud-Layer (2.3), registriert Klickflächen über FightGeo.rect_to_screen

Hud.fight_click / fight_key  (Ids und Tasten unverändert, 2.4)  ──►  voy.combat_act/move/pass/flee ; dir.set_selecting(valid) ; dir.skip_intro()
```

Regeln dieses Flusses: (a) `Combat` und `Voyage` kennen die Anzeige nicht; einzige Rückwirkung ist `voy.combat_stage(s)` (nie in `auto_combat`). (b) Ereignisse werden **einmal** vom Director geholt (Id-Zeiger), nicht mehr in `Hud._fight_events`. (c) Kein `await`, kein `create_timer` für Inszenierung; Klänge laufen über Cues in Bühnenzeit. (d) Anzeigewerte (`shown_*`) kommen aus den Ereignisfeldern `hp0/hp1/rank/turn`, nie aus `f.hp` des Spielstands.

### 2.3 Knotenbaum und Zeichenreihenfolge

```
Main (Node2D)
├─ _world (Node2D)                 im Kampf unsichtbar UND process_mode DISABLED (nach dem Kampf wiederherstellen)
├─ FightStage (Control, 480x215, clip_contents, mouse_filter IGNORE, focus NONE)   nur wenn nicht headless und Kampf mit Anzeige; sonst nie gebaut
│   ├─ Z0  Himmel (SkyLayer-Instanz, tone_mul, storm_override)               Tiefe 0,05
│   ├─ Z1  Ferne (stage_far, Möwen)                                           0,12
│   ├─ Z2  Meer fern (OceanLayer)                                             0,20
│   ├─ Z3  Kulisse (Gegnerschiff/eigenes Schiff/Dorf/Fangarme hinten)         0,30
│   ├─ Z4  Meer mitte (OceanLayer)                                            0,40
│   ├─ Z5  Dunst hinten (ColorRect + stage_fog)                               0,50
│   ├─ Z6  Reling, Rückwand, Requisiten hinten, Lampenkörper                  0,85
│   ├─ Z7  Deck (stage_deck, Fuge, Bodenrequisiten, Blutflecken: FxParticles.draw_stains)   1,00
│   ├─ Z8  Kontaktschatten, geworfene Schatten, Spiegelungen                  1,00
│   ├─ Z9  Abstufung (ColorRect + stage_grade): einziger Leser von hint_screen_texture
│   ├─ Z10 Lichtpfützen (additiv)                                             1,00
│   ├─ Z11 Figuren: je Kämpfer ein FighterNode (Node2D, _draw, ShaderMaterial fighter_lit), nach FigView.z sortiert (Handelnder zuletzt)
│   ├─ Z12 Wirkungen: FightFx.draw(ci) inkl. FxParticles.draw
│   ├─ Z13 Leuchten (BLEND_MODE_ADD): Lampenhöfe/-kerne, Halos, Mondhof, Blitzfläche
│   ├─ Z14 StageParticles (Glut, Gischt, Staub, Glühwürmchen; höchstens 80)
│   ├─ Z15 Dunst vorn (ColorRect + stage_fog, fade_bottom)                    1,20
│   ├─ Z16 Vordergrund (stage_front_<ort>, Kraken-Fangarme; nicht abgestuft)  1,45
│   └─ Z17 Regen (RainLayer, nur Kraken)                                      1,45
└─ CanvasLayer 1
    └─ Hud (Control)  ── FightPresenter.draw ──  Hud-Layer in dieser Reihenfolge:
        1. FightMarks.draw_edge (Herzrand der Schwelle, 24 Rechtecke, nur Bühnenrechteck)
        2. FightNumbers.draw (Zahlen und Schlagworte; Matrix FightGeo.layer_xf(1.0), nicht gezoomt)
        3. FightUi: Zielmarken (FightMarks.draw_target/area_marks), Schilder unter den Füßen, Statuskörperzeichen (FightMarks.draw_status_body)
        4. FightUi: Kopfzeile, Zugleiste, Fokusschild, große Ansage, Vollbild-Blitzrechteck (aus Cue stage_flash)
        5. FightUi: untere Leiste (Ansage, Bildunterschrift, Karten oder Gegnerkarte, Tastenzeile), Kurzkarte, Chronik
        6. Tooltips (nur Aufstellung); Klickflächen werden dabei in `_btns` eingetragen
```

Regeln: (1) Jeder `Control` der Bühne hat `mouse_filter = IGNORE` (Test T-S4). (2) Nur **eine** Fläche liest `hint_screen_texture` (Z9); die Abstufung liegt **unter** den Figuren. (3) Schichtmatrix `FightGeo.layer_xf(depth, zoom, center_x, shake)` (3.2), Ursprung auf ganze Pixel gerundet; die Kamera ändert nie Figurenpixel, nur Ort und Maßstab der Schichten. (4) Kein `Time.get_ticks_msec()` in der neuen Ansicht: Bühnenuhr bzw. Director-Echtzeituhr (`--shotclock`, `manual_clock`) → Bilder wiederholbar.

### 2.4 Layout des Kampfbildschirms (verbindlich, R5 2.2, Spielfeldpixel 480x320)

| Zone | Rechteck / Maß | Hinweis |
|---|---|---|
| Bühne | `Rect2(0, 0, 480, 215)` (`FightGeo.STAGE_RECT`) | 67 % der Höhe |
| Kopfzeile | `Rect2(0, 0, 480, 30)` über der Bühne | Kampfname (8, 11) Gold 8 px, "Runde n" (8, 21) 7 px |
| Zugleiste | ab x = 124, y 3..29; aktiv 22x26, übrige 16x22, Abstand 2, höchstens 10, dann "Runde n+1" | Mini-Porträts 14x14 (`FigArt.portrait`), Seitenstreifen, Kraftstrich |
| Chronik-Knopf | `Rect2(414, 4, 60, 12)`, ID `fchron`, Taste Tab | |
| Große Ansage | `Rect2(0, 32, 480, 40)` | Linien y 32 und 71, Text 22 px; Köpfe beginnen bei y ≥ 68 (Zoom 1,0 Rig: 108) |
| Kurzkarte (Hover) | `Rect2(6 oder 238, 31, 236, 12 + 10·Zeilen)` in der der Figur gegenüberliegenden Hälfte | nur wenn keine Zielwahl läuft |
| Fokusschild | Höhe 24, Breite = Text + 32; über dem Kopf (y = Kopf_screen − 32, wenn Kopf_screen ≥ 68), sonst seitlich neben dem Kopf; Riese links neben dem Kopf | folgt der Kamera, zoomt/wackelt nicht |
| Figuren | Fußmitten `FightGeo.HERO_X = [212,156,100,44]`, `FOE_X = [268,324,380,436]`, Riese `BIG_X = 408`, Sohle `FEET = 172`, Riese `BIG_SOLE = 164` | Fuge/Reling x 239 |
| Deck | `Rect2(-8, 142, 496, 73)` (Z7) | |
| Namensschild | `Rect2(cx − 26, 177, 52, 35)` (Riese 104 breit): Band 52x10 y 177, Kraftbalken 50x7 y 188, Verzweiflung 50x3 y 198 (nur Männer), Zustandssymbole y 203 (Männer) bzw. 198 (Gegner), 9x9, Schritt 10, höchstens 5, dann "+n" | `cx` = auf den Bildschirm umgerechnete Fußmitte |
| Zielwahl-Marke | über dem Kopf: Taste (Q W E R) + Trefferchance | gültige Ziele pulsierende Ellipse (Gegner `#d2564b`, Verbündete grün), ungültige 50 % abgedunkelt |
| Untere Leiste | `Rect2(0, 215, 480, 105)`, Füllung `#0b0c12`, Linien y 215 (INK), 216 (BRONZE), 217 (BRONZE_LO) | |
| Ansage | Grundlinie (8, 230) 9 px, Breite 350; Gold, beim Gegnerzug Rot, bei Rückzug Grau | |
| Abwarten | `Rect2(366, 220, 108, 13)`, ID `fwait`, Leertaste | |
| Bildunterschrift | Grundlinien 244 und 254, 8 px, Breite 464 | letzte zwei Meldungen oder Erklärung der überfahrenen Karte |
| Fertigkeitskarten | `Rect2(4 + 79·i, 258, 77, 46)`, i = 0..5 | Symbol 16x16 (3,3), Ziffer, Name 8/7/6 px |
| Gegnerkarte (Gegnerzug) | `Rect2(4, 258, 472, 46)` | ersetzt die Karten |
| Tastenzeile | Grundlinie (8, 317) 6 px | zustandsabhängig (R5 2.6) |
| Chronik-Platte | `Rect2(4, 34, 196, 176)`, ID `fchronplatte` | 15 Zeilen, schluckt Klicks |

**Klick-IDs und Tasten, die erhalten bleiben (Pflicht, Test K2):** `fs0..fs5` (Karten 1 bis 6; `fs4` Platztausch, `fs5` Rückzug **fest**, leere Plätze ohne ID, `_fight_options` liefert Leerstrings, `fight_click` ignoriert sie), `ft<Seite>_<Reihe>` (`ft0_0..3` Männer, `ft1_0..3` Gegner; nur gültige Ziele, in Bühnenkoordinaten **durch die Kameramatrix umgerechnet**: `FightGeo.rect_to_screen`), `fwait`, Aufstellung `fp/fu/fd/fl/fauto/fgo`, Loadout `lo<k>/lodef/lodone`. Neu: `fchron`, `fchronplatte`. Tasten: `1..6`, Leertaste, `Esc` (erst Chronik schließen, dann Auswahl verwerfen), `Q W E R` (Reihe 1 bis 4), `Tab` (Chronik), Aufstellung `A`, `Enter`/`KP_Enter`. `Main._click`, `Main._unhandled_input` und die Weiterleitung `_hud.fight_key/fight_click` bleiben **unverändert**; `_fight_skill`, `_fight_move`, `_fight_actor`, `_loadout_man` bleiben Felder des `Hud` (Screenshot-Flags greifen darauf zu).

### 2.5 Betriebsarten

| Art | Auslöser | Verhalten |
|---|---|---|
| **voll** | Kampf von Hand, nicht headless, `Settings.fight_view == 0` | alles |
| **kurz** | `Settings.fight_view == 1` | Zeiten ×0,5, **kein** Zoom/Schwenk/Zeitlupe/Spannungspause, Standbild ≤ 40 ms, Wackeln ×0,5, `bg` 0,85, Unbeteiligte `lit` 0,45, Teilchen `budget 0,5`, `FightFx.lod = 1`; Dauern siehe 3.9 |
| **schnell** | `voy.auto_combat` (Einstellung "Kämpfe: schnell") und alle Bots | **weder Director noch Bühne noch Presenter werden gebaut**, `stage_t` bleibt 0, `start_fight` löst synchron |
| **headless** | `DisplayServer.get_name() == "headless"` | `Hud._process` baut Presenter/Bühne nicht; `FightDirector`, `BeatPlanner`, `FightCam`, `FightImpact.plan/power/sounds`, `FightFont.width`, `FightNumbers.add/tick` sind trotzdem ohne Textur testbar |
| **schlicht** | `Settings.stage_fx == 0` | kein Nebel, keine Partikel (Bühne), kein geworfener Schatten/Spiegelung/Nachbild, kein Regen; Abstufung und Leuchten bleiben; Aufrufe ≤ 220 |
| **Wackeln aus/schwach** | `Settings.shake` 0 / 1 | Wackeln, Vollbildblitze und Zeitlupen-Zoom ×0 / ×0,5; Standbilder bleiben |

---

## 3. Verbindliche Schnittstellenverträge

### 3.1 Ereignisfelder in `Combat.events` (W1-01; Diff: `docs/kampf_spektakel/R1_werkzeuge/R1_combat_ereignisfelder.diff.txt`, auf `scripts/combat.gd` anwendbar)

Alle bestehenden Schlüssel (`id, type, who, n, crit, sk, text`) und ihre Bedeutung bleiben, **kein neuer `randf/randi`**, keine Regeländerung, Reihenfolge der bestehenden Ereignisse unverändert. Neu (R1 3.4, Priorität 1 und 2, **ohne** `status`):

| Feld / Typ | Wo | Inhalt |
|---|---|---|
| `act` (int), `by` (Fighter oder null), `rank` (int), `round` (int) | **alle** Ereignisse | Nummer der Handlung (gliedert in Beats; Blutung, Rundenwechsel, Nachwachsen, Platztausch, Warten, Flucht, Kraken-Ankündigung bekommen eigene Nummern), Verursacher, Reihe von `who` **im Augenblick der Meldung** (vor anschließender Bewegung), Runde |
| `tgts` (Array[Fighter]), `tgt` (String) | `attack` | alle anvisierten Ziele in Reihenfolge, auch bei Lied/Schild/Hohn/Klage/Tinte; `tgt` = `Roles.skill(sk)["tgt"]` (`foe, foes, ally, allies, self, fself, fallies, hero, heroes ...`); Berserker-Freundbeschuss: `friendly = true` |
| `hp0`, `hp1` (float), `lethal`, `door`, `resist` (bool), `dot` (bool) | `hit`, `heal` | Kraft unmittelbar vor/nach der Wirkung; Treffer tötete; Mann steht nun an der Schwelle; Mann an der Schwelle überlebte; Treffer ist Blutung |
| `turn` (neu) | `_next_actor`, wenn ein Akteur endgültig dran ist | `who` = Akteur, `n` = Runde, `text` = `hero`/`foe`, `row_h`, `row_f` = Kopien der Aufstellung nach Reihe; markiert das **Paketende** und liefert den Endstand der Reihen |
| `move` (neu) | `_swap` | je Beteiligtem `who`, `rank` = alte Reihe, `n` = neue Reihe, `text` = Anlass (`tausch, vorrücken, vor, zurück, pull, push`) |
| `skip`, `wait`, `flee` (neu) | `_next_actor`, `hero_pass`/`act_foe`, `act_foe` | `who` überspringt (`text`: `betäubt, Schreck, verzagt, Griff`), wartet, flieht (vor `erase`, damit `rank` stimmt) |

Regeln: jedes neue Ereignis hat `who != null`; `Hud` und Director ignorieren unbekannte Typen still (heutiges Verhalten). **Abnahme:** Logik-Prüfsumme (`tools/evhash.gd`) bleibt **3356533480**; `selftest.gd` `FEHLER: 0`; Rechenzeit im Schnellmodus höchstens +15 % (R1 maß +13 %).

`Voyage` (W1-01): `var stage_t := 0.0`; `func combat_stage(seconds: float) -> void` (nur `if combat != null and not auto_combat`: `stage_t = minf(maxf(stage_t, seconds), 4.0)`); in `_tick_combat`: `stage_t = maxf(stage_t - delta, 0.0)`, Gegnerzug nur bei `_combat_t <= 0.0 and stage_t <= 0.0`, im Zweig `state == "done"` zuerst `if stage_t > 0.0: return`. `COMBAT_PACE`, `combat_outro`, `combat_act` bleiben unverändert (Tests `t3_o`). `Settings` (W1-01): `static var fight_view := 0` (Schlüssel `play/fight_view`), `static var shake := 2` (`play/shake`), `static var stage_fx := 1` (`play/stage_fx`), laden/speichern wie `auto_combat`.

### 3.2 Vertragsdateien (wortgleich verwenden; Besitzer W1-01)

```gdscript
# scripts/fight_level.gd
class_name FightLevel
extends RefCounted

## Eskalationsstufe eines Treffers (D1 2, D3 1): tödlich vor kritisch vor schwer vor Streifer.
enum { GRAZE, NORMAL, HEAVY, CRIT, KILL }

static func of(n: int, crit: bool, lethal: bool, dot: bool = false) -> int:
	if lethal:
		return KILL
	if crit:
		return CRIT
	if dot or n <= 5:
		return GRAZE
	if n >= 24:
		return HEAVY
	return NORMAL
```

```gdscript
# scripts/fight_geo.gd
class_name FightGeo
extends RefCounted

const VIEW := Vector2(480, 320)
const STAGE_RECT := Rect2(0, 0, 480, 215)
const UI_BAR_Y := 215.0
const FEET := 172.0                       # Stiefelsohle aller Figuren, zugleich Drehpunkt der Kamera
const HERO_X: Array[float] = [212.0, 156.0, 100.0, 44.0]     # Reihe 1..4
const FOE_X: Array[float] = [268.0, 324.0, 380.0, 436.0]
const BIG_X := 408.0                      # Riese (Kraken)
const BIG_SOLE := 164.0
const FUGE_X := 239.0
const HORIZON := 104.0
const RAIL_Y := 136.0
const DECK_Y := 142.0
const CELL := Vector2i(116, 108)          # Rig-Zelle (112x104 plus 2 px Rand)
const ANCHOR := Vector2i(42, 101)         # Pixel der Zelle, der auf (Fußmitte, FEET) liegt; gespiegelt: Spalte 73
const OLD_CELL := Vector2i(44, 56)        # alter Atlas combat.png
const OLD_ANCHOR := Vector2i(22, 52)
const RIG_TOP := 64.0                     # Scheitel über der Sohle (Rig)
const OLD_TOP := 82.0                     # Scheitel im 2x-Gerüst (41 * 2)
const BIG_TOP := 88.0
## Standardanker ab Fußmitte (x nach vorn, y nach oben), falls <id>.json fehlt oder Gerüst
const RIG_ANCHORS := {"chest": Vector2(0, 38), "head": Vector2(0, 72), "hand": Vector2(32, 30), "tip": Vector2(56, 26)}
const OLD_ANCHORS := {"chest": Vector2(0, 60), "head": Vector2(0, 96), "hand": Vector2(40, 54), "tip": Vector2(70, 52)}

static var rig := false                   # FigArt setzt es: true, wenn alle Rig-Streifen vorhanden sind und nicht --norig

static func fe() -> float:                # Figurenmaßstab für Effekte (k in D3): Rig 1,6, Gerüst 2,0
	return 1.6 if rig else 2.0

static func top(big: bool) -> float:
	return BIG_TOP if big else (RIG_TOP if rig else OLD_TOP)

static func fig_x(side: int, rank: int, big: bool) -> float:
	if big:
		return BIG_X
	return (HERO_X if side == 0 else FOE_X)[clampi(rank, 0, 3)]

static func sole(big: bool) -> float:
	return BIG_SOLE if big else FEET

## Matrix einer Schicht der Tiefe d (1,0 = Figuren). Füße (y = FEET) bleiben bei d = 1 auf ihrer Zeile.
static func layer_xf(depth: float, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Transform2D:
	var s := 1.0 + (zoom - 1.0) * depth
	var c := 240.0 + (center_x - 240.0) * depth
	return Transform2D(Vector2(s, 0.0), Vector2(0.0, s),
			Vector2(roundf(240.0 - c * s + shake.x * depth), roundf(FEET * (1.0 - s) + shake.y * depth)))

static func to_screen(p: Vector2, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Vector2:
	return layer_xf(1.0, zoom, center_x, shake) * p

static func rect_to_screen(r: Rect2, zoom: float, center_x: float, shake: Vector2 = Vector2.ZERO) -> Rect2:
	return layer_xf(1.0, zoom, center_x, shake) * r
```
`FightGeo.layer_xf(1.0, ...)` ist die **einzige** Abbildung Bühne → Bild; Klickflächen, Schilder, Zahlen und Fokusschild benutzen sie (Test: Klickfläche in der Mitte trifft bei Zoom 1,0 und 1,5).

```gdscript
# scripts/fight_views.gd  (Anzeigewerte, vom Director geschrieben, von Bühne und Oberfläche gelesen; Längen in Bühnenpixeln, Zeiten in s)
class_name FightViews
extends RefCounted

class FigView extends RefCounted:
	var f: Combat.Fighter
	var big := false
	var frame := ""               # "" = Ruhe: Renderer wählt idle_0..3 / ready_0..1 / stun_0..1 / door_0..1 nach ready, stun, shown_door und Bühnenuhr; sonst Name aus FigArt.FRAMES
	var ready := false            # am Zug in der Eingabe
	var stun := false
	var off := Vector2.ZERO       # Versatz (Ausfall, Vortreten, Gleiten), ganze Pixel, ohne Kamera, +x = zum Gegner hin (Renderer spiegelt für Gegner)
	var lean := 0.0               # nur Gerüst: Neigung am Kopf in px (Zeilenband-Scherung), + = zum Gegner
	var flash := 0.0              # weißer Frame 0..1 (Director-Anteil; der Renderer nimmt das Maximum mit FxPose.hit)
	var red := 0.0                # Rotstich 0..1
	var lit := 0.0                # 0 = Ortslicht, 1 = Schlüssellicht (3.9)
	var desat_add := 0.0
	var alpha := 1.0
	var outline := Color(0, 0, 0, 0)  # a = 0 aus (Zielwahl: Gold/Rot/Grün)
	var z := 0                    # Zeichenreihenfolge; der Handelnde bekommt den höchsten Wert
	var drop := 0.0               # Vortreten: px tiefer
	var shadow_w := 0.0           # Schatten breiter (px)
	var ghosts: Array[Vector2] = []   # Nachbilder (Versatz gegenüber off), höchstens 3
	var x := 0.0                  # gezeigte Fußmitte (gleitet beim Nachrücken)
	var shown_rank := 0
	var shown_hp := 0.0
	var trail_hp := 0.0           # Nachzieher des Kraftbalkens
	var shown_door := false
	var alive := true             # false: stirbt/ist weg, wird gezeichnet bis alpha 0
	var hit_t := -1.0             # Sekunden seit dem Kontakt (Bühnenzeit), < 0 = kein Treffer aktiv
	var hit_level := 0            # FightLevel
	var hit_dir := 1.0            # Schlagrichtung (+1 nach rechts)
	var frozen := false           # Standbild: Pose halten, Zittern
	var death_kind := ""          # "", crumble, fall, sink, kraken
	var death_t := -1.0
	var death_dir := 1.0
	var status: Array[String] = []    # Zustandsnamen nach StatusIcons.ORDER (Schnappschuss am Kontakt)
	var status_pop := {}              # Name -> Alter in s (0..0,12 poppt)

class LightState extends RefCounted:
	var bg := 1.0                 # Hintergrundhelligkeit RELATIV zum Ortswert (Ruhe 1,0)
	var vignette := 0.0           # Zuschlag
	var spot_pos := Vector2.ZERO  # Mitte der Abstufungs-Ellipse in Bühnenpixeln
	var spot_r := Vector2(190, 110)   # Halbachsen bei Zoom 1; die Bühne multipliziert mit dem Zoom
	var spot_col := Color(1, 0.85, 0.5)
	var spot_amt := 0.0           # 0..1
	var spot2_pos := Vector2.ZERO # zweiter Spot (Fläche, Zielwahl)
	var spot2_amt := 0.0
	var foe_turn := false         # kaltes Licht, Schlüsselfarbe `foe_key` des Ortes
	var flicker := 0.0            # 0..1: Flackern ±8 % mit 7 Hz (Auswahlphase)

class UiState extends RefCounted:
	var plaque := {}              # Fokusschild {who, name, skill, icon, side, crit, small, t (0..1), alpha, dy, kind "act"|"chip", text}
	var big := {}                 # große Ansage {text, sub, col, style "rise"|"sink"|"pop", t, dur}
	var turn_pulse := {}          # {f, t}
	var round_flash := 0.0
	var warn_crush := false       # Kraken spannt sich
	var edge := 0.0               # Stärke des Schwellenrands 0..1 (Herzschlag, Bühnenzeit)
	var selecting := false
```

### 3.3 Figurenstreifen (W1-05, W1b-A/B/C, W1-06 erzeugen; W1-03 `FigArt` liest)

* **Datei je Figur:** `assets/fig/<id>.png`, **3712 x 108** (32 Spalten zu 116x108), Figur blickt nach **rechts**, Fußmitte in Zelle (42, 101), Stiefelsohle Zeile 101, 2 px transparenter Rand ringsum (jede Pose bleibt mindestens 2 px vom Zellrand; Rig-Skript meldet `CLIP`), Gegner werden zur Laufzeit gespiegelt (negative Breite, `position.x` = linke Kante). `<id>`: Männer `schild, axt, bogen, skalde, muskete` (Zuordnung `Roles.Id.SCHILD/AXT/BOGEN/SKALDE/MUSKET`), Gegner = Schlüssel aus `Foes.TYPES`: Menschen `rost, bogner, totenwart, waechter, priester, beschwoerer, knochen` (Draugr), `brecher, messerkerl, schuetze, haken, antreiber` (Räuber), `wache, armbrust, kaufmann` (Händler), `bauer, schmied, kraeuterfrau` (Dorf); Tiere `hund`, `tentakel` (W1-06). Der Satz wird **aus `Foes.TYPES` minus `hund`, `tentakel`, `kraken` abgeleitet**, nicht aus einer Zahl (18 + 5 = 23).
* **Spalten = Frame-Namen** (Konstante `FigArt.FRAMES`, 32 Namen, Reihenfolge = Spalte): `idle_0 idle_1 idle_2 idle_3 ready_0 ready_1 windup_0 windup_1 strike_0 strike_1 follow_0 follow_1 cast_0 cast_1 cast_2 block_0 block_1 dodge hit_0 hit_1 stun_0 stun_1 door_0 door_1 fall_0 fall_1 fall_2 dead cheer_0 cheer_1 cheer_2 grab`. Bedeutung und Haltezeiten: R2 5.3 (Haltezeiten legt der Director fest). Hund hat 14, Fangarm 12 belegte Spalten; fehlende Namen löst `FigArt.frame` über die Rückfalltabelle auf (`strike_1→strike_0`, `cast_*→strike_0`, `fall_*→hit_1`, `dead→hit_1`, `cheer_*→ready_0`, `grab→stun_0` + 12 px höher).
* **Anker je Figur:** `assets/fig/<id>.json`: `{"cell": [116,108], "anchor": [42,101], "frames": {"strike_0": {"hand": [x,y], "tip": [x,y], "chest": [x,y], "head": [x,y]}, ...}}`, Werte ab Fußmitte, **x nach vorn, y nach oben**, ganze Pixel; der Renderer spiegelt x für Gegner. Fehlt eine Pose, gelten `FightGeo.RIG_ANCHORS`.
* **2x-Gerüst (Übergang, `FightGeo.rig == false`):** alter Atlas `combat.png` (Zelle 44x56, Spalten 0 Stehen A, 1 Stehen B, 2 Angriff, 3 Treffer, 4 Schwelle; Zeile nach `Foes.ROW`/Rolle), **ganzzahlig 2x** gezeichnet (Anker (22,52)·2). Namenstabelle: `idle_0/2→0`, `idle_1/3→1`, `ready_*→0`, `windup_*→0` (+ `lean`), `strike_*/follow_*/cast_*→2`, `block_*/hit_*/stun_*/fall_*/dead/grab→3`, `door_*→4`, `dodge/cheer_*→0`. Kraken: `kraken.png` Zellen 0 bis 4 (Stehen A/B, Angriff, Treffer, spannt sich) 1x, `windup→kraken_ex 0` (Hochreißen), `strike_1→kraken_ex 1` (Zuschlagen), `fall→kraken_ex 2` (Sinken), sonst wie `hit`.
* **Umschalten:** `FigArt.init()` setzt `FightGeo.rig = true` genau dann, wenn für **jeden** Schlüssel (Männer + 18 Gegner + hund + tentakel) `assets/fig/<id>.png` existiert und nicht `--norig`; Selbstprüfung `FigArt.missing() -> PackedStringArray` (headless sicher: nur `FileAccess.file_exists`). **Nie gemischt** (Rig-Männer neben 40-px-Gegnern wären ungleich).
* **Laden:** nur wenn `DisplayServer.get_name() != "headless"`; `FigArt.prewarm(ids)` ab der Aufstellung (`ResourceLoader.load_threaded_request`), höchstens 9 Streifen je Kampf, Zwischenspeicher mit Obergrenze 12 Streifen, am Kampfende geleert; Texturen in einer Klassenvariable halten (sonst weißes Rechteck).

### 3.4 Kulissenatlanten (W1-04a/b erzeugen, W1-03 liest)

* Erzeugte Dateien `scripts/stage_atlas.gd` (`class_name StageAtlas`) und `scripts/stage_atlas_big.gd` (`class_name StageAtlasBig`) tragen: `const RECTS := {"<key>": {"file": "<datei ohne assets/ und .png>", "r": Rect2i(...), "a": Vector2i(ax, ay)}}` (`a` = Ankerpixel im Rechteck), `static func has(key) -> bool`, `static func get_rect(key) -> Dictionary`, `static func tex(file) -> Texture2D` (träge, nicht headless), dazu `const WINDOWS: Array[Vector2i]` (Fensterlichter des Dorfs, StageAtlasBig).
* **Schlüssel (fest, W1-03 fragt `has()` und lässt Fehlendes weg):** `StageAtlas`: Requisiten `barrel_l barrel_s crate_l crate_s rope sack net anchor bale_a bale_b bale_c chest_0 chest_1 bones rune brazier_0 brazier_1 cannon rudder doghouse fishbasket woodpile laundry shield_r shield_b pennant_0..3 scale ribs weapon_rack hooks candles`; Lampen `lantern_0..3 torch_stand flame_0..5 wisp_0..3 window smoke_0..2`; Deckkacheln `deck_0..5` (je 240x74: 0 unser Deck trocken, 1 nass, 2 Draugr, 3 Räuber, 4 Händler, 5 Steg); Schiffe `own` (192x136); Ferne `far_ghost far_trade smoke_col coast`; Himmel `moon_full moon_sickle star_0..2 veil_0..1`. `StageAtlasBig`: `foe_draugr foe_raeuber foe_haendler` (192x136, Anker unten Mitte (96,136)), `village` (560x112), `kraken_front_0..1` (96x168), `splash_0..3` (48x24), `front_draugr front_raeuber front_haendler front_dorf front_kraken` (576x215, durchsichtig), `village_smoke_0..3`.
* Größen und Inhalte der Bilder: D2 "Erzeugte Bilder" Nr. 1 bis 11; alles **in Zielgröße gezeichnet** (nie skaliert), eine Pixelgröße im Bild, Rand mindestens 1 px transparent wo Halo gebraucht wird.

### 3.5 Bühne (W1-03): `FightStage` (zustandsloser Zeichner)

```gdscript
class_name FightStage
extends Control
static var instances := 0                               # Test: im Schnellmodus/Headless bleibt 0
func begin(c: Combat, formation: String) -> void       # Ort (StageThemes), FighterNodes, Atlanten holen
func end() -> void                                      # Knoten frei, Streifen bleiben im Zwischenspeicher
func prewarm(formation: String, kinds: Array) -> void   # ab der Aufstellung
func set_fx(fx: FightFx) -> void                        # Z12 ruft fx.draw(ci) (inkl. Teilchen) und fx.draw_under(ci) (Flecken in Z7)
func render(zoom: float, center_x: float, shake: Vector2, light: FightViews.LightState, views: Array) -> void   # je Bild vom Presenter; Views = FigView, in Zeichenreihenfolge
func pulse_light(pos: Vector2, col: Color, radius: float, dur: float) -> void       # Halo am Einschlag (additiv, Z13)
func mood(col: Color, amount: float, dur: float) -> void                              # Ortsfarbe kurz verschieben (Abstufung)
func lamps_flare(amount: float, dur: float) -> void                                   # Lampen +/- (0,3 = +30 %)
func lightning(strength: float = 1.0) -> void
func react(kind: String, f: Combat.Fighter, strength: float = 1.0) -> void           # hit crit die miss heal foe_turn hero_turn kraken_slam win lose: Ortszusätze
func anchor(f: Combat.Fighter, which: String) -> Vector2    # "hand" "tip" "chest" "head" in Bühnenkoordinaten (Spiegelung, FigView.off, Rig-JSON oder FightGeo.*_ANCHORS)
func to_screen(p: Vector2) -> Vector2                       # = FightGeo.to_screen mit der zuletzt gerenderten Kamera
func is_ready() -> bool
var flash_scale := 1.0                                      # Barrierefreiheit, aus Settings.shake
var clock_override := -1.0                                  # >= 0: Bühnenuhr fest (--shotclock)
```
`StageThemes.DATA[<formation>]` (reine Daten, `validate() -> PackedStringArray`): Schlüssel nach D2 4 (`sky, sea, kulisse, deck, props, lamps, fog, grade, light, particles, wet, front, special`) mit den Zahlen aus D2 3.1 und 4.2 als Ausgangswerte. Shader-Uniforms und der Kern von `fighter_lit.gdshader`: D2 6; Helligkeit der Figur läuft allein über `lit` (kein zusätzliches `bright`), das Uniform `flash` erhält `max(FigView.flash, Weißanteil aus FxPose.hit)`, `red` aus `FigView.red` bzw. dem Rotstich von `FxPose.hit`. `FighterNode` ruft für Trefferpose und Todesbilder die vorhandene `FxPose` (W1-07, Signaturen 3.7): `FxPose.hit(t, level, dir, k, frozen) -> {dx, tint, col, active, split}`, `FxPose.crumble/fall/sink(...)`; solange W1-07 nicht geliefert ist, Stub mit gleicher Signatur und einfachem Verhalten.

Verbindliche Eigenschaften: Alle Maße über `FightGeo`; Pixel gerundet (`roundf`); Kamera über `FightGeo.layer_xf` (alle Kulissen mindestens 480 px breit, Himmel/Meer −16..496); `Waves.storm` wird **nicht** geschrieben (`storm_override` an `SkyLayer/OceanLayer/RainLayer`); keine Schreibzugriffe auf `Voyage`/`Combat`; Eingaben nie (alle `Control` `IGNORE`); ohne Aufruf von `render` zeigt die Bühne Ruhe (Rückfall: alle Figuren `lit` 0,5).

### 3.6 Regie (W1-02): Director, Planner, Kamera, Cues

```gdscript
class_name FightDirector
extends RefCounted
enum Mode { FULL, SHORT }
signal cue(kind: String, data: Dictionary)
static var instances := 0
func _init(mode: int = Mode.FULL, manual_clock: bool = false) -> void
func begin(c: Combat) -> void        # Anfangszustand aus c (gezeigte Kraft/Reihen), Einleitung planen; prüft Ereignisfelder (fehlt `act`: push_error, busy() bleibt false)
func end() -> void                   # Warteschlange und Verweise leeren
func feed(c: Combat) -> void         # neue Ereignisse (id > gesehen) in Beats schneiden und planen (mehr als 24 frische: keine Beats, nur Endzustand)
func tick(real_dt: float) -> void
func pending_s() -> float            # echte Sekunden, die der Director noch braucht (Obergrenze von voy.combat_stage: 4,0)
func busy() -> bool
func set_selecting(valid_targets: Array) -> void   # leer = nicht am Wählen; sonst Kamera 1,0 in 140 ms, ungültige Ziele lit 0
func skip_intro() -> void
func stage_dt() -> float             # Bühnenzeit des letzten tick (für FightFx.tick, FightNumbers.tick)
func fig(f: Combat.Fighter) -> FightViews.FigView
func figs() -> Array                 # Zeichenreihenfolge, inkl. Sterbender
func camera() -> FightCam
func light() -> FightViews.LightState
func ui() -> FightViews.UiState
func debug_seek(ms: float) -> void   # nur manual_clock
static func synth_events(c: Combat, kind: String) -> Array   # für --beat=<kind>
```
```gdscript
class_name FightCam
extends RefCounted
var zoom := 1.0
var center_x := 240.0
var shake := Vector2.ZERO            # ganzzahlig, erst nach dem Runden der Fahrt addiert
func tick(dt: float) -> void
func go(zoom_want: float, center: float, dur: float, kind: int) -> void   # kind: CUBIC_OUT (Eintritt), SINE_IN_OUT (Wechsel/Lösen)
func add_shake(amp_px: float, dur: float, axis: Vector2, mul: float) -> void   # Trauma-Modell, 25 Hz, erste zwei Ausschläge entlang `axis`
static func limit_zoom(want: float, x_att: float, x_foc: float, head_top_y: float, fe: float) -> float   # D1 3 (z_h, z_v), floor auf 1/8, < 1,0625 → 1,0
```
`BeatPlanner` (nur statische Funktionen, zeichnet nichts): `classify(events, ctx) -> String` (Entscheidungstabelle D1 "Schnittstellen"), `plan(events, ctx, mode) -> Beat`, `real_length(b) -> float`; alle Zahlen in **einer** Konstante `T` (3.9) – das ist die Stellschraube für W3-B.

**Cue-Katalog (Director → Presenter), verbindlich.** Zeiten sind Bühnenzeit des Beats; `data` immer mit den genannten Schlüsseln:

| kind | data | wann | Verbraucher (Presenter ruft) |
|---|---|---|---|
| `go` | `who, sk, tgts: Array, contact_in: float, contacts: Array[float]` (Kontakt je Ziel ab jetzt, s) | Beginn des Ausholens (Beat 0) | `FightImpact.go(fx, ctx, sk, tgts)` (Wirkungen mit Wartezeit `contact_in − Vorlauf`), `Sfx.skill_sound(sk,"go")` |
| `impact` | `att, tgt, sk, n, level, crit, lethal, first, dir, hp0, hp1` | Kontakt eines Ziels | `FightImpact.hit(...)` (Items, Teilchen, Stern, Klangschichten), `FightStage.react` |
| `number` | `f, cls, text, at: Vector2` (Bühnenpunkt) | Kontakt + Standbild | `FightNumbers.add(cls, text, at, 0.0, k)` |
| `miss` | `att, tgt, sk` | Kontakt eines Fehlschlags | `FightImpact.miss(...)` |
| `heal` | `who, tgt, n (= hp1 − hp0), sk` | Wirkung | `FightImpact.go`-Teil `heal` am Ziel, Zahl grün |
| `die` | `f, kind, dir` | nach dem Standbild des tödlichen Treffers | `FightImpact` (Teilchen, Klang), `FightStage.react("die")` |
| `word` | `f, text, cls` | Ereignisse `text/heroic/snap/spawn/overboard` | `FightNumbers.add("word", text.to_upper(), ...)` |
| `sfx` | `name, db, pitch` | Director-eigene Klänge (`focus, slow_in, slow_out, deathblow, round_tick, flare, heartbeat, exhale`) | `Sfx.play(name, db, 0.0, pitch)` |
| `halo` | `pos, col, radius, dur` | Kontakt (Stufe aus 3.9) | `FightStage.pulse_light` |
| `mood` / `lamps` / `lightning` | `col, amount, dur` / `amount, dur` / `strength` | Stufe 3, 4, Heldenmut, Zusammenbruch, Kraken | `FightStage.mood / lamps_flare / lightning` |
| `stage_flash` | `col, a, dur` | nur Ausnahmen K8; höchstens 3 je Sekunde (Director zählt) | Presenter zeichnet Rechteck im Hud-Layer |
| `status_pop` | `f, name` | Kontakt, wenn sich der Zustands-Schnappschuss ändert | `FigView.status_pop` (Director schreibt selbst), Klang optional |
| `turn_pulse` / `round` | `f` / `n` | Beginn eines Beats / Rundenwechsel | `UiState` (Director schreibt selbst), `round_tick` |

Standbild, Zeitlupe, Wackeln, Zoom, Weißblitz am Ziel, Rückstoß-Auslösung, Fokusschild, Licht und Dimmung führt der Director **selbst** über `FigView`/`LightState`/`UiState`/`FightCam`; dafür gibt es keine Cues.

### 3.7 Wucht (W1-07)

Signaturen wie D3 "Schnittstellen" (`FxKinds`, `FxParticles`, `FxPose`, `FightFont`, `FightNumbers`, `FightImpact`, `FightMarks`), mit diesen **Festlegungen**: (a) `FightImpact.power(dmg, crit, lethal)` ist ein dünner Aufruf von `FightLevel.of(dmg, crit, lethal)`; (b) `FightImpact.plan(level, look, lod, strength)` liefert **nur** Wirkungswerte (`white, recoil, split, blood, spark, star, stage_s`), **nicht** Standbild/Wackeln/Zoom/Zeitlupe (die gehören dem Director und stehen in `BeatPlanner.T`); (c) `FightImpact.go(fx, ctx, sk, tgts, contact_in)` und `hit(fx, nums, ctx, sk, level, tgt, dmg)` werden **vom Presenter bei den Cues `go`/`impact`** gerufen, nicht aus `Hud._fight_events`; (d) `ctx` (Wörterbuch `hit, head, feet, src, hand, dir, k, tgts`) baut der Presenter aus `FightStage.anchor` und `FightGeo.fe()`; (e) `FightFx`: `particles`, `lod`, `shake_axis` (ungenutzt unter Director), `draw_under`, `show_banner(..., dur)`, Items-Grenze 120, `tick(delta)` mit Schalter `external_clock` (Director liefert Bühnenzeit, `freeze/slowmo/zoom` unter `external_clock` wirkungslos), `FEET` entfällt zugunsten `FightGeo.FEET`, Zeichenmethoden rechnen relativ zu `FEET` und Ankern (`_ink` u. a. nicht mehr fest 22..237 x 62..118); alte Arten bleiben unverändert (Rückfall, `lod 2`); (f) jede Id aus `FightFx.SKILL_FX` **und** aus `Roles.SKILLS` hat einen Eintrag in `FightImpact.LOOK`, jeder Wert steht in `LOOKS` (Test); (g) `FightNumbers.draw(ci, xf)` bekommt `FightGeo.layer_xf(1.0, ...)`; Zahlen nicht gezoomt, nicht gewackelt; (h) kein `randf` (eigener Zufallsgeber, Seed 7).

### 3.8 Oberfläche (W1-08): `FightUi` (statisch, bekommt das `Hud` übergeben wie `SlotView`)

```gdscript
class_name FightUi
extends RefCounted
static func options(c: Combat) -> Array[String]            # fs0..fs5 mit Leerplätzen; fs4 = "move", fs5 = "flee" fest
static func draw(h: Hud, st: Dictionary) -> void           # zeichnet Punkt 3 bis 5 der Hud-Reihenfolge (2.3) und trägt Klickflächen ein
# st: {c, views: Array, zoom, center_x, shake, ui: FightViews.UiState, fight_skill, fight_move, valid: Dictionary (Fighter->bool),
#      mouse: Vector2, chron_open: bool, hover: Dictionary, phase: "select"|"target"|"act"|"foe"|"done", flash: Dictionary}
static func hit_chron(h: Hud, p: Vector2) -> bool
```
`StatusIcons` (aus R5-Prototyp: `ORDER`, `draw`, `draw_big`, `draw_pop(h, pos, name, age)`), `Tips.fighter_card(...)`, `Tips.skill_help(...)` (Texte aus R5 5.2). Klickflächen werden mit `_register(FightGeo.rect_to_screen(...), id)` eingetragen, Reihenfolge: zuerst `fchronplatte` (falls offen), dann Ziele, Karten, Knöpfe. Sprache: nur Deutsch, echte Umlaute.

### 3.9 Verbindliche Zahlen

**Stufenleiter** (Stufe = `FightLevel`; Spalten 0 Streifer, 1 normal, 2 schwer ab 24, 3 Krit, 4 Todesstoß/letzter Gegner; Standbild in Echtzeit-ms, Rest Bühnenzeit):

| Kanal (Quelle) | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| Zoom-Wunsch (D1) | 1,0 | 1,125 | 1,125 | 1,25 | 1,375 (begrenzt, `limit_zoom`) |
| Standbild ms (D1/R4; Mann empfängt: normal 60) | 40 | 80 | 110 | 150 | 160 |
| weißer Frame ms, Abklingen 80 (D2) | 33 | 50 | 50 | 66 | 80 |
| Rotstich ms (D2) | 100 | 150 | 150 | 180 | 220 |
| Rückstoß px bei k=1 (×`fe`, gerundet), Quad Out 120 ms (D3) | 2 | 4 | 6 | 9 | 9 |
| Spalt-Versatz 2 px (D3) | – | – | ja | ja | ja |
| Wackeln px / ms, Trauma (D1/R4) | 1 / 120, 0,4 | 2 / 200, 0,6 | 3 / 260, 0,7 | 5 / 360, 0,85 | 6 / 500, 1,0 |
| Zeitlupe (D1) | – | – | – | 0,5 über 100 | 0,35 über 150 **vor** Kontakt, 0,3 über 130 danach |
| Halo Radius / ms (D2) | 26 / 160 | 34 / 200 | 42 / 220 | 54 / 260 Gold | 64 / 350 |
| Blut / Funken (D3) | 3 / 0 | 7 / 4 | 12 / 6 | 16 / 9 | 20 / 9 |
| Stern am Einschlag (D3) | – | n4 r9 | n6 r12 | n12 r22 + n12 r12 | wie 3 |
| Lampen / Ortsfarbe (D2) | – | – | – | +30 % 200 ms; Gold 0,18, 120 ms | +50 % 300 ms; Rot 0,25, 400 ms |
| Klangschichten (D3 7) | Basis | Basis + Material | + `hit_sub` | + `crit` + `clash` | + `deathblow`, `death` |

Mehrfachtreffer einer Aktion: Standbild, Wackeln, Zoom, Zeitlupe nur nach dem **ersten** (stärksten) Treffer; weitere Treffer Standbild ×0,7, nur weißer Frame, Rückstoß, Teilchen, Zahl. Dritte gleichartige Aktion in Folge: Nachwirkung −20 %, Teilchen/Wackeln ×0,8. Gegnertod klein/groß nach D1 2 (groß: erster Tod, jeder dritte weitere, Gefallener kann Heilen/Beschwören/Horn). Vollbildblitz nur nach K8.

**Licht je Rolle** (`FigView.lit`; Umrechnung aus D1: `lit = (Helligkeit − 0,55) / 0,45`; alle Werte Ausgangswerte, W3-A stimmt sie mit `lumcheck` ab):

| Rolle | Heldenzug | Gegnerzug | Auswahlphase |
|---|---|---|---|
| Handelnder | 1,0, Rand Gold `d9b24a` | 0,78, Rand `d2564b` 60 % | Mann am Zug 1,0, Rand Gold, Flackern |
| Ziel / Opfer | 0,78 (Hilfe 1,0, Rand Grün) | **Opfer 1,0** | gültige Ziele 0,9, ungültige 0,0, überfahrenes Halo |
| Unbeteiligte Männer | 0,0, `desat_add` 0,10 | 0,33 | 0,55 |
| Unbeteiligte Gegner | 0,0, `desat_add` 0,10 | 0,0 | 0,55 |
| `LightState.bg` | 0,80 | 0,78 | 0,92 (Ruhe 1,0) |
| `vignette` Zuschlag | +0,10 | +0,15 | 0 |

An=140 ms Cubic Out, Ab=160 ms Sine In Out. Kraken-Beat: Riese 1,0, alle übrigen 0,0. Sieg: alle Überlebenden 1,0, `bg` 1,0 in 400 ms; Niederlage: `desat_add` 0,6 und `bg` 0,5 in 1500 ms. Auftritt der Figur (Ausholen 3 px zurück, Ausfall 12 px in 50 ms, Halten ≥ 150 ms, Rückkehr 160 ms, Vortreten, 3 Nachbilder; alle Pixelmaße gelten bei `fe = 1,6` und werden sonst mit `fe / 1,6` multipliziert und gerundet): D1 5.

**Zeitleisten (Soll in Echtzeit-ms, Abnahme ±3 ms) und Zeitbudget** (D1 7 und 9; kurz = ×0,5 wo nichts anderes steht):

| Beat-Art | voll | kurz |
|---|---|---|
| `held_nahkampf` / `held_bogen` / `held_muskete` / `gegner_nahkampf` / `gegner_fern` / `hilfe_alle` | 900 | 450 |
| `hilfe_ziel` / `hilfe_selbst` / `fehlschlag` | 800 / 700 / 700 | 400 / 350 / 350 |
| `held_krit` / `gegner_krit` | 1250 | 600 |
| `flaeche_2` / `_3` / `_4` | 900 / 1020 / 1150 | 450 / 510 / 575 |
| `gegner_faellt_klein` / `_gross` | 950 / 1000 | 475 / 500 |
| `mann_faellt` / `mann_faellt_schwelle` / `letzter_gegner` | 1700 / 1721 / 1500 | 800 / 800 / 700 |
| `schwelle_erreicht` / `schwelle_haelt` | 1140 / 1300 | 600 / 650 |
| `heldenmut` / `zusammenbruch` | 1800 | 700 |
| `blutung`, `ausgesetzt`, `abwarten`, `platztausch`, `flucht` | 350, 600, 250, 360, 600 | halbiert |
| `beschwoeren`, `kraken_spannt`, `wuergegriff`, `ueber_bord`, `kraken_quetscht` | 1100, 1100, 1100, 1400, 1900 | 550, 550, 550, 700, 900 |
| `kampfbeginn` / `kraken_auftritt` | 1300 / 2600 | 500 / 1200 |
| `sieg` (Kraken) / `niederlage` / `rueckzug` | 1900 (2600) / 2000 / 1200 | 900 |

Budget: gewöhnlicher Treffer **+0 s** über den Takt; Beats über 900 ms nur für die Tabellenfälle; je Kampf Summe der Überlängen **≤ 6,0 s** (Test), im Mittel **≤ +0,5 s** gegenüber heute (D1 9 rechnet +0,2 bis +0,3 s); kein Beat über 2,6 s; Watchdog: Beat länger als das Doppelte seiner Soll-Dauer oder `pending_s() > 4,0` → Warteschlange leeren, Endzustand setzen, `push_warning`. Warteschlange: Aufholfaktor `1 + 0,25·(wartend − 1)`, höchstens 1,75; bei mehr als 6 wartenden entfallen `blutung, abwarten, platztausch, hilfe_selbst, ausgesetzt`. Kamera lösen 120 ms **nach** Beat-Ende, beginnt bis dahin ein neuer Beat: schwenken (140 ms Sine In Out), bei Brennpunkt < 8 px und Zoom < 0,04 Abstand nichts bewegen. Zoomgrenzen und Brennpunkt (60/40 Held, 35/65 Gegner), Fokusschild-Lage, Zielwahl-Zustand: D1 3.

### 3.10 Töne (W1-09): 15 neue Klänge, in `tools/make_sfx.py` **hinter `slot_stack`** angehängt (bestehende Klänge bleiben bitgleich), 44,1 kHz, mono, 16 Bit, `GAIN`-Eintrag je Klang, `sfxtest.gd` zählt 63 → 78

| Datei | Dauer | `GAIN` dB | Einsatz | Rezept |
|---|---|---|---|---|
| `focus` | 0,16 s | −12 | Fokus-Eintritt, Schild gleitet ein | D1 |
| `deathblow` | 0,70 s | −3 | Stufe 4, immer gleich | D1 |
| `slow_in` / `slow_out` | 0,25 s | −8 / −10 | Zeitlupe ein/aus | D1 |
| `round_tick` | 0,09 s | −14 | Rundenwechsel | D1 |
| `flare` | 0,45 s | −9 | Lampen-Aufflackern (Stufe 3, 4, Heldenmut) | D2 |
| `whoosh` | 0,28 s | −9 | Ansturm, Rückzugsschuss | D3 |
| `crit` | 0,80 s | −3 | Krit und Todesstoß | D3 |
| `hit_wet` / `hit_bone` / `hit_ring` | 0,30 / 0,25 / 0,30 s | −9 / −9 / −10 | Materialschicht Fleisch / Knochen / Metall | D3 |
| `hit_sub` | 0,50 s | −6 | Stufe ≥ 2 | D3 |
| `crumble` | 0,70 s | −6 | Zerfall (Knochen) | D3 |
| `lock` | 0,18 s | −9 | Fadenkreuz rastet ein | D3 |
| `exhale` | 0,60 s | −8 | Widerstand an der Schwelle | D3 |

Regeln: je Kontakt höchstens 4 Klänge aus verschiedenen Dateien (`MIN_GAP` 0,12 s greift nicht gegeneinander), höchstens 6 gleichzeitig je Beat; Treffer-Tonhöhe ±3 % gestreut, in Zeitlupe (Faktor < 0,6) 0,75 bis 0,8; Herzschlag ist `heartbeat` mit Tonhöhe 0,85 (kein neuer Klang). Alle Klänge hängen an der Bühnenzeit (Director-Cues), nicht an `create_timer`. Hören kann kein Helfer: Pegel konservativ, Abnahme durch den Besitzer (Einstellung "Effekte lauter/leiser" wirkt wie bisher).

### 3.11 Einstellungen, Flags, Dateiformate

* **Einstellungen** (`Settings`, W1-01; Zeilen in der Einstellungsansicht baut W2-01): "Kampfansicht: voll / kurz", "Wackeln und Blitze: aus / schwach / normal", "Kampfbild: voll / schlicht".
* **Screenshot-Flags** (W2-01 baut alle in `main.gd`; Block der `_shot_*`-Variablen; alte Flags bleiben): `--seed=N`, `--shotform=draugr|raeuber|haendler|dorf|kraken`, `--beat=<art>:<ms>[,fast][,noshake]` (Arten: `melee bow musket heal miss crit area2 area4 foe foecrit kill killbig herodie herodoor lastfoe door resist heroic snap kraken spannt crush grab bord intro intro_kraken win lose bleed`; `FightDirector.synth_events` + `debug_seek`, manuelle Uhr), `--stage=<nofog,noglow,nograde,nospot,norim,noshadow,zoom:x,lightning,timing>`, `--shotclock=<s>`, `--nointro`, `--clicktest`, `--winsize=WxH`, `--oldfight`, `--norig`, `--fxsheet=a|b|c|d|e` (Wucht-Prüfstand), `--hovermouse=x,y`. Jeder Foto-Lauf schreibt eine Zeile `STAGE Messung: Zeichenaufrufe=... Primitive=... Objekte=...` (aus `Performance.RENDER_TOTAL_*`).
* **Foto-Ablauf:** `tools\dev\shot.ps1 -Out C:\...\x.png -Sec 1 -Flags "--seed=3 --beat=melee:330"`; `Sec` ist ungenau (erstes Bild lädt Texturen), darum bei `--beat` Zeit über `debug_seek`.
* **Dateiformate:** Streifen/JSON 3.3, Atlanten 3.4, Schrift `assets/fight_font.png` 329x27 (47 Glyphen zu 7x9, Zeilen Körper/Rand/untere Hälfte, D3 4), Zustandssymbole `assets/status_icons.png` 108x9 (12 Symbole zu 9x9, Reihenfolge `StatusIcons.ORDER` nach R5 3.1).

---

## 4. Wellen und Aufgabenkarten

**Ablauf:** Welle 1a (alle Karten W1-xx gleichzeitig, voneinander unabhängig) → Welle 1b (Gegner-Rig, braucht nur die gelieferte `rig_core.py` von W1-05) → Welle 2 (genau ein Besitzer baut ein) → Welle 3 (Feinschliff und unabhängige Prüfung, Besitzer disjunkter Dateien). Lieferungen gehen sofort ins Hauptprojekt (`deliver.ps1`), sobald die Akzeptanz der Karte grün ist; `.uid` und `.import` werden **nicht** mitgeliefert (entstehen bei `rungd.ps1 -Script import` in W2-01 S1).

**Tore:** **G0** vor Welle 1: W1-01 schreibt als Erstes `docs/kampf_spektakel/BASELINE.md` (selftest, sfxtest, musictest, `evhash`, `evtime`, `runbots` Gesamtzeit und Fehlerzeilen, `STAGE Messung` von `--shotfight2`/`--shotfx2`/`--shotkraken2` des heutigen Spiels) – alle späteren Vergleiche beziehen sich darauf. **G1** Ende Welle 1a: alle Karten W1-01 bis W1-09 geliefert, jeweilige Akzeptanz grün. **G2** Mitte W2-01 (nach Schritt S4): **Vorführstand** (neue Bühne, Licht, Regie, Wucht, Oberfläche mit Gerüst-Figuren) – hier würde der Besitzer zum ersten Mal urteilen; Pflicht-Prüfungen grün. **G3** Rig-Tor: alle Streifen vorhanden und W3-C-Abnahme. **G4** Endabnahme W3-F.

**Reihenfolge nach Wirkung je Aufwand** (falls Zeit knapp wird, in dieser Reihenfolge streichen von hinten): Licht/Bühne/Ort ▸ Regie (Beats, Kamera, Fokusschild) ▸ Wucht ▸ Oberfläche ▸ Rig ▸ Atmosphäre/Partikel ▸ Dorf-Panorama und Kraken-Vordergrund ▸ Schmuck (Nachbilder, Spiegelung, geworfene Schatten).

Jede Karte nennt: Sandbox, Besitzer-Dateien (exklusiv), Eingaben, Ausgaben, Schnittstelle, Akzeptanz, Testbefehle, Beweisbilder, Rückfall. "T" = Testbefehl (aus der Sandbox: `tools\dev\rungd.ps1 -Script tools/<x>.gd -Tail 300 -Timeout 600`), "S" = Foto (`tools\dev\shot.ps1 ...`).

### Welle 1a (parallel, voneinander unabhängig)

#### W1-01 Fundament: Ereignisfelder, Takt, Einstellungen, Verträge, Prüfwerkzeuge (Sandbox `w101`, ≈ 1,5 Tage)
* **Besitzer-Dateien:** `scripts/combat.gd`, `voyage.gd`, `settings.gd`, `fight_geo.gd`, `fight_level.gd`, `fight_views.gd`; `tools/evhash.gd`, `tools/evtime.gd` (aus `R1_werkzeuge/*.gd.txt`), `tools/eventtest.gd`, `tools/dev/lumcheck.py`, `tools/dev/fighttests.ps1`, `tools/dev/contactsheet.py`; `docs/kampf_spektakel/BASELINE.md`.
* **Eingaben:** R1 3.4/3.5/4.4 und `R1_combat_ereignisfelder.diff.txt`; SPEC 3.1, 3.2.
* **Ausgaben:** (1) erst `BASELINE.md`; (2) Diff eingespielt (Kommentar an `events` um `heroic`/`snap` und neue Felder nachführen); (3) `stage_t`/`combat_stage`/`_tick_combat`; (4) drei Settings mit Laden/Speichern; (5) die drei Vertragsdateien **wortgleich aus 3.2**; (6) `lumcheck.py <bild> x,y,w,h ...` (PNG-Leser ohne Bibliothek, skaliert Rechtecke mit Bildbreite/480, gibt mittlere Helligkeit und mittleres RGB je Rechteck; Modus `--strips` misst Streifenbreiten wie `R3_laufweiten.py`); `contactsheet.py <bilder...> -o out.png` (nebeneinander/untereinander, mit Beschriftung der Dateinamen, zum Beurteilen von Bewegungsfolgen); `fighttests.ps1` (ruft `selftest`, `sfxtest`, `musictest`, `eventtest`, `directortest`, `stagetest`, `fxtest`, `uitest`, soweit vorhanden, fasst die `FEHLER:`-Zeilen zusammen, Exit-Code ≠ 0 bei Fehlern).
* **Akzeptanz:** Logik-Prüfsumme `evhash` **3356533480** unverändert (vorher/nachher gemessen); `selftest` `FEHLER: 0`, `sfxtest`, `musictest` ebenso; `evtime` höchstens +15 %; `eventtest`: 200 Kämpfe (5 Aufstellungen x 40, feste Seeds): jedes Ereignis hat `act`, `by` (außer Blutung/Rundenwechsel), `rank`, `round`; `act` lückenlos und nichtfallend; jedes `hit` hat `hp0 >= hp1`, `hp1 == hp0 − n` außer an der Schwelle, `lethal` ⇔ folgt `die` desselben Ziels; je Handlung genau ein `turn` am Ende; `tgts` bei jedem `attack` gesetzt; `FightLevel.of(5,false,false)==GRAZE`, `(10,..)==NORMAL`, `(24,..)==HEAVY`, `(3,true,false)==CRIT`, `(3,true,true)==KILL`, Blutung GRAZE; `FightGeo`: `to_screen(p,1,240)` ohne Shake gleich `p` auf ±0,5 px, `rect_to_screen` einer Figur bei Zoom 1,5 enthält deren Fußpunkt, `layer_xf(d)` deckt für d ∈ {0,05..1,45}, Zoom ≤ 1,375 und `center_x` ∈ [240/z, 480−240/z] das Rechteck 0..480 (Test mit Kulissenbreite 480); `stage_t`: bei `auto_combat` bleibt `stage_t` 0 und `combat_stage(5)` wirkungslos; `combat_stage(99)` → 4,0; `_tick_combat` ruft `act_foe` bei `stage_t > 0` nicht, im Zweig `done` erst nach `stage_t`; `combat_act` löscht `stage_t` nicht; der bestehende Test `t3_o` bleibt grün.
* **Rückfall:** Settings-Standardwerte 0/2/1; ohne Director bleibt `stage_t` 0 (Verhalten wie heute).

#### W1-02 Regie: BeatPlanner, FightCam, FightDirector (Sandbox `w102`, ≈ 5,5 Tage)
* **Besitzer-Dateien:** `scripts/beat_planner.gd`, `fight_cam.gd`, `fight_director.gd`; `tools/directortest.gd`, `tools/dev/beat_timelines.py` (aus `D1_zeitleisten.py`, schreibt `docs/kampf_spektakel/img/D1_zeitleisten.svg`).
* **Eingaben:** D1 vollständig; SPEC 3.1 (Diff in der Sandbox **einspielen, nicht liefern**), 3.2 (Stubs), 3.6, 3.9.
* **Ausgaben:** drei Klassen nach 3.6; `BeatPlanner.T` (alle Zahlen aus 3.9 an **einer** Stelle, auch `lit`/`bg`/`vignette` je Rolle); `synth_events(c, kind)` für alle `--beat`-Arten; Zugleisten-Rechner `real_length`; `directortest.gd`.
* **Schnittstelle:** Cue-Katalog 3.6 (Schlüssel exakt wie dort); `FigView`-Felder nach 3.2; keine Abhängigkeit von `FightStage`, `FightImpact`, `FightUi`, `Hud`, `Sfx` (Cues statt Aufrufen); `FightImpact.death_kind/material` dürfen **nicht** gerufen werden (Director bekommt `death_kind` aus einer eigenen kleinen Tabelle in `BeatPlanner`, gleichlautend mit D3 6: `knochen, rost, bogner, totenwart, waechter, priester, beschwoerer → crumble`; `tentakel → sink`; `kraken → kraken`; sonst `fall`).
* **Akzeptanz (D1 T1 bis T9, mit den Zahlen aus 3.9):** T1 `real_length` jeder Beat-Art ±3 ms gegen die Tabelle (voll und kurz); T2 simulierte Uhr (16,7-ms-Schritte) bis `pending_s() == 0` weicht ≤ 40 ms ab; T3 Invarianten (Standbild ≤ 160 ms, ≤ 3 `stage_flash` je Sekunde, Zoom ∈ Vielfachen von 1/8 und ≤ `limit_zoom`, Modus kurz immer 1,0, `center_x` ∈ [240/z, 480−240/z], Cue-Zeiten innerhalb Beat + 100 ms, `lit` je Rolle gleich Tabelle 3.9, Bühnenzeit-Faktor 0,05 im Standbild); T4 400 echte Kämpfe aus `Combat` (auto_play mit Mitschnitt der Ereignisse): jede Handlung genau ein Beat, `shown_hp == hp` und `shown_rank == rank` am Ende, kein Beat > 2,6 s, **Summe der Überlängen je Kampf ≤ 6,0 s** (Mittel und Maximum berichten), gewöhnlicher Treffer exakt 900 ms; T5 Takt mit dem `Voyage` aus W1-01 (oder die Änderung 3.1 in der eigenen Sandbox angewendet): `act_foe` nie früher als `max(COMBAT_PACE, Beat-Ende)`; T6 Watchdog (angehaltene Uhr → nach doppelter Soll-Dauer leer, `stage_t` 0, Warnung; `combat_stage(99)` → 4,0); T7 Warteschlange (7 Beats: kleine Arten fallen weg, Faktor ≤ 1,75; 30 frische Ereignisse: keine Beats, nur Endzustand); T8 Fallback fehlende Felder: `begin()` mit altem Ereignisformat → `busy()` false, keine Cues, kein Fehler; T9 `tick` im Mittel < 0,3 ms, `feed` < 1 ms (1000 Bilder `held_krit`); T10 `FightDirector.instances == 0` nach 100 Schnellmodus-Kämpfen (Voyage baut keinen); T11 `set_selecting`: Zoom 1,0 in ≤ 160 ms, ungültige Ziele `lit` 0; T12 Fall-Reihenfolge: Beat `heldenmut`/`zusammenbruch` hängt hinter dem auslösenden Beat; Beat `blutung` gehört dem nächsten Akteur.
* **Testbefehle:** T `tools/directortest.gd` (Parameter `--budget` für T4 mit allen 400 Kämpfen), T `tools/eventtest.gd`, `python -X utf8 -I tools/dev/beat_timelines.py`.
* **Beweisbilder:** `docs/kampf_spektakel/img/D1_zeitleisten.svg` neu erzeugt (Summen 0 Abweichungen); optional Textprotokoll `W1-02_beat_<art>.txt` (FigView/Kamera/Licht alle 50 ms) für `melee`, `crit`, `foe`, `herodie`, `lastfoe`.
* **Rückfall:** siehe T8 und Watchdog; `pending_s()` ist nie größer als 4,0.

#### W1-03 Bühne: FightStage, FighterNode, FigArt, Shader, Themen (Sandbox `w103`, ≈ 7 Tage)
* **Besitzer-Dateien:** `scripts/fight_stage.gd`, `fighter_node.gd`, `stage_light.gd`, `stage_particles.gd`, `stage_themes.gd`, `fig_art.gd`, `sky_layer.gd`, `ocean_layer.gd`, `rain_layer.gd`, optional `stage_sheet.gd` (Prüfstand, nur per Flag); `shaders/stage_grade.gdshader`, `stage_fog.gdshader`, `fighter_lit.gdshader`, `sky.gdshader`, `ocean.gdshader`; `tools/stagetest.gd`.
* **Eingaben:** D2 (alles), R3 (Prototyp in `_sandbox\buehne`, Shader in `_sandbox\bild\shaders`), SPEC 2.3, 3.2 bis 3.5; `StageAtlas`/`StageAtlasBig` als Stub mit denselben Schlüsseln (leere Rechtecke, `has()` false → nichts zeichnen); `FxPose` aus `_sandbox\wucht\scripts\fx_pose.gd` kopieren (nicht liefern) oder Stub; Figuren: alter Atlas als 2x-Gerüst, Rig-Streifen sobald vorhanden.
* **Reihenfolge (Spikes zuerst, jeder mit Foto):** (1) **ein** `FighterNode` mit `fighter_lit` in der Engine: Randlicht auch gespiegelt (`flip`/negative Breite), 2-px-Rand, Region im Atlas, `flash`, `outline` (D2 B3); (2) Zoom 1,125/1,25/1,375/1,5/2,0 mit `layer_xf`: Streifenbreiten gleichmäßig (`lumcheck --strips`, A9; bei ungleichen Breiten Stufen weiter runden, Befund melden); (3) Z9 als einziger Leser von `hint_screen_texture`; (4) alle Schichten Z0 bis Z17 mit Platzhalterkunst; (5) fünf Themen aus `StageThemes`; (6) Partikel, Nebel (`fade_bottom`), Lampen, Pfützen, Schatten, Spiegelung, Nachbilder.
* **Ausgaben:** `FightStage` nach 3.5; `FigArt` (`FRAMES`, `init()`, `missing()`, `id_of(f)`, `has_rig(id)`, `sheet(id)`, `frame(id, name)`, `anchor(id, name, which)`, `portrait(id) -> {tex, src}`, `prewarm(ids)`; Gerüst-Tabelle 3.3); `StageThemes.validate()`; `storm_override`/`tone_mul`; Welt-Shader mit Standardwerten, die das Weltbild **byte-gleich** lassen; `FightGeo.rig` wird von `FigArt.init()` gesetzt.
* **Akzeptanz (D2 K1 bis K17, angepasst):** K1 Tests/Bots unverändert; K2 Kartenfoto (`--seed=3` ohne Kampf) vor/nach byte-gleich; K3 `stagetest.gd` (headless): `StageThemes.validate()` leer, jede Formation aus `Foes.FORMATIONS` hat ein Thema, `FigArt.frame` liefert für jede Pose und jeden Schlüssel eine gültige Spalte, `FigArt.missing()` nennt fehlende Streifen; K4 100 Schnellmodus-Kämpfe: `FightStage.instances == 0`, keine Textur/kein Shader geladen; K6 fünf Orte per Foto unterscheidbar (Himmel/Segel-Rechteck mit `lumcheck`: Draugr `G > R + 12`, Räuber `R > B + 25`, Händler `B > R + 10`, Dorf `R > B + 30` und `R > G`, Kraken < 0,6 x Händler-Helligkeit); K7 Handelnder ≥ 1,35 x Mann in Reihe 4, ohne Spot < 1,15; K8 Randlicht nur 1 px an der Kontur (≥ 25 Pixel, ≤ 18 % je Figur); K9 Zeichenaufrufe ≤ 340 allein für die Bühne (Gesamtbudget 420 gilt in W2), Primitive ≤ 6000; K10 `--clicktest` bei Zoom 1,0 und 1,5 (Klickfläche über `FightGeo.rect_to_screen`), alle `Control` der Bühne `IGNORE` (Test durchläuft den Baum); K12 geworfener Schatten sichtbar oder Rückfall Kontaktschatten (kein Fehler); K13 Zoom 1,5/2,0: Streifen 9/9/9 bzw. 12/12/12, Plaketten-Zeile gleich; K14 Draugr: Gegner ≥ 1,25 x Hintergrund; K15 Kraken: Regen sichtbar, Blitzfläche hebt Himmel ≥ 40 %, Riese Sohle y 164 ± 1; K16 `Settings.stage_fx = 0`: keine Partikel/Nebel, Aufrufe ≤ 220; K17 `--shotclock=2.0` zweimal byte-gleich. Zusätzlich: Pixel von Himmel/Meer/Deck/Figuren haben **eine** Pixelgröße (Sichtprüfung am 6x-Foto).
* **Testbefehle:** T `stagetest.gd`; S je Ort `--seed=3 --shotform=<f> --stage=...` (Prüfstand der Sandbox mit synthetischen `FigView`s: Ruhe, Auswahl, Handelnder links gegen Ziel rechts, Gegnerzug, Krit-Moment, Tod).
* **Beweisbilder:** `W1-03_<ort>_ruhe.png`, `_aktion.png` (5 Orte x 2), `W1-03_zoom_1125|125|1375|2.png`, `W1-03_rim_flip.png`, `W1-03_schlicht.png`.
* **Rückfall:** Shader-Kompilierfehler → `push_error`, Z9/Z15 ausgeblenden, Figuren ohne Material (nur `modulate`); fehlender Atlasschlüssel → Requisite weglassen; fehlender Streifen → Gerüst; `stage_fx = 0` → schlicht; `FightStage` nie gebaut in Schnellmodus/Headless.

#### W1-04a Kulissenbilder A: Deck, Requisiten, Lampen, eigenes Schiff, Ferne, Himmelszutaten (Sandbox `w104a`, ≈ 3,5 Tage)
* **Besitzer-Dateien:** `tools/make_stage_art.py`; `assets/stage_deck.png` (240x444: 6 Kacheln 240x74), `stage_props.png` (384x160), `stage_lamps.png` (256x64), `stage_own.png` (192x136), `stage_far.png` (320x48), `stage_sky_extra.png` (256x32); `scripts/stage_atlas.gd` (vom Skript erzeugt, `StageAtlas` nach 3.4).
* **Eingaben:** D2 "Erzeugte Bilder" Nr. 1 bis 6 und 11, R3 6.2, 5.3; `tools/make_art.py` (`Img`), Palette von `ship.png`, `enemies.png`, `combat.png` (Farben ziehen, nichts neu erfinden); Aufruf `python -X utf8 -I tools/make_stage_art.py` (Skript setzt `sys.path` selbst).
* **Reihenfolge nach Wirkung:** Laternen/Fackeln/Flammen/Irrlichter, Deck (6 Kacheln), Requisiten (alle Schlüssel 3.4), eigenes Schiff, Ferne, Himmelszutaten.
* **Akzeptanz:** alle Schlüssel aus 3.4 (`StageAtlas`) vorhanden, `has()` für jeden wahr, Rechtecke innerhalb der Datei; `rungd import` ohne Fehler; Skript zweimal gelaufen ergibt byteweise gleiche Dateien; nichts skaliert (eine Pixelgröße), kein Bild beschneidet seinen Gegenstand (Rand ≥ 1 px bei Leuchtquellen); Deckkacheln nahtlos nebeneinander und untereinander in der Höhe 73 (Naht alle 69 px, je Reihe um 23 versetzt); Laternenvarianten in den vier Ortsfarben; **jedes Bild angesehen** (Vorschaublatt 3x mit Beschriftung).
* **Beweisbilder:** `W1-04a_vorschau.png` (alle Atlanten 3x), `W1-04a_deck.png` (6 Kacheln nebeneinander auf dunklem und hellem Grund).
* **Rückfall:** fehlt ein Bild, lässt `FightStage` die Schicht weg (Atlas `has()`).

#### W1-04b Kulissenbilder B: Gegnerschiffe, Dorf, Kraken-Vordergrund, Vordergründe (Sandbox `w104b`, ≈ 4 Tage)
* **Besitzer-Dateien:** `tools/make_stage_art2.py`; `assets/stage_foe_draugr.png`, `stage_foe_raeuber.png`, `stage_foe_haendler.png` (je 192x136), `stage_village.png` (560x112), `stage_kraken_front.png` (384x168), `stage_splash.png` (192x24), `stage_front_draugr|raeuber|haendler|dorf|kraken.png` (je 576x215); `scripts/stage_atlas_big.gd` (erzeugt, `StageAtlasBig`).
* **Eingaben:** D2 "Erzeugte Bilder" Nr. 4, 7 bis 10, R3 5.3 (Plan je Kampfort), `tools/make_enemies.py` (Stil der vorhandenen Gegnerschiffe), `Img`.
* **Akzeptanz:** wie W1-04a; zusätzlich: Gegnerschiffe in **Zielgröße** gezeichnet (Anker unten Mitte (96,136)), Segel/Rumpf unterscheiden die Orte ohne Beschriftung (Geisterschiff zerlumpt grünlich, schwarz-rote Räuber mit Rammsporn, blau-gelbe Kogge, Dorfhang mit Häusern/Steg/Bäumen, Fensterlisten in `WINDOWS`); Vordergründe durchsichtig mit dunklen Silhouetten (nie abgestuft) und lassen den Kampfbereich (x 24..456, y 70..175) frei; Kraken-Fangarme 2 Frames; Spritzer 4 Frames.
* **Beweisbilder:** `W1-04b_vorschau.png`, `W1-04b_orte_montage.png` (die fünf Orte als Montage aus Himmel + Schiff + Vordergrund auf Deckkachel, mit `contactsheet.py`).
* **Rückfall:** wie W1-04a.

#### W1-05 Rig-Kern, Waffen/Köpfe, fünf Männer (Sandbox `w105`, ≈ 4,5 Tage)
* **Besitzer-Dateien:** `tools/rig_core.py`, `tools/make_fig_rig.py`, `assets/fig/schild.png|json`, `axt`, `bogen`, `skalde`, `muskete`.
* **Eingaben:** R2 5 (alles) und `R2_rig_proto.py` (Ausgangspunkt), 3.3; Prüfliste R2 5.8 und die Mängel R2 5.9 (dünne Waffen, Hände als Scheiben, Gesichter aus zwei Punkten, immer breiter Stand, kein Stoffspiel).
* **Ausgaben:** (1) Kern mit 31 Posen, Haltungsklassen `melee, shield, bow, gun, staff`, Waffenbibliothek (**alle 17**: Schwert, Rostschwert, Axt, Keule, Stab, Bogen, Muskete, Schild, Speer mit Schild, Hammer, Heugabel, zwei Messer, Haken, Armbrust, Horn, Korb, Beutel) und Kopfformen (**alle 13**: u. a. Kappe, Stirnband, Strohhut, Pelzmütze, Dreispitz, Kapuze mit Geweih, Nasalhelm); **Erweiterungspunkte** `register_weapon(name, fn)`, `register_head(name, fn)` und `spec(...)` für Beschreibungen, damit W1b-Karten ohne Eingriff in den Kern arbeiten; (2) Ausgabe 116x108-Streifen und `<id>.json` (Hand, Waffenspitze, Brust, Kopf je Pose); (3) CLI `python -X utf8 -I tools/make_fig_rig.py [<id>...|--all|--sheet <ordner>|--stats|--check]`; Gegnerspezifikationen werden aus `tools/rig_foes_*.py` geladen, **falls vorhanden**; (4) die fünf Männer, Beschreibungen aus `make_combat_art.py`.
* **Akzeptanz:** je Figur 32 Spalten (31 Posen + `grab`), **kein Frame am Zellrand** (`--check` meldet `CLIP`), Sohle in Zeile 101 in allen Posen außer Sturz/Liegen, jede Pose silhouettenmäßig vom Stehen unterscheidbar (Kontaktblatt R2-Art), Rollen erkennbar (Schild blau/Kettenhemd, Axt rot/Bart, Bogen Kapuze/Köcher, Skalde Robe/Stab mit Goldkugel, Muskete Dreispitz); Waffen mindestens 3 px dick; Gesicht mehr als zwei Punkte (Augen, Brauen, Bart/Nase wo passend); gespiegelt angesehen (Schild/Beutel vorn); Kettenmuster flimmert bei 1x nicht; Lauf aller fünf in < 10 s, deterministisch (byte-gleich); `<id>.json` vollständig; Kern liest `tools/rig_foes_*.py` und `tools/rig_ext_*.py`, wenn vorhanden.
* **Gate R (früher Zwischenstand, nach ≈ 1 Tag):** Kontaktblatt der fünf Männer (11 Kernposen) neben den alten Figuren und auf einer Platzhalterbühne bei 1x und 2x; Selbsturteil im Bericht; ist die Qualität **schlechter als die alten Figuren** (R2 5.9 ungelöst), gilt: Haltung/Waffen/Gesichter zuerst nachbessern, bevor Gegner gebaut werden (W1b startet erst nach "Gate R bestanden" im Bericht).
* **Beweisbilder:** `W1-05_maenner_kernposen.png`, `W1-05_schild_alle31.png`, `W1-05_vergleich_alt_neu.png`, `W1-05_buehne_1x.png`, `_2x.png`.
* **Rückfall:** `FightGeo.rig` bleibt false, solange eine Datei fehlt; alte Figuren laufen weiter.

#### W1-06 Tierfiguren: Hund, Fangarm, Kraken-Zusatzposen (Sandbox `w106`, ≈ 2 Tage)
* **Besitzer-Dateien:** `tools/make_fig_tier.py`; `assets/fig/hund.png|json`, `assets/fig/tentakel.png|json`, `assets/kraken_ex.png` (264x88, 3 Zellen: Hochreißen, Zuschlagen, Sinken).
* **Eingaben:** `tools/make_combat_art.py` (Zeichnung von Hund, Fangarm), `make_kraken` (Quelle von `kraken.png`), R2 4 (Weg C Stufe 3), D2 5.1; Streifenformat 3.3.
* **Ausgaben:** Hund 14 Spalten (Stehen, Bereit, Ausholen/Sprung, Zuschlagen/Biss, Nachschwung, Treffer, Jaulen, Fallen, Liegen ...), Fangarm 12 Spalten (Peitschen-Ausholen, Zuschlagen, Wellen-Stehen, Treffer, Sinken); alte Zeichnung **1:1** in 116x108-Zellen umgerastert (keine Skalierung), Rest der Spalten leer; Anker-JSON.
* **Akzeptanz:** alle belegten Spalten ohne Beschnitt, Fußlinie Zeile 101; `FigArt.frame` löst alle 32 Namen gültig auf (Rückfalltabelle 3.3); Kraken-Zusatzzellen 88x88 im Stil von `kraken.png`; Kontaktblätter angesehen (Hund hebt sich in Sprung/Treffer deutlich vom Stehen ab, Fangarm-Ausholen lesbar); Skript deterministisch.
* **Beweisbilder:** `W1-06_hund.png`, `_fangarm.png`, `_kraken_ex.png`, `_gemischt_mit_rig.png` (neben einem Rig-Mann aus `_sandbox\figuren\assets\rig_proto.png` oder W1-05).
* **Rückfall:** fehlen die Tierstreifen, bleibt `FightGeo.rig` false (Gerüst).

#### W1-07 Wucht: Wirkungsbilder, Teilchen, Trefferpose, Schrift, Zahlen, Marken (Sandbox `w107`, ≈ 5,5 Tage)
* **Besitzer-Dateien:** `scripts/fx_kinds.gd`, `fx_particles.gd`, `fx_pose.gd`, `fight_font.gd`, `fight_numbers.gd`, `fight_impact.gd`, `fight_marks.gd`, `fight_fx.gd`, `fx_sheet.gd`; `tools/make_fight_font.py`, `assets/fight_font.png`, `tools/fxtest.gd`.
* **Eingaben:** D3 (alles); fertige Teile in `_sandbox\wucht` (`fx_kinds.gd` 506 Zeilen, `fx_particles.gd`, `fx_pose.gd`, `fight_font.gd`, `proto_wucht.gd`) und `D3_make_fight_font.py` als Ausgangspunkt; SPEC 3.7, 3.9 (Stufen), K7, K10, K11, K19.
* **Ausgaben:** alle Klassen nach D3 mit den Festlegungen aus 3.7; `FightImpact.LOOK/LOOKS` für **jede** Fertigkeit; `FightFx`-Änderungen (3.7 e); `FightMarks.draw_edge/draw_target/draw_area_marks/draw_status_body` (Statuskörperzeichen laufen nach `FigView.status`, nicht nach Hud-Zustand); Prüfstand `fx_sheet.gd` (`--fxsheet=a|b|c|d|e`); alle Maße **mit `k` skaliert** (`k = 1,0`, `1,6`, `2,0` geprüft).
* **Änderungen gegenüber D3, die einzuarbeiten sind:** Stufentabelle nach 3.9 (Standbild/Wackeln/Zoom/Zeitlupe kommen **nicht** aus `plan`); `FightAnim` entfällt; Heilsäule Alpha 1,0; Krit-Stern r 22/12; "KRITISCH!" über dem Kopf, Zahl auf Brusthöhe; Tinte mit hellviolettem Rand; kein `randf` (Seed 7); Teilchen-Obergrenze 160 + 40 Flecken, Items-Grenze 120.
* **Akzeptanz:** D3 A1 bis A12 (ohne die Punkte zu `FightAnim`; `power`-Tests laufen über `FightLevel`) und B13 bis B17 am Prüfstand für `k ∈ {1,6; 2,0}`; jede Id aus `Roles.SKILLS` hat `LOOK` (Test); `FightFont.width("KRITISCH!", 2) == 106`; `FightFont.texture()` headless `null` ohne Absturz; `FightNumbers` nur Anzeigezeit, headless `add/tick` ok; **Aufrufe je Wirkung** (D3 8) gemessen, schlimmster Fall (Kraken-Quetschen auf vier Männer + Krit) ≤ 230 Aufrufe der Wirkungen; Lesbarkeit der Zahlen auf Himmelsblau, Holzbraun, Nebelgrün (Foto je Grund).
* **Testbefehle:** T `tools/fxtest.gd`; S `--fxsheet=a|b|c|d|e` (Prüfstand der Sandbox, Zeitpunkte wie `D3_blatt_*`); `python -X utf8 -I tools/make_fight_font.py --preview <datei>`.
* **Beweisbilder:** `W1-07_sheet_a|b|c|d|e.png` bei `k = 1,6`, `W1-07_zahlenklassen.png`, `W1-07_font.png`, `W1-07_tod_<gruppe>.png`, `W1-07_k20.png`.
* **Rückfall:** `FightFx.lod` 1/2; unbekannte Wirkungsart → alte Art (`FxKinds.draw` liefert `false`); fehlende Schrift → Zahlen mit Standardschrift.

#### W1-08 Oberfläche: Layout, Schilder, Zugleiste, Leiste, Fokusschild, Statussymbole (Sandbox `w108`, ≈ 2,5 Tage)
* **Besitzer-Dateien:** `scripts/fight_ui.gd`, `status_icons.gd`, `tips.gd`; `tools/make_status_icons.py`, `assets/status_icons.png`; `tools/uitest.gd`.
* **Eingaben:** R5 (alles; Entwurf als Diff `R5_proto_hud.diff.txt`/`R5_proto_main.diff.txt`/`R5_proto_fight_fx.diff.txt` und in `_sandbox\oberflaeche`), `R5_statussymbole.py`, `R5_proto_status_icons.gd.txt`, SPEC 2.4, 3.8, `FightViews` (3.2).
* **Ausgaben:** der R5-Entwurf **aus `hud.gd` herausgelöst** in `FightUi` (Funktionen bekommen das `Hud`; Zustand kommt aus `st`), `StatusIcons`, `Tips.fighter_card`, `Tips.skill_help`, `options(c)` mit festen Plätzen 5 und 6; Statussymbole zwölf; Kopfzeile, Zugleiste mit Porträts (`FigArt.portrait`, Rückfall R5-Rechteck), Schilder (Kraft/Verzweiflung/Zustände aus `FigView.shown_hp/trail_hp/status/status_pop`), Zielmarken, Fokusschild (aus `UiState.plaque`, auch seitlich neben dem Kopf, Riese links), große Ansage (aus `UiState.big`: Stile `rise/sink/pop`, Out-Back 120 ms, Band y 32..72), untere Leiste, Gegnerkarte, Kurzkarte (ohne Hinweiszeilen bis y 96 bei laufender Zielwahl), Chronik; Zeitpunkte: `status_pop` poppt 120 ms, Porträt pulst zweimal (aus `UiState.turn_pulse`).
* **Hud-Haken-Liste:** Bericht nennt **vollständig** jede Funktion/Variable von `Hud`, die `FightUi` ruft und die in `hud.gd` heute nicht steht (R5-Diff ergänzte u. a. `_t1`, `_fit_size`), mit Quelltext zum Einfügen; W2-01 übernimmt sie.
* **Akzeptanz:** R5 6.1 (jede Zeile ein Bild oder Lauf) mit synthetischen `FigView`/`UiState` in der Sandbox; `uitest.gd`: `options(c)` liefert bei 1 bis 4 Fertigkeiten immer 6 Plätze mit `flee` auf 5 und `move` auf 4 (Index), alle fünf zu langen Namen passen auf 6 px in 46 px (Messwerte R5 5.3), jede Klick-ID aus 2.4 wird eingetragen (Mock-Hud), Reihenfolge `fchronplatte` zuerst, `StatusIcons.ORDER` hat 12 Namen und das PNG 108x9; alle Texte Deutsch mit echten Umlauten; keine Tooltips mehr im Kampf außer Aufstellung; Fotos: Mann am Zug, Zielwahl, viele Zustände, Gegnerzug, Kraken spannt sich, Sieg/Niederlage, Chronik, Kurzkarte (Mann, Gegner, Symbol).
* **Testbefehle:** T `tools/uitest.gd`; S je Zustand mit Prüfstand-Haken in der Sandbox (`--shotfight2`, `--shotfight3`, `--shotkraken2`, `--shotheroic`, `--hovermouse=x,y`), Bilder gegen R5 `r5s_*.png` gehalten.
* **Beweisbilder:** `W1-08_fight2.png`, `_pick.png`, `_stat.png`, `_foe.png`, `_kraken.png`, `_win.png`, `_chron.png`, `_karte.png`, `_icons8x.png`.
* **Rückfall:** fehlt `status_icons.png`, zeichnet `StatusIcons` Buchstaben-Notbehelf; fehlt eine Hud-Funktion, bricht der Test mit klarer Meldung ab (nicht still).

#### W1-09 Töne (Sandbox `w109`, ≈ 1,5 Tage)
* **Besitzer-Dateien:** `scripts/sfx.gd` (nur `GAIN`), `tools/make_sfx.py` (15 Funktionen am Ende von `SOUNDS`, hinter `slot_stack`), `tools/sfxtest.gd`, `assets/sfx/<15 neue>.wav`.
* **Eingaben:** SPEC 3.10 (Rezepte: D1 "Erzeugte Bilder und Töne", D2 "Töne", D3 "Töne").
* **Akzeptanz:** 15 Dateien, Dauer ± 10 % der Tabelle, kein Clipping (Spitze < 0,98), keine Stille am Anfang > 5 ms, 44,1 kHz mono 16 Bit; bestehende 63 Klänge **bitgleich** (Hash vorher/nachher); `sfxtest` `FEHLER: 0` und zählt 78; `Sfx.GAIN` enthält alle 15; `musictest` unverändert; Skript deterministisch; Kurzbericht mit Spitzenwerten (hören kann kein Helfer: das ist zu sagen).
* **Testbefehle:** `python -X utf8 -I tools/make_sfx.py`, danach `rungd.ps1 -Script import`, T `tools/sfxtest.gd`, T `tools/musictest.gd`.
* **Rückfall:** `Sfx.play` mit unbekanntem Namen bleibt still (heutiges Verhalten, prüfen).

### Welle 1b (nach "Gate R bestanden" von W1-05; je Karte eine Datei mit Beschreibungen)

Gemeinsam für **W1b-A, W1b-B, W1b-C** (Sandbox `w1ba|w1bb|w1bc`): Eingaben: gelieferte `tools/rig_core.py`/`make_fig_rig.py` (aus dem Hauptprojekt), Beschreibungen der Gegner aus `tools/make_combat_art.py` (`FOES`), R2 5.7 und 5.8; **Besitzer-Dateien**: je eine `tools/rig_foes_<a|b|c>.py` (Beschreibungen mit `spec(...)`), optional `tools/rig_ext_<a|b|c>.py` (zusätzliche Waffen/Köpfe nur über `register_*`, **kein** Eingriff in `rig_core.py`; Wünsche an den Kern im Bericht), `assets/fig/<id>.png|json` der Karte. Akzeptanz je Figur = die von W1-05 (Prüfliste R2 5.8), dazu: Gegner erkennbar nach Formation (Silhouette, Farbe der Rüstung/Haut), **gespiegelt** angesehen, auf der Platzhalterbühne neben den Männern bei 1x und 2x; Rost-Draugr und Knochen: Kettenmuster nicht flimmernd; Draugr heben sich vom grünen Ort ab (Kontur/Farbe prüfen, R2/D2 B13); Kontaktblatt je Formation; deterministisch. Rückfall: `FightGeo.rig` bleibt false, bis alle 18 + 5 + 2 Streifen da sind.

| Karte | Figuren | Besonderheiten |
|---|---|---|
| **W1b-A** (≈ 2,5 Tage) | Draugr: `rost, bogner, totenwart, waechter, priester, beschwoerer, knochen` | Skelett/Draugr-Körperbau, Geweih/Stab/Kapuze, Schablone Totenwart/Priester/Beschwörer **unterscheiden** (R2 1.3), leuchtende Augen |
| **W1b-B** (≈ 2 Tage) | Räuber `brecher, messerkerl, schuetze, haken, antreiber` + Händler `kaufmann` | breit/schmal, zwei Messer, Haken mit Seil, Horn des Antreibers (am Zellrand!), Kaufmann mit Beutel/Pelzmütze |
| **W1b-C** (≈ 1,5 Tage) | `wache, armbrust` (Händler), `bauer, schmied, kraeuterfrau` (Dorf) | Speer + Schild, Armbrust, Heugabel, Hammer, Korb |

### Welle 2 (genau ein Besitzer)

#### W2-01 Integration: `FightPresenter`, Haken in `hud.gd` und `main.gd`, Flags, Selbsttest (Sandbox `w201` ≈ 6 Tage; Lieferung ins Hauptprojekt nach jedem Schritt)
* **Besitzer-Dateien:** `scripts/fight_presenter.gd` (neu), `scripts/hud.gd`, `scripts/main.gd`, `tools/selftest.gd` (nur Zeilen mit Präfix `fv_`), `tools/dev/shots_fight.ps1` (Serie aller Pflicht-Fotos aus 5.2). **Niemand sonst** fasst diese Dateien an (auch nicht in Welle 3: Wünsche gehen an W2-01).
* **Eingaben:** alle gelieferten Dateien aus Welle 1; SPEC 2, 3; Hud-Haken-Liste von W1-08; R1 5 (Inventar), R3 `R3_hud_main_diff.txt`.
* **Schritte (jeder einzeln testbar und mit Pflicht-Prüfungen 5.1 gesichert; Backup `..\_backup_vor_integration\` zuerst):**
  * **S1 Einspielen:** alle Welle-1-Dateien ins Projekt, `rungd.ps1 -Script import`, `fighttests.ps1` grün, alte Fotos (`--shotfight2` ...) unverändert.
  * **S2 Bühne und Regie:** `Main._ensure_stage()` (nicht headless, nur Kampf mit Anzeige, beim ersten `fight_prep`), `_world.visible = false` **und** `process_mode = DISABLED` im Kampf (danach wiederherstellen; Abgang des Gegnerschiffs nach Sieg prüfen), `FightStage.prewarm` aus `_draw_fight_prep`; `FightPresenter` (Director feed/tick, `voy.combat_stage`, `voy.combat_outro = 0` bei Director-Kämpfen, `render`, Cues → Wucht/Bühne nach Katalog 3.6; `dir.set_selecting`/`skip_intro` aus `fight_click/fight_key`); Hud-Haken: `_process` → `_presenter.tick`, `_draw_combat_view` → `if USE_FIGHT_V2 and _presenter != null and _presenter.active(): _presenter.draw(self, mouse); return`; `const USE_FIGHT_V2 := true`, Flag `--oldfight` (alter Pfad unverändert). Figuren noch Gerüst.
  * **S3 Oberfläche:** `FightUi.draw` im Presenter, `_fight_options` → `FightUi.options` (Rückzug fest auf 6), Tab/`fchron`/`fchronplatte` in `fight_click/fight_key`, Hud-Haken-Liste einbauen, Klickflächen über `FightGeo.rect_to_screen`; alte Hinweis-/Karten-/Journalzeichnung nur im alten Pfad.
  * **S4 Wucht:** alle Cues verdrahtet (Zahlen, Wirkungsbilder, Teilchen, Töne, Marken, Todesbilder, Wörter), `Hud._floats/_ghosts/_anim` nur im alten Pfad. **→ G2: Vorführstand.** Fotoserie 5.2 ansehen, Pflicht-Prüfungen 5.1 komplett.
  * **S5 Einstellungen und Betriebsarten:** drei Zeilen in der Einstellungsansicht, `Settings` → Director-Modus/`FightFx.lod`/`flash_scale`/`stage_fx`; Modus kurz; Schnellmodus/Headless unberührt (Test `FightStage.instances == 0`, `FightDirector.instances == 0`).
  * **S6 Flags** (3.11), `--clicktest`, `--shotclock`, Foto-Ablauf `shots_fight.ps1`.
  * **S7 Rig-Schalter:** sobald `FigArt.missing()` leer ist (G3), läuft `FightGeo.rig = true`; Ankerpunkte (`FightStage.anchor`) speisen `ctx`; Gerüst bleibt als `--norig`.
* **Akzeptanz:** 5.1 vollständig; die Klick-IDs und Tasten aus 2.4 funktionieren (Mausklick auf jedes Ziel und jede Karte per `--clicktest` bei Zoom 1,0 und gehaltener Kamera); `--oldfight` zeigt den heutigen Kampf; `hud.gd` wächst höchstens um 150 Zeilen (Haken + Hud-Haken-Liste); kein `Time.get_ticks_msec()` in neuen Dateien; Einstellungszeilen speichern/laden.
* **Rückfall:** `USE_FIGHT_V2 := false` oder `--oldfight`; Director-Notbremse; `Settings.stage_fx = 0`.

### Welle 3 (Feinschliff und Prüfung; Besitzer disjunkter Dateien, `hud.gd`/`main.gd` nur über W2-01)

| Karte | Besitzer-Dateien | Auftrag | Akzeptanz |
|---|---|---|---|
| **W3-A Bild** (≈ 4 Tage) | alle Dateien von W1-03, W1-04a/b | zwei Fotodurchgänge je Ort (Himmel, Schiff, Deck, Requisiten, Lampen, Nebel, Randlicht, Schatten), Lesbarkeit der Gegner (Draugr), `dark/desat/tint` in `stage_themes.gd` nach `lumcheck`, Kulissenmängel (R3 5.2) beheben | D2 K5 bis K9, K13 bis K16 mit dem Rig; Zeichenaufrufe 5.1; jedes Foto angesehen; Vorher-nachher-Montage je Ort |
| **W3-B Regie und Wucht** (≈ 4 Tage) | Dateien von W1-02, W1-07, W1-09 | Zahlen in `BeatPlanner.T` (inkl. `lit/bg`) am Foto/Kontaktbogen abstimmen (R4 Prüfplan 8), Zeitbudget mit Stoppuhr-Protokoll, Eskalationsleiter erlebbar ("Todesstoß sichtbar größer als Krit, Krit größer als normal"), Ermüdung, Modus kurz, Klang-`GAIN` | T1 bis T12 (Regie), D3 A/B, `W3-B_zeitbudget.md` mit gemessenen Beat-Dauern und Summen je Formation (100 Kämpfe je Formation) |
| **W3-C Figuren** (≈ 3 Tage) | Rig- und Tierdateien aller Figuren-Karten | alle 25 Streifen auf der Bühne neben den anderen bei 1x/1,25x/2x, R2-5.9-Mängel nachbessern, Stilangleichung Rig ↔ Tiere ↔ Kraken, Rig-Schalter prüfen, `anker.json`-Werte gegen Effekte (Hand/Spitze/Brust) | R2 5.8 für **alle**; `FigArt.missing()` leer; Foto je Formation mit Rig |
| **W3-D Oberfläche** (≈ 2 Tage) | `fight_ui.gd`, `tips.gd`, `status_icons.gd` | Textbreiten, Schriftgrößen, Kurzkarten-Überlappung, Zugleisten-Hover-Ring, Texte (R5 5.2), Farbschwäche (Form trägt Bedeutung) | R5 6.1 am echten Spiel; `uitest` |
| **W3-E Aufstellung (optional)** | über W2-01 | R5 B7/B8 (Gegnerkarten, Reihenfelder der Fertigkeitenwahl) | nur wenn alles andere abgenommen ist |
| **W3-F Unabhängige Abnahme** (≈ 2 Tage) | nur `docs/kampf_spektakel/ABNAHME.md` | frische Sandbox des Hauptprojekts; **alle** Pflicht-Prüfungen 5.1/5.2 durchführen, gegen `BASELINE.md` vergleichen, Fehlerliste mit Besitzer je Fund; wiederholen nach der Fehlerbehebung | ABNAHME.md mit allen Zahlen und Bildverweisen; keine offenen Punkte der Klasse "Absturz, Blockade, Regelwerk" |

---

## 5. Pflicht-Prüfungen

### 5.1 Läufe (nach jeder Karte der eigenen Dateien, nach jedem Schritt von W2-01 und in W3-F vollständig)

| Nr | Prüfung | Befehl | Bestanden, wenn |
|---|---|---|---|
| P1 | Regeln, Töne, Musik | `tools\dev\rungd.ps1 -Script tools/selftest.gd -Tail 1500 -Timeout 900`, ebenso `tools/sfxtest.gd`, `tools/musictest.gd` | `FEHLER: 0`; kein `SCRIPT ERROR` |
| P2 | Regelwerk bitgleich | `tools/evhash.gd` | Logik-Prüfsumme **3356533480** |
| P3 | Rechenzeit Schnellmodus | `tools/evtime.gd` | ≤ +15 % gegen `BASELINE.md` |
| P4 | Bots | `tools\dev\runbots.ps1 -Mode --autoplay -Seeds @(1,2,3)` und `-Mode --random` | keine Fehlerzeilen; Gesamtzeit ≤ +5 % gegen Basis; `voy.stage_t == 0` in jedem Lauf (Zähler `FightDirector.instances == 0`, `FightStage.instances == 0`) |
| P5 | Neue Tests | `tools\dev\fighttests.ps1` (eventtest, directortest, stagetest, fxtest, uitest) | überall `FEHLER: 0` |
| P6 | **Schnellmodus** | `stagetest.gd`: 100 Kämpfe `voy.auto_combat = true` | keine Bühne, kein Director, keine Textur/Shader, `stage_t` 0, Zeit je Kampf unverändert |
| P7 | **Headless-Sicherheit** | alle Läufe oben headless; Suche im Log nach `SCRIPT ERROR`, `ERROR:`, `Parse Error` | keine Treffer; `load` von Texturen/Shadern/Streifen nur bei `DisplayServer.get_name() != "headless"` (Quelltextsuche `load(` in neuen Dateien) |
| P8 | **Zeitbudget je Aktion in Sekunden** | `directortest.gd` T1/T4 + Stoppuhr-Protokoll in W3-B | Tabelle 3.9 ±3 ms; gewöhnlicher Treffer 0,900 s; Krit ≤ 1,25; Gegnertod ≤ 1,0; Mann fällt ≤ 1,7; letzter Gegner ≤ 1,5; Heldenmut/Bruch ≤ 1,8; Kraken-Quetschen ≤ 1,9; kein Beat > 2,6 s; **Überlängen je Kampf ≤ 6,0 s, Mittel ≤ +0,5 s** gegen heute |
| P9 | **Zeichenaufrufe je Bild** | jedes Foto meldet `STAGE Messung: Zeichenaufrufe=... Primitive=...` | ≤ 420 im Normalbild (Ruhe, Auswahl, Hieb), **≤ 520** im schlimmsten Bild (Kraken-Quetschen + Krit), Primitive ≤ 6000; Modus schlicht ≤ 220; Bühne allein ≤ 340 |
| P10 | Bildzeit | `Performance.TIME_PROCESS` + Renderzeit im Foto-Lauf, drei Läufe zu 600 Bildern, Median | ≤ 2x der heutigen Kampfansicht (Messung gegen `--oldfight`) und ≤ 6 ms Hud+Bühne auf dem Laptop |
| P11 | Klicken und Tasten | `--clicktest` (Zoom 1,0 und gehaltene Kamera 1,25), `fighttests` K2 | jedes Ziel `ft*` und jede Karte `fs0..5` trifft; `Esc`, `Q W E R`, `1..6`, Leertaste, `Tab` wie 2.4; Rückzug nur auf 6 |
| P12 | Leck und Wiederholung | 50 mal `begin/end` von Director und Bühne, danach `Performance.OBJECT_COUNT` | Schwankung ≤ 2 %; `FightAnim`-/`_ev_combat`-Verweise nach Kampfende null |
| P13 | Weltbild unverändert | Kartenfoto `--seed=3` (ohne Kampf) vor/nach | byte-gleich |
| P14 | Import | `rungd.ps1 -Script import` | keine Fehler; alle PNG/WAV/Shader geladen |
| P15 | Rückfälle | `--oldfight`, `--norig`, `Settings.stage_fx = 0`, Modus kurz, `Settings.shake = 0`, fehlender Atlasschlüssel (Test mit entfernter Zeile) | jeder Weg zeichnet einen vollständigen, bedienbaren Kampf ohne Fehlerzeile |

### 5.2 Pflicht-Fotos (Read-Werkzeug, Urteil im Bericht; Dateien `docs/kampf_spektakel/img/W2_<name>.png`)

Mit `tools\dev\shots_fight.ps1` (W2-01), je Foto zusätzlich `STAGE Messung`: Aufstellung `--shotfight`; Ruhe/Auswahl `--shotfight2`, `--shotfight3` (Zielwahl mit Q W E R und Trefferchance); `--beat=melee:0|200|250|330|540`, `bow:340`, `musket:280`, `heal:300`, `miss:250`, `crit:300|330`, `area2:400`, `area4:400|700`, `foe:470`, `foecrit:510`, `kill:400`, `killbig:450`, `herodie:600|1000|1400`, `herodoor:600`, `lastfoe:1100`, `door:600`, `resist:800`, `heroic:600|1200`, `snap:1200`, `kraken`, `spannt`, `crush:300|560`, `grab`, `bord`, `intro:600`, `intro_kraken:1200`, `win:800`, `lose:1000`, `bleed`; je Ort `--shotform=<f>` (5); `melee:330,fast` und `melee:330,noshake`; Gerüst (`--norig`) gegen Rig; `--winsize=3120x2080` für `crit:300` (Zoom-Streifen, A9); `--oldfight` zur Gegenprobe; Kontaktbogen (`contactsheet.py`) der Zeitpunkte 0/100/200/250/330/450/540/720/900 für `melee`, `crit`, `foe`, `herodie`, `lastfoe`. **Muss man sehen** (D1 A1 bis A16 und D3 B18 bis B20, gekürzt): Handelnder gerandet und hell, Unbeteiligte ≤ 0,62 seiner Helligkeit (`lumcheck`), Fokusschild statt Banner, Opfer beim Gegnerzug am hellsten, Zahl nach dem Standbild, Zoom-Kanten gleichmäßig, Namen/Balken ungezoomt, Zahlen lesbar auf allen Gründen, Ansagen über den Köpfen ohne Verdeckung der Gesichter, Schwellenrand ohne Verdeckung der Leiste.

### 5.3 Was kein Helfer prüfen kann (und der Bericht so sagen muss)

Bewegung (Flimmern der Kanten während Zoom/Schwenk, Dither-Schwimmen, Gefühl der Zeitlupe), Klang und Lautstärke, Faktor 6,5 des Besitzer-Bildschirms (Fotos haben 6,0; die Zoom-Messungen decken 6,0 und `--winsize=3120x2080` ab), Leistung auf dem Rechner des Besitzers. Gegenmittel: Einstellungen "kurz", "Wackeln und Blitze", "Kampfbild: schlicht"; der Besitzer urteilt nach G2.

---

## 6. Risiken und was zuerst entschieden/geprüft werden muss

### 6.1 Zuerst entscheiden/prüfen (in dieser Reihenfolge, alle in Welle 1)

1. **Baseline und Prüfsumme (W1-01):** erst messen, dann ändern. Ohne `BASELINE.md` ist keine spätere Aussage "nicht langsamer" belegbar.
2. **Pixel-Raster bei Zoom (W1-03 Spike 2):** ungleichmäßige Streifen bei 1,125/1,25/1,375 würden die Zoomstufen kippen (Rückfall: Stufen auf 1/4 runden, im Notfall Zoom nur im Standbild halten; Entscheidung trifft W1-03 am Messwert und meldet sie, SPEC 3.9 wird dann angepasst).
3. **Shader auf `_draw`-Figuren (W1-03 Spike 1):** UV bei `draw_texture_rect_region` mit 2-px-Rand, Randlicht gespiegelt; scheitert das, Rückfall auf je ein `Sprite2D` mit `region` (dann Todesbilder über Kinder-Sprites, D3-Bänder als Streifen-Sprites) – Schnittstelle `render()` bleibt gleich.
4. **Rig-Qualität (W1-05 Gate R):** schlechter als die alten Figuren heißt nachbessern, nicht ausliefern. Bis zu G3 trägt das 2x-Gerüst.
5. **`hud.gd` nur ein Besitzer** (K20): jede Karte beschränkt sich auf Dateien aus 2.1; Wünsche an `hud.gd`/`main.gd` gehen als Liste im Bericht an W2-01.
6. **Ereignisfelder rückwärtsverträglich:** `eventtest` + Prüfsumme als Torwächter (W1-01).

### 6.2 Risiken

| # | Risiko | Wirkung | Gegenmittel (Karte) |
|---|---|---|---|
| R1 | **Der Zustand eilt der Anzeige voraus** (Kraft, Reihen, Zustände, `c.actor`) | Balken fällt vor dem Hieb, Rampenlicht am falschen Mann | `hp0/hp1/rank/turn` in den Ereignissen, `shown_*` im Director, Licht folgt dem Beat (W1-01/02) |
| R2 | **Beats überlappen** (Mann auf Mann ohne Takt) | Kamera springt, Zahlen mischen sich | Warteschlange, Aufholfaktor, kleine Beats fallen weg, `stage_t` nur nach oben, Watchdog (W1-02) |
| R3 | **Takt wird länger** (Spieler empfindet Zähigkeit, Darkest-Dungeon-Klage) | Akzeptanz sinkt | Gewöhnlicher Treffer +0 s, Überlängen-Deckel 6 s, Modus kurz, Ermüdung −20 %, `schnell` unberührt; Messung P8 (W1-02, W3-B) |
| R4 | **Klickkarte stimmt nicht mehr** unter Kamera | falsche Ziele | `FightGeo.rect_to_screen` einzige Abbildung, Zoom 1,0 beim Wählen, `--clicktest` (W1-01/02/03, W2-01) |
| R5 | **Pixelflimmern/Wandern der Kanten** während der Fahrt (nicht prüfbar im Standbild) | Übelkeit/Unruhe | Fahrt ≤ 140 ms, danach konstant, Wackeln erst nach dem Runden, Einstellung `shake`, Modus kurz ohne Zoom; Besitzerurteil nach G2 |
| R6 | **Zu dunkel** (Mock D2 war es) | Lesbarkeit | `lit/bg` relativ, `lumcheck`-Kriterien (K7, K14), zwei Fotodurchgänge je Ort (W3-A/B) |
| R7 | **Rig gröber als die alten Figuren** | weniger Charakter | Gate R, Randlicht/Ortsfarbe, Männer zuerst fein, Gerüst als Rückfall (W1-05, W3-C) |
| R8 | **Kunstumfang** (≈ 30 Bilder, 25 Streifen) | Verzug | Parallelisierung in 7 Karten, Streichreihenfolge (Kapitel 4), Gerüst und Teilorte lauffähig, `has()`-Rückfälle |
| R9 | **Doppelte Wetterquelle** (Welt + Bühne) | doppelter Donner | Welt `PROCESS_MODE_DISABLED`, `storm_override`; Rückkehr der Welt (Gegner-Abgang nach Sieg) in W2-01 S2 prüfen |
| R10 | **Lade-Ruckler** (9 Streifen ≈ 14,5 MB) | Hänger nach "Kampf!" | `prewarm` in der Aufstellung, Cache-Obergrenze 12, Messung K11 (≤ 120 ms bis zum ersten Bühnenbild) |
| R11 | **Zeichenaufrufe/Primitive** | Ruckeln | Budget K22, `lod`, Partikel-Obergrenzen, P9/P10 |
| R12 | **Ereignis ohne `who`** stürzt Leser ab | Absturz | Director und `FightImpact` beginnen jeden Zweig mit `who == null → continue` (W1-02/07), Test T8 |
| R13 | **Zwei Wucht-/Regie-Tabellen driften** | Doppelwirkung (zwei Wackeln) | Eine Tabelle: Standbild/Wackeln/Zoom/Zeitlupe nur in `BeatPlanner.T`; `FightImpact.plan` liefert sie nicht; `FightFx` unter `external_clock` ohne `freeze/slowmo/zoom` |
| R14 | **Hud-Haken-Liste unvollständig** (FightUi ruft Hud-Funktionen, die fehlen) | Laufzeitfehler erst in W2 | W1-08 nennt sie vollständig, `uitest` mit Mock-Hud, Parse-Prüfung durch `import` in S1 |
| R15 | **Verträge driften** (jede Karte kopiert wortgleich, W1-01 liefert) | stille Abweichung | S1 vergleicht gelieferte Vertragsdateien mit den Stubs (Textvergleich ohne Kommentare); Abweichung = Fehler der abweichenden Karte |
| R16 | **Rig-Stripes im Speicher** (3712x108 x 9) | Speicherspitze | Cache-Obergrenze, Freigabe am Kampfende (P12) |
| R17 | **Ton nicht gehört** | Pegel falsch | konservative `GAIN`, Schichten −9 bis −10 dB, Besitzerurteil, `Settings.sfx_db` wirkt wie bisher |
| R18 | **Mehrere Hud-/Main-Änderungen in Welle 3** | Kollision | Wünsche an den Besitzer W2-01, gebündelt nach jeder Runde |
| R19 | **Zeitlupe und Klang** (Klänge in echter Zeit, Zeitlupe dehnt) | Klang eilt voraus | alle Klänge über Cues in Bühnenzeit, Tonhöhe 0,75 bis 0,8 in Zeitlupe (3.10) |
| R20 | **Schlussansage** wird nach Zeitlupen-Tod verkürzt (R1 4.3: nur 59 % sichtbar) | Ansage fehlt | `done`-Zweig wartet auf `stage_t`; `sieg`-Beat beginnt nach dem Todesbild; `combat_outro` 0 bei Director-Kämpfen |

### 6.3 Entscheidungen, die SPEC bewusst offen lässt (vom Besitzer der Karte am Messwert zu treffen und im Bericht zu begründen)

Zoomstufe bei ungleichen Streifen (W1-03), Rückstoß- und Halo-Größen bei `fe = 1,6` (W3-B), `lit/bg`-Werte (W3-A/B), ob der geworfene Schatten bleibt (K12), ob `Settings.shake` standardmäßig 2 oder 1 ist (Standard 2, Besitzerurteil), Lautstärken (Besitzerurteil).

---

## Anhang A: Dateibesitz auf einen Blick (exklusiv; Lieferung nur durch den Besitzer)

| Karte | Dateien |
|---|---|
| W1-01 | `scripts/combat.gd voyage.gd settings.gd fight_geo.gd fight_level.gd fight_views.gd`, `tools/evhash.gd evtime.gd eventtest.gd dev/lumcheck.py dev/fighttests.ps1 dev/contactsheet.py`, `docs/kampf_spektakel/BASELINE.md` |
| W1-02 | `scripts/beat_planner.gd fight_cam.gd fight_director.gd`, `tools/directortest.gd dev/beat_timelines.py` |
| W1-03 | `scripts/fight_stage.gd fighter_node.gd stage_light.gd stage_particles.gd stage_themes.gd fig_art.gd sky_layer.gd ocean_layer.gd rain_layer.gd stage_sheet.gd`, `shaders/stage_grade fighter_lit stage_fog sky ocean .gdshader`, `tools/stagetest.gd` |
| W1-04a | `tools/make_stage_art.py`, `assets/stage_deck props lamps own far sky_extra .png`, `scripts/stage_atlas.gd` |
| W1-04b | `tools/make_stage_art2.py`, `assets/stage_foe_* village kraken_front splash front_* .png`, `scripts/stage_atlas_big.gd` |
| W1-05 | `tools/rig_core.py make_fig_rig.py`, `assets/fig/{schild,axt,bogen,skalde,muskete}.png|json` |
| W1-06 | `tools/make_fig_tier.py`, `assets/fig/hund.* tentakel.*`, `assets/kraken_ex.png` |
| W1-07 | `scripts/fx_kinds fx_particles fx_pose fight_font fight_numbers fight_impact fight_marks fight_fx fx_sheet .gd`, `tools/make_fight_font.py fxtest.gd`, `assets/fight_font.png` |
| W1-08 | `scripts/fight_ui.gd status_icons.gd tips.gd`, `tools/make_status_icons.py uitest.gd`, `assets/status_icons.png` |
| W1-09 | `scripts/sfx.gd`, `tools/make_sfx.py sfxtest.gd`, `assets/sfx/<15>.wav` |
| W1b-A/B/C | `tools/rig_foes_a|b|c.py rig_ext_a|b|c.py`, `assets/fig/<id>.png|json` (7 / 6 / 5 Gegner) |
| W2-01 | `scripts/fight_presenter.gd hud.gd main.gd`, `tools/selftest.gd` (Präfix `fv_`), `tools/dev/shots_fight.ps1` |
| W3-xx | wie die Besitzer der gleichnamigen Welle-1-Dateien (3-A: Bühne und Kulisse; 3-B: Regie, Wucht, Ton; 3-C: Figuren; 3-D: Oberfläche; 3-F: nur `ABNAHME.md`) |

## Anhang B: Aufwand und Reihenfolge (Arbeitstage eines Entwicklers, grob)

Welle 1a: 1,5 + 5,5 + 7 + 3,5 + 4 + 4,5 + 2 + 5,5 + 2,5 + 1,5 = **37,5** (parallel, Kernpfad W1-03 und W1-05 ≈ 7 Tage); Welle 1b: 2,5 + 2 + 1,5 = **6** (parallel, ≈ 2,5 Tage nach Gate R); Welle 2: **6**; Welle 3: 4 + 4 + 3 + 2 + 2 = **15** (parallel ≈ 4 Tage). Summe rund **65 Arbeitstage**, Kalenderdauer bei voller Parallelisierung **ungefähr 17 bis 20 Tage**; Vorführstand G2 nach ≈ 13 Tagen (Welle 1a + S1 bis S4). Die Entwürfe summieren sich auf 49,75 Tage (D1 10,5 + D2 29,5 + D3 7,25 + R5 2,5); dieser Plan liegt darüber, weil Integration (6), Feinschliff und unabhängige Abnahme (15) hinzukommen, spart aber die Dopplungen (Geometrie, Stufentabellen, Töne, Prüfwerkzeuge, Zahlen/Marken, Selbsttest-Blöcke).
