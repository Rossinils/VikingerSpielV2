# R5: Oberfläche des Deckkampfs (Bestand, Schwächen, neues Layout, Symbole, Fokusschild, Texte)

Stand: 3. November 2026. Arbeitskopie mit dem Entwurf: `..\_sandbox\oberflaeche\` (Hauptprojekt unverändert). Alle Bilder liegen in `img/`:
`r5_*.png` zeigen den **heutigen** Kampfbildschirm (Hauptprojekt), `r5s_*.png` den **Entwurf** (Arbeitskopie). Alle Bilder sind Bildschirmfotos (2881x1921 oder 3081x2054), keine Mockups
von Hand: sie kommen aus dem Spiel selbst (`tools/dev/shot.ps1`), und jede Aussage über "so sieht es aus" wurde am Bild geprüft.
Der Entwurf besteht aus drei Diffs gegen den Stand vor dem Umbau (`R5_proto_hud.diff.txt`, `R5_proto_main.diff.txt`, `R5_proto_fight_fx.diff.txt`), der neuen Datei
`R5_proto_status_icons.gd.txt` (wird `scripts/status_icons.gd`) und dem Symbolstreifen (`R5_statussymbole.py` erzeugt `assets/status_icons.png`, 108x9, 12 Symbole).
Selbsttest in der Arbeitskopie: `FEHLER: 0` (zuletzt nach den Änderungen an `hud.gd` und `fight_fx.gd`). Nicht geprüft: Mausklicks im laufenden Spiel (kein Fenster), Zeitverhalten über viele Kämpfe, `runbots`.

---

## 0. Kurzfassung

1. **Der Kampfbildschirm verschenkt die Hälfte seiner Fläche.** Die Bühne ist nur y 0..166 hoch (52 %), die Figuren sind 44x56 Pixel (17,5 % der Bildhöhe), darunter liegen 154 Pixel Text, von denen die rechten zwei Drittel leer sind (`r5_fight2.png`, `r5_zonen_ist.png`).
2. **Die Zustandsbuchstaben sind das schlechteste Stück**: neun Buchstaben (`! G T Z B b M S +`) in 7 Pixeln hinter der Kraftzahl, `B` und `b` unterscheiden sich nur durch die Schreibweise, und **drei wichtige Zustände gar nicht** (Herausforderung, Panik, leere Muskete). Wer provoziert hat, sieht man heute nirgends, obwohl die Gegner dann fast nur auf ihn zielen.
3. **Vorschlag**: Bühne y 0..215 (67 %), Figuren doppelt (88x112), Namensschilder im Band-Stil direkt unter den Füßen (y 177..212), eine schlanke untere Leiste y 215..320 mit den sechs Karten (77x46), die Meldungen als zwei Zeilen Bildunterschrift, der Rest in einer Chronik-Platte (Taste Tab). Alle Klick-IDs und Tasten bleiben (Abschnitt 2.8).
4. **Zustandssymbole**: 12 Symbole zu 9x9 Pixel mit eigenem Umriss, Runden als 6-Pixel-Zahl in der Ecke (Abschnitt 3.1). Das Tooltip-Wirrwarr weicht einer **Kurzkarte** oben auf der Bühne und einer **Bildunterschrift** zur Fertigkeitskarte, die schwebenden Tooltips über dem Geschehen verschwinden im Kampf.
5. **Zugleiste mit Mini-Porträts** (14x14 Kopf, Seitenstreifen, Kraft) statt Anfangsbuchstaben; aktive Figur größer und golden eingefasst.
6. **Fokusschild** (Name der Figur und Fertigkeit mit Symbol, 24 Pixel hoch) über dem Kopf der handelnden Figur statt des Banners oben rechts; bei Riesen links neben dem Kopf. Es folgt der Kamera (`FightFx.stage_to_screen`).
7. **Fehler im Bestand, die man nebenbei behebt**: Rückzug rutscht bei weniger als vier Fertigkeiten auf eine Fertigkeitstaste (Abschnitt 1, B3); "alle," mit hängendem Komma auf der Karte Kriegslied; fünf Fertigkeitsnamen sind für ihre Karte zu breit (gemessen).
8. Aufwand für den Einbau: rund **2,5 Arbeitstage** (Abschnitt 2.10), der Entwurf läuft bereits. Empfohlen: die neue Oberfläche in eine eigene Datei `scripts/fight_ui.gd` legen, damit sie nicht mit den Umbauten der anderen Berichte (R1 Regie, R2 Figuren) im selben `hud.gd` kollidiert.

---

## 1. Bestandsaufnahme und Schwächen nach Gewicht

### 1.1 Wie der Bildschirm heute aufgeteilt ist

Bild `r5_zonen_ist.png` (Zonen auf einem Bildschirmfoto), Zahlen aus `hud.gd` `_draw_combat_view` und `_draw_fighter`:

| Zone | Rechteck (Spielfeldpixel, 480x320) | Inhalt | Anteil |
|---|---|---|---|
| Bühne | 0, 0, 480, 166 | Deck bei `FIGHT_FEET = 120`, Figuren 44x56, Namen, Balken, Buchstaben | 52 % |
| Kopf | 14, 8 bis 40 | "Deckkampf: Name" (11 px), "Runde n", Zugleiste (20x14, Anfangsbuchstaben, bis 10) | |
| Beschriftungen | y 56 | "Eure Männer (Reihe 1 vorn)", "Gegner" (8 px, gedimmt) | |
| Namen und Werte | je Figur, y 134..166 | Name 8 px, Kraftbalken 38x4, Verzweiflungsbalken 38x3, Zeile "Kraft + Buchstaben" 7 px | |
| Meldungen | 14, 172, 440, 60 | die letzten sechs Zeilen des Kampftagebuchs, 8 px mit 3 px Umrandung | 19 % |
| Hinweiszeile | 14, 236 | "X ist dran. Wähle eine Fertigkeit (1–6)." (9 px, Gold) | |
| Fertigkeitskarten | 6 + 78·i, 242, 74x58 | Symbol, Ziffer, Name, zwei Zeilen Werte | 18 % |
| "Abwarten (Leertaste)" | 6, 302, 150x12 | reiner Text, 8 px, gedimmt | |
| Große Ansage | 0, 58, 480, 52 | SIEG, KAMPF, HELDENMUT ... genau **über den Köpfen** (Köpfe y 68..80) | |
| Banner | 236, 4, 172x18 | "Name: Fertigkeit", immer rechts oben, egal wer handelt | |

### 1.2 Was gut ist und bleibt

* Das Kartenbild (Bronzerahmen, Hover-Leuchten, Auswahl, gesperrt abgedunkelt) und die Farbwelt (Papier, Gold, Rot, Grün, Violett) passen und sind lesbar.
* Rot gegen Grün für Gegner und Verbündete bei der Zielwahl ist sofort verständlich.
* Der Ablauf Fertigkeit wählen, Ziel wählen, `Esc` zurück, Leertaste warten ist klar und bleibt.
* Die Tooltips der **Aufstellung** (`Tips.fight_man`, `Tips.loadout`, `Tips.fight_auto`) sind sachlich in Ordnung.

### 1.3 Schwächen nach Gewicht

Gewicht: **A** = nimmt dem Spieler Information oder Platz, die er braucht; **B** = Fehlbedienung, Mehrdeutigkeit, Lesbarkeit; **C** = Schönheit und Pflege. Jede Zeile nennt das Bild, an dem man es sieht.

**Gewicht A**

| # | Schwäche | Beleg | Folge |
|---|---|---|---|
| A1 | **Bühne zu klein, Figuren zu klein.** 166 von 320 Pixeln, Figur 56 Pixel hoch. Darunter 154 Pixel (48 %) Text, rechts davon zwei Drittel leer. | `r5_fight2.png`, `r5_zonen_ist.png` | Der Besitzer will "Figuren im Fokus" und "mitreißend": mit 17,5 % Bildhöhe pro Figur geht das nicht. Jede Kamerafahrt R4 hat zu wenig Raum (Brennpunkt y 166). |
| A2 | **Zustandsbuchstaben**: `! G T Z B b M S +` hinter der Kraftzahl (`"62  BbMS+"`), 7 px. `B` (betäubt) und `b` (blutet) nur durch Groß-/Kleinschreibung getrennt, `T` steht für "geblendet" (kommt von Tinte), `Z` für "spannt sich", `!` für "an der Schwelle". Ohne Legende; die Erklärung steht nur im Tooltip, und dort hinter dem Buchstaben in Klammern. | `r5_tip_queue.png` ("100 S+", "62 BbMS+", "38 T", "10 !"), `r5_stat.png` | Spieler lesen Zustände nicht oder falsch. |
| A3 | **Drei Zustände fehlen ganz**: `taunt` (Herausforderung: Gegner zielen nur auf ihn), `panic` (setzt vor Schreck aus), Muskete leer (nur auf der Karte "Muskete leer: erst nachladen" sichtbar, nicht an der Figur). `_status_text` und `Tips.fighter` kennen sie nicht. | Quelltext `hud.gd` `_status_text`, `tips.gd` `fighter`; Felder `taunt`, `panic`, `loaded` in `combat.gd` | Ein Schildträger ruft die Gegner auf sich, und der Bildschirm zeigt es nirgends. |
| A4 | **Der Kraken-Zerquetschen-Angriff** (tötet alle Männer, wenn nicht betäubt) wird mit einem `Z` neben der Kraftzahl und einem schwebenden "spannt sich!" angekündigt. Er ist die gefährlichste Ankündigung des Spiels. | `r5_kraken2.png` ("65 Z") | Zu leise. Im Hinweistext und in der Zugleiste steht nichts. |
| A5 | **Meldungen**: sechs Zeilen Kampftagebuch, 8 px mit 3 px dicker Umrandung (`draw_string_outline`), Zeilen mit Leerzeichen eingerückt ("  trifft Wache: −13"), gleich gewichtet, nur das linke Drittel genutzt. Sie wiederholen, was schwebende Zahlen und Banner schon zeigen. | `r5_fight2.png`, `r5_kraken2.png` | Kostet 60 Pixel Höhe für wenig Nutzen; die Umrandung frisst bei 7 bis 8 px die Zeichen. |
| A6 | **Große Ansage deckt die Köpfe.** Band y 58..110 über Figuren, die bei y 68 beginnen. | `r5_heroic.png`, `r5_win.png` | Beim Höhepunkt (Heldenmut, Sieg) verschwinden die Gesichter hinter einem schwarzen Balken. |

**Gewicht B**

| # | Schwäche | Beleg | Folge |
|---|---|---|---|
| B1 | **Zugleiste aus Anfangsbuchstaben** (`H A H B A S S K`): doppelte Buchstaben (Halvar, Harald), kein Porträt, Seite nur über die Farbe, keine Kraft, keine Rundengrenze, 20x14 Pixel. | `r5_tip_queue.png` | Wer als Nächster dran ist, ist nicht zu erkennen. |
| B2 | **Tooltips im Kampf sind Textwände** (`Tips.fighter`: bis acht Zeilen, 178 bis 250 Pixel breit, folgt der Maus, deckt Figuren, Ziele und Karten). Bei Karten springt der Tooltip nach oben und deckt die Bühne. | `r5_tip_queue.png`, `r5_tip_card.png`, `r5_tip_fighter.png` | Beim Zielwählen verdeckt der Tooltip das, was man treffen will. |
| B3 | **Rückzug ist nicht fest auf Taste 6.** `_fight_options` hängt "Platztausch" und "Rückzug" hinter die vorhandenen Fertigkeiten an. Hat ein Mann nur zwei oder drei gewählte Fertigkeiten (erlaubt: ein bis vier), liegt **Rückzug auf Taste 3 oder 4**, Platztausch auf 2 oder 3, und es gibt weniger Karten. Rückzug beendet den Kampf ohne Rückfrage. | Quelltext `hud.gd` `_fight_options`, `fight_click` (`voy.combat_flee()`) | Wer aus Gewohnheit "4" für die vierte Fertigkeit drückt, zieht sich zurück. |
| B4 | **Hinweiszeile wandert und wechselt**: y 236 (Gold, 9 px) beim Mann, y 246 (Rot, 10 px) beim Gegnerzug, dann sind die sechs Kartenrahmen verschwunden. Die gewählte Fertigkeit steht nicht im Hinweis ("Wähle ein Ziel (Q W E R oder Klick), Esc bricht ab." gilt für alles). | `r5_pick.png`, `r5_foe.png` | Layout springt; im Zielmodus fehlt, was man gewählt hat. |
| B5 | **Zielwahl ohne Tastenbeschriftung**: Dreieck und weißes Pulsieren, aber kein Hinweis, welcher Gegner welche Taste (Q W E R = Reihe 1 bis 4) hat und wie gut die Trefferchance ist (steht nur im Tooltip). Ungültige Ziele werden nicht abgedunkelt. | `r5_pick.png`, `r5_move.png` | Q W E R sind nur durch Ausprobieren zu lernen. |
| B6 | **Karten**: Schriftgröße je Name 8 oder 7 (Grenze 10 Zeichen), dadurch "Platztausch" kleiner als "Wirbelhieb"; Ziffer als 7-px-Hochzahl; **fünf Namen sind zu breit** für 44 Pixel (gemessen mit `tools/r5_measure.gd`, Segoe UI Semibold): Herausforderung 53 px, Musketenschuss 51, Gezielter Schuss 50, Rückzugsschuss 50, Rundumschlag 46 (jeweils bei 7 px), Schreckschuss 44 gerade noch. Zeile "alle," mit hängendem Komma (Kriegslied: `"alle, %s" % left` mit leerem `left`). | `r5_kraken2.png` ("Schaden +25 % alle,"), Messwerte Abschnitt 5.3 | Abgeschnittene Namen (Godot kürzt bei gesetzter Breite), Schönheitsfehler. |
| B7 | **Fertigkeitenwahl (Loadout)**: Beschreibung in 6 px, kein Hinweis, aus welchen Reihen eine Fertigkeit einsetzbar ist (die Wahl ohne diese Angabe ist blind), "gewählt" als grüner Text, "Noch n Platz frei". | `r5_loadout.png`, `r5_lo.png` | Wer den Bogenschützen "Rückzugsschuss" wählt, erfährt erst im Kampf, dass er in Reihe 4 nicht geht. |
| B8 | **Aufstellung**: Gegner nur als Textzeilen ("Armbrustschütze (Kraft 33) · Schütze", die Gold-Hinweise unerklärt), kein Kopf, kein Bild; "Auf die Symbole klicken wählt die Fertigkeiten" nur als 7-px-Hinweis, die Symbole sehen nicht anklickbar aus; "Kampf!" nicht hervorgehoben. Der Tooltip der Mannzeile deckt die Spalten daneben. | `r5_prep.png`, `r5_tip_prep.png`, `r5_kprep.png` | Entdeckbarkeit gering. |
| B9 | **Namen ragen aus dem Raum**: Name 8 px mit Umrandung, Balken 38x4 ohne Zahl im Balken, Verzweiflung als 3-px-Strich ohne Marke bei 50. Kraftzahl liegt 10 Pixel darunter in einer anderen Schrift. | `r5_tip_queue.png` | Mehrere kleine Elemente statt eines Schildes. |
| B10 | **Tastenhilfe fehlt**: Ziel- und Fertigkeitstasten stehen nur in Hinweissätzen; keine feste Zeile. | alle | Neue Spieler finden `Esc`, `Q W E R` und Leertaste nicht. |

**Gewicht C**

| # | Schwäche | Folge |
|---|---|---|
| C1 | **Feste Höhen verstreut**: `FIGHT_FEET - 44.0`, `- 40`, `- 34`, `- 30`, `- 26`, `- 20`, `- 48`, `- 36`, `- 32`, `- 24`, `- 28` und weitere stehen über 30-mal in `hud.gd`; die Bühnenhöhe 166 steht in Vignette, Blitz und Ansage; `FightFx.FEET = 120` doppelt. | Jede Änderung der Bühne muss alle anfassen (im Entwurf geschehen, siehe Diff). |
| C2 | `_t` zeichnet **jeden** Text mit 3-px-Umrandung, auch 7-px-Text. | Kleine Zeichen werden dick; ein 1-Pixel-Schatten (`_t1` im Entwurf) liest sich auf dunklen Flächen klarer (vgl. `r5_fight2.png` und `r5s_fight2.png`). |
| C3 | Die Weltszene scheint unter dem Kampfbild zu 10 % durch (Alpha 0,9, `_draw_combat_view`). | Siehe R1 Risiko R22; harmlos, aber unruhig. |
| C4 | Zugleisten-Kästchen sind nur Hover-Flächen für `Tips.fighter`; weder Klick noch Hervorheben der Figur auf der Bühne. | Kleine Chance ungenutzt. |

### 1.4 Klickbarkeit, nüchtern geprüft

Auf dem 3120x2080-Schirm ist ein Spielfeldpixel rund 6,5 Bildschirmpixel breit. Alle heutigen Klickflächen sind groß genug: Karten 74x58 (480x375 Bildschirmpixel), Figuren `Rect2(x-22, 72, 44, 52).grow(4)`, "Abwarten" 150x12 (78 Bildschirmpixel hoch, aber reiner Text, deshalb nicht als Knopf erkennbar). Das Problem ist nicht die Fläche, sondern dass die Flächen nicht **aussehen** wie Knöpfe (Abwarten) und dass im Zielmodus keine Beschriftung zeigt, was geklickt wird (B5).

---

## 2. Neues Kampflayout (Bühne y 0..215)

Bilder: `r5s_fight2.png` (Mann am Zug), `r5s_pick.png` (Zielwahl), `r5s_stat.png` (viele Zustände), `r5s_zonen.png` (Zonen auf dem Bild), `r5s_foeact.png` und `r5s_fight_taste.png` (Gegnerzug).

### 2.1 Gesamtbild

```
y   0 +------------------------------------------------------------------------+
      | Kopfzeile 0..30: Kampfname, Runde | Zugleiste (Mini-Porträts) | Chronik   |
   30 +------------------------------------------------------------------------+
      | (Himmel / Hintergrund; große Ansage 32..72; Kurzkarte 31..; Fokusschild)   |
   68 |   Köpfe der doppelt großen Figuren (88x112), Füße auf y 172              |
  172 |   ======================== Deck (Planken) ===============================   |
  177 |   Namensschilder 177..212 (Band, Kraft, Verzweiflung, Zustandssymbole)     |
  215 +--- Kante der Leiste (3 Linien) -----------------------------------------+
  218 | Ansage (9 px, Gold)                                    [Abwarten (Leertaste)] |
  236 | Bildunterschrift Zeile 1 (8 px)                                           |
  246 | Bildunterschrift Zeile 2 (8 px)                                           |
  258 | [1 Karte][2 Karte][3 Karte][4 Karte][5 Platztausch][6 Rückzug]  (77x46)    |
  304 |                                                                           |
  317 | Tastenzeile (6 px)                                                        |
  320 +------------------------------------------------------------------------+
```

### 2.2 Rechtecke (Spielfeldpixel), genau

| Zone | Rechteck | Anmerkung |
|---|---|---|
| Bühne | `Rect2(0, 0, 480, 215)` | `UI_BAR_Y = 215`; 67,2 % statt 51,9 %, **+29,5 % Höhe** |
| Kopfzeile | `Rect2(0, 0, 480, 30)` | über dem Hintergrund, ohne eigene Fläche |
| Kampfname | Grundlinie (8, 11), 8 px Gold, höchstens 112 breit (`_fit_size [8, 7]`) | "Wachen des Handelsschiffs" misst 96 px bei 8 px |
| Rundenzähler | Grundlinie (8, 21), 7 px, gedimmt | "Runde %d" |
| Zugleiste | ab x = 124, y 3 bis 29 | aktiv 22x26 bei y 3, übrige 16x22 bei y 5, Abstand 2, höchstens 10; danach "Runde n+1" (6 px, gedimmt) |
| Chronik-Knopf | `Rect2(414, 4, 60, 12)` | ID `fchron`, Taste Tab |
| Große Ansage | `Rect2(0, 32, 480, 40)` | Linien bei y 32 und 71; Text 22 px bei Grundlinie 57, Unterzeile 9 px bei 68. Köpfe beginnen bei y 68, also **über** den Köpfen (Kraken-Kopf überlappt um 40 Pixel, die Ansagen sind kurz) |
| Kurzkarte | `Rect2(6 oder 238, 31, 236, 12 + 10·Zeilen [+ 4 + 9·Notizen])` | Hälfte gegenüber der berührten Figur; Männer 4 Zeilen, Gegner 3 |
| Fokusschild | Höhe 24, Breite = Text + 32, y = Kopfhöhe − 32 (Mann: y 36) | siehe Abschnitt 4 |
| Figuren (klein) | Zelle 88x112, Füße y 172, Mitten x = `[212, 156, 100, 44]` (Männer, Reihe 1 bis 4) und `[268, 324, 380, 436]` (Gegner) | Zellen überlappen um 32 Pixel (nur Transparenz, Waffen können berühren); Reling x = 239 |
| Riese | 132x132 (1,5-fach von 88x88), Mitte x = 408, Unterkante y = 163 | `FIGHT_BIG_X = 408` (heute 436, die Reihe-4-Mitte) |
| Deck | `Rect2(-8, 164, 496, 51)` | Planken bis zur Leiste, unten 10 Pixel Verlauf nach Schwarz |
| Namensschild | `Rect2(cx − 26, 177, 52, 35)` (Riese 104 breit) | siehe Abschnitt 3.2 |
| Zielwahl-Beschriftung | über dem Kopf, y = max(Kopf − 20, 33), Höhe 11 + Spitze 4 | Taste (11 breit) + Trefferchance |
| Chronik-Platte | `Rect2(4, 34, 196, 176)` | 15 Zeilen zu 10 Pixel, 7 px; ID `fchronplatte` (frisst Klicks) |
| Untere Leiste | `Rect2(0, 215, 480, 105)`, Füllung `#0b0c12`; Linien y 215 (INK), 216 (BRONZE), 217 (BRONZE_LO) | |
| Ansage | Grundlinie (8, 230), 9 px, Breite 350 | Gold; rot beim Gegnerzug; grau bei Rückzug |
| Abwarten-Knopf | `Rect2(366, 220, 108, 13)` | ID `fwait`, Leertaste |
| Bildunterschrift | Grundlinien 244 und 254, 8 px, Breite 464 | zwei Zeilen |
| Fertigkeitskarten | `Rect2(4 + 79·i, 258, 77, 46)`, i = 0..5 | IDs `fs0` bis `fs5` |
| Tastenzeile | Grundlinie (8, 317), 6 px | zustandsabhängig (2.6) |
| Gegnerkarte | `Rect2(4, 258, 472, 46)` | ersetzt die Karten beim Gegnerzug |

### 2.3 Warum diese Zahlen

* **Figuren doppelt**: 88x112 Pixel, Köpfe bei y 68, Fuß bei y 172. Ein Mann ist dann 35 % der Bildhöhe (vorher 17,5 %). Die Fläche der Figur wächst auf das Vierfache.
  Das ist die einfache Lösung (Anzeige skaliert die vorhandene Zelle 44x56 mit `draw_texture_rect_region`, Nearest-Filter, ganzzahliger Faktor, daher keine Kantenwanderung). Sie ist **provisorisch**, bis die Figuren-Gruppe größere Zellen liefert (`R2_figuren.md` 5.2: Zelle 112x104, Körper 64 px). Alle Maße der Oberfläche hängen an den **Füßen** (y 172); nur zwei Maße hängen an der Figurenhöhe (Fokusschild und Zielwahl-Beschriftung, beide über `head_y`): beim Wechsel der Figuren einen Wert `FIG_PX = 112` einsetzen.
* **Füße bei 172** statt 120: genau so tief, dass darunter 35 Pixel für das Namensschild und 5 Pixel Luft bis zur Leiste bleiben (172 + 5 + 35 = 212, Leiste bei 215).
* **Leiste 105 Pixel** (statt 154): Ansage 18 + Bildunterschrift 22 + Karten 46 + Tastenzeile 8 + Ränder. Die sechs Karten werden niedriger (46 statt 58), weil der Platz neben den Werten ungenutzt war.
* **Kamera**: Die Kameraberichte nennen als Brennpunkt y 166 (Unterkante der Bühne, `R4_vorbild.md` Technik 3). Neu: **y 215**. Die Namensschilder liegen im gezoomten Teil und bleiben mit der Unterkante sichtbar. Kopfzeile, Leiste, Fokusschild, Kurzkarte und Chronik liegen im Bildschirmraum und zoomen nicht.

### 2.4 Namensschild, Kraft und Zustände (Kurzfassung, Einzelheiten in 3.2)

Ein Band mit dem Namen (Georgia kursiv, 8 oder 7 px), darunter der Kraftbalken mit Zahl (7 px hoch), darunter bei Männern der Verzweiflungsbalken (3 px), darunter bis zu fünf Zustandssymbole (9x9) mit Rundenzahl. Damit sind Name, Kraft, Verzweiflung und Zustände **ein** Objekt unter den Füßen und nicht vier Textzeilen.

### 2.5 Zielwahl (Bild `r5s_pick.png`, `r5s_move.png`)

* Alle Figuren, die **kein** gültiges Ziel sind, werden auf 50 % abgedunkelt (Tönung 0,5 / 0,5 / 0,55).
* Gültige Ziele: pulsierende Ellipse unter den Füßen (Gegner rot `#d2564b`, Verbündete grün; Halbachse 31, bei Riesen 60, Höhe 20 % davon) und darüber eine Marke: Taste (Q W E R, 11 Pixel breit, in der Farbe abgedunkelt) und, bei Angriffen, die Trefferchance ("90 %") in einem dunklen Feld; eine Spitze zeigt auf den Kopf.
* Taste zu Reihe: Q = Reihe 1 (der Mitte am nächsten), W = 2, E = 3, R = 4, bei Männern wie bei Gegnern; bei Platztausch (`_fight_move`) und Verbündetenzielen auf der Männerseite.
* Der Mann am Zug trägt das goldene Dreieck (8x5 Pixel) bei y = Kopf − 8 und die goldene Linie unter den Füßen. Läuft ein Fokusschild, entfällt das Dreieck.
* Klickfläche je Figur: `Rect2(cx − 27, 72, 54, 136)` (klein) und `Rect2(cx − 56, 22, 112, 186)` (Riese), ID `ft<Seite>_<Reihe>`; nur im Zielmodus eingetragen und nur für **gültige** Ziele (wie heute).
  **Achtung (R1 Risiko R4):** Die Fläche liegt in Bühnenkoordinaten. Solange nur in der Eingabephase geklickt wird, ist der Zoom 1,0 und das stimmt. Hält die Kamera in der Eingabephase einen Zoom, muss die Fläche über `FightFx.stage_to_screen(...)` eingetragen werden (Hilfsfunktion im Entwurf vorhanden).

### 2.6 Inhalt der Leiste je Zustand

| Zustand | Ansage (y 230) | Bildunterschrift | Karten | Tastenzeile |
|---|---|---|---|---|
| Mann am Zug, nichts gewählt | "%s ist dran: Fertigkeit wählen (1–6)." (Gold) | die letzten zwei Meldungen; **beim Überfahren einer Karte** deren Erklärung (Name: Beschreibung, darunter Reihenbedingung und Rest) | sechs Karten | "1–6 Fertigkeit    Leertaste warten    Tab Chronik" |
| Fertigkeit gewählt | "%s: Ziel wählen (Q W E R oder Klick), Esc zurück." | wie oben | gewählte Karte golden | "Q W E R Ziel    Esc zurück    Tab Chronik" |
| Platztausch gewählt | "Platztausch: mit wem? Q W E R oder Klick, Esc zurück." | wie oben | Karte 5 golden | wie oben |
| Gegnerzug | "%s ist am Zug …" (Rot) | die letzten zwei Meldungen | **eine breite Gegnerkarte** `Rect2(4, 258, 472, 46)`: Kopf 28x28, Name, "Kraft a von b · Rolle", "Kann:" mit Symbol und Namen seiner Fertigkeiten | "Tab Chronik" |
| Kampf aus | "Sieg: %d Gegner gefallen." / "Niederlage: niemand steht mehr." / "Rückzug: ihr zieht euch zurück." | die letzten zwei Meldungen | leer | "Tab Chronik" |

Der Zustand "Kampf aus" zeigt kein Abwarten und keine Karten (heute steht dort noch "1–6 Fertigkeit"; im Entwurf behoben, `r5s_win.png`).
Kartenerklärung statt Tooltip: Die Zeilen kommen aus `Tips.skill` (Zeile 0 = Beschreibung, die Zeilen "Treffer n %, Schaden a–b" je Ziel entfallen, weil die Trefferchance jetzt bei den Zielen steht).

### 2.7 Karte (77x46), innen

| Teil | Maß |
|---|---|
| Symbol `SkillIcons` 16x16 | bei (3, 3) |
| Ziffer 1 bis 6, 7 px, Gold | Grundlinie (21, 11) |
| Name, 8 px; passt er nicht in 46 Pixel, dann 7, dann 6 (`_fit_size(title, 46, [8, 7, 6])`) | Grundlinie (28, 11), Zeichenbreite 47; alle fünf zu breiten Namen (Herausforderung u. a.) laufen auf 6 px und passen (Herausforderung 46 px bei 6) |
| Wertzeilen, 7 px | Grundlinien 29 und 38, x = 5, Breite 68 |
| Rückzug | roter Rahmen `#a83a35`, solange nicht gewählt |
| Zustände | normal / Hover (hell) / gewählt (Gold) / gesperrt (abgedunkelt 0,4, nicht anklickbar) |
| leerer Platz (weniger als vier gewählt) | gesperrter leerer Rahmen, Alpha 0,25, **ohne** ID; Platztausch bleibt Karte 5, Rückzug Karte 6 |

Bild `r5s_karten_lang_schild.png` (Herausforderung, Rundumschlag) und `r5s_karten_lang_muskete.png` (Gezielter Schuss, Schreckschuss) zeigen die langen Namen auf der neuen Karte.

### 2.8 Klick-IDs und Tasten, die erhalten bleiben müssen

**Kampf (`fight_click`, `fight_key`)**

| ID / Taste | Bedeutung | Anmerkung |
|---|---|---|
| `fs0` bis `fs5` | Karte 1 bis 6: `fs0..fs3` die gewählten Fertigkeiten, `fs4` **Platztausch** (Taste 5), `fs5` **Rückzug** (Taste 6) | Im Entwurf ergänzt `_fight_options` leere Plätze (Leerstring), damit `fs4` und `fs5` auch bei weniger als vier Fertigkeiten fest bleiben; `fight_click` ignoriert leere Plätze |
| `ft<Seite>_<Reihe>` | Ziel: `ft0_0..ft0_3` Männer, `ft1_0..ft1_3` Gegner (Reihe 0 = vorn) | Wie heute nur für gültige Ziele eingetragen. Reihenfolge der Eintragung: wer zuerst steht, gewinnt (`button_at`) |
| `fwait` | Abwarten | Leertaste |
| Tasten `1` bis `6` | `fs0..fs5` | `KEY_1..KEY_6` |
| Tasten `Q W E R` | Ziel Reihe 1 bis 4: Gegner; bei Platztausch und Verbündetenzielen die Männerseite | `fight_key` |
| `Esc` | gewählte Fertigkeit oder Platztausch verwerfen; ist die Chronik offen, zuerst sie schließen | |
| Leertaste | Abwarten | |
| `Tab` (**neu**) | Chronik ein/aus | ID `fchron` |
| `fchronplatte` (**neu**) | Platzhalter, der Klicks auf die offene Chronik schluckt (zuerst eingetragen, damit keine Figur darunter angeklickt wird); `fight_click` tut nichts damit | |

**Aufstellung (`fight_click`, `fight_key` ohne Kampf)**

| ID / Taste | Bedeutung |
|---|---|
| `fp<i>` | Mann i der linken Liste in die Kampfreihe oder heraus |
| `fl<i>` | Fertigkeitsstreifen von Reihe i öffnet die Fertigkeitenwahl |
| `fu<i>`, `fd<i>` | Reihe i nach vorn oder hinten |
| `fauto` | "Beste vier" (Taste `A`) |
| `fgo` | "Kampf!" (`Enter`, `KP_Enter`) |

**Fertigkeitenwahl**

| ID / Taste | Bedeutung |
|---|---|
| `lo<k>` | Fertigkeit k des Rollenpools (0..5) ein/aus |
| `lodef` | "Standard" |
| `lodone` | "Fertig" (`Esc`, `Enter`) |

Unverändert bleiben außerdem: der erste Klick schließt die Hilfe (`main.gd` `_click`), `Esc` im Kampf gehört dem Kampf (nicht dem Menü), die Tastenabgabe `main.gd` (`_hud.fight_key(key)` für `Phase.COMBAT`), die Schnittstelle `fight_click(id)`, die Felder `_fight_skill`, `_loadout_man`, `_fight_actor`, `_fight_move` (die Screenshot-Abläufe in `main.gd` greifen darauf zu), und der Schnellmodus (`voy.auto_combat`): die Oberfläche zeichnet nur, sie wartet nie.

### 2.9 Zeichenreihenfolge im Entwurf (`_draw_combat_view`)

1. Klickplatte der Chronik (nur eintragen, wenn offen)
2. Hintergrundrechteck, danach `draw_set_transform` (Kamera) mit Deck, Figuren samt Namensschildern, Fangarm-Bogen, `_draw_fight_overlay` (Vignette 0..215, Blitz, Geister)
3. Transform zurücksetzen: `_draw_fight_texts` (große Ansage), `_draw_focus_plaque`, `_draw_fight_header`, `_draw_fight_bar`, Chronik, `_draw_fighter_card` (oder `_draw_tip` im Menü)

Zeichenaufwand: grob 350 Rechtecke und Zeichenketten je Bild (acht Schilder zu je rund 20, Kopfzeile rund 80, Leiste rund 120, Chronik 16); das liegt unter dem Budget "einige hundert". Gezählt wurde nicht mit dem Profiler, sondern aus dem Quelltext geschätzt.

### 2.10 Einbau: Aufwand und Reihenfolge

| Schritt | Inhalt | Aufwand |
|---|---|---|
| 1 | Zustandstabelle (`_status_list`) und `StatusIcons` (neu), `assets/status_icons.png` mit `R5_statussymbole.py`; `import` | 0,25 Tage |
| 2 | Geometrie in einen Ort (`UI_BAR_Y`, `FIGHT_FEET`, `FIG_SC`, Köpfe über `head_y`); alle `FIGHT_FEET - n` in `FIGHT_FEET - FIG_SC * n` (oder Anker-Funktion) | 0,5 Tage |
| 3 | Namensschild, Kopfzeile, Zugleiste, Leiste, Gegnerkarte, Chronik, Kurzkarte (Entwurf übernehmen) | 0,75 Tage |
| 4 | Zielwahl (Marke, Abdunkeln), Tastenzeile, Fokusschild, Texte in `tips.gd` verlagern | 0,5 Tage |
| 5 | Aufstellung (Gegnerkarten) und Fertigkeitenwahl (Reihenfelder), `Tips.skill_short`-Fehler | 0,25 Tage |
| 6 | Prüfung: `selftest`, `sfxtest`, `musictest`, `runbots`, Bilder aller Zustände (Abschnitt 6) | 0,25 Tage |

Empfehlung: neue Datei `scripts/fight_ui.gd` (`class_name FightUi`, Funktionen bekommen das `Hud` übergeben wie `slot_view.gd`). `hud.gd` behält Zustand und Klicks und bekommt dünne Weiterleitungen. Das deckt sich mit dem Modul **FightPanel** und **FightPrep** aus `R1_ablauf.md` 5.4. Der Entwurf liegt als Diff vor und ist in `hud.gd` geschrieben, damit er sich ohne Weiteres laufen lässt.

### 2.11 Was der Entwurf zeigt und was nicht

Zeigt (alles als Bildschirmfoto belegt): Layout, Schilder, Kopfzeile, Zugleiste, Chronik, Kurzkarte, Zielwahl, Leiste je Zustand, Gegnerkarte, Schlussansagen, Aufstellung, Fertigkeitenwahl, Fokusschild für Mann und Riesen, Statussymbole an Männern und Gegnern.
Zeigt **nicht**: Kamerafahrt und Dimmung (liegt bei den anderen Berichten), die Wirkung der Ereignisfelder `hp0/hp1` und `status` (siehe 3.4), Mausklicks, Verhalten bei sehr kleinem Fenster.

---

## 3. Statussymbole, Namensschilder, Zugleiste

### 3.1 Statussymbole statt Buchstaben

Bild `r5_status_sheet.png` (8-fach vergrößert, auf Deckbraun und Nachtblau), Streifen `r5_status_atlas.png` (108x9, so käme es nach `assets/status_icons.png`), Erzeugung `R5_statussymbole.py` (nur Standardbibliothek, ein Pixelraster je Symbol).

**Format.** 9x9 Pixel je Symbol, 1 Pixel dunkler Umriss `#0d0b10` (damit es auf Deck, Himmel und Schild gleich gut steht), höchstens 4 Farben plus Glanz, Platz für eine Rundenzahl in der rechten unteren Ecke. Streifen von links nach rechts in der Reihenfolge der Tabelle (die Reihenfolge ist die Spalte; `StatusIcons.ORDER`).

| Nr | Name | Altes Zeichen | Aussehen | Farben | Titel im Tooltip | Text im Tooltip |
|---|---|---|---|---|---|---|
| 0 | `schwelle` | `!` | Totenschädel mit roten Augen | Knochen `#e4dcc4`, Rot `#7a2424` | An der Schwelle | 0 Kraft. Der nächste Treffer tötet ihn mit 50 %. |
| 1 | `griff` | `G` | violetter Ring (Fangarm schließt sich) | Violett `#8a62a6`, Hell `#c4a0e0` | Im Würgegriff | Kann nichts tun. Fällt der Fangarm nicht, geht er über Bord. (Zahl: Züge bis Bord) |
| 2 | `blind` | `T` | violette Tintenkugel mit Glanz | Violett | Geblendet | Treffer −20 %. |
| 3 | `quetschen` | `Z` | rotes Warndreieck mit weißem Ausrufezeichen | Rot `#c8453d`, Weiß | Spannt sich | Zerquetscht im nächsten Zug alle Männer. Betäuben verhindert es. |
| 4 | `betaeubt` | `B` | gelber Stern (Rauten) | Gold `#e0b84a`, Hell `#f6dc5a` | Betäubt | Setzt den nächsten Zug aus. |
| 5 | `blutet` | `b` | roter Tropfen | Rot, Hell `#ee7a66` | Blutet | %d Schaden zu Beginn seines Zuges. |
| 6 | `markiert` | `M` | rotes Fadenkreuz (Ring mit Punkt) | Rot, Weiß | Markiert | Nimmt 25 % mehr Schaden und ist leichter zu treffen. |
| 7 | `schildwall` | `S` | blaues Schild mit goldenem Kreuz | Blau `#5b8fd0`, Hell `#a9cdf5`, Gold | Schildwall | Schutz +40 %. |
| 8 | `kriegslied` | `+` | grüner Pfeil nach oben (Kraft) | Grün `#5cae5a`, Hell `#b0e48c` | Kriegslied (Gegner: Kriegshorn) | Schaden +25 %. |
| 9 | `spott` | (fehlte) | orangene Scheibe mit weißem Ausrufezeichen | Orange `#e8903a` | Herausforderung | Die Gegner zielen fast nur auf ihn. |
| 10 | `panik` | (fehlte) | hellblauer Blitz | Hellblau `#a9cdf5` | Gelähmt | Setzt vor Schreck den nächsten Zug aus. |
| 11 | `leer` | (fehlte) | graue leere Patronenhülse | Grau `#a39b84` | Muskete leer | Erst nachladen, dann schießen. |

Die Farben tragen die Bedeutung (Rot = Schaden/Gefahr, Gelb = Betäubung, Blau = Schutz, Grün = Stärkung, Violett = Wahrnehmung/Griff, Orange = Aufmerksamkeit); die **Form** trägt sie zusätzlich (nicht nur Farbe, für Farbschwache).

**Rundenzahl**: 6 px, Papierweiß, 1 Pixel dunkle Kontur nach vier Seiten, bei (6, 10) von der oberen linken Ecke des Symbols; `n = 0` zeigt keine Zahl: bei Schwelle, Spannt sich, Muskete leer, Gelähmt und Herausforderung liefert `_status_list` keine Rundenzahl (die Regeln haben dort keinen sinnvollen Zähler, Gelähmt dauert genau einen Zug).
**Reihenfolge** (Wichtigkeit, `_status_list`): Schwelle, Griff, Spannt sich, Betäubt, Geblendet, Blutet, Markiert, Schildwall, Kriegslied, Herausforderung, Gelähmt, Muskete leer. Auf dem Schild höchstens fünf, danach "+n" (6 px, gedimmt). Das Kraken-Warnsymbol erscheint zusätzlich **doppelt groß** (18x18, `StatusIcons.draw_big`) links neben dem Schild und pulsiert (Bild `r5s_tip_kraken.png`).
**Tooltips**: Mit der Maus über einem Symbol zeigt die Kurzkarte rechts dessen Titel, Rundenzahl und Text (Bild `r5s_tip_icon.png`, `r5s_tip_gegner.png`). Die Trefferfläche je Symbol ist 11x11 Pixel (Symbol plus 1 Pixel Rand).
**Bilder in Spielsituation**: `r5s_stat.png` (alle Zustände an Männern und Gegnern), `r5s_kraken2.png` (Spannt sich), `r5s_snap.png` (Gelähmt nach Zusammenbruch).

Grenzen: Ein Kämpfer kann nach Tabelle bis zu 12 Zustände haben; auf dem Schild stehen fünf. Wer mehr hat, sieht den Rest in der Kurzkarte (links Werte, rechts bis zu 3 bis 4 Zustände, dann "+n weitere").

### 3.2 Namensschild im Stil von Darkest Dungeon

Vorbildmerkmale (eigene Ableitung, [E]; Darkest-Dungeon-Zahlen und Anordnung sind nicht belegt, siehe `R4_vorbild.md` 2.2): Name und Balken **direkt unter den Füßen**, Balkenfarbe nach Seite (grün für Männer, rot für Gegner), Verzweiflung als schmaler zweiter Balken, Zustandssymbole unter dem Balken, Name kursiv und serifenhaft (hier Georgia kursiv wie die Titel im Spiel).

| Teil | Maß (Spielfeldpixel) | Hinweis |
|---|---|---|
| Schild gesamt | `Rect2(cx − 26, 177, 52, 35)`, Riese `104 x 35` | Männer 4 Stück: Mitten 212, 156, 100, 44; Gegner 268, 324, 380, 436, Riese 408 |
| Band | äußeres Rechteck 52x10 bei y 177, innen (1,1) 50x8; seitliche Zungen: 2 Pixel breiter, y 179..185 | Rahmen schwarz (INK), Füllung nach Zustand, 1 Pixel helle Oberkante (Alpha 0,75), 1 Pixel dunkle Unterkante (Alpha 0,25) |
| Name | Georgia kursiv, 8 px (7, wenn er nicht in 46 Pixel passt), Grundlinie y 185, mittig, 1 Pixel Schatten statt Umrandung | längster Name: "Beschwörer" 43 px bei 8 px (passt); "Totenwart"/"Kaufmann" 39 |
| Kraftbalken | `UiSkin.bar` bei (x + 1, 188), Breite 50, Höhe 7, Randlinie 1 Pixel außen | Männer: Farbe nach Kraft (`_kraft_col`), Gegner `#c8453d`; Zahl (Kraft, 6 px, mittig, 1 Pixel Schatten) im Balken |
| Verzweiflung | `UiSkin.mini_bar` bei (x + 1, 198), Breite 50, Höhe 3, Marke bei 50 % | Violett bis 70, danach Rot; nur Männer |
| Zustände | y 203 (Männer) oder 198 (Gegner), 9x9, Schritt 10, mittig um `cx` | höchstens fünf, dann "+n" |
| Schutzmarke | "geschützt" / "offen!" bei y 174 (7 px, Grundlinie), nur Gegner mit `guarded` | wie heute, nur an den neuen Ort |

**Füllung und Rahmen nach Zustand** (Farben `#rrggbb`):

| Zustand | Füllung | Rahmenlinie |
|---|---|---|
| Mann, normal | `17131c` | `7d6330` (Bronze) |
| Gegner, normal | `1e1315` | `8a3a35` |
| am Zug (Mann oder Gegner) | `2e2410` | Gold `d9b24a`; Name Gold |
| Mann an der Schwelle | `2b1016` | `d2564b` |
| Kraken spannt sich | pulsiert zwischen `2b1016` und `6a1a1a` (Takt 140 ms) | `ff6a5a`; Name zusätzlich ": spannt sich!" |

Bilder: `r5s_fight2.png` (normal), `r5s_stat.png` (Schwelle, Zustände), `r5s_kraken2.png`, `r5s_tip_kraken.png` (Warnung).

**Was man heute auf dem Schild noch nicht sieht, aber sehen sollte (abhängig von R1):** Der Kraftbalken zeigt im Entwurf den **Spielstand**, nicht die **gezeigte** Kraft; er fällt damit **vor** dem Hieb (Beleg und Gegenmittel in `R1_ablauf.md`, Risiko R1: `hp0/hp1` im Ereignis). Sobald R1 liefert, zeigt der Balken `shown_hp` und zieht mit einem hellen **Nachzieher** (Segment in `lightened(0.5)`, schrumpft in 0,4 s) nach; Zustandssymbole poppen auf dem Schild erst beim Treffer auf (120 ms, 1 Bild Weiß), wozu R1 die `status`-Ereignisse (Priorität 3) braucht. Bis dahin zeigt der Entwurf sie sofort.

### 3.3 Zugleiste mit Mini-Porträts

Bild `r5s_fight2.png` oben, `r5s_stat.png`, `r5s_tip_icon.png`.

| Teil | Maß |
|---|---|
| Lage | ab x = 124, y 3 (aktiv) oder 5 |
| Eintrag aktiv | 22x26, Rahmen Gold (pulsiert, Alpha 0,6..1,0 mit 220 ms) 1 Pixel außen |
| Eintrag übrige | 16x22, Abstand 2, bis 10 Einträge |
| Rahmen/Füllung | 1 Pixel INK; Männer `26344d`, Gegner `4b2626` |
| Seitenstreifen | Männer: 2 Pixel `6f9fe0` **oben**; Gegner: 2 Pixel `d2564b` **unten** |
| Kopf | 14x14, aus dem Atlas `combat.png`: Quellrechteck `Rect2(15, Zeile·56 + 9, 14, 14)`; Kraken: `Rect2(20, 14, 48, 48)` auf 14x14 verkleinert; mittig, Gegner 1 Pixel tiefer |
| Kraft | 2 Pixel hoch, Breite w − 4, bei y + h − 7 (Männer) oder − 6 (Gegner), Farbe wie der Balken |
| Ende | "Runde n+1" (6 px, gedimmt) hinter dem letzten Eintrag, wenn weniger als zehn |
| Hover | Kurzkarte (2.2) der Figur; Klick ohne Wirkung |

Die Zugleiste liefert `Combat.upcoming(10)`: das ist der Rest **dieser** Runde (ab `cursor`), nicht die nächste. Das ist richtig so (die Reihenfolge der nächsten Runde steht erst am Rundenanfang fest). Wer zwei Züge in Folge hat (`Kampfrausch`), steht im Rest nur einmal (R1, Risiko R21).
**Offen (Pflegewunsch, nicht im Entwurf):** Überfahren eines Eintrags zeichnet auf der Bühne einen weißen Ring um die Figur; der Eintrag der handelnden Figur pulst zweimal, wenn ihr Zug beginnt (`R4_vorbild.md` Technik 15).

### 3.4 Kurzkarte und Bildunterschrift statt Tooltips

Im Kampf gibt es keinen der alten schwebenden Tooltips mehr:

* **Kurzkarte** (`_draw_fighter_card`) beim Überfahren einer Figur, eines Zugleisten-Eintrags oder eines Zustandssymbols: Rechteck 236 breit bei y 31 in der der Figur **gegenüberliegenden** Bühnenhälfte (damit sie weder die Figur noch deren Zielmarken verdeckt). Links Titel (Georgia, 9 px, Gold: "Name (Rolle)" oder Gegnername), "Kraft a von b · Tempo t", "Ausweichen d % · Schutz p %", bei Männern "Verzweiflung v · Müdigkeitsstufe"; rechts bis zu vier (Gegner drei) Zustände mit Symbol, Name und "· n Runden". Beim Überfahren eines Symbols zeigt die rechte Hälfte stattdessen dessen Titel und Erklärung (umbrochen, 7 px). Unter einer Trennlinie bis zu zwei **Hinweiszeilen** (7 px): Griff, Zerquetschen, Unerreichbarkeit des Kraken, Heldenmut/Zusammenbruch-Hinweis, "Kann: …", "Immun gegen: …", "Feige: …". Bilder `r5s_tip_figur.png`, `r5s_tip_gegner.png`, `r5s_tip_held.png`, `r5s_tip_kraken.png`.
* **Bildunterschrift** (`_card_help`) beim Überfahren einer Fertigkeitskarte: zwei Zeilen unter der Ansage; Zeile 1 der Name und die Beschreibung, Zeile 2 die Reihenbedingung und was dazugehört (in Grün/Rot, wie `Tips.skill`). Bild `r5s_tip_karte.png`.
* Die **Aufstellung** behält die schwebenden Tooltips (`Tips.fight_man`, `Tips.loadout`, `Tips.fight_auto`).

**Bekannter Mangel des Entwurfs:** Die Kurzkarte kann mit Hinweiszeilen bis y 96 reichen und dann die Köpfe der gegenüberliegenden Hälfte berühren (Bild `r5s_tip_kraken.png`: Staffspitze des Skalden). Abhilfe: Hinweiszeilen nur anzeigen, solange keine Zielwahl läuft, oder die Kurzkarte auf 2 Zeilen kürzen. Die Texte selbst gehören nach `scripts/tips.gd` (`Tips.fighter_card`), nicht in `hud.gd`.

### 3.5 Chronik

Taste `Tab` oder Knopf "Chronik (Tab)", `Rect2(4, 34, 196, 176)`, die letzten 15 Meldungen (7 px, Farbe nach `kind`: Grün gut, Rot schlecht, Papier neutral), Titel "Chronik" (Georgia 9 px). Reines Lesen; schließt mit `Tab` oder `Esc`. Bild `r5s_chron.png`.

---

## 4. Namensschild und Fertigkeitsbanner der handelnden Figur im Fokusbild

Bilder: `r5s_fokus_mann.png` (Mann, Hieb), `r5s_fokus_kraken.png` (Riese, Schnabelhieb), `r5s_foeact.png` (Gegner, Wache: Hieb, Ereignisablauf), `r5s_pick.png` (Ziellage des Mannes).
Alles hier fügt sich in die Beats von `R4_vorbild.md` 4 (Technik 1, 5, 16) und `R1_ablauf.md` ein; die **Zeiten** sind Ausgangswerte [E], die Maße sind am Bild geprüft.

### 4.1 Zwei Teile, ein Auftritt

1. **Namensschild am Fuß** (Abschnitt 3.2) der handelnden Figur: Gold gefasst (Füllung `2e2410`, Rahmen Gold, Name Gold) und eine goldene Linie 2 Pixel unter den Füßen (`Rect2(cx − 22, 174, 44, 2)`, dazu ein weicher Lichtschein darüber, 3 Stufen). Das gilt schon **während der Eingabe** (Dauerlicht, R4 Technik 16), nicht erst bei der Aktion.
2. **Fokusschild über dem Kopf** (neu): ein Schild mit Fertigkeitssymbol, Name der Figur und Name der Fertigkeit. Es erscheint **mit dem Ausholen** (Ereignis `attack`), nicht davor, und ersetzt das Banner oben rechts (`_fx.banner`, 236, 4, 172x18).

### 4.2 Das Fokusschild, Maße

| Teil | Maß |
|---|---|
| Größe | Höhe 24, Breite = max(Breite des Fertigkeitsnamens bei Georgia kursiv 10 px, Breite des Figurennamens bei 7 px) + 32, auf ganze Pixel |
| Lage (Mann, Gegner) | x mittig über `cx` (nach dem Zoom: `_fx.stage_to_screen`), auf [4, 476 − Breite] geklemmt; y = Kopfhöhe − 32 = **36** (Kopf bei 68) |
| Lage (Riese) | **links neben dem Kopf**: x = `cx − 72 − Breite`, y = 44 (Kopfhöhe 36 + 8); die Spitze zeigt nach rechts auf den Kopf (Dreieck 6 Pixel breit, 10 hoch) |
| Rahmen | 1 Pixel INK außen; oben eine 2-Pixel-Linie in der Seitenfarbe, unten eine 1-Pixel-Linie Alpha 0,35 |
| Farben Mann | Füllung `1a2030` (96 %), Linie Gold `d9b24a` |
| Farben Gegner | Füllung `2a1416` (96 %), Linie `d2564b` ("kalte Farbe", R4: Gegnername 200 ms **vor** dem Ausholen) |
| Symbol | `SkillIcons` 16x16 bei (x + 4, y + 5) in einem 18x18-Rahmen `INK` bei (x + 3, y + 4) |
| Zeile 1 | Figurenname, 7 px, in der Seitenfarbe, Grundlinie y + 11, x + 25 |
| Zeile 2 | Fertigkeitsname, Georgia kursiv 10 px, Papierweiß, Grundlinie y + 21, x + 25 |
| Spitze | nach unten 8x5 Pixel unter dem Schild, mittig über `cx` (Mann/Gegner) |
| Schatten | 1 Pixel Schlagschatten statt 3 Pixel Umrandung (`_t1`) |

Ablauf (Ausgangswerte aus R4 Technik 5): erscheint in 100 ms (Cubic Out, 8 Pixel von oben nachrückend, Alpha 0 bis 1), steht bis **Kontakt + 150 ms** (etwa 400 ms), geht in 100 ms heraus (Alpha 1 bis 0, im Entwurf `outv = clamp(t / 0.25, 0, 1)`). Heute steht das Banner 1,25 s und überlappt den nächsten Zug; der Entwurf nutzt diese Zeit (`FightFx.show_banner`, `t = 1.25`) noch unverändert, weil die Regie (R1) die Dauer neu setzen wird: Parameter `dur` zu `show_banner` ergänzen.

Besonderheiten:

* **Kritischer Treffer**: Linie und Rahmen golden (auch beim Gegner), 1 Bild weißer Blitz im Symbolrahmen, Zeile 2 um die Marke " · Kritisch!" ergänzt (7 px, Gold). Dazu braucht das Schild das Feld `crit` des `hit`-Ereignisses (liegt vor).
* **Heilung, Lied, Hilfe**: kleiner (Schrift 7), 300 ms, **kein** Fokusschild am Ziel; das Ziel bekommt nur die schwebende Zahl.
* **Flächenangriffe** (Wirbelhieb, Pfeilregen): ein Schild über dem Handelnden, keines an den Zielen.
* **Gegner mit mehreren Aktionen hintereinander**: das Schild gleitet zur neuen Figur (Kameraübergabe, R4 Technik 4), statt zu verschwinden und wiederaufzutauchen.
* **Große Ansage hat Vorrang**: Läuft eine große Ansage, wird das Fokusschild nicht gezeichnet.
* **Unter Zoom**: Das Schild zoomt **nicht** mit (bleibt lesbar), folgt aber dem Kopf: `FightFx.stage_to_screen(p) = p * zoom_scale() + zoom_offset()` (im Entwurf ergänzt). Beim Wackeln wackelt es nicht.
* **Dimmung** (R4 Technik 1): Während der Aktion sind alle Figuren außer Handelndem und Ziel auf 55 % abgedunkelt; das gilt **auch für deren Namensschilder** (Alpha 0,55). Handelnder und Ziel behalten volles Licht; das Schild des Ziels zeigt den fallenden Kraftbalken (3.2). (Nicht im Entwurf; die Zahlen sind aus R4 übernommen.)

### 4.3 Zusammenspiel mit dem Rest

| Element | Während Eingabe | Während Aktion |
|---|---|---|
| Goldenes Dreieck über dem Kopf | ja (8x5 bei Kopf − 8) | entfällt (das Fokusschild hat eine Spitze) |
| Fußschild des Handelnden | gold | gold |
| Zielmarken, Q W E R | ja | entfallen |
| Kurzkarte (Hover) | ja | nein |
| Bildunterschrift | Karte oder letzte Meldungen | letzte Meldungen |
| Karten | wählbar | gesperrt (abgedunkelt) |

---

## 5. Alle UI-Texte (bestehend) und die neuen deutschen Texte

### 5.1 Bestehende Texte (heute im Spiel)

**`scripts/hud.gd`, Kampf**

| Ort | Text |
|---|---|
| Kopf | `Deckkampf: %s` (Kampfname), `Runde %d` |
| Beschriftung der Bühne | `Eure Männer (Reihe 1 vorn)`, `Gegner` |
| Schutzmarke | `geschützt`, `offen!` |
| Zustandsbuchstaben | `!` Schwelle, `G` Griff, `T` geblendet, `Z` spannt sich, `B` betäubt, `b` blutet, `M` markiert, `S` Schildwall, `+` Kriegslied |
| Hinweiszeile | `Wähle ein Ziel (Q W E R oder Klick), Esc bricht ab.`, `%s ist dran. Wähle eine Fertigkeit (1–6).`, `%s ist am Zug …` |
| Karten (feste) | `Platztausch` / `tauscht mit einem` / `anderen Mann`; `Rückzug` / `Kampf endet ohne` / `Sieg` |
| Abwarten | `Abwarten (Leertaste)` |
| Banner | `%s: %s` (Name: Fertigkeit); Name bei Gegnern aus `Foes.info(kind).short`; `Würgen` für `f_kr_wuerg` |
| Große Ansagen | `KAMPF` / Kampfname; `DER KRAKEN` / `Fangarme zuerst, dann der Körper`; `SIEG` / `%d Gegner gefallen`; `DER KRAKEN SINKT` / `Das Meer ist wieder still`; `NIEDERLAGE` / `niemand steht mehr`; `RÜCKZUG` / `ihr zieht euch zurück`; `HELDENMUT` / `%s: %s`; `ZUSAMMENBRUCH` / `%s: %s`; `GEFALLEN` / `%s kehrt nicht zurück` |
| Schwebende Texte | `−%d`, `verfehlt`, `+%d`, `über Bord!`, `wächst nach`; `gepackt!`, `frei!`, `spannt sich!`, `rastet aus!`, `unterbrochen!`, `geblendet`, `Rache!` und `beschworen` kommen als Ereignistext aus `combat.gd` |
| Aufstellung | `Aufstellung`, `gegen: %s`, `Bis zu vier Männer kämpfen, die anderen bleiben zurück. Wer zuerst steht, kämpft vorn. Auf die Symbole klicken wählt die Fertigkeiten.`, `Reihe %d`, `Reserve`, `Kampfreihe (vorn zuerst)`, `%d  frei`, `Gegner`, `%d  %s  (Kraft %d)` (+ `· <Rolle>`), `Beste vier (A)`, `Kampf! (Enter)`, `Tempo und Rolle bestimmen, wer wann was kann.` |
| Fertigkeitenwahl | `Fertigkeiten: %s, %s`, `Wähle bis zu vier der sechs. Die Wahl gilt für alle weiteren Kämpfe, bis du sie änderst.`, `gewählt`, `Ohne Nachladen ist die Muskete nach einem Schuss nutzlos.`, `Noch %d Platz frei.`, `Standard`, `Fertig (Esc)` |
| Rollen der Gegner im Überblick (`Foes.role_hint`) | `Heiler`, `Beschützer`, `Beschwörer`, `Antreiber`, `Zerrer`, `Rammer`, `Schreier`, `Schütze` |

**`scripts/tips.gd`, Kampf**

| Funktion | Text |
|---|---|
| `skill_short` (Karte, 2 Zeilen) | `nur aus Reihe` / `1, 2, 3`; `keine Einsätze` / `mehr`; `Muskete leer:` / `erst nachladen`; `Muskete ist` / `schon geladen`; `kein Ziel in` / `Reichweite`; `Treffer %d %%` / `Schaden %d–%d`; `alle Gegner` / `markiert`; `%d Ziele` / `je %d–%d`; `Gegner zielen` / `nur auf ihn`; `Schutz +40 %` / `zieht Gegner an` oder `für einen Mann`; `löst Betäubung,` / `Blutung, Tinte`; `Schaden +25 %` / `alle, %s` oder `%d Runden`; `Kraft +%d`; `Mut +%d`; `lädt die` / `Muskete` |
| `skill` (Tooltip einer Karte) | Beschreibung der Fertigkeit; `Stufe %d aus der Kampfschule: %s.`; `Einsetzbar aus Reihe %s (jetzt Reihe %d).`; `Trifft Reihe %s des Ziels.`; `Die Muskete ist geladen` / `leer`.; `Noch %d von %d Einsätzen in diesem Kampf.`; `%s: Treffer %d %%, Schaden %d–%d` |
| `fighter` (Tooltip einer Figur) | `Kraft %d von %d` (+ `  ·  an der Schwelle`); `Ausweichen %d %%, Schutz %d %%, Tempo %d`; `Verzweiflung %d. Müdigkeit: %s`; `In diesem Kampf schon gekippt.`; `Bei 100 Verzweiflung kippt er: mit etwa 3 Chancen in 10 wächst er über sich hinaus (Heldenmut, ein Skalde hilft), sonst bricht er zusammen (verzagt oder Berserker).`; `Zustand: betäubt, blutet (%d × %d), markiert, Schildwall, Kriegslied, im Griff (G), geblendet (T): Treffer −20 % für %d Runden, spannt sich (Z)`; `%s hält ihn: fällt oder betäubt der Fangarm nicht, geht er über Bord. Er selbst kann nichts tun.`; `Hält %s und zieht ihn in %d Zügen über Bord. Fällt er, ist der Mann frei; betäubt, verliert er Zeit.`; `Zerquetscht im nächsten Zug alle Männer auf Deck. Betäubt, verpufft es.`; `Unerreichbar, solange noch ein Fangarm steht. Alle Fangarme fällen (sie wachsen nach %d Runden mit 60 %% Kraft nach), dann ist er dran.`; `Jetzt offen: Fangarme sind alle gefällt. Schnell zuschlagen, bevor einer nachwächst.`; `Kann: …`; `Und alle paar Runden Zerquetschen: erst angekündigt, im nächsten Zug ausgeführt.`; `Immun gegen: …`; `Feige: flieht, wenn er allein ist.`; `Mit %s: Treffer %d %%, Schaden %d–%d` |
| `fight_man` | `%s: %s` (Rolle: Beschreibung); `Fertigkeiten: …`; `Kraft %d (%s), Verzweiflung %d.`; Ausrüstungszeilen; `Schmiede: Waffe Stufe %d (+%d %% Schaden), Rüstung Stufe %d (+%d %% Schutz).`; `Müde Männer treffen schlechter und schaden weniger. Wer bei 0 Kraft getroffen wird, kann sterben.`; `Aus der Reserve: kein Platz an Deck bleibt unbesetzt.`; `Er verlässt für den Kampf seinen Platz (%s).` |
| `loadout`, `fight_auto` | `Fertigkeiten von %s`; `Klicken wählt aus den sechs Fertigkeiten der Rolle vier aus.`; `Beste vier`; `Wählt aus allen Männern bis zu vier: von jeder Rolle den Kräftigsten, Schildträger vorn, dahinter Axt und Bogen, der Skalde hinten. Müde Männer (unter 25 Kraft) bleiben möglichst zurück.` |

**`scripts/combat.gd`, Meldungen des Kampftagebuchs** (`_log`; erscheinen in der Bildunterschrift und der Chronik): `Der Kampf beginnt: %d gegen %d.`; `— Runde %d —`; `Ein neuer Fangarm bricht aus dem Wasser.`; `%s blutet (−%d).`; `%s ist betäubt und setzt aus.`; `Der Kraken verliert den Schwung: das Zerquetschen misslingt.`; `%s hängt im Griff und kann sich nicht rühren.`; `%s ist vor Schreck wie gelähmt und setzt aus.`; `%s zögert und verliert seinen Zug (verzagt).`; `%s wechselt auf Reihe %d.`; `%s wartet.`; `Der Rückzug wird geblasen.`; `%s flieht.`; `%s rückt vor.`; `Der Kraken spannt seine Arme um das Schiff! Im nächsten Zug zerquetscht er das Deck. Ein Betäubter kann es nicht.`; `%s lässt %s los.`; `%s presst %s: −%d`; `  %s wird über Bord gezerrt!`; `  %s ist frei!`; `%s: %s gegen %s.`; `%s: %s.`; `  verfehlt %s.`; `  trifft %s: −%d` (+ ` (kritisch!)`); `  %s verliert den Mut (Verzweiflung +%d).`; `  %s ist betäubt.`; `  %s blutet.`; `  %s ist markiert.`; `  %s wird nach vorn gezerrt.`; `  %s wird nach hinten gestoßen.`; `  %s hängt im Griff! Fällt der Fangarm nicht bald, geht er über Bord.`; `  %s sieht nichts mehr (Treffer −20 %%).`; `%s: %s schützt %s.`; `%s ruft die Gegner heraus: sie zielen nur noch auf ihn.`; `%s lädt die Muskete nach.`; `%s: %s heilt %s (Kraft +%d).`; `%s: %s tröstet %s (Verzweiflung −%d).`; `%s ruft einen %s herbei.`; `HELDENMUT! %s stürmt vor: ein Zug extra, 3 Runden mehr Schaden.`; `HELDENMUT! %s beißt die Zähne zusammen: Kraft +30 und Schutz.`; `HELDENMUT! %s reißt alle mit: mehr Schaden für alle, Verzweiflung −8.`; `%s ist wieder ganz bei sich.`; `ZUSAMMENBRUCH! %s sieht rot: stärker, aber nicht mehr zu bremsen.`; `ZUSAMMENBRUCH! %s verliert den Mut und erstarrt. Seine Angst steckt die anderen an.`; `PANIK! %s ist vor Schreck wie gelähmt.`; `%s rastet aus und schlägt %s!`; `  %s hält noch durch.`; `  %s ist an der Schwelle!`; `  %s fällt.`; `Der Kraken sinkt brüllend in die Tiefe, seine Fangarme erschlaffen.`; `  %s fällt im Kampf.`; `  %s will Rache für seinen Bruder %s!`; `  %s trauert um %s.`

**Namen**: Fertigkeiten und ihre Beschreibungen stehen in `scripts/roles.gd`, Gegner in `scripts/foes.gd` (`name`, `short`), Kampfnamen in `Foes.FORMATIONS` (`Draugr`, `Räuber`, `Wachen des Handelsschiffs`, `Dorfbewohner`, `Kraken`). Sie wurden nicht kopiert; gemessen wurden sie (5.3).

### 5.2 Neue und geänderte Texte (Entwurf und Empfehlung)

**Im Entwurf umgesetzt**

| Ort | Text |
|---|---|
| Kopfzeile | `Chronik (Tab)` (Knopf), `Runde %d` hinter der Zugleiste als Hinweis auf die nächste Runde |
| Chronik | `Chronik` |
| Ansage | `%s ist dran: Fertigkeit wählen (1–6).`, `%s: Ziel wählen (Q W E R oder Klick), Esc zurück.`, `Platztausch: mit wem? Q W E R oder Klick, Esc zurück.`, `%s ist am Zug …` (Gegnername aus `Foes.info.name`), `Sieg: %d Gegner gefallen.`, `Niederlage: niemand steht mehr.`, `Rückzug: ihr zieht euch zurück.` |
| Knopf | `Abwarten (Leertaste)` |
| Tastenzeile | `1–6 Fertigkeit    Leertaste warten    Tab Chronik`; `Q W E R Ziel    Esc zurück    Tab Chronik`; `Tab Chronik` |
| Kartenhilfe (Platztausch) | `Platztausch: tauscht mit einem anderen Mann die Reihe und kostet den Zug.` / `Vorn wird man getroffen und trifft nah; hinten schießen und singen die anderen.` |
| Kartenhilfe (Rückzug) | `Rückzug: der Kampf endet sofort, ohne Sieg und ohne Beute.` / `Wer noch im Griff eines Fangarms hängt, geht dabei über Bord.` |
| Gegnerkarte | `Kann:`, `Kraft %d von %d  ·  <Rolle>` |
| Zustände (siehe 3.1) | `An der Schwelle`, `Im Würgegriff`, `Geblendet`, `Spannt sich`, `Betäubt`, `Blutet`, `Markiert`, `Schildwall`, `Kriegslied` (Gegner: `Kriegshorn`), `Herausforderung`, `Gelähmt`, `Muskete leer` mit den Texten der Tabelle 3.1; Rundenzusatz ` · %d Runden`, ` · 1 Runde`; `kein Zustand`; `+%d weitere` |
| Kurzkarte (Zeilen) | `Kraft %d von %d  ·  Tempo %d`, `Ausweichen %d %%  ·  Schutz %d %%`, `Verzweiflung %d  ·  %s` |
| Kurzkarte (Hinweise) | `%s hält ihn: ohne Befreiung geht er über Bord.`, `Hält %s: in %d Zügen über Bord. Fällt er, ist der Mann frei.`, `Zerquetscht im nächsten Zug alle Männer. Betäuben verhindert es.`, `Unerreichbar, solange ein Fangarm steht.`, `Jetzt offen: schnell zuschlagen, bevor ein Fangarm nachwächst.`, `Bei 100 Verzweiflung: Heldenmut oder Zusammenbruch.`, `Kann: …`, `Immun gegen: Blutung, Betäubung`, `Feige: flieht, wenn er allein ist.` |
| Schild | `<Name>: spannt sich!` (Kraken) |
| Aufstellung | `Gegner (vorn zuerst)`, `Kraft %d` (Gegnerkarte), `Fertigkeiten: klicken`; "Kampf!" gold hervorgehoben |
| Fertigkeitenwahl | `einsetzbar aus Reihe` mit vier Feldern 1 bis 4; `%d von %d gewählt.` statt "Noch %d Platz frei." |

**Empfohlen, noch nicht im Entwurf**

| Ort | Text | Zweck |
|---|---|---|
| Ansage bei gespanntem Kraken (Mann am Zug) | `Achtung: Der Kraken spannt sich! Betäubt ihn, sonst zerquetscht er das Deck.` (Rot, anstelle der üblichen Ansage; nur wenn eine Fertigkeit mit Betäubung zur Wahl steht, sonst `Achtung: Der Kraken spannt sich! Betäuben ist nicht möglich.`) | Gefährlichste Ankündigung deutlich machen (A4) |
| Ansage bei Zielwahl mit Verbündetem | `%s: Wen? Q W E R oder Klick, Esc zurück.` | passt zu `armed_ally`, statt "Ziel wählen" |
| Ansage bei Zielwahl mit Fläche | wird übersprungen (`needs_target` ist falsch), kein Text | keine Änderung |
| Rückzug mit Bestätigung (**wahlweise**) | erster Druck auf `6`: Karte pulsiert, Ansage `Rückzug wirklich? Noch einmal 6 oder Klick, Esc zurück.`; erst der zweite Druck führt aus | Schutz vor Fehlgriff (B3); Bots rufen `voy.combat_flee` direkt, sind nicht berührt; ist eine Entscheidung des Besitzers im Sinn von "Spielfluss bleibt klar", deshalb nicht im Pflichtpaket |
| Fokusschild bei Krit | Zeile 2 `Fertigkeit · Kritisch!` | Technik 5 (R4) |
| Tooltips `Tips.fighter` (Zustandsliste) | `Zustand: betäubt, blutet (%d × %d), markiert, Schildwall, Kriegslied, im Griff, geblendet: Treffer −20 % für %d Runden, spannt sich, herausfordernd, gelähmt` (ohne Buchstaben in Klammern; zwei neue Zustände) | Buchstaben fallen weg |
| `Tips.skill_short` | `"alle, %s" % left` ändern: `["Schaden +25 %", "alle" if left == "" else "alle, " + left]` | hängendes Komma (B6) |

### 5.3 Messwerte der Textbreiten (Segoe UI Semibold, Georgia kursiv; `R5_messen.gd.txt`, Aufruf `godot --headless --path . --script tools/r5_measure.gd`)

Fertigkeitsnamen in Spielfeldpixeln bei 8, 7, 6 px; Kartenbreite alt 44, neu 46 (Auswahl der Schriftgröße):

| Name | 8 px | 7 px | 6 px | alt (7 px, 44) | neu (46) |
|---|---|---|---|---|---|
| Herausforderung | 61 | 53 | 46 | zu breit | passt |
| Musketenschuss | 58 | 51 | 44 | zu breit | passt |
| Gezielter Schuss | 58 | 50 | 43 | zu breit | passt |
| Rückzugsschuss | 57 | 50 | 43 | zu breit | passt |
| Rundumschlag | 53 | 46 | 40 | zu breit | 7 px passt knapp (46 von 46) |
| Schreckschuss | 51 | 44 | 38 | knapp | 7 px passt (44 von 46) |
| alle übrigen (Hieb bis Lähmschuss) | bis 43 | bis 37 | bis 32 | passt | 8 px passt |

Namensschilder (Georgia kursiv 8 px, innen 46 Pixel): längster Name `Beschwörer` 43, danach `Totenwart` und `Kaufmann` 39, `Trommler` 37, `Armbrust` 36; Männernamen bis 29. Alles passt bei 8 px. Kampfname `Wachen des Handelsschiffs`: 96 px bei 8 px, Platz 112.
Meldungen: längste Zeile (`Der Kraken spannt seine Arme ...`) 408 px bei 8 px, Platz 464, passt.

---

## 6. Prüfliste, offene Punkte, Dateien

### 6.1 Abnahme (jede Zeile ein Bild oder ein Lauf)

| Prüfung | Weg | Soll |
|---|---|---|
| Alle Zustände des Kampfbildschirms | `shot.ps1` mit `--shotfight`, `--shotfight2`, `--shotfight3`, `--shotkraken`, `--shotkraken2`, `--shotheroic`, `--shotsnap`, `--shotfx`, `--shotfx2`, `--shotfx3`, `--shotloadout`, dazu die neuen Flags (6.3); Skript `R5_shots.ps1.txt` fotografiert alle Zustände nacheinander | nichts abgeschnitten, nichts überdeckt, Schilder lesbar |
| Lange Namen | `--shotui=long`, `--shotui=long2` | alle Namen innerhalb des Kartenrahmens |
| Zustände | `--shotui=stat` | alle Symbole erkennbar, Zahlen lesbar |
| Hover über Figur, Symbol, Karte, Zugleiste | `--hovermouse=x,y` mit den Punkten aus `R5_shots.ps1.txt` (Mann (120,86), Karte (200,280), Gegner (268,130), Symbol (100,207), Kraken (408,110)) | Kurzkarte überdeckt keine Zielmarke |
| Klickflächen | Zeichnen mit `--hudflag=zones`, danach Abgleich der IDs in 2.8 | jede ID erhalten, nichts Neues stört |
| Rückzug | Mann mit 2 oder 3 Fertigkeiten | `6` bleibt Rückzug, `3` oder `4` tun nichts |
| Regeln, Balance, Speicherstände | `tools/dev/rungd.ps1 -Script tools/selftest.gd` | `FEHLER: 0` |
| Töne, Musik | `tools/sfxtest.gd`, `tools/musictest.gd` | wie vorher |
| Bots | `tools/dev/runbots.ps1 -Mode --autoplay -Seeds @(1,2,3)` und `--random` | keine Fehlerzeilen, keine längere Laufzeit (die Oberfläche läuft nicht im Schnellmodus) |
| Kein Absturz im Headless-Modus | Texturen (`status_icons.png`, `combat.png`, Kraken) nur laden, wenn `DisplayServer.get_name() != "headless"` | `StatusIcons.texture()` lädt träge und liefert in Tests nur, was gezeichnet wird; `Hud._draw` läuft dort nicht |
| Pixelraster | Bilder bei Zoom 1,0 und 1,125 vergleichen | keine wandernden Kanten bei Zeichensätzen (Name und Balken zoomen mit der Bühne, siehe R1 R13) |

### 6.2 Offene Punkte und Grenzen des Entwurfs

1. **Anzeige eilt dem Spielstand voraus** (Kraft, Zustände, Zugleiste): erst mit R1 (`hp0/hp1`, `status`, `turn`) behebbar.
2. **Kamera** (Dimmung 55 %, Zoom, Brennpunkt y 215): gehört den anderen Berichten; die Hilfsfunktion `FightFx.stage_to_screen` und die Reihenfolge der Zeichnung (2.9) sind die Schnittstelle.
3. **Figurengröße**: Die Doppelung 2x ist die einfache Lösung; die Rig-Figuren (R2) verlangen die Konstante `FIG_PX` und den Kopfpunkt (`head_y`) für Fokusschild und Zielmarke.
4. **Kurzkarte** kann Köpfe der Gegenseite berühren (3.4); `fchronplatte` und Kurzkarte schließen sich aus (`not _chron_open`).
5. **Mausklicks nicht am Gerät erprobt**; die Klickflächen sind aus dem Quelltext abgeleitet und über die Zielwahl-Bilder geprüft.
6. **Zugleiste**: Hover-Ring auf der Bühne und Pulsieren des aktiven Eintrags (3.3) fehlen.
7. **Rückzug-Bestätigung** und die Krakenansage (5.2) sind Empfehlungen, nicht umgesetzt.
8. **Texte gehören nach `tips.gd`** (Kurzkarte, Hinweise, Zustandstitel), im Entwurf stehen sie noch in `hud.gd`.
9. Der Entwurf verändert `Hud._fight_options`: es liefert jetzt immer sechs Einträge (leere Plätze als Leerstring). Außerhalb von `hud.gd` wird die Funktion nirgends benutzt (per Suche geprüft), die Tests sind nicht betroffen.

### 6.3 Dateien

| Datei | Inhalt |
|---|---|
| `docs/kampf_spektakel/R5_oberflaeche.md` | dieser Bericht |
| `docs/kampf_spektakel/R5_statussymbole.py` | erzeugt `img/r5_status_atlas.png` und `img/r5_status_sheet.png`; Zeichenvorlage der 12 Symbole |
| `docs/kampf_spektakel/R5_proto_hud.diff.txt`, `R5_proto_main.diff.txt`, `R5_proto_fight_fx.diff.txt` | der Entwurf als Unterschiede zum Stand vor dem Umbau (Arbeitskopie `..\_sandbox\oberflaeche\`) |
| `docs/kampf_spektakel/R5_proto_status_icons.gd.txt` | `scripts/status_icons.gd` (`StatusIcons.draw`, `draw_big`, `ORDER`) |
| `docs/kampf_spektakel/R5_messen.gd.txt` | Textbreitenmessung (`tools/r5_measure.gd` in der Arbeitskopie) |
| `docs/kampf_spektakel/R5_shots.ps1.txt` | Aufruffolge aller Kampfbilder (Parameter `-Proj` Arbeitskopie, `-Out` Zielordner, `-Pre` Dateipräfix) |
| `img/r5_*.png` | Bestand (heutiges Spiel): `r5_fight2`, `r5_fight3`, `r5_pick`, `r5_move`, `r5_foe`, `r5_stat`, `r5_win`, `r5_lose`, `r5_flee`, `r5_heroic`, `r5_snap`, `r5_intro`, `r5_kraken1`, `r5_kraken2`, `r5_fx_axt`, `r5_fx_bogen`, `r5_fx_musket`, `r5_prep`, `r5_prep3`, `r5_kprep`, `r5_loadout`, `r5_lo`, `r5_tip_card`, `r5_tip_fighter`, `r5_tip_kraken`, `r5_tip_prep`, `r5_tip_prep2`, `r5_tip_queue`, `r5_tip_stat`, `r5_zonen_ist` |
| `img/r5s_*.png` | Entwurf: `r5s_fight2`, `r5s_pick`, `r5s_move`, `r5s_foe`, `r5s_foeact`, `r5s_fight_taste`, `r5s_stat`, `r5s_win`, `r5s_lose`, `r5s_flee`, `r5s_heroic`, `r5s_snap`, `r5s_intro`, `r5s_kraken1`, `r5s_kraken2`, `r5s_bogen`, `r5s_prep`, `r5s_prep3`, `r5s_kprep`, `r5s_lo`, `r5s_lo2`, `r5s_chron`, `r5s_zonen`, `r5s_fokus_mann`, `r5s_fokus_kraken`, `r5s_karten_lang_schild`, `r5s_karten_lang_muskete`, `r5s_tip_figur`, `r5s_tip_gegner`, `r5s_tip_held`, `r5s_tip_icon`, `r5s_tip_karte`, `r5s_tip_kraken` |

Neue Screenshot-Flags in der Arbeitskopie (`main.gd`, `hud.gd`; im Hauptprojekt noch nicht vorhanden):
`--shotui=pick|move|foe|foeact|stat|win|lose|flee|lo|lo2|prep3|kprep|long|long2` (Zustand des Deckkampfs), `--hudflag=chron,zones,zonesist,nointro,banner,bannerboss` (Chronik offen, Zonen einblenden, ohne Einleitungsansage, Fokusschild stehen lassen), `--zimg=Pfad` (Hintergrundbild für `zonesist`).
