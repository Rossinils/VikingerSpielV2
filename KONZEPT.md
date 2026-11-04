# Halt Kurs — Konzept (Arbeitstitel)

Düsteres Wikinger-Roguelike. Du führst ein Langschiff und seine Crew durch eine immer rauere Nordsee, plünderst, kaufst, kämpfst und fährst weiter – bis das Schiff kentert.
Vorbilder im Gefühl: *Darkest Dungeon* (Stress, Marotten, Verluste tun weh, trockener Erzähler), *Slay the Spire* (Karte mit Stationen, Segen und Gegenstände), alte Flashgames (klein, dicht, sofort spielbar).
Abgrenzung zu *Pixel Piracy*: kein offenes Sandbox-Chaos, sondern handgebaute Etappen mit klaren Entscheidungen. **Das Meer ist der Hauptgegner, die Crew ist der Grund, warum es wehtut.**

## Leitplanken

- **Endlose Fahrt:** Es gibt keinen Sieg und kein Ziel am Ende der Karte. Man fährt Etappe um Etappe; die Fahrt endet erst, wenn das Schiff sinkt oder niemand mehr an Bord ist. Gemessen wird am Ende: Etappe, Stufe, Strecke, Beute, Gefallene (die Saga).
- **Kurze Etappen:** eine Etappe (10 Meilen, am Ende ein Hafen) dauert etwa fünf bis zehn Minuten. Passt zu „ein paar Etappen, dann Pause“.
- **Jederzeit beenden:** Autosave bei jeder Planung, Fortsetzen ab der letzten Planung (was man seitdem im Hafen oder in einer Seeschlacht entschieden hat, geht beim Abbruch verloren).
- **Ton:** düster, rau, trockener schwarzer Humor – vor allem durch den Erzähler (der Skalde), nicht durch Albernheit.
- **Tempo:** rundenbasiert wie Darkest Dungeon. Keine Echtzeit, keine Quicktime-Events, keine bewegten Balken: wenige Entscheidungen, die man lange abwägen kann und die schwer wiegen.
- **Technik:** Godot 4, 2D-Pixelart, 480×320 Spielfeld (3:2), stufenlos skaliert und damit bildfüllend auf 3:2-Bildschirmen wie 3120×2080 (Faktor 6,5; die frühere ganzzahlige Skalierung ließ dort schwarze Ränder, weil 6 × 480 = 2880 kleiner ist als 3120), Text in Bildschirmauflösung. Bei anderen Seitenverhältnissen (z. B. maximiertes Fenster) bleiben schmale Ränder, im Vollbild (F11) auf 3:2-Anzeigen nicht. Primär Windows, Web-Export bleibt möglich.

## Aufbau einer Fahrt

- **Hauptmenü** (beim Start und mit Esc), im Stil von Darkest Dungeon nur Schrift, das Gewählte leuchtet zwischen zwei Rauten: Fahrt beginnen oder fortsetzen, Neue Fahrt (zweimal bestätigen), **Einstellungen** (Musik, Ton, Effekte, Vollbild und Hilfe beim Start; werden in `user://settings.cfg` gemerkt), Gedenkstein, Beenden; darunter das Vermächtnis. Hier und nach dem Ende laufen die Lieder mit Gesang.
- **Etappe:** eine Seekarte mit 10 Meilen, am Ende immer ein Hafen, auf der ersten Etappe auch in der Mitte einer, später meistens. Nach dem Ablegen im Zielhafen beginnt die nächste, **härtere Etappe** (siehe Schwierigkeit).
- **Stufen:** Erfahrung gibt es für erreichte Knoten (5), gewonnene Begegnungen (25), Seeschlachten (30 + 4 je Etappe) und Etappen (40 + 5 je Etappe). Jede Stufe kostet 60 + 40 × Stufe. Bei jedem **Stufenaufstieg** wählt man einen von drei zufälligen **Segen** (`scripts/perks.gd`): mehr Rumpf, mehr Proviant, schnellere Segel oder Riemen, bessere Zimmerleute, Schutz vor Gefahren, Panzerung, Rammbock, ein Fass Pulver, eine Karte mit größerer Sichtweite und mehr. Segen gelten für den Rest der Fahrt.
- **Schwierigkeit:** je Etappe +20 % Seegangs- und Gefahrenschaden, nach zwei Etappen ein Grad mehr Seegang (nach vier zwei), mehr Gefahren, mehr Begegnungen, mehr Draugr, Ungeheuer und Räuber, und Gegner mit +12 Rumpf je Etappe, +14 % Schaden und mehr Besatzung. Beute wächst um 12 % je Etappe, die Preise in der Werft (Gegenstände, Rumpf, Pulver) um 10 %; die festen Preise in Hafen und Dorf (Met, Anheuern, Proviant, Handeln, Handwerker) bleiben gleich.
- **Etappen-Themen:** Ab der zweiten Etappe hat jede ein Thema (nie zweimal hintereinander dasselbe): **Nebelmeer** (viel Nebel, nur zwei Meilen Sicht), **Sturmfront** (ein Grad mehr Seegang, mehr Böen und Brecher), **Piratengewässer** (dreimal so viele Räuberschiffe), **Totensee** (dreimal so viele Draugr, oft Kraken). Das Thema steht unter dem Kartenkopf.
- **Vermächtnis:** Der Gedenkstein gibt jeder neuen Fahrt kleine Vorteile mit: weiteste Etappe 3: Beute +50, 4: Proviant +2, 5: Teerung im Rumpf, 7: Odins Gunst; je 8 Gefallene ein Veteran (zäh und stark, höchstens drei). Das Menü zeigt es an. Tests und Bots starten ohne.
- **Rente für Tests:** `--maxstage=N` (Bots: 6) lässt die Fahrt nach Etappe N enden, damit Testläufe zu Ende kommen.

## Die Fahrt: Knoten, Strecke, Wache für Wache

Wie ein Kampfzug in Darkest Dungeon: Du siehst, was kommt, überlegst in Ruhe und zahlst für deine Wahl.

1. **Kurs auf der Seekarte:** ein Netz aus Knoten (meist 3 pro Meile, Wege dazwischen). Fast jeder Knoten ist eine **Gabelung** (im Schnitt etwa 13 je Etappe, mindestens eine zwischen zwei Spalten), und die Wege sind verschieden: ein ruhigerer, sicherer Weg gegen einen riskanteren, der dafür oft eine Begegnung (also Beute) bietet. Fährt man mit der Maus über einen Knoten, erklärt ein Tooltip Seegang, Gefahr und Begegnung. Jeder Knoten hat Seegang (1–5), vielleicht eine Gefahr (Brecher, Böen, Riffe, Nebel) und vielleicht eine Begegnung (H, I, M, D, G, R, T). Man kennt die nächsten drei Meilen (im Nebel nur eine). Wähle den nächsten Knoten.
2. **Manöver bauen** (drei Regler: Segel, Ruder, Küste; jede Stellung zeigt Vor- und Nachteil) und die **Mannschaft ordnen** (7 Decksplätze).
3. **Vorschau:** zeigt genau, was die Wahl auf diesem Kurs mit dieser Besatzung bewirkt: Strecke (und wo man ankommt), Proviant, Entfernung zum nächsten Hafen, Rumpf, Schutz vor der Gefahr, Risiko „über Bord“, wer erschöpft wird. Nur der Zufall (wen die See nimmt) bleibt offen.
4. **Auslaufen:** die Folgen laufen der Reihe nach ab, der Skalde kommentiert. Danach die nächste Fahrt.
5. **Mann über Bord:** eigene Entscheidung. Seil werfen (Retter wählen, Aussicht in Prozent, kostet Proviant, evtl. Rumpf und Kraft) oder zurücklassen (alle verlieren Mut).

**Strecke (stufenlos):** Eine Fahrt (eine „Wache“) bringt das Schiff so viele **Meilen** voran, wie Vortrieb und Besatzung hergeben, z. B. 1,1 oder 0,5. Eine Meile ist der Abstand zwischen zwei Knotenspalten. Das Schiff kann **zwischen zwei Knoten** liegen: Es fährt dann auf dem festgelegten Weg weiter, der Kurs ist gesetzt, die Karte zeigt es als Punkt auf der Strecke, die Vorschau nennt den Prozentsatz. Jeder erreichte Knoten wird einzeln abgehandelt (Seegang, Gefahr). **An einem Knoten mit Begegnung (auch am Hafen) hält das Schiff an**, der Rest der Strecke verfällt. Auch an jeder Gabelung (Knoten mit mehr als einem Weg) hält das Schiff an und der Rest der Strecke verfällt: den Weg wählt man selbst. Führt nur ein Weg weiter, fährt es durch. Der Seegang schadet auch auf offener Strecke (anteilig, mindestens 40 %).

Der Seegang steuert Wellen, Regen und Blitze der Darstellung, das Schiff reitet auf einer echten Wellenfläche.

### Das Manöver: drei Regler (`scripts/strategy.gd`)

Alle Zahlen stehen in `Strategy.build()`. Zwischen den Fahrten bleiben die Stellungen stehen, man ändert nur, was sich ändern soll. Tasten 1–3 Segel, 4–6 Ruder, 7–9 Küste, oder die Knöpfe anklicken. Fährt man mit der Maus über einen Knopf, zeigt die Vorschau links, was diese Stellung bewirken würde.

| Regler | Stellungen | Vorteil | Preis |
|---|---|---|---|
| **Segel** | eingeholt / gerefft / voll | Vortrieb 0 / 0,5 / 1; eingeholt macht Böen harmlos (gerefft hält sie zur Hälfte ab) und mindert den Seegangsschaden | voll: Böen ungeschützt, 20 % mehr Seegangsschaden, mehr Verlust über Bord |
| **Ruder** | ruht / ruhig / kräftig | Vortrieb 0 / 0,6 / 1; Rudern macht das Schiff lenkbarer (Schutz vor Brechern, Riffen, Nebel) und trägt auch eine müde Besatzung weiter | ruhig kostet 12, kräftig 24 Kraft je Ruderer; „ruht“ lässt die Ruderer erholen |
| **Küste** | nah / mittel / weit | nah: 30 % weniger Seegangsschaden, weniger über Bord; weit: Riffe harmlos | nah: Riffe sehr gefährlich (−0,5 Schutz) und genaueres Steuern; weit: 25 % mehr Seegangsschaden, mehr über Bord |

- **Strecke einer Fahrt** = Vortrieb × Besetzung der nötigen Stationen (Ruder, Segel, Steuer). Max. 2,0 Meilen (voll + kräftig), min. 0,5 (nur gerefft); unter 0,3 treibt das Schiff nur. Gegenstände und Segen verändern den Vortrieb (z. B. Segeltuch +15 %).
- **Beidrehen** = Segel eingeholt und Ruder ruht: keine Strecke, alle ruhen sich aus (die Zimmerleute nur, wenn nichts zu flicken ist; sonst flicken sie besser, ×1,5, unter Kraftverlust), Verzweiflung sinkt, kostet 1 Proviant wie jede Fahrt. Die Küste spielt dann keine Rolle. Ohne Proviant lässt sich diese Stellung nicht einstellen.
- Die früheren sechs Fahrweisen leben als Vorlagen in `Strategy.PRESETS` weiter, nur für Bots, Tests und `--select=N`.

### Mannschaft
- **Kraft** (grün): sinkt bei Arbeit (etwa die Hälfte der früheren Werte: Müdigkeit baut sich über eine Etappe auf, nicht über drei Fahrten). Vier **Müdigkeitsstufen** statt einer Klippe: *frisch* ab 70 (100 % Leistung), *müde* ab 40 (90–100 %), *erschöpft* ab 15 (65–90 %), *am Ende* darunter (35–65 %). Auf der Mannkarte steht dafür z / zz / zzz, der Balken ändert die Farbe. Die **Ladung ist der Ruheplatz** (−15 bis −25 je Fahrt, Beidrehen −30). Die **Wachablösung** (Taste A oder Schalter in der Mannschaftsansicht, Standard an) tauscht vor der Fahrt den Müdesten (unter 40) gegen den frischesten Mann auf der Ladungsbank, wenn der mindestens 25 Kraft mehr hat; das Protokoll nennt es, und man kann es jederzeit selbst zurücksetzen.
- **Verzweiflung** (lila): steigt bei Sturm, Verlusten und Hunger. Bei 100 **verzagt** der Mann: halbe Leistung und er steckt seine Nachbarn an.
- **Proviant** ist die Uhr (wie die Fackel in Darkest Dungeon): jede Fahrt kostet 1, egal wie weit sie kommt; langsam fahren kostet also pro Meile mehr. Start 26, Lager 32 (mit Fässern mehr). Ohne Proviant sterben Erschöpfte.
- **Rumpf** ist der Zustand des Schiffes (100, mit Gegenständen und Segen mehr). Bei 0 sinkt es. Bei ruhiger See (1–2) gibt es keinen Schaden, ab Raue See (3) leidet der Rumpf, dazu kommen Gefahren.
- **Zimmermänner** (2 Plätze) flicken den Rumpf: ca. 8 Rumpf pro Mann und Fahrt bei voller Kraft, beim Beidrehen mehr. Gibt es nichts zu reparieren, ruhen sie sich aus.
- **Reparieren unterwegs:** auf einer Insel in der Bucht flicken (Proviant 1: Rumpf +20), im Küstendorf Handwerker bezahlen (Beute 25: Rumpf +25), im Hafen in der Werft (Beute 20: Rumpf +25), im Kampf „Flicken“.
- Ertrunkene sind endgültig tot.

## Das Schiff: Gegenstände

Sieben Plätze (`scripts/items.gd`): **Bug** (Rammsporn, Drachenkopf), **Rumpf** (Teerung, Eisenbeschläge, Doppelte Planken), **Segel** (Segeltuch, Prunksegel, Sturmsegel), **Riemen** (Lange Riemen, Eschenriemen), **Kanone I und II** (Bronzekanone, Schwere Kanone) und **Laderaum** (Proviantfass, Pulverkammer, Werkzeugkiste, Beutetruhe). Jeder Gegenstand ändert Schiffswerte (Rumpf, Panzerung, Vortrieb, Seegangs- und Gefahrenschaden, Reparatur, Beute, Proviant- und Pulverlager, Kanonen, Rammschaden). Die Sichtweite der Karte erhöhen nur Segen. Ein gekaufter Gegenstand ersetzt, was auf seinem Platz sitzt.

- **Werft im Hafen:** Reiter **Gegenstände**: Angebot von drei zufälligen Gegenständen, jeder mit gewürfelter **Seltenheit** (Preis wächst mit Etappe und Seltenheit), Rumpf reparieren (+25), Pulver kaufen (+4, nur mit Kanonen). Ab der zweiten Etappe wird oft eine Kanone angeboten. Reiter **Schmiede**: Waffe und Rüstung jedes Mannes (bis Stufe 4: +8 % Schaden, +3,5 % Schutz je Stufe, Preise 70 bis 340 Beute) und die **Kampfschule** (jede Fertigkeit bis Stufe 3: +10 % Schaden und +2 Treffer, +15 % Heilung; reine Hilfen wie Schildwall nur bis Stufe 1: eine Runde länger). Wer fällt, nimmt seine Stufen mit.
- **Ausrüstung der Männer** (`scripts/gear.gd`): jeder Mann trägt Waffe, Rüstung und Amulett, 18 Stücke (je sechs) in denselben vier Seltenheiten, mit Werten wie Schaden, Schutz, Krit, Treffer, Ausweichen, Tempo, weniger Verzweiflung und Regeneration je Runde. Sie liegen im **Vorrat** (sechs Plätze), bis jemand sie in der Werft im Reiter **Ausrüstung** anlegt (Klick, "Beste anlegen" macht es für alle). Im Reiter **Rüstkammer** kauft man drei Stücke und verkauft Vorrat für die Hälfte. Funde: 35 % nach einem gewonnenen Deckkampf, im Wrack oft statt eines Schiffsgegenstands, beim Kraken immer mindestens Episch. Fällt ein Mann, kehrt seine Ausrüstung in den Vorrat zurück, seine Stufen aus der Schmiede gehen verloren. Ist der Vorrat voll, wird jeder Fund sofort verkauft.
- **Spielautomaten** (`scripts/slots.gd`, `scripts/slot_view.gd`, Einzelheiten in `AUTOMATEN.md`): drei Zugänge, ein Regelwerk. Die **Spelunke** im Hafen (Nornenwalzen: fünf Walzen, zehn Linien, drei Einsatzstufen, höchstens zehn bezahlte Drehs je Besuch), der **Freidreh** nach manchen gewonnenen Deckkämpfen (nach dem Kraken sind die Freispiele sicher) und **Adlerssons Spielschiff** (seltene Begegnung ab Etappe 2: hoher Einsatz in Beute, Rumpf oder einem Mann, Risikoleiter, Adlerssons Streich). Drei Blitzrunen wecken den Draugr ("It's alive!"): Freispiele mit Joker, Stapeln und Power-Ups. Große Gewinne geben einen Segen, sehr große einen Fund, die Jackpot-Linie legendäre Ausrüstung. Der fahrende Glücksspieler heißt Adlersson; die legendäre **Pfandflasche** (selten gefunden, höchstens drei) gibt bei ihm ein sicheres Freispiel.
- **Seltenheiten:** Gewöhnlich (grau), Selten (blau, Werte ×1,3), Episch (violett, ×1,65 und ein Zusatzwert), Legendär (gold, ×2,1, stärkerer Zusatzwert und eigener nordischer Name). Nachteile eines Gegenstands wachsen nicht mit, Kanonen bleiben eine. Gewürfelt wird im Laden, bei Funden im Wrack (besser), nach 30 % der gewonnenen Seeschlachten und immer beim Kraken (mindestens Episch). Ein besserer Fund ersetzt das alte Stück auf dem Platz, das alte wird verkauft. Im Schiffsbild und in der Werft zeigen farbige Rahmen und Titel die Seltenheit, der Tooltip alle Werte.
- **Schiffsansicht (Taste B oder „Schiff“ über der Mannschaft):** alle Plätze mit ihren Gegenständen, die Schiffswerte und die Segen.
- **Mannschaftsansicht (Taste C):** alle sieben Plätze von Heck bis Bug mit Kraft und Verzweiflung, rechts der Steckbrief; Mann anklicken, dann Mann (tauschen) oder freien Platz (hinsetzen); nur in der Planung.

## Der Deckkampf (`scripts/combat.gd`, Konzept und Zahlen in `KAMPFSYSTEM.md`)

Entern, Überfall auf ein Handelsschiff und Überfall auf ein Dorf sind **rundenbasierte Kämpfe** wie in Darkest Dungeon, kein Würfelwurf mehr. Vorher wählt man in der **Aufstellung** bis zu vier Kämpfer aus allen Männern an Bord (auch aus der Reserve) und ihre Reihenfolge (▲▼; „Beste vier“ wählt von jeder Rolle den Kräftigsten). Jeder Mann hat eine **Rolle**: Schildträger (hält vorn, betäubt, Schildwall, Herausforderung), Axtmann (Schaden, Blutung, Ansturm, Wirbelhieb), Bogenschütze (trifft jede Reihe aus Reihe 2–4, markiert, Pfeilregen), Skalde (Kriegslied, Heilsegen, Trostlied, Weckruf, Hohnlied, ohne Einsatzgrenzen) und **Musketier** (schwere Schüsse, danach Nachladen, dazu die Pistole). Jede Rolle kennt sechs Fertigkeiten, vier nimmt der Mann mit in den Kampf (Wahl in der Aufstellung, jede mit einem kleinen Symbol). Jede Fertigkeit darf nur aus bestimmten Reihen eingesetzt werden und trifft bestimmte Reihen. Die Zugreihenfolge ergibt sich aus Tempo plus Zufall (Zugleiste oben); Trefferchancen und Schaden stehen vor der Wahl im Tooltip. **Kraft** ist die Verletzbarkeit; bei 0 ist der Mann „an der Schwelle“, jeder weitere Treffer tötet mit 50 %. Gegner haben Reihen, Ausweichen, Schutz, Immunitäten (Draugr bluten nicht) und fliehen, wenn die Hälfte gefallen ist. Es gibt Heiler, Beschützer, Beschwörer, Antreiber und Rammer, die Aufstellungen wechseln je Kampf; Brüder rächen sich, Gefährten trauern. Verzweiflung wächst durch kritische Treffer und Verluste und sinkt bei jedem gefallenen Gegner. **Nerven:** Erreicht ein Mann im Kampf 100 Verzweiflung (schwere Treffer, Krit, die Schwelle, Verluste und Gegner-Lieder treiben sie hoch), kippt er einmal je Kampf: meist ein Zusammenbruch (verzagt oder Berserker, der gelegentlich einen Kameraden schlägt), aber mit etwa drei Chancen in zehn Heldenmut (Zug extra, Heilung oder mehr Schaden für alle), mit einem Skalden an der Seite etwas häufiger. Dazu eine große Ansage und eigener Klang. Wer nicht von Hand kämpfen will, wählt in den Einstellungen „Kämpfe: schnell“ (die Maschine spielt beide Seiten). Der Ausgang bestimmt die Beute: Sieg bringt die Beute der Begegnung, Niederlage und Rückzug nur Verluste.

**Der Kraken** (Entern in der Seeschlacht) ist ein Boss: zwei Fangarme vorn, dahinter der Körper als Riesenfigur. Der Körper ist unerreichbar, solange ein Fangarm steht; gefällte Fangarme wachsen nach vier Runden mit 60 % Kraft nach. Ein **Würgegriff** hält einen Mann fest (G): er kann nichts tun, und zieht der Fangarm ihn nicht binnen zwei Zügen über Bord, ist er frei, wenn der Fangarm fällt oder betäubt wird. Die **Tintenwolke** (T) senkt die Trefferchance, **Zerquetschen** (Z) wird angekündigt und trifft im nächsten Zug alle, ein Betäubter kann es nicht. Wer über Bord geht, wird nach dem Kampf gerettet.

Die Kampfansicht ist eine **Bühne** (`scripts/fight_stage.gd`, Kulissen aus `tools/make_stage_art.py`): links das eigene Langschiff mit Schilden an der Reling, rechts das Schiff der Gegner (Geisterschiff, Räuber, Händler), das Dorf oder der Kraken; jeder Ort hat eigenen Himmel (Mondnacht, Feuerhimmel, Abendrot, Gewitter), eigenes Licht und eigene Planken. Die Männer links und die Gegner rechts sind **Körperfiguren mit Rig** (`tools/rig_core.py`, `assets/fig/`): 23 Menschen (fünf Rollen, achtzehn Gegner) und Hund und Fangarm haben je 32 Bilder (Atmen, Bereitschaft, Ausholen, Schlag, Nachschwung, Zauber, Block, Ausweichen, Treffer, Betäubung, Knien an der Schwelle, Fall, Leiche, Jubel, Gepackt), der Kraken wird aus seinem Bild gestreckt und gesenkt; sie stehen auf einem Deck mit Enterbrücke in der Mitte. **Wer dran ist, steht im Licht**: ein Lichtkegel von oben und eine Lichtpfütze auf den Planken (warm bei den Männern, kalt beim Gegnerzug), alle anderen und der Hintergrund sinken ins Halbdunkel; bei der Zielwahl leuchten nur die gültigen Ziele, mit rotem Pfeil und pulsierendem Rahmen. Dazu Nebelbänke, Laternenschein, Wellenglanz, beim Kraken Regen und Blitz. Die **Regie** (`scripts/fight_director.gd`, `beat_planner.gd`, `fight_cam.gd`) macht aus jeder Handlung einen Beat: beim Gegnerzug eine Ankündigung, dann Ausholen und Schlag mit Ausfall (Nachbilder), im Augenblick des Kontakts ein **Standbild** (40 ms bei einem Streifer bis 160 ms beim Todesstoß, das Opfer zittert), weißer Blitz und Rotstich am Ziel, Rückstoß, Funken, Blut und ein Stern am Einschlag, schwebende Zahlen und das Banner mit dem Namen der Fertigkeit. Je schwerer der Treffer, desto mehr Wucht: schwer (ab 24) wackelt stärker, **Krit** fährt die Kamera auf 1,25 und verlangsamt kurz, der **Todesstoß** und der letzte Gegner fahren auf 1,375 mit Zeitlupe vor und nach dem Kontakt. Die **Kamera** fährt auf Handelnden und Ziel (Zoom 1,125 bis 1,375, Schwenk 140 ms, der Hintergrund bewegt sich weniger als Deck und Figuren), wackelt zuerst entlang der Schlagachse und löst sich 120 ms nach der Handlung, falls nicht gleich der nächste Beat kommt; bei der Zielwahl steht sie auf 1,0, damit alle Ziele sichtbar bleiben. Ein Beat dauert höchstens so lang wie der Takt (900 ms), außer Krit, Tod, Schwelle, Heldenmut und ein paar anderen; je Kampf dürfen die Überlängen zusammen 6 s nicht überschreiten, danach wird gekürzt. Gegner und Ende des Kampfes warten auf die Regie (`Voyage.stage_t`), nie länger als 4 s. In den Einstellungen schalten „Kampfbild“ zwischen **voll** und **schlicht** (ohne Nebel, Glanz, Regen, Blitz), „Kampfansicht“ zwischen **voll** und **kurz** (halbe Zeiten, keine Kamerafahrt) und „Wackeln“ zwischen **aus**, **schwach** und **normal**. Im Schnellmodus („Kämpfe: schnell“) und in allen Bots gibt es keine Regie. Noch nicht umgesetzt aus dem Entwurf in `docs/kampf_spektakel/`: die eigene Wucht-Schrift, Fokusschild und Zugleiste mit Statussymbolen, neue Klangschichten.

## Das Lager (Zeltlager, `scripts/camp.gd`)

Eine Rast an Land. Auf der Karte stehen **Ankerbuchten** (A, sicher, eine bis zwei je Etappe). Ein Lager geht dort oder auf **ruhiger See ohne Gefahr**, **einmal je Etappe**, nicht im Hafen (dort „Rasten“) und nicht zwischen zwei Knoten. Es kostet **2 Proviant**, auf der Karte vergeht keine Meile. Man hat **6 Lagerpunkte** für: Essen (1, Proviant ein halber je Mann, Kraft +20, Mut +5), Schlafen (2, Kraft +40, Mut +10), Wache stellen (1, Nacht sicherer), Lied (1, Mut +12), Flicken (1 je Zimmermann, Rumpf +12), Fischen (1, Schwimmer oder Seebär, Proviant +3), Karten lesen (1, Sterngucker, Sicht +1), Geschichten teilen (1, Paar mit Bindung, Mut +12), Met (1, Beute −10, Mut +20, Kater). „Mannschaft ändern“ (Reserve ↔ Deck) kostet nichts. Beim Aufbrechen wird die **Nacht** abgewickelt: Chance 5 % in der Bucht, 22 % an offener Küste (halb ohne Schlaf, ein Viertel mit Wache, mehr in späteren Etappen, Piratengewässern und Totensee): Überfall (Abwehr nach Kampfstärke), Sturm, ein Fremder (Proviant +3) oder ein Fund (Beute). Taste L oder die Schaltfläche „Lager“ über „Auslaufen“; Tasten 1–9 wählen Aktionen, Enter bricht auf.

## Begegnungen

Wie in Darkest Dungeon, wenn man einen Raum durchsucht: Man kann sie über die Wahl des Kurses **ansteuern oder umgehen**, jede hat Risiko und Belohnung. Man kann an ihnen nicht vorbeirasen: das Schiff hält an.

| Begegnung | Optionen |
|---|---|
| **Handelsschiff** (H) | Entern (Aussicht aus der Kampfstärke), Handeln (Beute 30 gegen Proviant 6), Vorbeiziehen |
| **Insel** (I) | Erkunden (meist ergiebig, manchmal Hinterhalt), am Strand suchen, **Bucht: flicken**, vorbeifahren |
| **Seeungeheuer** (M) | Kämpfen, Opfern (Proviant 4), Davonrudern |
| **Hafen** (T) | Man bleibt, bis man ablegt. Met (Beute 25: Verzweiflung −20), Rasten (Proviant 2: Kraft +30), Anheuern (Beute 40: ersetzt einen Gefallenen), Proviant (Beute 15: +8), **Werft**, Ablegen |
| **Küstendorf** (D) | Überfallen, heimlich plündern, **Handwerker** (Beute 25: Rumpf +25), vorbeifahren |
| **Draugr-Schiff** (G), **Räuberschiff** (R), **Kraken** (K, ab Etappe 3) | Seeschlacht, siehe unten |
| **Wrack** (W) | Durchsuchen (oft ein Fund, darunter ein Gegenstand; manchmal eine Falle), Holz bergen (Rumpf +12), vorbeifahren |

Gefallene Namen bleiben in der Gefallenenliste, auch wenn ihr Platz neu besetzt wird.

## Seeschlacht (`scripts/battle.gd`)

Bis zu 6 Runden wie ein Kampf in Darkest Dungeon: Der Gegner **kündigt seinen nächsten Zug an**, du wählst eine von bis zu sieben Taktiken, die Karten zeigen die Folgen. Gegner und ihre Züge:

| Gegner | Werte (Etappe 1) | Züge |
|---|---|---|
| **Draugr-Schiff** | Rumpf 60, 6 Draugr, Beute 70 | Rammstoß (Rumpf −16), Enterkommando (2 Männer verletzt, Todesgefahr), Totenklage (Verzweiflung +14 für alle) |
| **Räuberschiff** | Rumpf 50, 8 Räuber, Beute 95 | Kanonenfeuer (Rumpf −11, ein Mann verletzt), Enterkommando, Rammstoß |
| **Kraken** | Rumpf 85, 6 Tentakel (alle Tentakel ab = Sieg), Beute 130 | Tentakelgriff (Rumpf −6, ein Mann kann über Bord gerissen werden), Zerquetschen (Rumpf −22), Tintenwolke (Verzweiflung +10, Kraft −8 für alle). **Entern ist ein Deckkampf gegen den Kraken** (siehe unten) |

Taktiken: **Rammen** (Schaden nach Ruder- und Steuerleistung plus Rammgegenstände, eigener Rumpf −8), **Pfeilhagel** (tötet bis zu 3, Kraft −5, mindert Enterer auf 60 %), **Kanonen** (14 Schaden je Kanone nach Kampfstärke, kostet 1 Pulver, danach eine Runde Nachladen, tötet je zwei Kanonen einen Mann), **Entern** (Aussicht aus der Kampfstärke; Sieg: Gegner −4, Niederlage: ein Toter), **Schildwall** (Gegnerzug nur zu 40 %), **Flicken** (Zimmerleute: Rumpf +19, kein Angriff), **Fliehen** (Rumpf −4 bei guter Ruderbesatzung, sonst −10, keine Beute). Panzerung nimmt jedem Treffer etwas ab. Sieg: Beute (mit Zuschlägen), Proviant +4, Verzweiflung −10, Erfahrung. Nach der 6. Runde zieht der Gegner ab, ohne Beute. Mit jeder Etappe werden Gegner zäher und treffen härter.

## Crew, Stress, Marotten

- Jeder Mann hat einen Namen, **1–2 Eigenschaften** und die Werte Kraft und **Verzweiflung**. Maus über einen Mann (Karte unten oder Figur an Deck) zeigt den Steckbrief.
- Eigenschaften (`scripts/traits.gd`): Starker Arm, Geschickte Hände, Sterngucker, Zäh, Ängstlich / Gelassen, Heißsporn, Seebär / Pechvogel, Schwimmer, Faulpelz. Widersprüchliche Paare kommen nie zusammen. Anwerber im Hafen haben ebenfalls welche.
- Bei 100 Verzweiflung kippt er: **verzagt** (halbe Leistung, steckt die Nachbarn an) oder **Berserker** (1,2-fache Leistung, schlägt manchmal den Nachbarn nieder; Heißsporne werden eher Berserker).
- **Beziehungen** (`Voyage.bonds`, zu Beginn ausgelost: 1–2 Brüderpaare, mit 70 % ein Rivalenpaar): **Brüder** nebeneinander beruhigen sich, trauern bei Verlust (+30), nehmen Zurücklassen übel, ziehen fester am Seil; **Rivalen** nebeneinander reizen sich (Streit möglich), atmen bei Verlust auf. Anzeige: goldener (Bruder) oder roter (Rivale) Punkt an der Mannkarte, Steckbrief nennt den Partner.
- **Gefährten:** Wer einen Mann aus dem Wasser zieht und beide noch keine Bindung haben, wird mit ihm Gefährte (blauer Punkt): nebeneinander etwas ruhiger (−2), Trauer bei Verlust nur halb so stark (+15), Rettungsaussicht +8 %.
- **Reserve:** Neben den sieben Männern an Deck gibt es Plätze unter Deck (Start 2, mit Hängematten aus der Werft bis 5). Reservisten arbeiten nicht, sind vor dem Meer sicher, erholen sich bei jeder Fahrt (Kraft +15, Verzweiflung −3) und kämpfen bei Entern und Überfall mit. Sie essen mit: ab dem achten Mann an Bord kostet jeder Mann einen halben Proviant je Fahrt. An Deck kommen sie nur im **Hafen, im Lager und am Anfang einer Etappe** (Mannschaftsansicht C: Reservist anklicken, dann einen Mann an Deck oder einen freien Platz; „Entlassen“ für Reservisten). Fällt jemand an Deck, rückt der frischeste Reservist nach; die Wachablösung tauscht Müde am Etappenanfang gegen frische Reservisten.
- **Taverne:** Im Hafen öffnet „Anheuern“ die Mannschaftsansicht mit drei Anwärtern (Kraft, Eigenschaften, Preis nach Kraft und Eigenschaften, wächst mit der Etappe). Wer Platz hat (Reserve oder ein gefallener Mann), heuert an; ohne Gefallenen kommt der Neue in die Reserve.
- Tod ist endgültig. Gefallene kommen auf den **Gedenkstein** (bleibt zwischen Fahrten).

### Saga, Gedenkstein, Speichern
- Am Ende schreibt der Skalde die **Saga** der Fahrt aus dem, was wirklich geschah (Tote, Rettungen, Beute, Sturm, Anheuern, Seeschlachten, Trauer) und nennt Etappe, Stufe und Strecke. Sie steht auf dem Endbildschirm.
- Der **Gedenkstein** (Taste G oder im Hauptmenü, ein Klick oder G/Esc schließt ihn) listet die Gefallenen der gewählten Fahrt mit Todesursache und blättert durch die Sagas aller beendeten Fahrten (`user://gedenkstein.json`, die letzten 40).
- Die laufende Fahrt wird **bei jeder Planung gespeichert** (Etappe, Strecke, Stufe, Segen, Gegenstände, Pulver, Regler) und beim nächsten Start fortgesetzt (`user://run.json`). Mit Strg+N oder „Neue Fahrt“ im Menü (zweimal bestätigen) beginnt man neu. Nach dem Ende beginnt Enter sofort die nächste Fahrt, Esc führt ins Hauptmenü.
- Gespeichert wird nur im echten Spiel, nie bei Tests, Bots oder Screenshots.

## Der Skalde (Erzähler)

Trockener Kommentator wie der Ahne in Darkest Dungeon, aber nordisch und fies freundlich. Beispiele für den Ton:
- „Olaf wollte nur kurz nach dem Wetter sehen. Das Wetter sah zurück.“
- „Er starb, wie er lebte: überraschend und nass.“

## Musik

Die Lieder liegen in `Musik/` (WAV, zusammen mit den Liedtexten als .md), die selbst komponierten Hintergrundstücke ohne Gesang in `Musik/Hintergrund/`. Gespielt wird je nach Lage, mit sanfter Überblendung, Endlosschleife und Weiterspielen an der unterbrochenen Stelle (`scripts/music.gd`). **Während der Fahrt läuft nie Gesang.**

| Lage | Stück |
|---|---|
| Hauptmenü, nach dem Ruhestand | *Neue Ufer, neues Land* (mit Gesang) |
| Nach dem Untergang | *Halt aus, mein Freund* (mit Gesang) |
| Fahrt bei Seegang 1–2 | *Morgenwind* (komponiert, D dorisch, Harfe und Laute über Teppich und Orgelpunkt) |
| Fahrt bei Seegang 3, Mann über Bord | *Halt aus, mein Freund* ohne Gesang (die Fassung „Without Lead Vocal“) |
| Fahrt bei Seegang 4–5 | *Sturmwache* (komponiert, A aeolisch, Rahmentrommeln, tremolierende Streicher, Fiedelmotiv) |
| Seeschlacht | *Eisen und Salz* (komponiert, E phrygisch, schwere Trommeln, Ostinato-Bass, Hornrufe) |
| Hafen | *Taverne am Kai* (komponiert, G mixolydisch im 6/8-Takt, Laute und Fußtrampeln) |

Die vier Stücke kommen aus `tools/make_music.py` (reines Python, jeder Lauf liefert dieselbe Musik, Mono 22 kHz, nahtlose Schleife). Sie sind ungehört auf Plausibilität geprüft (Pegel, Schleifennaht, Klangverteilung), nicht nach Gehör. Ein Stück wechselt frühestens nach 40 Sekunden, nur Rettung, Seeschlacht, Hafen, Menü und Spielende wechseln sofort. Tasten: M = Musik an/aus, + / − = Lautstärke (wird gemerkt). Tests und Bots spielen nie Ton.
Noch ohne Tondatei: *Stürmische See* (nur der Text liegt vor).

### Soundeffekte

45 Klänge, von Hand synthetisiert (`tools/make_sfx.py`, reines Python, wiederholbar), in `assets/sfx/`. Gespielt von `scripts/sfx.gd` mit Zufallsvariation der Tonhöhe und Drosselung gleicher Klänge. Lautstärke je Klang in `Sfx.GAIN`. Neu: *cannon* (Kanonenschuss, in der Seeschlacht) und 18 Kampfgeräusche (Schwerthieb, Axt, Schildstoß, Bogen, Pfeiltreffer, Biss, Heilung, Harfe, Kriegslied, Fall, Totenklage, Schild, Kraken-Brüllen, Tentakel, Tinte; je Fertigkeit in `Sfx.SKILL_SND`, ausgelöst von der Kampfansicht). Die Klänge sind ungehört auf Plausibilität geprüft (Wellenform, Pegel, Dauer). Tests, Bots und Screenshots erzeugen nie Ton.

## Grafik und Oberfläche

- **Gegenstands-Symbole und Segen-Embleme** (`tools/make_item_icons.py`, `scripts/item_icons.gd`): 36 Symbole für Schiffsgegenstände, Ausrüstung und die Pfandflasche (20×20 auf dunkler Platte, Rand und Glanz je nach Seltenheit eingebrannt: grau, blau, violett, gold) in Werft, Rüstkammer und Ausrüstung; 14 Medaillon-Embleme (32×32) für die Segen beim Stufenaufstieg. Reihenfolge und Lader werden vom Skript miterzeugt.
- **Politur (zuletzt):** Himmel mit gedithertem Verlauf, driftenden Pixelwolken, Sonne, Küstensilhouette und Möwen (`shaders/sky.gdshader`, `tools/make_sky.py`), drei Wasserschichten mit Schaumkämmen, Glitzern, Bugwelle und Kielwasser, Regen mit Spritzern, Blitz als Silhouette; überarbeitetes Langschiff und Crew (`tools/make_art.py`); Kulissen für Draugr, Räuber, Kraken, Handelsschiff, Insel, Dorf, Hafen und Wrack hinter dem eigenen Schiff (`tools/make_enemies.py`, `scripts/enemy_layer.gd`); Pixelrahmen, Pergament-Seekarte mit Symbolen je Begegnung, Porträts der Mannschaft, Randvignette (`tools/make_ui.py`, `scripts/ui_skin.gd`). Alles harte Pixel im 480×320-Raster.
- Seitenansicht, Pixelart, gedeckte Palette (Schwarzblau, Moosgrün, Rost, Knochenweiß, wenig Rot als Akzent). Wasser als Parallax-Schichten mit Wellensimulation. Assets per Skript (`tools/make_art.py`).
- **Kopfzeile:** Rumpf, Proviant, Beute (und Pulver mit Kanonen) links, Meile und See rechts; die Erfahrung ist nur ein feiner violetter Strich am oberen Rand, Etappe und Stufe stehen über der Seekarte.
- **Mitte:** nur die letzten beiden Meldungen des Skalden.
- **Links:** ein Feld nur, wenn es etwas zu entscheiden gibt: Vorschau der Fahrt (nur Strecke, Ankunft, Proviant, Rumpf, Gefahren, Warnungen), Beschreibung der Begegnung, der Gegner der Seeschlacht.
- **Unten:** ein dunkles Band mit drei Reglergruppen (nur die Stellung steht auf dem Knopf, Vor- und Nachteil erscheinen beim Darüberfahren), der Schaltfläche „Auslaufen“, zwei kleinen Reitern „Schiff“ und „Crew“ und der Mannschaft. Begegnungs-, Hafen- und Schlachtkarten sind höher (bis zu sieben Karten).
- **Tooltips:** Fährt man mit der Maus über einen Wert, erklärt ein Kasten die Mechanik und rechnet sie mit den aktuellen Zahlen vor (`scripts/tips.gd`): Rumpf, Proviant, Beute, Pulver, Meile, Seegang und Etappe/Stufe/Thema in der Kopfzeile und über der Karte; jede Zeile der Vorschau (Meilen, Ankunft, Proviant, Rumpf, jede Gefahr wie „Nebel −8“ mit Grundschaden, Etappenhärte, Schutz der Regler und Folge, „Über Bord“, Besetzung, Erschöpfte); jeder Knoten der Seekarte; jede Begegnungskarte mit Kosten, Aussicht und der echten Beute samt Art; das Gegnerfeld der Seeschlacht (Beute bei Sieg). Der Steckbrief eines Mannes erklärt zusätzlich Kraft, Verzweiflung und seinen Platz. Mannschaft (C), Schiff und Werft (B), Segen bei Stufenaufstieg (Tasten 1–3), Gedenkstein (G).

## Bedienung

| Eingabe | Wirkung |
|---|---|
| Klick auf einen Knoten (Seekarte rechts) oder Q / W / E | Kurs wählen; zwischen zwei Knoten steht er schon fest |
| 1 – 3 / 4 – 6 / 7 – 9 oder Klick auf einen Knopf | Segel / Ruder / Küste einstellen |
| Begegnung: 1 – 3 oder Klick (Hafen 1 – 6, Seeschlacht 1 – 7) | Option bzw. Taktik wählen |
| Enter oder „Auslaufen“ | eine Fahrt fahren |
| Klick auf Mann, dann Mann / freien Platz | Plätze tauschen / Mann versetzen |
| Mann über Bord: R / Z | Seil werfen / zurücklassen; anderen Mann anklicken = Retter wechseln |
| C / B | Mannschaftsansicht / Schiff und Werft |
| Werft: 1–3, R, P | Angebot kaufen, Rumpf reparieren, Pulver kaufen |
| Esc | Auswahl aufheben, sonst Hauptmenü; nach dem Ende ins Hauptmenü |
| H / F11 / M / + − / G / Strg+N | Hilfe, Vollbild, Ton, Lautstärke, Gedenkstein, neue Fahrt (zweimal) |

## Testen ohne Spieler und ohne dass ein Fenster aufgeht (stört nicht bei der Arbeit am PC)

Alles Wichtige zum lokalen Start, zu den Prüfungen und zu den Hilfsskripten steht in `README.md`; die Befunde der letzten Prüfung in `docs/PRUEFUNG.md`. Kurz: `tools/dev/alltests.sh` (Linux/macOS/Git Bash) führt alle Tests aus, `--textcheck` meldet abgeschnittenen Text.

- Logiktest: `godot --headless --path . --script tools/selftest.gd` (außerdem `tools/musictest.gd`, `tools/sfxtest.gd`).
- Bots: `godot --headless --path . -- --autoplay --log --timescale=20 --seed=3 --maxstage=8` (`--random` für den Zufallsbot). Der kluge Bot probiert alle 27 Reglerstellungen in der Vorschau durch, kauft in der Werft, wählt Segen und nutzt in der Seeschlacht Karten gegen den angekündigten Zug.
- Screenshots ohne Fenster: `godot --path . --no-window --resolution 3120x2080 -- --nohelp --select=1 --shot=bild.png@2`. Weitere Schalter: `--shotenc`, `--shotswim`, `--shotharbor [--shopopen]`, `--shotbattle`, `--shotcrew`, `--menu`, `--giveperk`, `--giveloot`, `--hoverdial=0,2`, `--forceenc=N` (jede Begegnung ist Typ N: 5 Draugr-Schiff, 6 Räuberschiff, 7 Kraken, 8 Wrack), `--nohelp`, `--settingsopen`, `--shotmem`, `--hovermouse=x,y` (Tooltip-Screenshot mit „Maus“ an dieser Stelle, in Spielfeldpixeln).

## Meilensteine

1. **M1 Prototyp:** Schiff auf Wellen, Regen, Blitz. *(fertig)*
2. **M2 Überfahrt:** Manöver, Crew an Stationen, Kraft/Verzweiflung, Mann über Bord. *(spielbar)*
3. **M3 Seekarte & Begegnungen:** Knotenkarte, Handelsschiff, Insel, Seeungeheuer, Hafen, Küstendorf, Musik und Soundeffekte. *(spielbar)*
4. **M4 Run-Struktur:** Eigenschaften, Marotten, Saga, Gedenkstein, Speichern, Beziehungen, Draugr-Seeschlacht. *(gebaut)*
5. **M5 Endlosfahrt:** Etappen, Stufen und Segen, Gegenstände und Werft, Kanonen, Räuberschiffe, stufenlose Strecke, Hauptmenü, Musik ohne Gesang während der Fahrt, Reparatur in Bucht und Dorf. *(gebaut, Balance ungeprüft von Menschen: bewusst deutlich schwerer als vorher)*
6. **M6b Besatzung und Lager:** Erschöpfung neu (Stufen, Wachablösung), Reserve, Taverne mit Anwärtern, Lager. *(gebaut, Balance ungeprüft: der kluge Bot kommt jetzt auf etwa Etappe 5)*
6. **M6 Ausbau:** Kraken, Wracks mit Gegenstandsfunden, Etappen-Themen, Gefährten, Einstellungen, Vermächtnis, schlankere Oberfläche nach Darkest-Dungeon-Vorbild. *(gebaut in `Vikingerspiel_v2`, Balance ungeprüft von Menschen)*
7. **M7 Politur:** Balancing nach echten Läufen, Windows-Export (braucht die Godot-Exportvorlagen, noch nicht installiert), Web optional.

## Weitergeben (Windows-Export)

Das Spiel lässt sich als einzelne Halt Kurs.exe (Godot-Export, Vorlage 4.7.2, pck eingebettet) weitergeben; Einstellung in export_presets.cfg, Ergebnis in build/ (Halt_Kurs_Windows.zip mit LIES MICH.txt, etwa 90 MB). Die Datei ist nicht signiert, Windows warnt beim ersten Start. Spielstand und Einstellungen liegen unter %APPDATA%\Halt Kurs v2. Nach jeder Änderung neu exportieren.
