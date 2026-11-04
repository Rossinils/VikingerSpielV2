# R2: Figuren (Bestand, Posen, drei Wege, Empfehlung)

Auftrag: die Kämpfer sollen lebendiger und größer werden, damit der Angreifer im Rampenlicht wirklich etwas zu zeigen hat. Dieses Blatt
analysiert die Bildpipeline und die 25 Figuren, sagt ehrlich, was heute da ist, was für eine Darkest-Dungeon-artige Darstellung fehlt,
und entscheidet zwischen drei Wegen. Alles Behauptete ist an Bildern geprüft (Ordner `img/`, Namen mit `R2_`). Prototypen liefen nur in der
Arbeitskopie `..\_sandbox\figuren\`, im Hauptprojekt wurde keine Spieldatei angefasst.

## 0. Kurzfassung

1. **Heute:** 25 Figuren (5 Männer, 20 Gegner) plus Kraken, je **fünf Standbilder** (Stehen A, Stehen B, Angriff, Treffer, An der Schwelle) in Zellen
   von 44 x 56. Der Körper ist nur **36 bis 46 Pixel hoch** (11 bis 14 % der Feldhöhe 320). Der Stil ist einheitlich und lesbar, aber jede
   Figur hat **keinen Ausholen-, Nachschwung-, Block-, Zauber-, Schuss-, Sturz- oder Siegesframe**. Stehen A/B unterscheiden sich um ein Pixel.
   **24 von 125 Frames sind am Zellrand abgeschnitten**, darunter bei 19 von 25 Figuren der wichtigste Frame "Angriff" (beim Axtmann fehlt der Axtkopf,
   `img/R2_proto_oldstrike.png`).
2. **Was die Engine mit Pixel-Snap kann (im Spiel gemessen, Abschnitt 3):** ganzzahlige Skalierung und Zeilenband-Scherung sind sauber;
   Drehung ist bis etwa 10 Grad brauchbar, darüber sieht man "gedrehte Pixel"; Stauchen/Strecken geht bis etwa 12 %; Nachbilder und Aufblitzen
   (Farbfaktor über 1) funktionieren und kosten fast nichts. Ein **2x-Kamerazoom ist scharf**, entlarvt aber die Schwächen der kleinen Figuren
   (fehlender Axtkopf, Gesichter aus zwei Punkten); Text innerhalb des Zooms wird mitvergrößert und muss ausgenommen werden.
3. **Prozedural allein (Weg A) macht aus einem Standbild nie einen Schlag:** die Waffe schwingt nicht. Es wirkt wie ein Ruck mit Nachbildern.
4. **Ein gemeinsames Körper-Rig im Python-Code (Weg B) funktioniert:** Prototyp `R2_rig_proto.py` erzeugt aus Beschreibungen (Körperbau, Farben, Kopf,
   Waffe) **31 Frames je Figur** in einer Zelle von **112 x 104**, Körper **65 px** hoch (1,6-fach), Waffen und Arme als Geometrie (scharf, nie gedrehte Pixel).
   8 Figuren aus 5 Haltungsklassen stehen (Bilder `R2_rig_helden.png`, `R2_rig_gegner.png`, `R2_rig_alle_frames.png`, Bühne `R2_proto_rigstrike.png`).
   Ehrlich: sie sind noch steifer und gröber als die handgesetzten Figuren (dünne Waffen, Gesichter aus zwei Punkten, kein Stoff, Standbreite immer gleich),
   aber sie tragen jede Pose, die man braucht, und sind als Satz konsistent.
5. **Empfehlung: Weg C in Stufen.** Stufe 1 ist Weg A in der Anzeige (Zeitleiste der Posen, Lehnen, Nachbilder, Aufblitzen, Zoomführung) auf einer
   **Frame-Namenstabelle statt Spaltenzahlen**, sofort nutzbar und später unverändert weiterverwendet. Stufe 2 ist das Rig für **alle 22 menschlichen
   Figuren** (5 Männer, 17 Gegner). **Hund, Fangarm und Kraken behalten ihre Zellen** und bekommen A-Behandlung plus zwei bis drei von Hand gezeichnete
   Zusatzframes (Bild `R2_proto_mixed.png` zeigt, dass beide Größen zusammen gut aussehen). Gesamtaufwand etwa **12,5 Arbeitstage** (A allein 2, B voll 14,5).
6. **Spezifikation (Abschnitt 5):** Zelle 112 x 104, Fußmitte (40, 98), Figuren schauen nach rechts und werden zur Laufzeit gespiegelt, 32 Spalten
   (31 Frames plus 1 reserviert), **eine PNG je Figur** (`assets/fig/<id>.png`, 3584 x 104), träges Laden je Kampf, Anker (Brust, Kopf, Hand, Waffenspitze)
   kommen als Nebenprodukt aus dem Rig.

---

## 1. Bestand und ehrliche Qualitätsbewertung

### 1.1 Pipeline

* `tools/make_combat_art.py` (reines Python, Klasse `Img` aus `tools/make_art.py`: `set/rect/disc/line/polyline/outline/blit`) zeichnet jede Figur
  aus **Rechtecken und Linien**: `pose_geometry(pose)` liefert nur `lean`, `bob`, `hip`, `kneel` und die Handposition; `draw_legs/torso/head/arms` setzen
  Körperteile, `blade/axe/spear/bow/staff/...` setzen die Waffe an die Hand, `outline(#0b0a0e)` zieht die 1-px-Kontur. Gegner werden **im Atlas schon gespiegelt**.
* `assets/combat.png`: 5 Spalten x 25 Zeilen, Zelle **44 x 56**, Fußzeile 52, Mitte Spalte 22. Zeilen 0 bis 4 = Männer in der Reihenfolge der `Roles.Id`
  (Schild, Axt, Bogen, Skalde, Muskete), Zeilen 5 bis 24 = Gegner nach `Foes.ROW` (rost 5 ... kraeuterfrau 24, hund 17, tentakel 18). 220 x 1400 Pixel, 23 KB.
* `assets/kraken.png`: 5 Zellen von 88 x 88 (Riese, `Foes.BIG`), gleiche fünf Posen (die fünfte heißt "spannt sich").
* `hud.gd` (`_draw_fighter`, ab 2208): Figur steht mit der Fußzeile auf `FIGHT_FEET = 120`, x je Reihe (`FIGHT_HERO_X` 206/152/98/44, `FIGHT_FOE_X` 274/328/382/436),
  `draw_texture_rect_region` mit `roundf` auf ganze Pixel. **Pose = Spalte:** Stehen wechselt A/B alle 520 ms (`(ticks/520 + rank) % 2`), `_anim[f]` schaltet für **0,42 s**
  auf Spalte 2 (Angriff, Ausfall `9 px * sin`) oder Spalte 3 (Treffer, Rottönung 1,7/0,6/0,55, Zittern ±1 px), Ausweichen 0,3 s (nur Versatz). Spalte 4 bei `door`
  (Mann an der Schwelle) und beim "gespannten" Kraken. **Tod = rot getönte Treffer-Pose, die 0,7 s (Kraken 1,2 s) ausblendet** und 6 px sinkt (`_ghosts`).
  Es gibt **kein Ausholen**: die Angriffspose steht sofort, der Treffer kommt `hw = 0,2 + 0,13 * k` s später (Zeitkonstanten: `R1_ablauf.md`, 1.2).
* Zeichnen kostet pro Figur ein `draw_texture_rect_region` plus zwei Schattenstreifen, Namen, Balken und Zustandstext (bei der aktiven Figur noch Lichtkegel und Markierung).

### 1.2 Messwerte (aus `assets/combat.png` gelesen, Skript `analyse.py` im Arbeitsordner)

| Messung | Wert |
|---|---|
| Körper im Stehen (Höhe x Breite) | Menschen 36 bis 46 x 19 bis 32 px; Hund 21 x 37; Fangarm 54 x 25 |
| Anteil an der Feldhöhe (320) | 11 bis 14 % (Mann mit Axt 41 px = 13 %) |
| Ungenutzte Zellhöhe | rund 12 px über dem Kopf (Zelle 56, Körper 40 bis 46) |
| Stehen A zu Stehen B | je 74 bis 254 verschiedene Pixel: bei den meisten Menschen liegen Rumpf und Kopf in B **eine Zeile höher** (Atmen = 1 px Wippen, Beine fest); Robenträger fast gar nicht; nur der Fangarm bewegt sich echt (576 Pixel) |
| Am Zellrand abgeschnittene Frames | **24 von 125** (19 %): Angriff bei Schild, Axt, Bogen, Muskete, Rost, Bogner, Brecher, Messerkerl, Schütze, Haken, Wache, Armbrust, Bauer, Schmied, Hund, Wächter, Knochen, Antreiber, Kräuterfrau (19), Treffer bei Wache, Bauer, Schmied (3), Stehen A und B beim Antreiber (Horn, 2) |
| Posen, die es gar nicht gibt | Ausholen, Nachschwung, Block, Zaubern/Singen, Schießen (als Bewegung), Sturz, Leiche, Sieg, Betäubt, echtes Atmen |

### 1.3 Bewertung der 25 Figuren und des Kraken (Blick auf die Kontaktblätter)

Die Kontaktblätter (alle Posen, vierfach vergrößert): `img/R2_kontakt_helden.png` (Zeilen 0 bis 4), `R2_kontakt_gegner_a.png` (5 bis 9),
`R2_kontakt_gegner_b.png` (10 bis 14), `R2_kontakt_gegner_c.png` (15 bis 19), `R2_kontakt_gegner_d.png` (20 bis 24), `R2_kontakt_kraken.png`.
Die Bewertung gilt dem Stand für einen dramatischen Kampf, nicht für den Stand als kleines Standbild. **gut** = trägt eine Großaufnahme, **ok** = lesbar, aber dünn,
**schwach** = fällt auf.

| Zeile | Figur | Urteil | Befund |
|---|---|---|---|
| 0 | Schildträger | gut | Kettenhemd, blauer Schild, Nasalhelm: bester Mensch. Angriff: Schwert nur noch als kurzer Strich am Zellrand; Treffer hebt das Schwert senkrecht (liest sich als Aufbäumen, nicht als Schmerz) |
| 1 | Axtmann | gut | roter Kittel, Bart, langes Haar. Axtkopf ist ein graues Rechteck (Beil); **Angriff ohne Axtkopf** (abgeschnitten) |
| 2 | Bogenschütze | ok | Kapuze, Köcher. Angriff: Bogen und Sehne klar, Pfeilspitze abgeschnitten |
| 3 | Skalde | gut | Robe, Bart, Stab mit Goldkugel. **Angriff kaum von Stehen zu unterscheiden** (Stab drei Pixel tiefer): keine Singe-/Zauberhaltung |
| 4 | Musketier | gut | Dreispitz, Feder. Angriff: Gewehr waagrecht, Mündungsfeuer als gelber Block ins Bild gemalt (doppelt zum Effekt), rechts abgeschnitten |
| 5 | Rost-Draugr | ok | grüne Haut, Rosthelm; Schwert (Rostbraun auf braunem Wams) kaum zu sehen |
| 6 | Draugr-Bogner | gut | Skelett in Kapuze, leuchtende Augen |
| 7 | Totenwart | gut | Geweih, Stab mit grünem Licht. Dieselbe Schablone wie Priester und Beschwörer, nur andere Farben |
| 8 | Räuber-Brecher | gut | breit, Keule, wirkt kräftig; Angriff links abgeschnitten |
| 9 | Messerkerl | ok | schmal, rotes Stirnband; Messer sind 2-px-Striche, schlecht lesbar |
| 10 | Räuber-Schütze | ok | fast ein Zwilling von Bogner und Armbrustschütze (Kappe statt Kapuze) |
| 11 | Hakenwerfer | ok | Kopftuch, Haken als dünner Strich, Seilrolle am Gürtel |
| 12 | Schiffswache | gut | Helm, blau-gelbe Tunika, Schild und Speer; Treffer: Speerspitze oben abgeschnitten |
| 13 | Armbrustschütze | ok | Armbrust klein, Pose kaum lesbar |
| 14 | Kaufmann | gut | Pelzmütze, Beutel, breit: nach dem Kraken die Figur mit dem meisten Charakter |
| 15 | Bauer | ok | Strohhut, Heugabel; Angriff und Treffer abgeschnitten |
| 16 | Schmied | gut | Schürze, Hammer; Treffer oben abgeschnitten |
| 17 | Dorfhund | **schwach** | 37 x 21 px, vier Posen fast gleich (Treffer und Schwelle sehen aus wie Stehen) |
| 18 | Fangarm | gut | schönstes Sprite, einzige Figur mit echtem Stehen-Wechsel, Angriff und Treffer mit Neigung |
| 19 | Knochenpriester | gut | Schablone wie Totenwart |
| 20 | Grabwächter | gut | Skelett mit Kettenhemd und Schild; Angriff links abgeschnitten |
| 21 | Totenbeschwörer | gut | rote Robe, Geweih, Schablone wie Totenwart |
| 22 | Skelett | ok | dünn und klein (Körper 36 px), Angriff abgeschnitten |
| 23 | Trommler | gut | Horn; **schon im Stehen am Zellrand abgeschnitten** |
| 24 | Kräuterfrau | ok | Korb; Angriff abgeschnitten |
| (88 x 88) | Kraken | gut | stärkstes Bild, aber ein Brustbild mit fast gleichen Stehen-Posen; Angriff (Schnabel offen, Neigung), Treffer (Augen zu), Spannen (Augen rot, Arme hoch) |

**Fazit:** Palette, Konturen und Licht (oben links) sind einheitlich, die Silhouetten und Farben reichen zum Erkennen. Aber das Material ist für
**Kleinformat und Standbild** gebaut: Eine Pose je Zustand, kaum Bewegung im Stehen, jede zehnte Figur am Rand abgeschnitten, Gesichter aus zwei Punkten, drei Schablonen
für alle Robenträger, ein Hund, der nicht lebt. Bei Großaufnahme (Zoom) verlieren die Figuren sofort ihre Glaubwürdigkeit (Abschnitt 3.6).

---

## 2. Fehlende Posen und Frames für eine Darkest-Dungeon-artige Darstellung

Darkest Dungeon lebt von **wenigen, stark gezeichneten Posen, die man hält**: ein klares Ausholen (Gewicht nach hinten), ein Aufprall-Frame, ein Nachschwung, und beim Ziel
ein Treffer-Frame, der den Körper verbiegt. Dazu gehören im Spiel (Auslöser siehe `_fight_events`):

| Pose | Wann (Ereignis/Zustand) | heute | Wie wichtig | Ersatz ohne neues Bild? |
|---|---|---|---|---|
| **Idle mit Atmung** (Schleife 3 bis 4 Frames) | immer, wer nicht dran ist | 2 Frames, 1 px Wippen | hoch (Lebendigkeit), billig | teilweise: Atmen = Stauchen/Strecken um 1 bis 2 px |
| **Bereit** (am Zug, Gewicht nach vorn) | `c.actor == f` | nur goldener Pfeil und Lichtkegel | hoch | Lehnen 2 bis 4 px (Scherung) |
| **Ausholen** | `attack`-Ereignis bis zum Treffer (`hw`) | fehlt (Angriffspose sofort) | **sehr hoch** | kaum: die Waffe muss nach hinten oben, das kann kein Standbild ersetzen |
| **Zuschlagen** (Aufprallframe, 1 bis 2 Frames halten) | beim Treffer (`hw`) | Pose "Angriff" (abgeschnitten) | sehr hoch | nein |
| **Nachschwung/Abfangen** | nach dem Treffer | fehlt | hoch | teilweise: Lehnen und Zurückgleiten |
| **Schießen** (Bogen: Ziehen, Loslassen; Muskete: Anlegen, Schuss mit Rückstoß; Armbrust) | `b_*`, `m_*`, `f_pfeil`, `f_armbrust` | gleiche Pose wie Nahkampf | hoch | nein (Sehne, Rückstoß sind Körperhaltung) |
| **Zaubern/Singen/Rufen** | `k_*` (Lieder), `f_klage`, `f_horn`, `f_beschwoeren`, `f_heilen`, `s_ruf`, `a_wut` | fehlt | hoch (Skalde, Priester, Trommler) | nein; Ringe und Noten sind nur Effekt |
| **Blocken/Parieren** | Treffer auf Mann mit `guard` (Schildwall), Schildstoß | fehlt | mittel bis hoch | Block-Frame fehlt; Rückstoß prozedural möglich |
| **Ausweichen** | `miss` | nur Versatz um 5 px | mittel | ja, Lehnen nach hinten plus Versatz |
| **Treffer** (Aufprall, Erholung) | `hit` | 1 Frame, Rottönung | hoch | teilweise: Lehnen, Stauchen, Rottönung |
| **Betäubt** | `stun > 0` | nichts | mittel | Pendeln (Scherung links/rechts) |
| **An der Schwelle** (Atmung) | `door` | 1 Frame (kniend) | mittel | Atmen prozedural |
| **Fallen** (3 Frames) und **Leiche** | `die` | rot getönte Treffer-Pose, Ausblenden | **sehr hoch** (jeder Tod) | Ausblenden bleibt, Fallen nicht ersetzbar |
| **Sieg/Jubel** | `result == win` | nichts | mittel | Hüpfen (Versatz), Waffe fehlt oben |
| **Gepackt** (Kraken) | `held_by` | nichts | niedrig | hochziehen um 12 px plus Pendeln |

Mindestliste, damit der Kampf "gezeichnet" wirkt: Idle 3, Ausholen 2, Zuschlagen 2, Nachschwung 2, Treffer 2, Fallen 3, Leiche 1 = **15 Frames je Figur**; mit Bereit,
Zaubern, Blocken, Ausweichen, Betäubt, Schwelle, Sieg sind es die 31 der Spezifikation (Abschnitt 5.3).

---

## 3. Was Drehung, Skalierung und Zoom mit den Pixel-Einstellungen wirklich tun

Prototypen laufen im echten Spiel (Arbeitskopie `figuren`, Aufruf `shot.ps1 -Flags "--proto=<Name>"`, Quelltext `R2_proto_figuren.gd.txt`,
`R2_proto_rig.gd.txt`), Auflösung des Bildschirmfotos 6,0 x. Projekt: `snap_2d_transforms_to_pixel` und `snap_2d_vertices_to_pixel` AN, Nearest-Filter,
Stretch `canvas_items` fraktional. **Alles hier sind Standbilder: dass Bewegung nicht flimmert, habe ich nicht gefilmt, nur aus der Bauart geschlossen** (Position wird
mit `roundf` auf ganze Pixel gerundet; Winkel in Schritten von 2 Grad und Bildwechsel zu 15 bis 20 Hz halten die Kanten ruhig).

### 3.1 Drehung (`img/R2_proto_rot.png`)

Drehung um die Fußmitte mit `draw_set_transform(pos, winkel, scale)`, Winkel 0, 4, 8, 12, 20, 35 Grad, drei Figuren.

| Winkel | Urteil |
|---|---|
| 0 bis 8 | unauffällig bis leicht unruhig an den Kanten; als Lehnen gut |
| 12 | Kanten treppig, Umrisslinie ungleich dick (ein bis zwei Pixel), in Bewegung vertretbar |
| 20 bis 35 | deutlich "gedrehte Pixel": schräge Kästchen, Umriss reißt, Gesicht und Hände verschmieren; nur für 1 bis 2 Frames (Treffer, Sturz) |

Regel: **Drehung nur bis etwa 10 Grad als Dauerzustand**, darüber höchstens 0,1 s. Die Figuren drehen sich nicht aufs Pixelraster zurück (kein Neurastern, die Pixel
selbst werden gedreht); das ist die bekannte "Mixel"-Optik. Für den Sturz ist eine Drehung deshalb schlechter als ein echter Frame.

### 3.2 Skalierung und Stauchen/Strecken (`R2_proto_scale.png`, `R2_proto_squash.png`)

* **Ganzzahlig (2x, 3x): vollkommen scharf**, die Pixelgröße wächst einfach.
* **1,25x und 1,5x:** ungleich breite Pixel (an Umrissen und am Gesicht sichtbar), in Ruhe zu sehen, in Bewegung kaum.
* **Stauchen/Strecken** (Fuß unten): ±12 % (1,12/0,88) ist unauffällig und gibt Gewicht; ±25 % (1,25/0,8) verformt sichtbar, nur für ein bis zwei Frames.
  Fußpunkt als Pivot, sonst schwebt oder sinkt die Figur.

### 3.3 Zeilenband-Scherung (`R2_proto_shear.png`)

Das Bild wird in Streifen von 2 Zeilen geschnitten und jeder Streifen um **ganze Pixel** versetzt (Fuß fest, Kopf am weitesten). Kein Pixel wird gedreht.
Ergebnis: **sauber, pixelgenau**, kostet ~28 Zeichenaufrufe je Figur (56 Zeilen / 2); bis 6 bis 8 Pixel Lehnen am Kopf ausgezeichnet, bei 12 Pixeln sieht man die Stufen
an Armen und Waffe (die Waffe bleibt dabei aufrecht, sie dreht nicht). Gut für **Lehnen vor dem Schlag und beim Treffer**, ideal für Fangarme (Wellenbewegung mit
Sinusversatz je Streifen).

### 3.4 Prozedurale Folge aus einem Bild (`R2_proto_strip.png`, "Weg A")

Sechs Phasen (Stehen, Ausholen, Schlag, Nachschwung, Abfangen, Stehen) der Axt aus **einem** Atlasbild: Lehnen/Drehung, Versatz, Stauchen,
3 Nachbilder (gelb getönt, 22 bis 30 % deckend), Aufblitzen durch Farbfaktor (1,5/1,4/1,2: heller, funktioniert in `draw_texture_rect_region`). Zweite Zeile dieselbe Folge mit Scherung.
Urteil: Die Folge liest sich als **Ruck mit Nachbildern**, nicht als Schwung; die Waffe bleibt in der Hand wie im Standbild, die Angriffspose ist am Zellrand abgeschnitten
(die Axt fehlt). Nachbilder und Aufblitzen sind der überzeugendste Teil (preiswert und sofort dramatisch); das Ausholen ist nur ein Zurücklehnen.

### 3.5 Verwendbare Regeln aus 3.1 bis 3.4

* Winkel in Schritten von 2 Grad, Versatz in ganzen Pixeln (`roundf`), Pivot = Fußmitte (Anker).
* Nachbilder: die letzten 2 bis 3 Positionen der Figur, jede mit Alpha 0,3/0,18 und warmem Ton; **ein Aufruf je Nachbild**.
* Aufblitzen: Farbfaktor (1,25 bis 1,6) für die Länge des Aufpralls, danach zurück.
* Wegen der Stufen bei Scherung und Drehung: nicht auf Posen anwenden, die ohnehin schon gelehnt sind.

### 3.6 Kamerazoom 2x (Bilder `R2_proto_oldzoom.png`, `R2_proto_rigzoom.png`, `R2_proto_rigzoom15.png`, außerdem `R2_zoom2_fight2.png`, `R2_zoom2_fx2.png`)

* **Schärfe: sehr gut.** 2x ist ganzzahlig, die Pixel werden einfach doppelt so groß, das Raster bleibt gleich (es gibt schon heute Zoomschübe von 5 bis 11 %, `FightFx.zoom`).
* **Alte Figuren bei 2x (`R2_proto_oldzoom.png`):** es zeigt sich jede Schwäche: das Bild "Angriff" des Axtmanns **ohne Axtkopf**, Gesichter aus zwei Punkten, klobige Blöcke.
  Zoom macht die kleinen Figuren nicht größer im Sinn von "besser", sondern nur größer im Sinn von "gröber".
* **Rig-Figuren bei 2x (`R2_proto_rigzoom.png`):** tragen die Großaufnahme (Körper 130 px, Waffen und Arme bleiben sauber), das Bild wirkt wie ein Kampf, nicht wie ein Schaubild.
* **1,5x:** im Test (Faktor 6,0, also 9 Bildschirmpixel je Kunstpixel) einwandfrei. Auf dem 3120 x 2080-Bildschirm des Besitzers (Faktor 6,5, also 9,75) sind Pixel abwechselnd 9 und 10 breit,
  so wie heute schon bei 6/7. Nicht geprüft; erwartet keine zusätzliche Auffälligkeit.
* **Falle:** der heutige Zoom (`hud.gd` 2370 bis 2411) steckt die ganze Bühne **samt Text** in die Transformation. Namen und Leisten werden mit vergrößert und stoßen
  an das Journal (`R2_zoom2_fight2.png`: "Reihe 1 vorn" über dem Titel). Beim Zoom Namen, Balken und Zahlen **außerhalb** der Transformation an die umgerechneten Orte setzen
  (`R2_proto_rigzoom.png` macht es so).
* Fokus: bei 2x sieht man nur 240 von 480 Spielfeldpixeln. Angreifer und Ziel in die Mitte (im Prototyp Brennpunkt (228, 92)); dazu eine Reihe links und rechts.

---

## 4. Die drei Wege

### Weg A: 44 x 56 behalten, im Spiel prozedural animieren

**Inhalt.** Keine neuen Bilder (nur die 24 abgeschnittenen Frames reparieren, siehe unten). In `hud.gd` kommt eine Zeitleiste je Kämpfer
(`windup -> strike -> follow -> idle`) auf den vorhandenen fünf Posen, dazu Lehnen (Scherung), Stauchen/Strecken, Nachbilder, Aufblitzen, Atmen (1 bis 2 px Strecken),
Pendeln bei Betäubung, Hüpfen bei Sieg, Fangarme mit Sinus-Scherung, Hund springend, Tod als Drehen (35 Grad) plus Ausblenden.

* **Erwarteter Gewinn: mittel.** Sofort sichtbar: Wucht (Nachbilder, Blitz), Lebendigkeit (Atmen, Wippen), Fangarme und Hund leben. Nicht erreichbar: ein echtes Ausholen
  und ein Schwung der Waffe, Zaubern, Schießen, Blocken, Fallen (Beweis: `R2_proto_strip.png`). Zoom 2x macht die Figuren eher schlechter (3.6).
* **Risiko: niedrig.** Reine Anzeige, kein Atlas ändert sich (bis auf Reparatur der abgeschnittenen Frames), alte Pipeline bleibt. Gefahr: es sieht nach 14 Tagen "hübscher Ruck" aus und
  man hat trotzdem keinen Schlag. Sehr schnell erledigt.
* **Aufwand: etwa 2 Arbeitstage** (Zeitleiste und Hilfsfunktionen 1,5; Reparatur der Zellränder 0,5: Zellbreite 56 statt 44, Anker bleibt 22 oder
  Waffenlängen kürzen).
* **Beispiel-Bild:** `img/R2_proto_strip.png` (sechs Phasen aus einem Bild, Nachbilder, Aufblitzen), `R2_proto_oldstrike.png` (heutige Figuren auf der Bühne, Angreifer mit Nachbildern, Ziel in Treffer-Pose,
  Trefferstrich), `R2_proto_shear.png`, `R2_proto_rot.png`.

### Weg B: alle Figuren größer (64 x 80) und mit vielen Frames neu zeichnen, mit gemeinsamem Körper-Rig

**Inhalt.** Das Rig (Prototyp `docs/kampf_spektakel/R2_rig_proto.py`, reines Python, Standardbibliothek plus `make_art.py`): Eine Figur ist eine Beschreibung (Körperbau, Farben, Kopf,
Rüstung, Waffe, Haltungsklasse). Eine Pose ist eine Tabelle von Gelenkzielen (Hüfte, Lehnen, Füße, Hände, Waffenwinkel). Arme und Beine laufen über Zwei-Knochen-IK,
Rumpf, Gliedmaßen und Waffen werden als **Geometrie** gesetzt (Kapseln, Polygone), nicht als gedrehte Pixel; der Kopf (12 x 12) wird für die Liegepose verlustfrei um 90 Grad gedreht.
Alle 31 Frames, **Haltungsklassen** `melee`, `shield`, `bow`, `gun`, `staff` (dort liegen Ausholen/Zuschlagen unterschiedlich: Sehne ziehen und lösen, Gewehr anlegen und Rückstoß, Stab hoch und herab).
Erzeugungszeit: **1,5 Sekunden** für 248 Frames (8 Figuren).

* **Erwarteter Gewinn: hoch.** Echtes Ausholen, Zuschlagen, Nachschwung, Blocken, Zaubern, Fallen und Liegen; Körper 65 px statt 40 (1,6x); alle Figuren **als Satz konsistent**
  (Proportionen, Stand, Armlängen aus einem Quelltext, jede Änderung wirkt auf alle); die Anker für Effekte (Hand, Waffenspitze, Brust, Kopf) fallen ohne Handarbeit ab.
* **Risiko: mittel.** (1) **Stilbruch:** die Rig-Figuren sind steifer und gröber als die handgesetzten (dünne Waffen, Gesichter aus zwei Punkten, kein Stoffspiel, immer
  gleiche Standbreite, kein Dreiviertelblick). Der Prototyp zeigt, dass man damit leben kann, die Qualität der Feinabstimmung entscheidet. (2) Hund, Fangarm, Kraken haben keinen Menschenkörper
  und brauchen eigene Rigs (zwei bis fünf Tage zusätzlich). (3) Atlas: 22 Figuren x 32 x (112 x 104) ist viel; deshalb eine PNG je Figur (Abschnitt 5.5). (4) Bühnenlayout:
  65 bis 80 px hohe Figuren stoßen mit Stab und Geweih an die Zugleiste (FEET 120 minus 80 = 40; die Leiste liegt bei y 26 bis 40). Layout muss mitziehen (`R1_ablauf.md`, R14).
* **Aufwand: etwa 14,5 Arbeitstage** (Aufstellung unten).
* **Beispiel-Bilder:** `img/R2_proto_rigstrike.png` (Bühne mit denselben Positionen wie heute, 4 Männer gegen 4 Gegner, Angreifer im Zuschlagen mit Nachbildern, Ziel in Treffer-Pose),
  `R2_proto_rigzoom.png` (2x auf das Paar), `R2_proto_sizes.png` (Größenvergleich 1:1), `R2_rig_helden.png`, `R2_rig_gegner.png`, `R2_rig_alle_frames.png` (31 Frames des Schildträgers).

### Weg C: Mischform

**Inhalt.** Das Rig erzeugt die 22 menschlichen Figuren (5 Männer, 17 Gegner). **Hund, Fangarm und Kraken** behalten ihre Zellen (44 x 56 und 88 x 88); sie bekommen A-Behandlung
(Sinus-Scherung beim Fangarm, Hüpfen und Stauchen beim Hund, Wellen und Ruck beim Kraken) und je zwei bis drei neu gezeichnete Frames (Kraken: Hochreißen, Zuschlagen, Sinken; Hund: Sprung, Jaulen;
Fangarm: Peitschen-Ausholen). Die Anzeige (Zeitleiste, Nachbilder, Zoom) baut auf Frame-**Namen** auf, sodass der alte Atlas (5 Frames) und die neuen Streifen (32 Frames)
beide bedient werden: fehlende Namen fallen auf die nächste vorhandene Pose zurück. Damit **ist Stufe 1 (A) kein Umweg**, sondern die Grundlage von B.

* **Erwarteter Gewinn: hoch** (etwa 90 % von B): die Menschen sind die 22 von 25 Figuren, auf die der Blick fällt; Tiere und Boss sind ohnehin Gestalten eigener Größe und tragen die
  Mischung (Bild `R2_proto_mixed.png`: Rig-Männer, Fangarme, Hund und Kraken auf einem Deck; ehrlich: Fangarme und Hund wirken neben den Rig-Menschen flacher und einfacher).
* **Risiko: niedrig bis mittel.** Der Stilbruch aus B bleibt (Mensch gegen Rig), die schwierigsten Figuren (Vierbeiner, Kurvenkörper, Riese) fallen aus dem Wagnis. Das alte
  Artwork bleibt als Rückfall (`FigArt.use_rig`-Schalter).
* **Aufwand: etwa 12,5 Arbeitstage**, davon die ersten 2 identisch mit A.
* **Beispiel-Bild:** `img/R2_proto_mixed.png`.

### Aufwandsvergleich (Arbeitstage eines Entwicklers, einschließlich Prüfen mit Bildschirmfotos)

| Posten | A | B | C |
|---|---|---|---|
| Anzeige: Zeitleiste, Frame-Tabelle, Nachbilder, Aufblitzen, Zoomführung, Spiegelung, Geister, Sieg, Schwelle | 1,5 | 3 | 3 (mit A) |
| Zellränder des alten Atlas reparieren | 0,5 | entfällt | 0,5 (nur Hund, Fangarm) |
| Rig-Kern, Waffenbibliothek (17 Typen), Kopfformen (13), Haltungsklassen (5) | | 3 | 3 |
| Fünf Männer feinabstimmen | | 1,5 | 1,5 |
| 17 menschliche Gegner (je 0,5 Tage: Beschreibung, 31 Frames ansehen, Feinheiten) | | 1,5 | 1,5 |
| Hund (Vierbeiner-Rig, 18 Frames) | | 1,5 | 0,5 (nur Zusatzframes) |
| Fangarm (Kurvenkörper) | | 1 | 0,5 |
| Kraken (neues Brustbild, 9 Frames) | | 2 | 1 (3 Frames) |
| Feinabstimmung Bühne (Größen, Abstände, FX-Anker, Zugleiste) | | 1 | 1 |
| **Summe** | **2** | **14,5** | **12,5** |

---

## 5. Empfehlung und Spezifikation

### 5.1 Entscheidung

**Weg C in drei Stufen, jede für sich abnehmbar:**

1. **Stufe 1 (2 Tage), Anzeige auf Frame-Namen:** `FigArt` (neu, `scripts/fig_art.gd`) liefert zu `(Figur, Frame-Name)` die Textur, das Quellrechteck und die Anker; auf dem alten Atlas bildet es
   `idle_0/1 -> 0/1`, `strike_0 -> 2`, `hit_0 -> 3`, `door_0 -> 4`, den Rest auf den nächsten. Darauf kommen Zeitleiste, Nachbilder, Aufblitzen, Lehnen (Scherung), Zoomführung mit Text außerhalb der Transformation. Die
   24 abgeschnittenen Frames werden dabei repariert (Zellbreite 56).
2. **Stufe 2 (8,5 Tage), Rig für die 22 Menschen:** `tools/make_fig_rig.py` (ausgebaut aus `docs/kampf_spektakel/R2_rig_proto.py`) schreibt `assets/fig/<id>.png`; die Anzeige lernt die
   32 Spalten und die Anker (1,5 Tage, der Rest dieses Postens: Rig-Kern 3, Männer 1,5, Gegner 1,5, Bühne 1). Reihenfolge der Entwicklung: zuerst die fünf Männer, dann die Gegner je Formation
   (Draugr: rost, bogner, totenwart, waechter, priester, beschwoerer, knochen; Räuber: brecher, messerkerl, schuetze, haken, antreiber; Händler: wache, armbrust, kaufmann; Dorf: bauer, schmied, kraeuterfrau).
   **Ausgeliefert wird erst, wenn alle 22 stehen:** Rig-Männer neben 40 px kleinen alten Gegnern wären ungleich.
3. **Stufe 3 (2 Tage), Sondergestalten:** Zusatzframes für Hund (Sprung, Jaulen), Fangarm (Peitschen-Ausholen), Kraken (Hochreißen, Zuschlagen, Sinken); Sinus-Scherung für Fangarme.

**Warum nicht nur A:** A kann kein Ausholen und keinen Schwung (3.4); bei Zoom 2x fällt die Qualität der kleinen Figuren auf (3.6). **Warum nicht B voll:** Hund, Fangarm und Kraken brauchen
eigene Körpermodelle, kosten drei Tage mehr und sind schon heute (Fangarm, Kraken) die besten Bilder des Satzes. **Warum nicht gleich nur C ohne A:** ohne die Frame-Namenstabelle bleibt jede spätere Rig-Figur an
die fünf Spalten gebunden, und der Fortschritt aus Stufe 1 gäbe es erst nach einer Woche.

### 5.2 Zelle, Anker, Konstanten

| Größe | Wert | Anmerkung |
|---|---|---|
| Zelle | **112 x 104** | gemessen: links bis 40 px, rechts bis 63 px (Axt, Keule, Stab), oben bis 80 px (Stab, Geweih, Axt im Jubel). Zelle 96 x 96 schnitt bei Stab im Zuschlagen und Sturz nach hinten ab (erster Versuch 80 x 88 noch mehr). Reserve rechts für Speer und Hellebarde (bis 70) |
| Anker | **Fußmitte x = 40, Stiefelsohle y = 98** (Kontur auf 99) | wie heute Fußzeile 52 in der 44 x 56-Zelle: `Rect2(feet - Vector2(40, 98), Vector2(112, 104))` mit `feet = (x der Reihe, FIGHT_FEET)` |
| Blickrichtung | alle nach **rechts** | Gegner zur Laufzeit gespiegelt (spart das Doppeln im Atlas) |
| Körperhöhe (Scheitel, ohne Waffe) | 64 px; mit Stab oder Geweih bis 80 | Hüfte 28 über der Sohle, Brust 38, Kopfmitte 55 |
| Spalten je Figur | 32 | 31 Frames plus 1 reserviert ("gepackt") |
| Streifen je Figur | **3584 x 104** (1,5 MB im Speicher, etwa 15 bis 25 KB als PNG: 8 Figuren im Atlas des Prototyps sind 126 KB) | eine PNG je Figur |
| Atlas, falls doch ein gemeinsamer gewünscht | 3584 x (22 x 104 = 2288) | 8,2 Mpx, 33 MB im Speicher; Zeilen wie heute: 0 bis 4 Männer (Roles.Id), 5 bis 24 `Foes.ROW` (hund/tentakel leer lassen: alter Atlas) |

Konstanten (Vorschlag für `scripts/fig_art.gd`):

```gdscript
const CELL := Vector2(112, 104)
const ANCHOR := Vector2(40, 98)          # Fußmitte, Zeile der Stiefelsohle
const FRAME_COUNT := 32
const FRAMES := ["idle_0", "idle_1", "idle_2", "idle_3", "ready_0", "ready_1", "windup_0", "windup_1", "strike_0", "strike_1",
	"follow_0", "follow_1", "cast_0", "cast_1", "cast_2", "block_0", "block_1", "dodge", "hit_0", "hit_1", "stun_0", "stun_1",
	"door_0", "door_1", "fall_0", "fall_1", "fall_2", "dead", "cheer_0", "cheer_1", "cheer_2", "grab"]
const SPINE := {"chest": Vector2(0, 38), "head": Vector2(0, 55), "top": 64.0}   # x nach vorn, y nach oben, ab Fußmitte (Stehen)
```

Zeichnen (zwei **Fallen**, in denen der Prototyp hängen blieb): gespiegelt wird mit **negativer Breite**, dann ist `position.x` die **linke Kante**
(`Rect2(feet.x - (112 - 40), top, -112, 104)`, nicht `feet.x + 40`); und die Textur muss in einer Klassenvariable (`static var` oder Objektfeld) leben, solange gezeichnet wird, sonst wird sie als weißes Rechteck gezeichnet.

### 5.3 Posenliste mit Frameanzahl (Reihenfolge = Spaltenindex)

| Nr | Name | Frames | Zweck und Auslöser | Haltezeit (Vorschlag) |
|---|---|---|---|---|
| 0 bis 3 | `idle_0..3` | 4 | Atmen, Schleife 0-1-2-3 (Brustwippen um 0, 1, 2, 1 px, Kopf und Waffe folgen) | je 0,2 s, Phase je Reihe versetzt |
| 4, 5 | `ready_0/1` | 2 | am Zug: Gewicht nach vorn, Waffe angehoben | je 0,25 s |
| 6, 7 | `windup_0/1` | 2 | Ausholen (Schlag: Waffe über oder hinter den Kopf; Bogen: Ziehen; Muskete: Anlegen; Stab: heben) | 0,08 und 0,12 (bis zum Trefferzeitpunkt `hw`) |
| 8, 9 | `strike_0/1` | 2 | Zuschlagen, Aufprall, Loslassen (hier Einfrieren und Blitz) | 0,08 und 0,08 |
| 10, 11 | `follow_0/1` | 2 | Nachschwung, Abfangen | 0,14 und 0,15 |
| 12 bis 14 | `cast_0..2` | 3 | Singen, Rufen, Beschwören, Heilen, Horn, Kampfruf (nicht-Kämpfer nutzen Waffe hoch und Mund offen) | je 0,12 |
| 15, 16 | `block_0/1` | 2 | Parieren/Blocken (Schild vor, Waffe quer); `_1` = Aufprall | halten bis `hw`, `_1` 0,12 |
| 17 | `dodge` | 1 | Ausweichen (nach hinten gelehnt) | 0,3 s (wie heute) |
| 18, 19 | `hit_0/1` | 2 | Treffer, Erholung | 0,10 (bei Krit +0,07 Einfrieren) und 0,15 |
| 20, 21 | `stun_0/1` | 2 | benommen, Schleife | je 0,3 |
| 22, 23 | `door_0/1` | 2 | kniend an der Schwelle, Atmen | je 0,5 |
| 24 bis 26 | `fall_0..2` | 3 | Fallen nach hinten | 0,08, 0,10, 0,12 |
| 27 | `dead` | 1 | Leiche (Kopf nach links gedreht, Waffe liegt daneben); bleibt, blendet aus | `_ghosts`-Dauer |
| 28 bis 30 | `cheer_0..2` | 3 | Sieg, Schleife | je 0,2 |
| 31 | `grab` | 1 | reserviert (Kraken-Griff); zunächst `stun_0` plus 12 px angehoben | |

**Ereignis -> Frame (kein neues Ereignisfeld nötig, nur Zustand und Ereignisse, die es heute gibt):**

| Auslöser | Frames |
|---|---|
| `attack` (Nahkampf) | `windup_0, windup_1` bis `hw`, dann `strike_0, strike_1, follow_0, follow_1`, dann `ready/idle` (heute 0,42 s, neu etwa 0,65 s: das ist der Preis, der in `_combat_t` einzurechnen ist, `R1_ablauf.md` 4.4) |
| `attack` mit Pfeil oder Kugel | `windup_0` (Anlegen), `windup_1` (Ziehen), `strike_0` beim Abschuss (Rückstoß, Sehne gespannt aus), `follow_0/1` |
| `attack` mit Lied, Ruf, Beschwörung (`k_*`, `f_klage`, `f_horn`, `f_beschwoeren`, `f_heilen`) | `cast_0..2`, dann `idle` |
| `hit` | `hit_0` 0,10 s, dann `hit_1`, dann `ready/idle`; ist `f.guard > 0` oder die Fertigkeit ein Schildstoß, dafür `block_1` mit Funken |
| `miss` | `dodge` (Versatz wie heute) |
| `die` | `fall_0..2`, dann `dead`, ausblenden (`_ghosts`: heute zeigt es die Treffer-Pose) |
| `f.door` | `door_0/1` statt `idle` |
| `f.stun > 0` | `stun_0/1` statt `idle` |
| `c.actor == f` im Zug | `ready_0/1` statt `idle` |
| `result == win` | Überlebende Männer `cheer_0..2` |

### 5.4 Anker für Effekte

Heute hängen Treffer-, Pfeil-, Funken- und Zahleneffekte an festen Höhen (`FIGHT_FEET - 30` für Brust, `- 44` für Zahlen, `- 60` für den Pfeil über dem aktiven Mann). Mit 65 px Körper gehören sie höher.

| Anker (ab Fußmitte, y nach oben) | Wert |
|---|---|
| Brust des Ziels (Treffer, Funken, Hiebstrich) | (0, 38) |
| Kopf (Zahlen, "verfehlt") | (0, 72) |
| Pfeil über dem aktiven Mann / Zielmarke | (0, 78) |
| Hand im Zuschlagen (Schwert, Axt, Keule: 31 bis 36 vor, 29 bis 30 hoch) | (+32, 30) |
| Waffenspitze im Zuschlagen | Schwert (+56, 26), Axt (+61, 26), Keule (+63, 26), Stab (+55, 52) |
| Pfeilstart | Bogen im Lösen (+23, 42) |
| Mündung | Muskete im Anschlag (+35, 46) |

Diese Werte stammen aus dem Rig: `python R2_rig_proto.py <ordner> anchors` schreibt `rig_anker.json` (Hand, Waffenspitze, Brust, Kopf je Figur und Frame). In
Stufe 2 liefert das Werkzeug sie je Frame an die Anzeige (`assets/fig/anker.json`), damit Pfeile, Kugeln und Hiebstriche **aus der Waffe** kommen statt aus einer festen Höhe.

### 5.5 Dateien und Laden

* **Eine PNG je Figur:** `assets/fig/<id>.png`, `<id>` = `schild, axt, bogen, skalde, muskete` und die Schlüssel aus `Foes.TYPES`. Je Kampf höchstens 8 Streifen (rund 12 MB), träge geladen in einem
  Zwischenspeicher (wie `_big_texture`). Hund, Fangarm, Kraken bleiben `combat.png` und `kraken.png` (Stufe 3: `kraken.png` bekommt 3 neue Zellen).
* `FigArt.sheet(kind) -> {tex, cell, anchor, has_rig}`; `FigArt.frame(kind, name) -> {src: Rect2, flip: bool}` (Fallback-Tabelle für den alten Atlas).
* Wie bisher `load` nur, wenn nicht `DisplayServer.get_name() == "headless"`.
* Erzeugungszeit des Satzes: 8 Figuren in 1,5 s, hochgerechnet 25 Figuren in etwa 5 s.

### 5.6 Anzeige-Regeln (für Stufe 1 und 2)

* Positionen und Winkel in Schritten; Pivot = Fußmitte. Lehnen bei alten Figuren über Zeilenband-Scherung (2 Zeilen), bei Rig-Figuren nicht nötig (die Haltung steckt im Frame).
* Nachbilder: je Aufprall 2 bis 3 Kopien der Frames `windup_1`/`strike_0` mit Alpha 0,18 und 0,3, warm getönt (siehe `R2_proto_rigstrike.png`). Ein Aufruf je Kopie.
* Aufblitzen: Farbfaktor 1,25 bis 1,6 für die Dauer von `strike_0` (siehe `R2_proto_strip.png`).
* Zoom: 2x nur mit Rig-Figuren (alte Figuren: 1,2x bis 1,5x); Namen, Balken und Zahlen außerhalb der Zoom-Transformation (Beispiel: `R2_proto_rigzoom.png`).
* Zeichenbudget: zu Sprite, Schatten, Namen und Balken je Kämpfer kommen höchstens 3 Nachbilder beim Angreifer; die Figuren bleiben weit unter dem Rahmen "einige hundert Aufrufe je Bild".

### 5.7 Aufwand pro Figur (Rig, Stufe 2)

* **Beschreibung:** 12 bis 20 Zeilen (`spec(...)`: Körperbau (Schulter- und Hüftbreite, Torsohöhe), Farben, Kopfform, Haar, Rüstung, Haltungsklasse, Waffe); die 17 Gegner lassen
  sich fast 1:1 aus `make_combat_art.FOES` übernehmen.
* **Prüfen:** 31 Frames am Kontaktblatt (Streifen oder Raster) ansehen, 5 bis 10 Anpassungen (Waffenlänge, Körperbreite, Haltung bei Rüstung).
* Zeit: **0,5 Tage** je Figur (mit Screenshot der Bühne), die 5 Männer je 0,3 Tage zusätzlich für Feinheiten. Neue Waffentypen einmalig: Speer mit Schild (Wache, Wächter), Hammer, Heugabel, zwei Messer, Haken, Armbrust, Horn, Korb, Beutel
  (9 offen; im Prototyp sind Schwert, Rostschwert, Axt, Keule, Stab, Bogen, Muskete, Schild fertig); Kopfformen: im Prototyp 7, offen 6 (Kappe, Stirnband, Strohhut, Pelzmütze, Dreispitz-Varianten, Kapuze mit Geweih).
* **Rig-Kern** mit Verbesserungen aus der Prüfliste unten: 3 Tage.

### 5.8 Prüfliste (Abnahme einer Figur)

1. Kontaktblatt aller 31 Frames: kein Frame am Zellrand (Rig-Skript meldet `CLIP`).
2. Jede Pose hat einen **lesbaren** Unterschied zum Stehen (Silhouette).
3. Schuhsohle in allen Frames in Zeile 98 (außer Sturz und Liegen), kein Schweben oder Eintauchen.
4. Gespiegelt als Gegner ansehen (Schrift gibt es keine; asymmetrische Details wie Schild, Beutel vorn).
5. Auf der Bühne neben den anderen sieben Kämpfern bei 1x und 2x ansehen.
6. Rost-Draugr und Knochen: Kettenmuster (Schachbrett) bei 1x nicht flimmernd.

### 5.9 Was im Prototyp noch nicht gut genug ist (Rig)

* Waffen sind dünn (Muskete, Rostschwert, Stab), Hände sind Scheiben, Gesichter bestehen aus zwei Punkten und einer Braue.
* Haltung gleicht sich zu sehr (immer breit gestellt, Knie gebeugt); Robenträger bewegen die Beine gar nicht (Saum steht).
* Kein Stoffspiel (Umhang, Robe, Beutel), keine Gegenbewegung der Haare und Bärte, kein Blickwinkel (alles Profil).
* Zaubern der Skalde (cast) ist nur ein Arm-Heben; die Pose gehört mit Handzeichen verfeinert.
* Der Schildträger blockt mit dem Schild vor dem Gesicht; Blick bleibt verdeckt.
* Die Nachbilder aus Weg A (`R2_proto_rigstrike.png`) wirken dunkel und etwas schmutzig; gelber Farbton und höhere Deckkraft ausprobieren.

### 5.10 Was nicht geprüft ist

* Bewegung: nur Standbilder, kein Film. Das Flimmern von drehenden Kanten und die Wirkung der Zeitleiste sind aus der Bauart geschlossen.
* Faktor 6,5 (3120 x 2080): die Bildschirmfotos haben 6,0 (`shot.ps1`).
* Leistung im vollen Kampf mit 8 Rig-Figuren: nicht gemessen; erwartet unter 100 Aufrufe je Bild (5.6).
* Zusammenspiel mit Regie (Fokuskamera, Abdunkeln) und der Bühne: wird von deren Dokumenten (`R1_ablauf.md`, Bühne, Oberfläche) bestimmt.

---

## 6. Dateien und Reproduktion

| Datei | Inhalt |
|---|---|
| `docs/kampf_spektakel/R2_figuren.md` | dieses Blatt |
| `docs/kampf_spektakel/R2_rig_proto.py` | Prototyp des Körper-Rigs (Zelle 112 x 104, 31 Frames, 8 Figuren): `python -X utf8 docs/kampf_spektakel/R2_rig_proto.py <ordner> [sheets \| key:axt,schild \| stats \| atlas \| anchors]` (ohne `-I`: es lädt `tools/make_art.py` über `sys.path`) |
| `docs/kampf_spektakel/R2_proto_figuren.gd.txt`, `R2_proto_rig.gd.txt` | Prototypen für die Engine (Arbeitskopie `figuren`, `scripts/proto_figuren.gd`, `scripts/proto_rig.gd`); Aufruf `--proto=rot\|scale\|squash\|shear\|strip\|oldstrike\|rigstrike\|oldzoom\|rigzoom\|rigzoom15\|sizes\|mixed` |
| `img/R2_kontakt_*.png` | Kontaktblätter aller Figuren und Posen (4x) |
| `img/R2_ist_fight2.png`, `R2_ist_fx2.png` | Stand heute im Spiel |
| `img/R2_proto_rot.png`, `_scale`, `_squash`, `_shear`, `_strip` | Drehung, Skalierung, Stauchen, Scherung, prozedurale Folge (Abschnitt 3) |
| `img/R2_zoom2_fight2.png`, `R2_zoom2_fx2.png` | 2x-Zoom mit der Anzeige von heute (Text wird mit vergrößert) |
| `img/R2_proto_oldstrike.png`, `R2_proto_oldzoom.png` | heutige Figuren auf der Bühne im Zuschlagen, 1x und 2x |
| `img/R2_proto_rigstrike.png`, `R2_proto_rigzoom.png`, `R2_proto_rigzoom15.png` | Rig-Figuren auf der Bühne im Zuschlagen, 1x, 2x, 1,5x |
| `img/R2_proto_sizes.png` | Größenvergleich 1:1 |
| `img/R2_proto_mixed.png` | Mischform (Weg C) |
| `img/R2_rig_helden.png`, `R2_rig_gegner.png`, `R2_rig_alle_frames.png` | Rig-Posen: elf Kernposen der fünf Männer und dreier Gegner, alle 31 Frames des Schildträgers |

Hinweis: Die Bilder aus einem früheren Versuch (`R2_rig_axt/schild/rost/skalde.png`, Zelle 80 x 88) sind durch die obigen ersetzt, sie zeigten abgeschnittene Frames.
