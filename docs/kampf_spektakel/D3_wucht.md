# D3: Wucht (Effekte, Zahlen, Todesbilder, Marken, Töne)

Stand: 4. November 2026. Entwurf für den Bauhelfer. Grundlage: Auftragsblatt und R1 bis R5, `scripts/fight_fx.gd`, `scripts/hud.gd` (`_fx_go`, `_fx_hit`, `_fx_miss`, `_fight_events`, `_draw_fighter`), `scripts/sfx.gd`, `tools/make_sfx.py`.
Arbeitskopie mit **laufendem Prototyp**: `..\_sandbox\wucht\` (Hauptprojekt unverändert). Dort liegen fertig und getestet (Parse und Bild): `scripts/fx_kinds.gd`, `fx_particles.gd`, `fx_pose.gd`, `fight_font.gd`,
`assets/fight_font.png`, `scripts/proto_wucht.gd` (Wirkungsblätter, Flag `--proto=a|b|c|d|e`). Der Python-Erzeuger der Schrift liegt als `docs/kampf_spektakel/D3_make_fight_font.py`.
Alle Bilder in `docs/kampf_spektakel/img/` mit Namen `D3_*` sind Bildschirmfotos aus dem Spiel (6,0-fach, Pixelraster sichtbar). **Ehrlich vorab:** alles ist an Standbildern geprüft, keine Bewegung gefilmt;
Zahlen, die aus R4 stammen, sind Ausgangswerte zum Abstimmen (Abschnitt "Aufwand und Risiko").

Abgrenzung: Kamera, Rampenlicht, Dimmung, Bühne und Takt (`stage_t`) gehören den Entwürfen Regie und Bühne; Figurenzellen und Posen-Frames dem Entwurf Figuren; Layout der unteren Leiste, Karten, Chronik, Kurzkarte, Statussymbol-Atlas dem Entwurf R5.
Dieser Entwurf liefert **Wirkung am Ziel** (Bilder, Teilchen, Zahlen, Trefferpose, Tod), **Marken an den Figuren** (Schild-Animation, Zustandssymbole, Zielmarke, Fadenkreuz, Herzrand) und **Töne**.
Alles hier ist reine Anzeige. Nichts davon wird im Schnellmodus (`voy.auto_combat`), bei Bots oder headless erzeugt oder gerechnet.

---

## Leitidee

1. **Ein Treffer ist ein Satz aus kleinen Antworten innerhalb von 100 ms**: weißer Frame am Ziel, kurzes Einfrieren, Bild der Waffe (Sichel, Spalt, Druckwelle, Biss ...), Splitter in der Farbe des Getroffenen, Rückstoß, Zahl, geschichteter Klang. Jedes für sich klein, zusammen schwer (R4, Technik 6 bis 9).
2. **Fünf Stufen, jede in allen Kanälen gleichzeitig eine Stufe über der vorigen**: Streifer, normal, schwer (ab 24), kritisch, Todesstoß. Der Normalfall (20 bis 30 Treffer je Kampf, R1 1.6) bleibt kurz und leise; Krit (1 bis 2 je Kampf) und Tod (3 je Kampf) bekommen alles, was wir haben.
3. **Die Art der Fertigkeit liest man am Bild, nicht am Namen**: Hieb = Sichelbogen, Spaltung = Lichtfall und Spalt, Stoß = Druckwelle mit Staubring, Pfeil = Zischspur und steckender Schaft, Kugel = Mündungsfeuer, Rauchring, Spur, Biss = Kiefer, Krallen = drei Schrammen, Peitsche = laufende Welle, Heilung = Lichtsäule, Lieder = Klangbögen mit Winkeln, Schild = Kuppel, Tinte = Klumpen im Bogen, Beschwörung = Runenkreis mit Säule.
4. **Die Figur gibt die Antwort mit dem Körper**: weißer Frame (50 ms), Rückstoß in ganzen Pixeln, bei schweren Treffern der Spalt-Versatz (zwei Hälften 2 Pixel auseinander), rote Tönung, die in 200 ms abklingt; Tod als Zerfall (Knochen), Sturz (Menschen) oder Absinken (Fangarme, Kraken).
5. **Schrift ist Teil der Wucht**: eine eigene 5x7-Pixelschrift mit Rand (`fight_font.png`) für Zahlen, "KRITISCH!", "VERFEHLT", "BLOCK", "WIDERSTAND". Gleich breite Ziffern, ganzzahlig skalierbar, Klassen unterscheiden sich in Größe, Farbverlauf und Zeichen, nicht nur in der Farbe.
6. **Dauerzustände sind leise, Ereignisse laut**: Schwelle = roter Rand mit Herzschlag (Bild, kein Ton außer im Zug des Mannes), Zustände = Symbole mit Aufpoppen, Zielwahl = Marke und Fadenkreuz.
7. **Wirkung ist billig**: nur `draw_rect`, `draw_line`, `draw_arc`, `draw_colored_polygon`, `draw_texture_rect_region`; keine Shader, keine neuen Knoten (die Bühne aus R3 darf Wirkungen zusätzlich additiv leuchten lassen, das ist ihr Teil).

Belege am Bild (Prototyp, `img/`):

| Bild | Zeigt |
|---|---|
| `D3_blatt_a.png` | Hieb (Schwert, Axt), Spaltschlag, Stoß mit Druckwelle in je vier Zeitpunkten |
| `D3_blatt_b.png` | Pfeil, Kugel, Biss, Peitschenhieb des Fangarms |
| `D3_blatt_c.png` | Heilung, Kriegslied, Schildwall und Block, Tinte |
| `D3_blatt_d2.png` | Krit (Starburst, Schriftzug), Trefferpose mit Spalt, Zerfall, Sturz |
| `D3_blatt_e.png` | Beschwörung, Krallen, Fadenkreuz (offen und eingerastet), Zahlenklassen, Herzrand an der Schwelle |
| `D3_font_vorschau.png` | die Schrift in allen Klassen auf Deck und Nacht |

Ergebnis der Durchsicht der Bilder (nicht beschönigt): **gut** sind Sichelbogen, Spaltschlag, Pfeil mit Zischspur, Kugel mit Rauchring, Schildkuppel, Zerfall in Bändern, Fadenkreuz, Zahlen, Beschwörung. **Zu ändern** (in "Ablauf und Zahlen" eingerechnet):
Der erste Krit-Starburst (Radius 34) verdeckte das Ziel (`D3_blatt_d.png`); mit Radius 22 und innerem Stern 12 bleibt die Figur lesbar (`D3_blatt_d2.png`). Der Schriftzug "KRITISCH!" darf nicht auf der Schadenszahl liegen (Schriftzug über dem Kopf, Zahl auf Brusthöhe).
Die Tinte (dunkelviolette Kreise) ist auf dem dunklen Prüfgrund kaum zu sehen und muss auf dem echten Deck mit hellem Rand nachgebessert werden. Die Heilsäule ist blass (Alpha anheben). Der Sturz (Zeilenband-Scherung plus Rotton) liest sich als "verbogen" und trägt nur wegen seiner Kürze (0,36 s); im Standbild nicht beurteilbar.

---

## Ablauf und Zahlen

Alle Zeiten in **Anzeigezeit** (laufen also mit Einfrieren und Zeitlupe, `FightFx.tick`), Null = **Kontakt** `t0` (heute `hw`, R1 1.2). Maße in Spielfeldpixeln bei **k = 1** (Figur 44x56, Brust `FEET - 30`, Kopf `FEET - 48`).
Bei größeren Figuren (R5: Zelle 88x112, k = 2) gilt: Radien, Längen, Teilchengeschwindigkeiten und Rückstoß mal k; Linienstärken, Ränder und Teilchengrößen mal `maxi(1, roundi(k))`; Zeiten unverändert.

### 1. Die fünf Stufen (Wucht-Leiter)

Stufe aus `power(dmg, crit, lethal)`: Krit hat Vorrang vor Schwer, Tödlich (aus `die` auf `hit` desselben Ziels, R1 2.2) vor allem. Streifer: Schaden ≤ 5 (Blutung 4, Würgen 6 liegt knapp darüber: normal). Schwer: ab 24 (wie heute).

| Stufe | 0 Streifer | 1 normal | 2 schwer | 3 kritisch | 4 Todesstoß |
|---|---|---|---|---|---|
| weißer Frame am Ziel (`tint 6,6,6`) | 33 ms | 50 ms | 66 ms | 100 ms | 100 ms |
| Einfrieren (global, nur einmal je Aktion, größter Wert gilt) | 0 | 50 ms | 80 ms | 90 ms | 100 ms |
| danach Zeitlupe | nein | nein | nein | 0,4 für 250 ms | 0,35 für 450 ms |
| Rückstoß des Ziels (Quad Out in 120 ms, halten bis 260, zurück bis 460) | 2 px | 4 px | 6 px | 9 px | 9 px |
| Spalt-Versatz der Figur (zwei Hälften je 2 px auseinander, 60 ms hin, weg bis 400 ms) | nein | nein | ja | ja | ja |
| Wackeln der Bühne (zuerst entlang der Schlagachse, dann frei) | 1 px / 120 ms | 2 px / 200 ms | 3 px / 260 ms | 4 px / 360 ms | 5 px / 400 ms |
| Blitz der Bühne (Alpha / Dauer; höchstens 3 je Sekunde) | nein | nein | nein | Gold 0,16 / 120 ms | Weiß 0,22 / 80 ms |
| Kamera-Impuls (`FightFx.zoom`, nur wenn die Regie keine gehaltene Kamera hat) | 0 | 0 | +0,03 / 0,25 s | +0,05 / 0,3 s | +0,08 / 0,8 s |
| Blut (Teilchen, Farbe nach Material) | 3 | 7 | 12 | 16 | 20 |
| Funken (Teilchen) | 0 | 4 | 6 | 9 | 9 |
| Stern am Einschlag | nein | `n=4, r=9` | `n=6, r=12` | zwei Sterne `n=12`, `r=22` und `r=12` | wie Krit |
| Zahl | Klasse "Streifer" klein, grau | normal | schwer, Orangeverlauf | Krit, Gold | wie die Klasse des Treffers |
| zusätzlicher Klang | nein | Schicht 1 | Schicht 1 + `hit_sub` | Schicht 1 + `hit_sub` + `crit` + `clash` | wie Krit + `death` |
| größter Zuschlag auf den Takt (an Regie gemeldet) | 0 | 0,05 s | 0,08 s | 0,35 s | 0,6 s (Todesbild, Regie legt bis 1,5 s) |

Regeln: (a) Mehrfachtreffer einer Aktion (Fläche): Einfrieren, Wackeln und Blitz nur beim stärksten, die anderen Ziele bekommen nur weißen Frame, Rückstoß, Teilchen, Zahl (R4). (b) Dritte gleichartige Aktion in Folge: Teilchenzahl und Wackeln ×0,8 (Ermüdung). (c) Spielereinstellung "Wackeln und Blitze: aus/schwach/normal" (Faktor 0 / 0,5 / 1) wirkt auf Wackeln, Blitz und Zeitlupen-Zoom; Standbilder bleiben.
(d) "Stufe kurz" (Regie): `FightFx.particles.budget = 0.5`, `FightFx.lod = 1`, kein Spalt-Versatz, keine Sterne außer Krit.

### 2. Zeitplan eines normalen Nahkampftreffers (Schwerthieb, Einzelziel), vom Kontakt aus

| ms | Was |
|---|---|
| -100 | Sichelbogen beginnt (`crescent`, 340 ms; die Spitze erreicht den Einschlagpunkt bei t0 + 43 ms, der Schweif schrumpft von hinten) |
| 0 | Ziel: weißer Frame 50 ms; Einfrieren 50 ms (Zähler laufen weiter, nur Anzeige steht); Stern `n=4 r=9` 200 ms; Blut 7 und Funken 4 starten; Klang Basis `slash` und Schicht `hit_wet` (+15 ms) |
| 0 bis 120 | Rückstoß 0 -> 4 px (Quad Out), Trefferpose (Spalte 3 des Atlas; später `hit_0`) bis 460 ms |
| 50 | (nach dem Einfrieren) Zahl springt auf, siehe Abschnitt 4 |
| 50 bis 250 | rote Tönung klingt ab (`Color(1,1,1) -> Color(1.6,0.55,0.5)` Mischung über 200 ms rückwärts) |
| 120 bis 260 | Rückstoß halten; Wackeln 2 px läuft ab 0, 200 ms, die ersten 80 ms entlang der Schlagachse |
| 260 bis 460 | Rückweg in Quad Out |
| 450 | Funken und Blut sind verglüht (Lebensdauer 0,18 bis 0,85 s je Art), Blutflecken bleiben als 1-Pixel-Striche 14 s auf dem Deck |
| 800 | Zahl ist weg |

Der Angreifer wird hier nicht beschrieben (Figuren und Regie), nur eine Schnittstelle: **er bleibt beim weißen Frame des Ziels in seiner Zuschlagpose** und löst sich frühestens bei t0 + 150 ms (R4 "Halten").

### 3. Wirkungsarten je Fertigkeit (alle neuen `FightFx`-Arten mit Parametern)

Neue Arten stehen in `FxKinds` (Zeichner, `static func draw(ci, kind, it, u) -> bool`) und werden von `FightFx.draw` im Standardzweig dorthin weitergereicht. Gemeinsame Felder jedes Eintrags: `x`, `y` (Ort), `sc` (Maßstab k, Standard 1), `dir` (+1 nach rechts), `fy` (Zeile der Füße, wo nötig). Der Zähler `u` = Alter / Dauer.

| Art (`FxKinds`) | Wofür | Parameter (Standard) | Dauer | Beschreibung, am Bild geprüft |
|---|---|---|---|---|
| `crescent` | Hieb, Hieb mit Axt | `r` 26, `th` 4, `a0` -115°, `a1` 35°, `col` (1,0.96,0.82), `rim` (1,0.7,0.3); Axt: `r` 28, `th` 8, `a0` -100°, `a1` 28°, `rim` (1,0.5,0.18); Krit: `r` 30, `th` 9, `col` (1,0.92,0.6), `rim` (1,0.45,0.1) | 340 ms (Axt 380) | Sichelbogen aus 12 Vierecken in zwei Durchgängen (Glut außen, Kern innen), Farbverlauf Rand -> Kern; 24 Zeichenaufrufe, bei `lod 1` 8 Schritte |
| `cleave` | Spaltung | `sc` | 600 ms | weißer Lichtstrich fällt in 120 ms (40 px oben bis 22 px unten), dann klafft ein dunkler Spalt bis 3 px breit mit hellen Kanten, schließt sich; Stern `n=4 r=8` bei +100 ms, Blut 12 bei +100 ms |
| `shock` | Stoß, Hammer, Ramme, Ruf, Kraken-Quetschen | `r` 30 (Stoß 34, Axt 18, Quetschen 60), `fy` | 400 bis 500 ms | zwei Ringe (zweiter um 120 ms versetzt, 75 % Radius), achtzackige Strahlen bis 55 % der Zeit, flacher Staubring am Boden (Ellipse mit Höhe 20 %) |
| `arrow2` | Pfeil, Armbrust | `x,y,x2,y2`, `fl` Flugzeit (0,2; Armbrust 0,14), `miss` | 900 ms | Pfeil mit drei Nachbildern (Zischspur), steckt nach dem Treffer 0,75 s im Ziel, Schaft zittert 150 ms (1 px, 60 Hz); bei `miss` fliegt er vorbei und blendet aus |
| `star` | Einschlag, Krit | `n` Spitzen (4, 6, 8, 12), `r`, `col`, `rot`, `core` (an) | 180 bis 500 ms | Stern aus 2n Spitzen (lang und kurz im Wechsel), weißer Kern; wächst in 22 % der Zeit auf 110 %, sinkt auf 100 %, blendet ab 50 % aus |
| `smoke_ring` | Muskete, Pistole | `dir` | 700 ms | Pulverrauchring löst sich vom Lauf (flache Ellipse, 22 px nach vorn) |
| `reticle` | Fadenkreuz | `r` 16, `col` (0.95,0.3,0.25) | 450 ms (Zielwahl: gehalten) | Ring schnurrt von 2,2 r auf r in 45 % der Zeit und dreht dabei 1,2 rad; ab 55 % rastet er weiß ein (Linie 2 px, vier Marken) |
| `claws` | Krallen (Hund, Draugr), Netz-Wurf nicht | `dir` | 500 ms | drei Schrammen, 30 ms versetzt, rot nachglühend |
| `bite2` | Biss, Schnabel | `s` Größe (Kraken-Schnabel 1,8) | 500 ms | Ober- und Unterkiefer mit vier Zähnen schnappen in 32 % der Zeit zu, danach bleiben Zahnspuren (4 rote Punkte) und ein Schlitz |
| `whip2` | Fangarm-Peitsche, Griff | `x,y,x2,y2` | 450 ms | Bogenpeitsche mit laufender Welle (3 px, Ordnung 9 Wellen), Knall mit sechs Strahlen bei 46 bis 64 %, Ring bei 50 % |
| `heal2` | Heilung (Mann, Gegnerheiler) | `fy` | 900 ms | Lichtsäule aus sieben Strichreihen, grüner Bodenring (Ellipse 28 %), fünf Pluszeichen steigen auf. **Änderung gegenüber Prototyp:** Alpha der Säule 0,85 -> 1,0, zusätzlich 120 ms Aufhellung des Empfängers (Tönung 1,2 / 1,35 / 1,2) |
| `song` | Kriegslied, Trost, Weckruf, Hohnlied | `mode` = `war` (Gold), `calm` (Blau), `wake` (Weiß), `mock` (Violett, zackig) | 1100 ms | drei Klangbögen vor dem Sänger, aufsteigende Noten |
| `aura_up` | Stärkung (Kriegslied: Wirkung bei jedem Mann), Wut | `col` | 700 ms | drei Winkel (Pfeile nach oben) steigen am Körper auf |
| `dome` | Schildwall, Deckung | `fy`, `sc` (Deckung 0,7) | 1100 ms | blaue Kuppel (24 x 42 px) mit Sechseckmuster, die sich in 25 % der Zeit aufbaut; ein heller Strich fährt darüber |
| `block` | Treffer auf geschützte Figur | `dir` | 300 ms | weißer Bogen und Gegenring am Schild, Funken (`spark` 7), Klang `hit_ring` |
| `ink2` | Tinte | `tx` (Array Ziel-x), `ty` | 1300 ms | je Mann ein Klumpen im Bogen vom Kraken, dort bleibt eine Wolke mit Tropfen; leichter Violettschleier über 22..130 (Alpha 0,16). **Änderung:** Wolke mit hellviolettem Rand (0.35,0.2,0.55), sonst auf dem Deck unsichtbar |
| `circle` | Beschwörung | `fy`, `col` (0.72,0.45,0.98) | 1200 ms | Runenkreis (zwei Ellipsen, acht kreisende Zeichen, Bodenrisse), ab 40 % eine Lichtsäule 78 px; der Beschworene erscheint von unten (Abschnitt 6) |
| `speed_lines` | Krit | `n` 10 | 350 ms | Strahlenkranz um den Einschlag |
| `crit_text` | Krit | `text` "KRITISCH!" | 1000 ms | in der Wucht-Schrift: 60 ms in Maßstab 3, dann 2, Goldverlauf mit Orange unten, Rand dunkelbraun, steigt ab 500 ms. **Lage:** mittig über dem Kopf (`head.y - 16`), nie über der Zahl |

Alte Arten (`slash`, `bash`, `arrow`, `whip`, `bite`, `heal`, `notes`, `shield`, `ink`, `ring`, `dust`, `bullet`, `muzzle`, `spark`) bleiben unverändert bestehen (Rückfall, `FightFx.lod = 2`, Selbsttest); `bullet`, `muzzle`, `ring`, `reload`, `taunt`, `rage`, `horn`, `wail` werden weiter benutzt.

**Zuordnung Fertigkeit -> Einschlagbild** (neue Tabelle `FightImpact.LOOK`, jede Fertigkeit aus `FightFx.SKILL_FX` **muss** einen Eintrag haben, Selbsttest). Die Bilder (`LOOKS`) setzen sich so zusammen:

| Bild | Beim Ausholen | Beim Kontakt (Parameter wie oben) | Teilchen | Töne (Basis aus `Sfx.SKILL_SND`, Schicht je Material) |
|---|---|---|---|---|
| `cut` | - | `crescent` + `star n4 r9` | blood 9, spark 4 | `slash` |
| `chop` | - | `crescent` (Axt) + `shock r18` + `star n6 r12` | blood 12, splinter 6 | `chop` |
| `cleave` | - | `cleave` + `star n4 r8` | blood 12 | `chop` + `hit_sub` |
| `bash` | - | `shock r34` (leicht: 20) + `star n8 r11` | dust 7 am Boden, spark 4; Rückstoß +2 | `bash` |
| `arrow` | - | `arrow2` Flug + `star n4 r7` am Ziel | bone 4 (Knochenziele) oder blood 5, spark 3 | `bow` / `arrow_hit` |
| `bullet` | `muzzle` + `smoke_ring` (+ Mündungsblitz, Wackeln 2 px / 180 ms) | `bullet` Flug (90 ms) + `star n8 r10` | blood 7, spark 5 | `musket` / `arrow_hit` |
| `bite` | - | `bite2` | blood 7 | `bite` |
| `claws` | - | `claws` | blood 6 | `slash` |
| `whip` | - | `whip2` + `star n6 r9` (violett) | water 8, ichor 5 | `tentacle` |
| `stab` | - | `crescent` flach (`a0` -25°, `a1` 15°, `r` 30, `th` 3) + `star n4 r7` (**ungeprüft**; Rückfall `cut`) | blood 6 | `slash` |
| `heal` | `notes` klein am Heiler | `heal2` am Ziel | - | `harp` + `heal` |
| `song_*` | `song` mit `mode` (`war`, `calm`, `wake`, `mock`) | `aura_up` an den Zielen (Krieg, Weck) | - | `warsong` / `harp` |
| `guard` | `dome` (Schildwall) oder `dome sc 0,7` (Deckung) | - | - | `shield` |
| `shout` | zwei `shock r34` orange (Herausforderung `s_ruf`), drei `shock r70` (Horn) | - | - | `clash` / `horn` |
| `rage` | drei Ringe (wie heute) + `aura_up` rot | - | ember 6 | `heartbeat` |
| `summon` | `circle` auf Reihe 0 der Gegner | - | soul 8 | `bones` |
| `ink` | `ink2` (Ziele aus `c.heroes`) | - | - | `ink` |
| `crush` | `shock r60` an jedem Mann, 3 Ringe, Blitz Dunkelrot 0,5 / 0,6 s, Wackeln 6 px / 0,7 s (wie heute) | pro Mann `bash`-Stufe schwer | dust 10 | `kraken_roar` / `tentacle` |

Fertigkeiten -> Bild, vollständig (so übernehmen):
`s_hieb cut`, `s_stoss bash`, `s_wall guard`, `s_deckung guard`, `s_rund cut` (Fläche), `s_ruf shout`,
`a_hieb chop`, `a_spalt cleave`, `a_ansturm chop` (zusätzlich `speed_lines n6` hinter dem Angreifer und Staub), `a_wirbel chop` (zwei Sicheln mit `dir` +1 und -1, ein Treffer je Ziel), `a_spalter cleave` (Stufe +1 in Zahl und Stern), `a_wut rage`,
`b_schuss arrow`, `b_mark arrow` + `reticle` (Zielmarke bleibt, Abschnitt 5), `b_regen arrow` (Fläche, `lod 1`), `b_brand arrow` (Schaft glimmt: ember 4 am Ziel), `b_lahm arrow`, `b_rueck arrow` (+ Staub am Startort),
`k_stab bash`, `k_krieg song_war`, `k_heil heal`, `k_trost song_calm` (+ `heal2` schwach), `k_weck song_wake`, `k_hohn song_mock`,
`m_schuss bullet`, `m_nachladen` (wie heute `reload`), `m_pistole bullet` (kleiner: `star r7`, kein Rauchring), `m_streu bullet` (drei Spuren mit Streuwinkel +-0,12), `m_kopf bullet` + `reticle` (Dauer 450 ms), `m_knall bash` + `muzzle`,
`f_hieb cut`, `f_kralle claws`, `f_pfeil arrow`, `f_klage` (drei Ringe wie heute, r90, plus `soul` 6), `f_stoss bash`, `f_messer stab`, `f_netz cut` (Seile als zwei `ring` bleiben Zukunft), `f_armbrust arrow` (`fl` 0,14), `f_wurf bash`, `f_gabel stab`, `f_hammer chop` + `shock r18`, `f_biss bite`, `f_ramm bash` (schwer),
`f_heilen heal`, `f_deckung guard` (Kuppel in Gegnerrot (0.85,0.45,0.4)), `f_horn shout`, `f_beschwoeren summon`,
`f_kr_peitsche whip`, `f_kr_griff whip` (zusätzlich violetter Ring um den Mann beim Text "gepackt!"), `f_kr_schnabel bite` mit `s` 1,8 + `chop`-Sichel, `f_kr_tinte ink`, `f_kr_quetsch crush`, `f_kr_wuerg bash` mit ichor 6.

Fehlschlag (`miss`): **kein** Stern, kein Einfrieren, kein Wackeln. Hieb: schwache Sichel (`faint`, Alpha 0,3) neben dem Ziel; Pfeil und Kugel fliegen vorbei (wie heute, `arrow2` mit `miss`); Ziel weicht 5 px (Quad Out, 0,3 s); Wort "VERFEHLT" grau, gleitet 8 px seitlich (Abschnitt 4); Klang `whiff`.

### 4. Zahlen und Schrift (`FightFont`, `FightNumbers`)

Atlas `assets/fight_font.png`: **329 x 27 Pixel**, 47 Zeichen (`0-9 + - ! ? % . : x A-Z Ä Ö Ü`), Zelle 7x9 (Glyph 5x7 plus 1 Pixel Rand), Zeile 0 Körper, Zeile 1 Rand (verdicktes Glyph), Zeile 2 untere Hälfte (Zeilen 4 bis 6) für den Farbverlauf. Schritt 6 Pixel je Zeichen, alle Ziffern gleich breit. Gezeichnet wird in drei Durchgängen (alle Ränder, alle Körper, untere Hälfte), sonst übermalt ein Rand den Nachbarn. Das Minuszeichen `−` (U+2212) wird auf `-` abgebildet. Text wird großgeschrieben. **Breite** eines Wortes = `(Zeichen * 6 - 1) * Maßstab` (`KRITISCH!` bei 2: 106 Pixel).

Maßstab: `ns = maxi(1, roundi(k))` für normale Zahlen, `ns + 1` für Krit und Schlagworte (Krit-Schriftzug), Heilung `ns`. Größen bei k = 1: normal 7 px hoch, Krit 14 px.

| Klasse | Text | Farbe Körper / unten / Rand | Maßstab | Besonderes |
|---|---|---|---|---|
| normal (Mann trifft Gegner) | `-14` | Papier (0.96,0.93,0.86) / - / (0.05,0.03,0.04) | ns | |
| empfangen (Gegner trifft Mann) | `-9` | (0.95,0.38,0.32) | ns | |
| schwer (ab 24) | `-27` | (1.0,0.67,0.24) / (0.9,0.43,0.16) | ns | Verlauf |
| Krit | `-31` | (1.0,0.9,0.48) / (1.0,0.58,0.16) / (0.28,0.09,0.02) | ns + 1 | 8 px höher, ±1 px Zittern 4 Bilder (66 ms), 1000 ms sichtbar |
| Blutung, Zustandsschaden | `-3` | (0.75,0.24,0.22), Alpha 0,85 | ns | klein, am Zuganfang des Betroffenen |
| Heilung | `+18` | (0.43,0.86,0.47) | ns | steigt langsam: 800 ms statt 500 ms |
| Streifer | `-3` | grau (0.67,0.67,0.7) | ns | |
| Fehlschlag | `VERFEHLT` | (0.67,0.67,0.7) | 1 | gleitet 8 px zur Seite weg von der Schlagrichtung |
| Block | `BLOCK` | (0.6,0.78,1.0) | ns | mit `block`-Wirkung |
| Widerstand (Mann an der Schwelle hält stand) | `WIDERSTAND` | (0.78,0.88,1.0) | ns | mit Ausatmen, Abschnitt 5 |
| Zustandsworte | `GEPACKT!`, `FREI!`, `SPANNT SICH!`, `UNTERBROCHEN!`, `GEBLENDET`, `RACHE!`, `BESCHWOREN`, `ÜBER BORD!`, `WÄCHST NACH` | Farben wie heute in `_fight_events` | ns, `SPANNT SICH!` und `ÜBER BORD!` ns + 1 | ersetzen die kleingeschriebenen Texte aus `combat.gd` (Anzeige wandelt `text` mit `to_upper()`) |

Ablauf einer Zahl (Anzeigezeit ab Start = t0 + Einfrierdauer): 0 bis 100 ms springt sie von 6 px unter ihrem Ziel auf den Ort (Out-Back: `1 + 2.70158 (u-1)^3 + 1.70158 (u-1)^2`), 100 bis 250 ms steht sie, 250 bis 750 ms steigt sie 12 px (Quad Out; Heilung 800 ms), letzte 150 ms blendet sie aus. Krit: Start 8 px höher, bleibt bis 1000 ms.
Mehrere Zahlen am selben Ziel: 80 ms versetzt, abwechselnd +-6 px seitlich, zusätzlich zufälliger Versatz 0 bis 3 px (feste Reihe, kein `randf`, damit Screenshots stimmen). Ort: **an den Körper** (`hit.y`), nie über dem Namensschild. Zahl und Schriftzug werden **nicht** mit der Kamera gezoomt und **nicht** gewackelt: `FightNumbers.draw(ci, xf)` bekommt die Bühnenmatrix (R3 `actor_xf()`) und rechnet nur den Ort um; die Pixel bleiben ganzzahlig.

Auf hellem Grund (Himmel, Deck) liest sich die Schrift durch ihren Rand (`D3_font_vorschau.png`, `D3_blatt_e.png` untere Reihe: Zahlen auf Blaugrau und Braun lesbar).

### 5. Marken an den Figuren

**5.1 Gezeigte Kraft und Schild-Animation (`FightAnim`).** Der Spielzustand eilt der Anzeige voraus (R1 Befund 1): Kraftbalken fallen vor dem Hieb. `FightAnim` hält je Kämpfer eine **gezeigte Kraft** `shown` und einen **Nachzieher** `trail`:
`hurt(f, n, at)` merkt `shown_target = f.hp` (Endstand), `at = t0`; vor `at` zeigt der Balken `min(f.hp + n, f.hp_max)` (für Männer an der Schwelle und bei Heilung: Endstand ohne Korrektur; ohne die R1-Felder `hp0/hp1` ist das die einzige, aber ausreichende Näherung). Bei `at` springt `shown` auf den Endstand, `trail` bleibt 150 ms stehen und schrumpft dann in 400 ms (Farbe `lightened(0.5)`, bei Männern warmes Weiß). Heilung: `shown` füllt sich in 350 ms, grünes Aufblitzen 120 ms über dem Balken.
Außerdem: Schild des Ziels zittert 120 ms ±1 px waagerecht (30 Hz, nur bei Stufe ≥ 1); Schild des Akteurs hebt sich beim Zugbeginn in 100 ms um 4 px (Cubic Out) und blitzt 1 Bild golden; Schild eines Gefallenen: Balken fällt auf 0, Schild sinkt in 500 ms 3 px und blendet aus. Verzweiflungsbalken ab 70: Alpha pulsiert (2 Hz, 0,65 bis 1,0).

**5.2 Zustandssymbole.** Atlas, Reihenfolge, Farben und Texte unverändert aus R5 (3.1: `assets/status_icons.png`, 108x9, zwölf Symbole zu 9x9, `StatusIcons.ORDER`, höchstens fünf je Schild). Ergänzung der Animation:
* **Aufpoppen:** das Symbol wird beim **Kontakt** des auslösenden Treffers sichtbar (nicht beim Zeichnen des nächsten Bildes): `FightAnim.status_seen(f, list, at)` vergleicht die Liste mit der des letzten Bildes (nur Anzeige, kein neues Ereignis in `combat.gd`, R1 Priorität 3 entfällt damit). Erstes Bild mit `modulate (6,6,6)` (weiß), dann 100 ms von 3 px höher nach unten (Cubic Out); Rundenzahl tickt beim Wechsel mit Weißblitz.
* **Verschwinden:** das Symbol fällt 3 px und blendet in 150 ms aus.
* **Am Körper** (nur Figuren im Licht oder am Zug, höchstens 3 Aufrufe je Zustand): betäubt = drei Sterne kreisen über dem Kopf (Ellipse 10x3, Umlauf 1,2 s); blutet = ein roter Tropfen fällt alle 1,1 s 6 px am Körper; markiert = kleine Fadenkreuz-Ecken (vier Winkel 2 px) um die Brust; Schildwall = blauer Bogen vor der Figur (Alpha 0,5); Kriegslied = gelbes Winkelchen steigt alle 1,5 s; Herausforderung = oranger Ring zuckt am Boden; geblendet = vier violette Punkte auf Kopfhöhe; gelähmt = hellblaue Zackenlinie 2 px.
Tooltip und Kurzkarte bleiben bei R5.

**5.3 Zugleiste mit Porträts (Wucht-Teil).** Maße, Kopfausschnitt (14x14 aus `combat.png`: `Rect2(15, Zeile * 56 + 9, 14, 14)`), Seitenstreifen und Kraftstrich unverändert aus R5 (3.3). Ergänzungen:
Der Eintrag des Akteurs pulst **zweimal** beim Zugbeginn (Rahmen Gold, Alpha 0,6 bis 1,0, 220 ms je Puls); Überfahren eines Eintrags zeichnet einen weißen Ring (Ellipse unter den Füßen, 1 px) um die Figur; Eintrag eines Gefallenen: Porträt grau und durchgestrichen (zwei Pixel diagonal), bleibt bis Rundenende; ein neu Beschworener schiebt sich mit 100 ms von rechts hinein. Mit Figurenzellen aus dem Entwurf Figuren liefert `FigArt.portrait(kind) -> {tex, src}` den Ausschnitt (Rückfall: R5-Rechteck).

**5.4 Zielmarke und Fadenkreuz.**
* **Zielwahl** (Fertigkeit gewählt, `fight_click`/`fight_key` warten auf Ziel): gültige Ziele wie R5 2.5 (pulsierende Ellipse, Taste Q W E R, Trefferchance). Zusätzlich auf dem Ziel unter der Maus oder mit der letzten Taste (`reticle_hold`): Ring r = 15 k, dreht mit 0,5 rad/s, vier Marken, Gegner rot (0.95,0.3,0.25), Verbündete grün; **ein** Ring je Bild. Beim Aktivieren (Klick/Taste) rastet es ein: `FightFx.add("reticle", ..., 0.0, 0.45)`: Ring schnurrt in 200 ms (= vor dem Kontakt bei 0,2 s) auf r, weißer Ring, 2 px, Klang `lock`. Das Einrasten gibt es **nur** bei Präzisionsfertigkeiten (`b_mark`, `m_kopf`) und bei Zielwahl; gewöhnliche Schüsse kennen es nicht (Leiter, nicht jedes Mal).
* **Fläche:** statt des Rings vier Eckwinkel (2 px) an allen gültigen Zielen, Alpha 0,7.
* **Markiert** (Zustand): dauerhaft die kleinen Eckwinkel um die Brust, rot, Alpha 0,8.
* Klickflächen: unverändert (R5 2.5, R3 4.6: `xf * rect`).

**5.5 Rand an der Schwelle und Herzschlag.** Zustand: lebender Mann mit `door == true`. Der Rand liegt nur auf der Bühne (nicht auf Leiste und Karten), sechs Bänder von 4 px links und rechts, 3 px oben und unten, Farbe (0.62,0.02,0.05), Alpha `a * (1 - i/6)^1.4`, 24 Rechtecke je Bild.
`a(t) = base + amp * heart(t)`, `heart(t)` = Lub-Dub (`max(exp(-((ph)/0.07)^2), 0.65*exp(-((ph-0.28)/0.08)^2))`, `ph = fmod(t * bpm/60, 1)`). Ein Mann an der Schwelle: `base 0,06`, `amp 0,20`, 60 Schläge/min. Jeder weitere +0,06 `amp` (höchstens 0,32). Ist der Mann am Zug: `amp * 1,4`, 70 Schläge/min. Zeit = Anzeigezeit (Einfrieren hält den Puls, Zeitlupe dehnt ihn).
Ton nur an drei Stellen: (1) Zugbeginn des Mannes: `heartbeat` -9 dB, Tonhöhe 0,85 (zwei Schläge im Klang); (2) Treffer auf einen Mann, der schon vorher an der Schwelle war (`FightAnim` merkt `door_prev`): lebt er danach noch = **Widerstand**: weißer Blitz auf dem Sprite (100 ms), Wort `WIDERSTAND`, Klang `exhale`, Rand ×1,6 für 600 ms; stirbt er = Todesstoß (Abschnitt 6); (3) Erreichen der Schwelle (`door` neu wahr, nicht gefallen): Wort `SCHWELLE!` rot, zwei Schläge `heartbeat`, Rand ×1,6 für 1 s. Sonst still.

**5.6 Rundentrommel.** Wechselt `c.round_no` (Vergleich je Bild in `FightAnim`), läuft `Sfx round_drum` (-4 dB) und die Schrift `RUNDE n` (Maßstab 2, Gold (0.9,0.75,0.35), Rand (0.1,0.06,0.03)) steht 900 ms mittig bei y = 30, ohne Pause, ohne Abdunkeln. Nicht in Runde 1 (dort kommt die Einleitung) und nicht, solange eine große Ansage läuft.

### 6. Todeseffekte (`FxPose`, `FightAnim.dying`)

Statt der heutigen rot getönten Trefferpose, die ausblendet (`_ghosts`), startet bei `die` ein Todesbild je Materialgruppe (`FightImpact.death_kind(f)`):

| Gruppe | Figuren | Ablauf (Anzeigezeit ab Tod = Ende des tödlichen Treffers) | Teilchen | Töne |
|---|---|---|---|---|
| `crumble` (Zerfall) | rost, bogner, totenwart, waechter, priester, beschwoerer, knochen | `FxPose.crumble`: 14 Bänder zu 4 px, von oben nach unten je 30 ms später, jedes dreht seitlich (sin(i·2,3)·7 px · q²) und sinkt (12 px · q²), Alpha 1 - q² (Band-Dauer 450 ms); nach 500 ms bleiben fünf kleine Knochenreste 400 ms liegen; gesamt 0,8 s | bone 12, dust 8 (ab +100 ms), soul 4 (ab +150 ms; Totenwart, Priester, Beschwörer: 8) | `hit_bone` bei 0, `crumble` bei +100 ms |
| `fall` (Sturz) | brecher, messerkerl, schuetze, haken, wache, armbrust, kaufmann, bauer, schmied, antreiber, kraeuterfrau, hund, alle Männer | `FxPose.fall`: Zeilenband-Scherung (2 Zeilen je Band), Kopf geht 20 px weg vom Angreifer, Körper sinkt 6 px, Tönung in 0,17 s zu Rot, Dauer 0,36 s; danach liegt er 0,35 s (Tönung (1.4,0.65,0.6)), blendet in 0,45 s aus; gesamt 1,16 s. Später (Entwurf Figuren) ersetzt der Frame `fall_0..2` und `dead` die Scherung | blood 10 (+Fleck), dust 6 bei +300 ms; Mann: soul 3; Kaufmann: coin 6 | `fall`, bei Mann `death` |
| `sink` (Absinken) | tentakel | Sprite wird von unten abgeschnitten (Sinkhöhe 56 px in 0,7 s, Quad In), Wassersäule | water 10, ichor 6; Ring `shock r30` auf dem Deck | `tentacle`, `splash` |
| `kraken` | kraken | Blitz Weiß 0,6 s Alpha 0,3 (wie heute), Wackeln 7 px / 0,7 s, Sprite sinkt 88 px in 1,2 s, drei `shock`-Ringe r60 bei 0 / 150 / 300 ms; alle anderen Gegner fallen gleichzeitig mit ihrer Gruppe (R1 2.4) | water 24, ichor 14 (Teilchen-Obergrenze 160 bleibt) | `kraken_roar` Tonhöhe 0,7 -4 dB, `splash` |

Der Todesstoß (`power 4`) schiebt davor: Standbild 100 ms, Zeitlupe 0,35 für 450 ms (Regie darf **vor** den Kontakt vorziehen, die Anzeige kennt `die`), Wackeln 5 px / 400 ms, weißer Frame 100 ms. Zwei von drei Gegnertoden je Kampf bekommen nur die kleine Fassung (Standbild 60 ms, keine Zeitlupe; Ermüdung, R4); der letzte Gegner und jeder Mann bekommen die große.
Tod eines Mannes zusätzlich: Verzweiflungs-Rand ×1,6 für 600 ms vergeht, `GEFALLEN` (große Ansage, Regie) bleibt unverändert.

### 7. Töne (Schichtung)

Pro Kontakt starten höchstens **vier** Klänge, jeder aus einem anderen Wavefile (so greift `MIN_GAP` 0,12 s nicht gegeneinander):

1. **Basis** wie heute: `Sfx.skill_sound(sk, "hit")`, 0 dB (Krit heute +2 dB entfällt, dafür Schicht 4).
2. **Materialschicht** bei t0 + 15 ms, -9 dB (Material des Ziels aus `FightImpact.material(f)`): Fleisch (Männer, Räuber, Händler, Dorf, Hund) `hit_wet`; Knochen (Draugr-Gruppe) `hit_bone`; Metall (Ziel mit `guard > 0`, Schiffswache, Grabwächter, Schildträger) `hit_ring` -10 dB; Fangarm und Kraken: keine (Basis `tentacle` genügt).
3. **Schwer** (Stufe ≥ 2): `hit_sub` -6 dB bei t0.
4. **Krit** (Stufe 3 und 4): `crit` -3 dB bei t0 und `clash` -6 dB bei t0 + 20 ms; Todesstoß zusätzlich `death` bei t0 + 100 ms.
Tonhöhe: Basis wie heute (zufällig 0,95 bis 1,05); Schichten feste 1,0; in der Zeitlupe `pitch = max(time_scale, 0,7)` für Wirkungsklänge, Musik bleibt (Regie). Ausholen: nur `swing` bei Nahkampf (wie heute); `whoosh` nur bei Kamerafahrt (Regie ruft, > 40 px). Töne werden zum Zeitpunkt des Eintreffens des Ereignisses mit `delay = hw` geplant (wie heute); der Versatz in der Zeitlupe nach einem Krit ist **nicht** korrigiert (R1 4.3, bekannt, kein neuer Fehler).
`GAIN` bekommt die zehn neuen Klänge (Abschnitt "Erzeugte Bilder und Töne").

### 8. Zeichenbudget und Betriebsarten

* Wirkungen (alle `FightFx`-Items + Teilchen + Zahlen): höchstens **350 Zeichenaufrufe je Bild** (Messung: `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` im Foto-Lauf, R3 2.7: Grundlast 108 bis 188). Teilchen: Obergrenze 160 + 40 Flecken (feste Obergrenze im Code). Items: Obergrenze 120 (heute 80).
* Schätzung je Einschlagbild (Aufrufe): `crescent` 24 (`lod 1`: 16), `shock` 14, `star` 2, `speed_lines` 10, `crit_text` 27 bei Maßstab 2, Zahl 9, Teilchen bis 160. Schlimmster Fall: Kraken-Quetschen auf vier Männer (4 x (`shock` 14 + Zahl 9) + Teilchen 100 = 230) plus Zusätze: unter 350.
* `FightFx.lod`: 0 voll; 1 (mehr als 2 Ziele in einer Aktion oder mehr als 12 frische Ereignisse): halbe Sichelschritte, keine Staubringe, Teilchen ×0,5; 2 (mehr als 24 frische Ereignisse, das heutige `loud == false`): **keine** neuen Wirkungen, nur Zahlen. Im Schnellmodus, bei Bots und headless wird `FightImpact` **nie aufgerufen** (die Kampfansicht wird nicht gezeichnet), `FightFx.particles.tick` auf leerer Liste kostet nichts.
* Pixelraster: alle Orte `roundf`, Polygone auf `.round()`, Winkel der Sichel frei (Vierecke, nie gedrehte Pixel); Teilchen ganzzahlig 1 bis 3 px. Zahlen ganzzahlig skaliert.

---

## Schnittstellen

Alle neuen Klassen sind `RefCounted` mit `static`-Zeichnern, die das `Hud` (CanvasItem) übergeben bekommen, wie `FightFx.draw(ci)` und `SlotView.draw(hud, mouse)`. Nirgends `await`, Timer oder Zufall (`FxParticles` hat einen eigenen `RandomNumberGenerator` mit festem Seed 7: Screenshots stimmen).

### Neue Klassen

```gdscript
# scripts/fx_kinds.gd  (liegt fertig in der Arbeitskopie, 506 Zeilen)
class_name FxKinds extends RefCounted
const KINDS := ["crescent", "cleave", "shock", "arrow2", "star", "smoke_ring", "reticle", "claws", "bite2", "whip2", "heal2",
	"song", "aura_up", "dome", "block", "ink2", "circle", "speed_lines", "crit_text"]
static func draw(ci: CanvasItem, kind: String, it: Dictionary, u: float) -> bool   # false = unbekannte Art

# scripts/fx_particles.gd  (fertig, 107 Zeilen)
class_name FxParticles extends RefCounted
const MAX := 160 ; const MAX_STAINS := 40 ; const PRESETS := {blood, ichor, spark, splinter, bone, ember, water, dust, soul, coin}
var budget := 1.0 ; var floor_y := 122.0 ; var size_mul := 1   # size_mul NEU: Teilchengröße bei k >= 2
func emit(kind: String, at: Vector2, dir: float, count: int, k: float = 1.0, wait: float = 0.0) -> void
func tick(dt: float) -> void
func draw_stains(ci: CanvasItem) -> void     # UNTER den Figuren
func draw(ci: CanvasItem) -> void            # über den Figuren
func clear() -> void

# scripts/fx_pose.gd  (fertig, 66 Zeilen)
class_name FxPose extends RefCounted
const RECOIL := [2.0, 4.0, 6.0, 9.0] ; const FLASH := [0.033, 0.05, 0.066, 0.1]    # NEU: Stufe 4 benutzt Index 3
static func hit(t: float, power: int, dir: float, k: float = 1.0, frozen: bool = false) -> Dictionary   # {dx, tint, col, active, split}
static func crumble(ci, tex, src: Rect2, dst: Vector2, u: float, dir: float) -> void
static func fall(ci, tex, src: Rect2, dst: Vector2, u: float, dir: float) -> void
static func sink(ci, tex, src: Rect2, dst: Vector2, u: float) -> void       # NEU: Abschneiden von unten, Quad In
static func heart(t: float, bpm: float = 60.0) -> float                     # NEU (aus proto_wucht.gd, mit bpm)

# scripts/fight_font.gd  (fertig, 51 Zeilen)
class_name FightFont extends RefCounted
const GLYPHS := "0123456789+-!?%.:xABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ" ; const CW := 7 ; const CH := 9 ; const STEP := 6
static func texture() -> Texture2D                  # null headless
static func width(text: String, scale: int = 1) -> int
static func draw(ci: CanvasItem, text: String, pos: Vector2, scale: int, body: Color, low := Color(0,0,0,0), rim := Color(0.05,0.03,0.04,1)) -> void

# scripts/fight_numbers.gd  NEU
class_name FightNumbers extends RefCounted
var list: Array = []        # {text, cls, at (Bühnenpunkt), age (negativ = wartet), dur, side_off, scale}
func add(cls: String, text: String, at: Vector2, wait: float, k: float = 1.0) -> void   # cls: normal|taken|heavy|crit|bleed|heal|graze|miss|block|resist|word
func tick(dt: float) -> void                         # Anzeigezeit
func draw(ci: CanvasItem, xf: Transform2D) -> void   # xf = Bühne -> Bild (Identität ohne Bühne)
func clear() -> void

# scripts/fight_impact.gd  NEU: reine Entscheidungen plus die Aufrufe an FightFx (die Tabelle LOOK/LOOKS)
class_name FightImpact extends RefCounted
enum Power { GRAZE, NORMAL, HEAVY, CRIT, KILL }
const LOOK := {}      # Fertigkeits-Id -> Bildname (Abschnitt 3); jede Id aus FightFx.SKILL_FX muss vorkommen
const LOOKS := {}     # Bildname -> {"go": Array, "hit": Array} Aufruflisten
static func power(dmg: int, crit: bool, lethal: bool) -> int
static func plan(power: int, look: String, lod: int, strength: float = 1.0) -> Dictionary
	# {"white": s, "freeze": s, "slow_f": f, "slow_d": s, "recoil": px, "split": bool, "shake_amp": px, "shake_dur": s, "flash_a": a, "flash_d": s,
	#  "zoom": amp, "blood": n, "spark": n, "stage_s": Sekunden Zuschlag an den Takt}   # reine Zahlen, headless prüfbar
static func material(f: Combat.Fighter) -> String       # "flesh" | "bone" | "metal" | "ichor"
static func death_kind(f: Combat.Fighter) -> String     # "crumble" | "fall" | "sink" | "kraken"
static func hit(fx: FightFx, nums: FightNumbers, ctx: Dictionary, sk: String, power: int, tgt: Combat.Fighter, dmg: int) -> Dictionary   # gibt plan() zurück
static func go(fx: FightFx, ctx: Dictionary, sk: String, tgts: Array) -> void      # Ausholen: Mündungsfeuer, Lied, Kuppel, Kreis ...
static func miss(fx: FightFx, nums: FightNumbers, ctx: Dictionary, sk: String) -> void
static func sounds(sk: String, power: int, tgt: Combat.Fighter, wait: float, crit: bool) -> Array   # [[name, db, delay, pitch], ...], höchstens 4

# scripts/fight_anim.gd  NEU: Anzeigewerte je Kämpfer (Besitzer: Hud, eine Instanz)
class_name FightAnim extends RefCounted
func reset(c: Combat) -> void                  # bei neuem Kampf und am Kampfende (löscht Verweise auf Fighter)
func hurt(f: Combat.Fighter, n: float, at: float) -> void      # Balken: gezeigte Kraft, Nachzieher, Schildzittern
func heal(f: Combat.Fighter, at: float) -> void
func sync(c: Combat, dt: float) -> void        # je Bild: Rundenwechsel, door_prev, Zustandsvergleich, Herzpuls; löst Klänge und Worte aus
func shown_hp(f) -> float ; func trail_hp(f) -> float
func status_age(f, name: String) -> float      # < 0 nicht vorhanden; 0 bis 0,12 poppt
func turn_pulse(f) -> float                    # 0..1 für Zugleiste und Schild
func edge() -> float                           # Stärke des Schwellenrands 0..1 (Anzeige zeichnet FightMarks.draw_edge)
func start_death(f: Combat.Fighter, kind: String, dir: float, at: float) -> void
func dying() -> Array                          # {f, kind, t, dir, cx}
func tick(dt: float) -> void

# scripts/fight_marks.gd  NEU: Zeichner der Marken (Statuskörperzeichen, Zielmarke, Herzrand)
class_name FightMarks extends RefCounted
static func draw_status_body(ci, f: Combat.Fighter, head: Vector2, t: float, k: float) -> void
static func draw_target(ci, pos: Vector2, key: String, chance: int, ally: bool, hold: bool, t: float, k: float) -> void
static func draw_area_marks(ci, pos: Vector2, t: float, k: float) -> void
static func draw_edge(ci, strength: float, stage: Rect2) -> void          # 24 Rechtecke
```

### Änderungen an bestehenden Klassen

```gdscript
# fight_fx.gd
var particles := FxParticles.new()       # fertig im Prototyp
var lod := 0                             # 0 voll, 1 reduziert, 2 nur Zahlen; setzt das Hud je Bild aus der Zahl frischer Ereignisse
var shake_axis := Vector2.ZERO           # NEU: shake(amp, dur, axis := Vector2.ZERO): die ersten 40 % der Dauer schwingt offset() entlang axis
func draw_under(ci: CanvasItem) -> void  # Flecken unter die Figuren (fertig)
# in draw(): _: FxKinds.draw(ci, kind, it, u) ; am Ende particles.draw(ci) ; items-Grenze 120 ; clear() leert particles ; tick() ruft particles.tick(delta)
func show_banner(skill_name, who, side, icon := "", dur := 1.25) -> void   # dur NEU, Regie kürzt auf 0,4 s
```
`SKILL_FX` bleibt unverändert (Wahrheit für `is_flight`, `lunges`, `go_fx`, `hit_fx`); `LOOK` ergänzt sie.

```gdscript
# sfx.gd
GAIN += {"whoosh": -9.0, "crit": -3.0, "round_drum": -4.0, "hit_wet": -9.0, "hit_sub": -6.0, "hit_ring": -10.0, "hit_bone": -9.0, "crumble": -6.0, "lock": -9.0, "exhale": -8.0}
# (keine Änderung an Sfx.play, skill_sound, MIN_GAP)
```

### Wer ruft wen (alles in der gezeigten Kampfansicht, nie im Schnellmodus)

```
Hud._fight_events(c)                      (läuft in _draw, R1 Risiko R7)
  attack  -> FightImpact.go(_fx, ctx, sk, tgts)          ; _anim (Pose, Ausfall) wie heute
  hit     -> p = FightImpact.power(n, crit, lethal)      ; plan = FightImpact.hit(_fx, _nums, ctx, sk, p, who, n)
             _anim_state.hurt(who, n, hw)                ; Sfx-Schichten: for s in FightImpact.sounds(...): Sfx.play(s[0], s[1], s[2], s[3])
             Regie bekommt plan["stage_s"] und plan["freeze"] (Takt, Fokus, Kamera)
  miss    -> FightImpact.miss(...)
  heal    -> FightImpact.go-Teil "heal" am Ziel ; _anim_state.heal(who, 0.25)
  die     -> _anim_state.start_death(who, FightImpact.death_kind(who), dir, hold)   (ersetzt _ghosts-Eintrag)
  text/heroic/snap/spawn/overboard -> _nums.add("word", ...)  (Großschreibung, Klassen aus Abschnitt 4)
Hud._tick_fight(delta)    -> _fx.tick (inkl. particles) ; _nums.tick ; _anim_state.tick ; _anim_state.sync(c, dt)
Hud._draw_fight_overlay   -> _fx.draw_under(self) [vor den Figuren] ; Figuren (Trefferpose aus FxPose.hit / dying aus _anim_state.dying()) ;
                             _fx.draw(self) [Wirkung + Teilchen] ; FightMarks.draw_edge ; _nums.draw(self, stage_xf)
Hud._draw_fighter         -> Schild über FightAnim.shown_hp/trail_hp/status_age/turn_pulse ; FightMarks.draw_status_body ; FightMarks.draw_target
```

`ctx` (Wörterbuch, gebaut von `Hud._fx_ctx(f_att, f_tgt)`; **die einzige Stelle**, die Figurenmaße kennt):
`{"hit": Vector2 Brust des Ziels, "head": Vector2, "feet": Vector2, "src": Vector2 Brust des Angreifers, "hand": Vector2, "dir": ±1, "k": Maßstab, "wait": hw, "tgts": Array[Vector2]}`.
Heute: `hit = (fig_x, FIGHT_FEET - 30)`, `head = (fig_x, FIGHT_FEET - 48)`, `feet = (fig_x, FIGHT_FEET)`, `k = 1`. Mit Rig-Figuren (Entwurf Figuren, Anker aus `assets/fig/anker.json`) kommen `hit`, `head` und `hand` aus dem Rig; `FightImpact` ändert sich dabei nicht.

---

## Dateien

| Datei | Neu / geändert | Besitzer | Inhalt |
|---|---|---|---|
| `scripts/fx_kinds.gd` | neu (liegt fertig in `_sandbox\wucht`) | Wucht | Zeichner der 19 neuen Wirkungsarten |
| `scripts/fx_particles.gd` | neu (fertig) | Wucht | Teilchen und Flecken |
| `scripts/fx_pose.gd` | neu (fertig, plus `sink`, `heart(bpm)`) | Wucht | Trefferpose, Zerfall, Sturz, Absinken |
| `scripts/fight_font.gd` | neu (fertig) | Wucht | Zeichnen der Wucht-Schrift |
| `scripts/fight_numbers.gd` | neu | Wucht | Schwebende Zahlen und Schlagworte (ersetzt `Hud._floats`) |
| `scripts/fight_impact.gd` | neu | Wucht | Stufen, `plan`, Tabellen `LOOK`/`LOOKS`, Materialien, Töne-Schichtung, Aufrufe an `FightFx` |
| `scripts/fight_anim.gd` | neu | Wucht | gezeigte Kraft, Nachzieher, Zustandsvergleich, Runden- und Schwellenerkennung, Todesliste |
| `scripts/fight_marks.gd` | neu | Wucht | Zustandszeichen am Körper, Zielmarke, Flächenmarken, Herzrand |
| `scripts/fx_sheet.gd` | neu (aus `proto_wucht.gd`, Namen geändert) | Wucht | Wirkungsblätter als Prüfstand (`--fxsheet=a|b|c|d|e`), nie im Spiel erreichbar |
| `scripts/status_icons.gd` | neu, übernommen aus R5 (`R5_proto_status_icons.gd.txt`) | R5 Oberfläche | Atlas lesen, `draw`, `draw_big`; Wucht ergänzt nur `draw_pop(h, pos, name, age)` |
| `scripts/fight_fx.gd` | geändert (siehe Schnittstellen, rund 40 Zeilen) | Wucht (Datei), Regie hängt `hold`/`banner dur` an | |
| `scripts/hud.gd` | geändert: `_fx_go`, `_fx_hit`, `_fx_miss`, die Zweige `hit`/`miss`/`heal`/`die`/`text` in `_fight_events`, `_tick_fight`, `_draw_fight_overlay`, `_draw_fighter` (nur die Aufrufe, nicht das Layout) | **gemeinsam**: Wucht liefert die Aufrufe, Regie und R5 besitzen den Rest. Vor dem Einbau Stand der anderen Entwürfe abgleichen; `_floats` und `_ghosts` fallen weg | |
| `scripts/sfx.gd` | geändert: `GAIN` (10 Zeilen) | Wucht | |
| `scripts/main.gd` | geändert: Flag `--fxsheet=...` (6 Zeilen), `--shotwucht` (siehe Akzeptanzkriterien) | Wucht | |
| `tools/make_fight_font.py` | neu (aus `docs/kampf_spektakel/D3_make_fight_font.py`) | Wucht | erzeugt `assets/fight_font.png`; Vorschau `--preview` |
| `tools/make_sfx.py` | geändert: zehn Funktionen, `SOUNDS` **am Ende** ergänzt | Wucht | siehe unten |
| `assets/fight_font.png` | neu (generiert) | Wucht | 329x27 |
| `assets/sfx/*.wav` | zehn neue (generiert) | Wucht | siehe unten |
| `assets/status_icons.png` | neu (generiert) | R5 Oberfläche | `docs/kampf_spektakel/R5_statussymbole.py` |
| `tools/selftest.gd` | geändert: ein Block mit Präfix `wu_` | Wucht | Abschnitt "Akzeptanzkriterien" |
| `tools/sfxtest.gd` | geändert: Liste der neuen Klänge | Wucht | |

Reihenfolge des Einbaus (jeder Schritt einzeln testbar, danach `rungd.ps1 -Script import`, `selftest`, ein Foto): (1) Schrift und `FightNumbers` (Zahlen ersetzen `_floats`); (2) Teilchen und Trefferpose; (3) `FxKinds` und `LOOK`-Tabelle, ein Bild nach dem anderen (Hieb, Axt, Stoß, Pfeil, Kugel, dann Rest); (4) Todesbilder; (5) Töne; (6) `FightAnim`, Marken, Herzrand, Zugleiste.

---

## Erzeugte Bilder und Töne

### Bilder (Python, nur Standardbibliothek, `Img` aus `tools/make_art.py`)

| Datei | Größe | Erzeuger | Inhalt |
|---|---|---|---|
| `assets/fight_font.png` | 329 x 27 (47 Glyphen zu 7 x 9, drei Zeilen: Körper, Rand, untere Hälfte), ca. 1 KB | `python -X utf8 -I tools/make_fight_font.py [--preview ordner/b.png]` | Wucht-Schrift; Glyphen als Textraster im Skript (5x7), Rand = verdicktes Glyph |
| `assets/status_icons.png` | 108 x 9 (12 Symbole zu 9 x 9) | `python -X utf8 -I tools/make_status_icons.py` (aus `R5_statussymbole.py`) | Zustandssymbole, nicht von Wucht gezeichnet |

Alle übrigen Wirkungen entstehen im Spiel aus Code (Linien, Polygone, Teilchen); **keine** weiteren Bilddateien. Die Figuren-Posen (Treffer, Sturz) kommen aus dem Entwurf Figuren, bis dahin aus `combat.png` mit `FxPose`.

### Töne (`tools/make_sfx.py`, 44,1 kHz, mono, 16 Bit)

Neue Funktionen stehen in `SOUNDS` **hinter `slot_stack`**. Das Skript nutzt einen globalen Zufallsgeber (`random.seed(7)`) und erzeugt alle Klänge in Reihenfolge; wer am Ende anhängt, ändert keinen vorhandenen Klang. Jede Funktion benutzt nur die vorhandenen Bausteine (`osc`, `noise`, `filt`, `sweep`, `env`, `decay`, `smooth`, `mix`, `gain`, `delay`). Größen: Dauer x 88 200 Bytes.

| Datei | Dauer / Größe | Erzeugungsidee | Spitze (SOUNDS) | `GAIN` | Einsatz |
|---|---|---|---|---|---|
| `whoosh.wav` | 0,28 s, 25 KB | `sweep(noise(0.28), "bp", lambda t: 400 + 2600*smooth(t,0,0.13) - 1800*smooth(t,0.13,0.28), 1.4)`, Hüllkurve `smooth(t,0,0.05) * (1 - smooth(t,0.14,0.28))`; darunter ein leiser Sinus 90 Hz | 0,55 | -9 | Kamerafahrt (Regie), Ansturm |
| `crit.wav` | 0,8 s, 71 KB | Glockenteiltöne wie `s_clash`, aber höher und kürzer: `1480 Hz * (1, 2.0, 3.01, 4.2)`, tau 0,25 / 0,18 / 0,12 / 0,08; dazu Sub-Schlag `osc("sine", 70 -> 40 Hz in 0,15 s)` tau 0,22; dazu Schimmer `filt(noise, "hp", 6000)` mit `smooth(t,0,0.1) * decay(0.12)` | 0,85 | -3 | Krit, Todesstoß |
| `round_drum.wav` | 0,9 s, 79 KB | zwei Bodentrommel-Schläge bei 0 und 0,22 s (zweiter 8 % höher): Sinus 95 -> 62 Hz tau 0,16, Fellklick `filt(noise,"lp",700)` tau 0,02, Fellton `filt(noise,"bp",220,3.0)` tau 0,2 | 0,8 | -4 | Rundenwechsel |
| `hit_wet.wav` | 0,3 s, 26 KB | `filt(noise,"lp",1100,0.9)` tau 0,05 + Sinus 90 -> 50 Hz tau 0,05 + kurzes `hp`-Zischen 3 kHz tau 0,01 (Nässe) | 0,6 | -9 | Schicht Fleisch |
| `hit_sub.wav` | 0,5 s, 44 KB | Sinus 55 -> 32 Hz in 0,15 s, tau 0,18, durch `lp 120`, weicher Einsatz 5 ms | 0,8 | -6 | Schicht schwer, Krit |
| `hit_ring.wav` | 0,3 s, 26 KB | zwei Teiltöne 3100 und 4700 Hz tau 0,04 und 0,03 + `filt(noise,"hp",5000)` tau 0,008 | 0,55 | -10 | Schicht Metall, Block |
| `hit_bone.wav` | 0,25 s, 22 KB | drei Klacks bei 0 / 25 / 60 ms: `filt(noise,"bp",1800,2.0)` tau 0,012, Sinus 400 Hz tau 0,02 | 0,6 | -9 | Schicht Knochen |
| `crumble.wav` | 0,7 s, 62 KB | Rieseln: 22 kleine Klicks (`filt(noise,"hp",2500)`, tau 0,006) in zufälligen Abständen, Dichte fällt mit `exp(-t/0.3)`; darunter `filt(noise,"lp",200)` Rumpeln, Einsatz 0,05 s | 0,6 | -6 | Zerfall |
| `lock.wav` | 0,18 s, 16 KB | zwei Klicks: Rechteck 1,2 kHz tau 0,015 bei 0, dann Sinus 2,4 kHz tau 0,05 bei 0,07 s | 0,5 | -9 | Fadenkreuz rastet ein |
| `exhale.wav` | 0,6 s, 53 KB | Atem: `sweep(noise(0.6), "lp", lambda t: 2400 - 1800*smooth(t,0,0.5), 0.8)` mit Hüllkurve `smooth(t,0,0.12) * (1 - smooth(t,0.25,0.6))` | 0,5 | -8 | Widerstand an der Schwelle |

Summe rund 424 KB. Der Herzschlag-Klang ist **kein** neuer Klang: `heartbeat.wav` (0,7 s, Lub-Dub) mit Tonhöhe 0,85 (`Sfx.play("heartbeat", -9, 0, 0.85)`). Totenklage, Horn, Beschwörung, Kraken, Splash, Sturz (`fall`) und Tod (`death`) bleiben vorhandene Klänge.

---

## Akzeptanzkriterien

**A. Tests, ohne Fenster** (`rungd.ps1 -Script tools/selftest.gd` muss `FEHLER: 0` melden; neuer Block `wu_`):

1. Jede Fertigkeits-Id aus `FightFx.SKILL_FX` hat einen Eintrag in `FightImpact.LOOK`, und jeder Wert steht in `LOOKS`. Jede Fertigkeits-Id aus `Roles.SKILLS` (wie der bestehende Test zu `Sfx.SKILL_SND`) hat eine.
2. `FightImpact.plan(p, look, lod)` ist für `p = 0..4` monoton in `freeze`, `recoil`, `shake_amp`, `blood`; `stage_s` höchstens 0,1 für Stufe 0 bis 2, 0,4 für 3, 0,7 für 4; `plan(..., lod = 2)` liefert `blood = 0`, `spark = 0`.
3. `FightImpact.power(5, false, false) == GRAZE`, `power(10, false, false) == NORMAL`, `power(24, false, false) == HEAVY`, `power(3, true, false) == CRIT`, `power(3, true, true) == KILL`.
4. `FxParticles`: 1000 Mal `emit` ergibt `list.size() <= 160`; nach `tick(20.0)` sind `list` und `stains` leer; `tick` wirft nichts auf leerer Liste.
5. `FightFont.width("KRITISCH!", 2) == 106`; jedes Zeichen der festen Wortliste (`KRITISCH! VERFEHLT BLOCK WIDERSTAND GEPACKT! FREI! SPANNT SICH! UNTERBROCHEN! GEBLENDET RACHE! BESCHWOREN ÜBER BORD! WÄCHST NACH RUNDE SCHWELLE! GEFALLEN` und alle Ziffern) kommt in `FightFont.GLYPHS` vor.
6. `FightFont.texture()` liefert headless `null` und stürzt nicht.
7. `FightNumbers`: `add` und `tick` laufen headless (kein `draw`); nach `tick(3.0)` ist `list` leer.
8. `FightAnim.hurt(f, 12, 0.2)`: `shown_hp(f) == min(f.hp + 12, f.hp_max)` vor `tick(0.2)`, danach `== f.hp`; `trail_hp` fällt innerhalb 0,6 s auf `f.hp`.
9. `FightImpact.death_kind`: `"knochen"` -> `crumble`, `"brecher"` -> `fall`, `"tentakel"` -> `sink`, `"kraken"` -> `kraken`, Mann -> `fall`.
10. Tonlisten: `FightImpact.sounds("a_hieb", 3, flesh_target, 0.2, true)` hat höchstens 4 Einträge, nur Namen aus `Sfx.GAIN`; `sfxtest.gd` meldet `FEHLER: 0` und findet alle zehn neuen `.wav`.
11. **Schnellmodus und Bots unverändert:** `runbots.ps1 -Mode --autoplay -Seeds @(1,2,3)` und `-Mode --random` ohne Fehlerzeilen; Gesamtzeit höchstens 5 % über dem Ausgangswert; Logik-Prüfsumme der 200 Kämpfe (R1, `3356533480`) unverändert (`combat.gd` wird nicht angefasst). Im Code: kein Aufruf von `FightImpact`/`FightNumbers`/`FightAnim` außerhalb von `Hud._draw*`, `_fight_events` und `_tick_fight`; `rungd.ps1 -Script tools/selftest.gd` mit `voy.auto_combat = true` ruft sie nie.
12. `musictest.gd` und `sfxtest.gd`: `FEHLER: 0`.

**B. Bildschirmfotos** (`shot.ps1`, Bild mit dem Read-Werkzeug ansehen; Pass/Fail am Bild):

13. `--fxsheet=a` (Hieb, Axt, Spalt, Stoß): in jeder Zeile ist im dritten Bild (t0) der weiße Frame, der Stern und der Teilchenstrahl zu sehen; im Stoß-Bild ein Ring und ein flacher Staubring am Boden; im letzten Bild nur noch Flecken auf dem Boden. (Beleg: `D3_blatt_a.png`.)
14. `--fxsheet=b`: der Pfeil trägt im Flug eine Spur, steckt später im Ziel; die Kugel hat Mündungsfeuer, Rauchring und Spur; Biss zeigt beide Kiefer; Peitsche zeigt eine gewellte Linie (Beleg: `D3_blatt_b.png`).
15. `--fxsheet=c`: Heilsäule **deutlich** sichtbar (Alpha angehoben), Lied mit Bögen und Winkeln, Kuppel mit Block-Funken, Tinte mit **hellem Rand** und auf dem Deck unterscheidbar (Beleg des Mangels: `D3_blatt_c.png` zeigt sie noch zu blass).
16. `--fxsheet=d`: Krit-Starburst `r` 22 lässt Kopf und Waffe des Ziels erkennbar (Beleg: `D3_blatt_d2.png`); "KRITISCH!" liegt **über** der Zahl und überdeckt sie nicht; Trefferpose zeigt den Spalt von 2 px; Zerfall hinterlässt am Ende Reste und Flecken.
17. `--fxsheet=e`: Fadenkreuz im ersten Bild rot und groß, im zweiten weiß und eingerastet; Zahlenklassen unterscheidbar; der Rand pulsiert zwischen den Bildern sichtbar (Alpha 0,10 bis 0,34).
18. Im Spiel (`--shotfx2`, später `--shotwucht=hieb|axt|stoss|pfeil|kugel|krit|tod_bone|tod_fall|schwelle|zug`, die dieselben Zustände wie `--shotfx*` bauen und die Wirkung im Kontaktbild zeigen): Zahl und Schriftzug scharf und ohne Kamerazoom, Schild des Ziels zeigt den **gefallenen** Kraftbalken erst **nach** dem Kontakt (Foto bei `-Sec` vor und nach `hw`), Teilchen in der Farbe des Materials (Blut rot, Knochen weiß, Fangarm violett).
19. Lesbarkeit der Zahlen auf Himmelsblau, Deck und Gegnerschiff-Hintergrund (R3-Bühne): jede Klasse erkennbar, kein Zusammenlaufen mit dem Hintergrund (Foto je Thema).
20. Rand an der Schwelle im Foto sichtbar, aber Namen, Balken und Karten (Leiste) bleiben unberührt; Rand deckt höchstens 24 Pixel am linken und rechten Bühnenrand.

**C. Leistung:** `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` im Foto-Lauf (Hilfsausgabe `STAGE Messung` wie in R3): Wirkungen höchstens 350 Aufrufe über der Grundlast; schlimmster Fall (Kraken-Quetschen auf vier Männer plus Krit) gemessen und im Bericht festgehalten.

---

## Aufwand und Risiko

Aufwand (Arbeitstage eines Entwicklers einschließlich Prüfen mit Bildschirmfotos). Der Prototyp (Zeichner, Teilchen, Pose, Schrift, Blätter) liegt in der Arbeitskopie und ist in den Tagen schon abgezogen:

| Posten | Tage |
|---|---|
| Schrift im Hauptprojekt, `FightNumbers`, `Hud._floats` ablösen, Klassen und Zeitabläufe der Zahlen | 0,75 |
| `FxParticles`, `FxPose` in den Kampf einbauen, Trefferpose mit weißem Frame und Rückstoß, Spalt-Versatz, `FightImpact.power/plan` samt Test | 0,75 |
| `LOOK`/`LOOKS`, alle 53 Fertigkeiten durchgehen (ein Foto je Bildart), Parameter abstimmen (Krit, Tinte, Heilung, Stich) | 1,5 |
| Todesbilder (vier Gruppen), Absinken, Kraken-Finale | 0,75 |
| Töne: zehn Funktionen, Anhören unmöglich im Auftrag (Hören durch den Besitzer), Pegel nur über `GAIN` und Spitzenwerte plausibel; Schichtung und `sfxtest` | 0,75 |
| `FightAnim`: gezeigte Kraft, Nachzieher, Zustandsvergleich und Aufpoppen, Rundenerkennung, Schwelle, Herzrand | 1,0 |
| `FightMarks` (Körperzeichen, Zielmarke, Fadenkreuz, Zugleisten-Pulse), Anschluss an R5-Layout | 1,0 |
| Tests (`wu_`-Block, `sfxtest`), `--fxsheet`/`--shotwucht`, Leistungsmessung, Abgleich mit Regie und Bühne | 0,75 |
| **Summe** | **7,25** (davon 2 Tage Abstimmen am Foto) |

Risiken:

| # | Risiko | Gegenmittel |
|---|---|---|
| W1 | **Anzeige nur an Standbildern geprüft**: Flimmern der Sichelkanten, Wandern der Zahlen unter Kamerazoom, Ruckeln des Rückstoßes sind nicht beurteilt | alle Orte `roundf`; Sichel aus Vierecken (nie gedrehte Pixel); beim ersten Spiellauf drei Szenen ansehen; Teilchen ganzzahlig |
| W2 | **Zeichenbudget** (Teilchen 160 + Sichel 24 Aufrufe je Ziel bei Flächenangriff) | `lod`, Obergrenzen, Messung (Kriterium C); Schadenswürfe gleichzeitig: nur der stärkste Treffer bekommt Sterne |
| W3 | **Kamera** der Regie (gehaltener Zoom, Schwenk) und **Dopplung** von Wackeln, Zoom, Einfrieren und Zeitlupe mit den Zahlen der Regie | `FightImpact.camera_owned` abschaltbar; Wucht meldet nur `plan` und führt Kamerawerte nicht selbst; eine gemeinsame Tabelle ist die Wahrheit |
| W4 | **hud.gd** wird von drei Helfern gleichzeitig umgebaut | Wucht ändert nur die Aufrufstellen (Tabelle in "Dateien"); `ctx` ist die einzige Stelle mit Figurenmaßen; neue Dateien tragen alles andere |
| W5 | **Figurenmaße ändern sich** (R2: Zelle 112x104, R5: 88x112) | alle Maße `k`-skaliert; Anker aus `ctx`; `FightImpact` braucht beim Wechsel keine Änderung |
| W6 | **Zeitlupe und Klänge**: `Sfx` läuft in echter Zeit (R1 4.3), der Todesklang kommt nach einem Krit zu früh | bekannt, nicht neu; Klänge werden zum Kontakt geplant; bei Regie `stage_t` und Einheitsuhr wird `Sfx` dort mitgezogen |
| W7 | **Zustandsvergleich statt Ereignis** für Symbole: Aufpoppen kann ±1 Bild früher oder später als der Treffer erscheinen | Vergleich nur je Bild; Poppzeit auf `hw` des gleichzeitig eingetroffenen Treffers gelegt; wenn R1 `status`-Ereignisse liefert, ersetzt es den Vergleich ohne Anzeigeänderung |
| W8 | **Lautstärke der Töne** nicht gehört (Auftrag: kein Ton) | Spitzenwerte und `GAIN` konservativ gewählt (Schichten -9 bis -10 dB); Abnahme durch den Besitzer; Einstellung "Effekte lauter/leiser" wirkt auf `offset_db` |
| W9 | **Schrift auf hellem Grund** (Himmel, Händlerschiff) | 1-Pixel-Rand in Dunkelbraun; Foto je Thema (Kriterium 19); notfalls dunkler Streifen unter der Zahl |
| W10 | **Spalt-Versatz und weißer Frame** (Tönung > 1) brauchen `draw_texture_rect_region` mit Modulate über 1; funktioniert im Prototyp, aber nicht im Compatibility-Renderer | im Projekt gilt Forward+ (R3); sonst Rückfall auf Hellrot |
| W11 | **Ereignis `who == null`** stürzt `_fight_events` (R1 R11) | neue Zweige beginnen mit `if who == null: continue`; `FightImpact` prüft Parameter |
| W12 | **Leck**: `FightAnim` und `FightNumbers` halten `Fighter`-Objekte (R1 R20) | `reset(c)` bei neuem Kampf und am Kampfende, Verweise auf null |

---

## Was ich bewusst weglasse und warum

* **Impact-Frame (invertiert, Schwarz-Weiß) und Smear-Frames.** R4 reiht sie als Schmuck ein; sie ohne Frames der Figuren (R2) zu bauen sähe nach Fehler aus. Später, nur für den Todesstoß.
* **Letterbox, Kamera-Roll, Vollbildblitze.** Letterbox gehört der Regie; Roll rastet bei Pixelkunst hässlich ein; Vollbildblitze nur als schwaches Gold (Krit) und Weiß (Tod), höchstens drei je Sekunde.
* **Ein Shader für den weißen Frame und die Umrisse.** Die Tönung über 1 genügt (am Prototyp geprüft, `D3_blatt_d2.png` Zeile 2); Umriss und Bildschirm-Abstufung gehören der Bühne (R3).
* **Neue Ereignisse in `combat.gd` für Zustände, Reihen, Ziele.** Anzeige-seitiger Vergleich reicht für Symbole, Rundenwechsel und Schwelle; `hp0/hp1`-Felder (R1 3.4) wären besser, werden aber nicht vorausgesetzt (Näherung `hp + n`). Das Regelwerk bleibt unangetastet.
* **Gleitende Bewegung der Figuren** (Vortreten, Reihenwechsel). Das ist Regie und Figuren; hier nur der Rückstoß des Getroffenen.
* **Mehr Töne.** Zehn neue Klänge reichen für die Schichtung; Ausholgeräusche vor dem Kontakt (R4: 60 bis 100 ms) und Musikabsenkung bleiben der Regie.
* **Blutflecken über das Kampfende hinaus** und Teilchen mit Kollision; Flecken (1-Pixel-Striche, 14 s) genügen.
* **Netz-Wurf (`f_netz`) mit Seilbild und Messer-Stich (`f_messer`, `f_gabel`) mit eigener Art.** Heute `cut` bzw. flacher `stab`; Letzterer ist ungeprüft, Rückfall `cut` ist in der Tabelle eingetragen.
* **Zustandssymbole als Ereignisse mit eigenem Banner.** Zahl und Symbol genügen; Texte bleiben bei R5 (Kurzkarte, Tooltip).
* **Eigene Schrift für Kleinbuchstaben.** Alle Schlagworte sind groß (Wucht-Schrift); Fließtext und Meldungen bleiben in der Spielschrift (R5).
* **Tonhöhenverschiebung der Musik in der Zeitlupe** und **Sidechain beim Fokus**: Regie.
