# Spielautomaten

Drei Zugänge, ein Regelwerk (`scripts/slots.gd`), eine Anzeige (`scripts/slot_view.gd`), Einbindung in `scripts/voyage.gd`.
Alles, was gewürfelt wird, steht fest, bevor sich die Walzen drehen. Die Anzeige inszeniert nur.

## Die drei Zugänge

| | Wo | Maschine | Einsatz | Besonderheit |
|---|---|---|---|---|
| A | Hafen, Karte **Spelunke** (Taste 6) | Nornenwalzen | Beute, drei Stufen (4+2·Etappe, doppelt, fünffach) | höchstens 10 bezahlte Drehs je Hafenbesuch |
| B | nach einem gewonnenen Deckkampf (30 %), nach dem **Kraken** immer | Nornenwalzen | keiner, der Freidreh ist umsonst (Einsatz doppelt, nach dem Kraken dreifach der Grundstufe) | beim Kraken lösen drei Blitzrunen sicher die Freispiele aus |
| C | Begegnung **Adlerssons Spielschiff** (ab Etappe 2, selten) | Adlerssons Walzen | Beute, ein Viertel des Rumpfes oder ein Mann | Risikoleiter, Adlerssons Streich, bis 3 Runden |

Solange ein Automat offen ist, warten die Schritte der Begegnung (`Voyage._process`). Die Freidrehs nach Siegen öffnen sich nur im
echten Spiel und bei Bots (`Voyage.automat_bonus_on`), damit Tests und Hilfsläufe unberührt bleiben.

## Nornenwalzen (5 Walzen x 3 Reihen, 10 Linien)

Symbole: Schild, Axt, Horn, Rabe, Drachenschiff, Mjölnir, **Draugr**, **Odinsauge** (Joker), **Blitzrune** (Scatter).
Gewinne in Vielfachen des Linieneinsatzes (Einsatz / 10) für 3 / 4 / 5 gleiche von links:

| Symbol | 3 | 4 | 5 |
|---|---|---|---|
| Schild | 3 | 10 | 30 |
| Axt | 4 | 12 | 40 |
| Horn | 5 | 15 | 50 |
| Rabe | 8 | 25 | 80 |
| Drachenschiff | 12 | 40 | 150 |
| Mjölnir | 20 | 80 | 300 |
| Draugr | 30 | 120 | 500 |
| Odinsauge | 40 | 200 | 1000 |

* **Blitzschlag** (5 % der Drehs im Grundspiel): zwei bis fünf Felder werden zu Jokern, mit Blitz und Donner.
* **Drei, vier oder fünf Blitzrunen** irgendwo: 8, 12 oder 16 **Freispiele** ("It's alive!") und 2x, 10x oder 50x den Einsatz.
* Vor der dritten Blitzrune wird gebremst: zeigen die ersten Walzen zwei, laufen die restlichen langsamer, mit Trommelwirbel.

### Freispiele ("It's alive!")

Angelehnt an den Frankenstein-Automaten: der Draugr erwacht (mit Elektroden am Hals), die Spule links lädt sich auf.

* Der **Draugr ist Joker**. Dazu erscheinen ganze **Stapel** (eine Walze nur Draugr).
* Jeder **Stapel** zählt als Faktor für den ganzen Dreh (zwei Stapel: x2, bis x5).
* Eine **Blitzrune auf der ersten Walze** ist ein **Power-Up** (x2 50 %, x3 28 %, x5 16 %, x10 6 %); Faktoren multiplizieren sich.
* Zwei weitere Blitzrunen (nicht auf der ersten Walze) geben drei Freispiele dazu (höchstens 30 insgesamt).
* Ein Durchgang zahlt höchstens das 300-fache des Einsatzes.

## Belohnungen jenseits der Beute

Bezogen auf die ganze Folge (Dreh samt Freispielen), in Einsätzen:

* ab 6x: Banner "GROSSER GEWINN", Münzregen
* ab 10x: der Skalde dichtet dazu
* ab 20x: **Segen** (Perk, drei zur Wahl) und Banner "MEGA GEWINN"
* ab 60x: dazu ein **Fund** (Ausrüstung, mindestens episch), Banner "SAGENHAFT"
* **Odins Jackpot** (fünf Augen auf einer Linie): Segen und legendäre Ausrüstung

## Adlerssons Walzen (3 Walzen x 3 Reihen, 5 Linien)

Gewinne in Vielfachen des **Einsatzwertes** für drei gleiche auf einer Linie: Rabe 2, Wolf 5, Drachenschiff 12, Mjölnir 25, Odinsauge 100.

| Einsatz | Wert | Verlust |
|---|---|---|
| Beute | die Hälfte der Beute (mindestens 20, höchstens 100 + 50·Etappe) | die Beute |
| Rumpf | Rumpf x 0,25 x 3 | ein Viertel des Rumpfes (nie unter 1) |
| Ein Mann | 120 + 40·Etappe | der Mann ist tot, seine Ausrüstung kehrt in den Vorrat zurück |
| **Pfandflasche** (legendär) | 80 + 30·Etappe | keiner: ein sicherer Gewinn, siehe unten |

* **Adlerssons Streich**: drei Masken auf einer Linie. Alle Gewinne sind weg, der Einsatz ist verloren, dazu eine Strafe: ein Mann fällt, Rumpf −25 %, Proviant halbiert oder Verzweiflung +25 für alle.
* Ein Gewinn wird erst beim **Kassieren** gutgeschrieben, höchstens 3000 Beute auf einmal. Davor die **Risikoleiter**: Münzwurf, verdoppeln oder alles verlieren, bis zu viermal.
* Belohnungen wie bei den Nornenwalzen (nach dem Wert des einzelnen Drehs).
* Bis zu drei Runden je Begegnung.

## Die Pfandflasche (legendärer Schlüsselgegenstand)

Ein Gegenstand ohne Platz am Schiff (`Voyage.pfand`, höchstens 3, wird mit der Fahrt gespeichert), immer **legendär** (goldene Schrift, Hinweis in der Schiffsansicht unter Taste B).

* **Wirkung:** Bei Adlersson gibt man sie ab (Karte "Pfandflasche" oder als vierter Einsatz am Automaten) und bekommt ein **sicheres Freispiel**: Seine Walzen drehen, bis es einen Gewinn gibt, Adlerssons Streich zählt nicht, nichts steht auf dem Spiel. Einsatzwert 80 + 30·Etappe, der Gewinn liegt im Topf (kassieren oder Risikoleiter) und ist wie sonst bei 3000 gedeckelt. Die Flasche zählt nicht als Runde und geht auch nach der letzten Runde noch.
* **Fundorte:** Wrack beim Durchsuchen (jeder zehnte Fund), nach gewonnenen Deckkämpfen (4 %, nach dem Kraken 50 %), beim Met in der Taverne (7 %). Mehr als drei trägt man nicht, jede weitere wird gegen Pfand eingelöst (25 + 10·Etappe Beute).
* **Zahl:** der Schnitt eines sicheren Freispiels liegt bei Etappe 3 um 1000 Beute (Wert 170, im Mittel das Sechsfache).
## Zahlen (aus `tools/slotsim.gd`, 400 000 Drehs)

* Nornenwalzen: Rückzahlung rund **120 %**, davon etwa 68 % Grundspiel und 52 % Freispiele. Freispiele alle **42 Drehs**, im Schnitt 22 Einsätze (Median 16). Ein Dreh samt Freispielen bringt in 1 von 22 Fällen mindestens das 5-fache, in 1 von 79 das 20-fache, in 1 von 576 das 60-fache.
* Adlerssons Walzen: Rückzahlung rund **112 %**, Gewinn in 14 % der Drehs, Adlerssons Streich in 3 %, mindestens 10x in 1 von 33, Odinsauge-Linie in 1 von 289.
* Die Grenze der Drehs je Hafen und die Einsatzstufen verhindern, dass man damit Beute melkt; die Freidrehs sind ein Geschenk.

## Anzeige und Ablauf (`SlotView`)

Zustände: IDLE, SPIN, EVAL, ALIVE, PAUSE, SUMMARY, FLIP, CURSE. Klick oder Leertaste während des Ablaufs beschleunigt ihn (nicht in der Szene "It's alive!").

* Walzenlauf mit weichem Auslaufen und Nachfedern, Unschärfe bei hoher Geschwindigkeit, Walzenwand (oben und unten dunkler).
* Auswertung Linie für Linie (Linie, Zahl, Summe zählt hoch), nicht gewinnende Felder werden abgedunkelt.
* Blitzschlag verwandelt Felder, Stapel und Power-Up zucken, der Faktor rechts zählt mit.
* Szene **It's alive!**: Verdunkelung, Gewitter, der Draugr (sechsfach vergrößert) reißt die Augen auf, Blitze, Funken an den Elektroden, "IT'S ALIVE!" mit Schlag und Wackeln, Zahl der Freispiele. Der Schrei steht in `assets/sfx/slot_alive.wav`.
* Gewinn-Banner mit Strahlen, Münzregen (Sprites), Funkenschauer, Blitz-Linien, Lampenkranz mit Lauflicht.
* Adlersson: grüne Kulisse, Münzwurf-Animation, Szene "Adlerssons Streich" mit der Maske in Großaufnahme.

Tasten: Leertaste/Enter dreht, Pfeil hoch/runter ändert den Einsatz, Esc schließt.

## Werkzeuge

* `tools/slotsim.gd`: rechnet beide Automaten durch (`--n=400000`).
* `tools/make_slot_art.py`: Symbole und Münzen nach `assets/slots.png`. `tools/make_enemies.py`: Adlerssons Schiff (Zelle 12). `tools/make_ui.py`: Kartensymbol `ic_L`.
* `tools/make_voice.ps1`: nimmt die Rohstimmen mit der Windows-Sprachausgabe auf (`tools/voice/*.wav`); `tools/make_sfx.py` verwandelt `its_alive.wav` in den Schrei (tiefer, verzerrt, mit Donner, Chor und Blitzen). Die Stimme ist die englische Windows-Sprachausgabe (`its_alive.wav`): zweimal "It's alive!", das zweite Mal höher und lauter; die deutsche Aufnahme `es_lebt.wav` liegt als Reserve bereit.
* Screenshots: `--shotslot=idle|spin|win|alive|free|jackpot|loki|loki_win|loki_curse|harbor|lokicard`, `--shotslot=play` und `playloki` drehen durch die echte Anzeige.
* Tests: `tools/selftest.gd` (Abschnitt "Spielautomaten"), Bots spielen die Automaten mit (`Main._bot_slot`).

## Offen

* Ob Einsätze, Rückzahlung und Grenzen sich gut anfühlen, ist nur gerechnet, nicht gespielt. Die Zahlen stehen als Konstanten oben in `slots.gd`.
* Idee: eine zweite Maschine mit Haltefunktion (Walzen anhalten) oder ein Jackpot, der über mehrere Hafenbesuche wächst.
