# Reserve, Trupp-Wechsel und Lager — Ideen für ein neues Erschöpfungssystem

Stand: **R1 (Reserve und Taverne), R2 (Erschöpfung) und R3 (Lager) sind eingebaut.** Abweichungen vom Entwurf: Reservisten kosten einen halben Proviant je Fahrt (statt einem Drittel, nach dem Test mit Bots); im Lager hängen die Aktionen an Eigenschaften, Rollen gibt es noch nicht; der Nachtüberfall ist noch eine Abwehrchance statt eines Deckkampfes (kommt mit dem Kampfsystem); ein Lager je Etappe, nicht im Hafen. Früherer Stand: **R2 (Erschöpfung neu) ist eingebaut** (Kraftkosten halbiert, vier Müdigkeitsstufen, Wachablösung über die Ladungsbank, Tooltips). R1 (Reserve) und R3 (Lager) sind noch Entwurf. Beim Einbau wurde die Etappenhärte von 10 auf 14 % angehoben, weil der kluge Bot ohne die alte Müdigkeit von Etappe 2,6 auf 4,3 kam (mit 14 % rund 3,8). Gehört zusammen mit `KAMPFSYSTEM.md` (die Reserve liefert dort die frischen Kämpfer).

## 1. Warum das heutige System nervt (Diagnose)

Heute verliert jeder Mann an seiner Station bei jeder Fahrt Kraft (Ruder 12 bzw. 24, Segel 8 bzw. 12, Steuer 10–14, Zimmermann 8–12, plus 2 je Seegang über 2). Unter 40 Kraft arbeitet er nur noch zu 30–100 %. Erholen kann sich nur, wer auf der **einen** Ladungsbank sitzt (+25) oder wenn man beidreht (kostet eine Fahrt und Proviant).

Folge: Bei sechs Arbeitern und einem Ruheplatz muss man nach jeder zweiten bis dritten Fahrt Männer umsetzen. Es gibt dabei **keine Entscheidung**, nur eine offensichtlich richtige Handlung (den Müdesten auf die Bank, den Frischesten an seine Stelle). Die Müdigkeit ist Pflichtprogramm, kein Dilemma. Und bei einem Fehler sinkt die Arbeitsleistung abrupt (Schwelle bei 40).

Ein gutes System macht aus „Pflicht“ **Wahl**: *Wann* rasten wir, *wo*, *mit wem*, *auf wessen Kosten*.

## 2. Idee in drei Bausteinen

```
Reserve (mehr Männer)  +  Trupp-Wechsel am Etappenanfang  +  Lager (Rast mit Wahl)
        |                          |                               |
   Ablösung ohne Arbeit      echte Zusammenstellung        Erholung als Entscheidung
```

### 2.1 Reserve: mehr Männer, aber nicht alle im Dienst

- Es gibt weiter **sieben Decksplätze** (die Stationen bleiben, wie sie sind). Neu: die **Reserve**, Männer unter Deck.
- **Kapazität:** Start 2 Plätze; mehr durch Gegenstände und Segen („Hängematten“ +2, „Mannschaftsraum“ +2, höchstens 5). Gesamtmannschaft also 7 bis 12.
- **Reservisten** arbeiten nicht, sind **sicher vor dem Meer** (kein „über Bord“, kein Schaden bei Brechern), erholen sich pro Fahrt (**Kraft +15, Verzweiflung −3**) und können später die Stationen übernehmen oder (mit dem Kampfsystem) **als Enterkommando** kämpfen, ohne dass das Schiff Stationen verliert.
- **Preis, damit nicht immer das Maximum richtig ist:**
  - *Verpflegung:* Der Proviantverbrauch je Fahrt steigt mit der Mannschaftsgröße (7 Mann: 1; 8–9: 1 und jede zweite Fahrt +1; 10–12: 2). Der Tooltip an „Proviant“ rechnet es vor.
  - *Kaufpreis:* Anheuern kostet Beute, besser Ausgebildete mehr.
  - *Hungersterben:* bei leerem Proviant trifft es alle, nicht nur die Aktiven.
- **Anheuern neu:** In der Hafentaverne stehen **drei Anwärter** zur Wahl (statt eines einzigen Zufallsmannes, der nur einen Gefallenen ersetzt): Kraft, Verzweiflung, Eigenschaften sichtbar; bei Kampfsystem auch Rolle. Neue Auswahl pro Hafen. Anheuern geht, solange Reservekapazität frei ist, nicht nur bei Verlusten. **Entlassen** am Kai ist möglich (kleine Verzweiflung bei Brüdern).
- **Warum das hilft gegen die Müdigkeit:** Ein müder Mann geht in die Reserve und ein frischer nimmt seinen Platz. Man braucht keine Ladungsbank mehr als Müdigkeitsfalle.

### 2.2 Trupp-Wechsel an jedem Etappenanfang (alle 10 Meilen)

- Im Hafen (und beim Ablegen einer neuen Etappe) öffnet sich eine **Aufstellungsansicht**, die die vorhandene Mannschaftsansicht (Taste C) erweitert: links die sieben Decksplätze, rechts die **Reserve**.
- Man tauscht per Klick: Reservist ↔ Aktiver; Aktive untereinander. Dazu **Stationszuweisung** (wer ist Steuer, wer Zimmermann).
- **Mitten auf der Etappe** bleiben Wechsel zwischen Aktiven wie bisher möglich, Wechsel mit der Reserve dagegen nur im **Lager** oder bei einer **Begegnung im Hafen**. Sonst wäre die Reserve ein Gratis-Ersatz und Müdigkeit wieder bedeutungslos. (Einstellbar; Voreinstellung: nur Hafen und Lager.)
- Verletzte (niedrige Kraft nach Kämpfen) und Verzweifelte (Stress hoch) kann man im Hafen **in der Reserve auskurieren lassen**: das ist der DD-Sanatorium-Gedanke, bezahlt mit Proviant statt Beute.

### 2.3 Lager (Zeltlager): Rast als Entscheidung

Das Lager ersetzt das ungeliebte Müdigkeitspflegen durch eine **bewusste Rastphase**, die man **plant** wie einen Kampf.

**Wann/wo?**
- Auf der Seekarte erscheinen Knoten mit **Ankerbucht** (neues Symbol): geschützte Plätze mit Strand. Dort ist das Lager sicher und günstig.
- Auf **ruhiger See** (Seegang 1–2) ohne Gefahr am Knoten ist ein Lager an jedem Knoten möglich, aber mit Überfallrisiko.
- Bei Seegang ≥ 3 oder mit Gefahr am Knoten ist **kein Lager** möglich (nur Beidrehen).
- **Kosten:** Proviant 2 (Nacht und Essen), und die Fahrt verfällt (Zeit vergeht; auf der Karte keine Meile).
- **Wirkung auf die Schwierigkeit:** je Etappe nur **ein** Lager außer den Häfen (das Hafenlager heißt „Rasten“ im Hafen, bleibt wie heute).

**Lagerpunkte (wie in Darkest Dungeon: begrenzte Zeit, viele Möglichkeiten):** Jedes Lager hat **6 Lagerpunkte**. Man gibt sie für Aktionen aus; jede Aktion nennt vorher Wirkung und Chance (Tooltip).

| Aktion | Kosten | Wirkung |
|---|---|---|
| **Essen** | 1 Punkt, Proviant 1 je 2 Männer | Kraft +20, Verzweiflung −5 für alle, die mitessen |
| **Schlafen** | 2 Punkte | Kraft +40, Verzweiflung −10 für alle. Ohne Wache 25 % Überfall |
| **Wache stellen** | 1 Punkt, ein Mann bleibt wach (Kraft −10) | Überfallchance auf 5 % |
| **Lied am Feuer** | 1 Punkt, braucht einen Skalden (später Rolle) | Verzweiflung −15 für alle |
| **Geschichten teilen** | 1 Punkt, zwei Männer mit Bindung | Verzweiflung −10 beide, Bindung stärker |
| **Flicken** | 1 Punkt je Zimmermann | Rumpf +12 |
| **Fischen / Jagen** | 1 Punkt, Schwimmer oder Seebär | Proviant +2 bis +4, 20 % Verletzung |
| **Karten lesen** | 1 Punkt, Sterngucker | Sicht +1 Meile auf der nächsten Etappe (nur einmal) |
| **Trupp ändern** | 0 Punkte | Reserve ↔ Aktive tauschen (die Lagerzeit macht den Wechsel möglich) |
| **Met trinken** | 1 Punkt, Beute −10 | Verzweiflung −20 für alle, am Morgen Kraft −5 (Kater) |

- Die Aktionen kommen großteils aus **Eigenschaften** (Sterngucker, Schwimmer, Gelassen, Geschickte Hände), die damit mehr Gewicht bekommen als reine Zahlenfaktoren.
- **Nachtereignis** (nach dem Lager, Chance steigt mit Etappe und Thema): Überfall (kurzer Kampf), Sturm zieht auf (Karte −1 Sicht, Rumpf −5), Fremder am Feuer (Handelsmöglichkeit), Fund am Strand, Skaldenzeile. In der Totensee Draugr, in Piratengewässern Räuber.
- **Wie fühlt es sich an:** Man sieht ein Lager auf der Karte kommen (Ankerbucht in zwei Meilen), plant Proviant und Müdigkeit darauf, wählt den Weg dorthin. Ein Lager ist eine kleine Insel der Ruhe in einer harten Fahrt, kostet aber Zeit, Proviant und das Risiko der Nacht.

## 3. Erschöpfung neu abgestimmt

Zusätzlich zum Lager drei Änderungen am Kraft-Modell:

1. **Weniger Tropfen, mehr Rhythmus.** Der Kraftverlust je Fahrt wird kleiner (etwa halb so groß), die Erholung im Lager und in der Reserve größer. Müdigkeit baut sich über eine **Etappe** auf, nicht über drei Fahrten. Zahlen werden per Simulation abgestimmt (Ziel: ein durchschnittlicher Arbeiter wird bei einer Etappe ohne Rast einmal „müde“, aber nicht „erschöpft“).
2. **Weiche Müdigkeitsstufen statt Klippe bei 40.** Vier sichtbare Stufen mit Symbol an der Mannkarte: *frisch* (> 70, 100 %), *müde* (40–70, 90 %), *erschöpft* (15–40, 65 %), *am Ende* (< 15, 35 % und Verzweiflung wächst). Die Stufen stehen im Tooltip.
3. **Ablösung auf Wunsch (Schalter):** Ein Schalter „Wachablösung“ (Standard an) sorgt dafür, dass **vor** der Fahrt automatisch ein müder Aktiver (unter 40) durch den frischesten Reservisten ersetzt wird, wenn man im Hafen oder Lager die Reserve zuletzt aufgefüllt hat. Der Wechsel steht in der Vorschau (grüne Zeile „Ablösung: Ulf → Knut“) und lässt sich pro Fahrt überstimmen. Damit entfällt die Fleißarbeit, die Entscheidung („wen setze ich ein?“) bleibt beim Lager und bei der Zusammenstellung der Reserve. Wo keine Reserve ist, bleibt alles wie bisher.

Beidrehen (Segel ein und Ruder ruht) bleibt für kleine Pausen: Erholung etwas kleiner als im Lager, ohne Wahl, ohne Nachtereignis, nur Proviant 1. Für die Ladungsbank gilt weiterhin „ruhig“, aber sie ist nicht mehr der einzige Ruheplatz; als Station bekommt sie einen Zweck (Proviantmeister: −10 % Verbrauch bei besetzter Bank), damit niemand dort „hängen bleibt“.

## 4. Zusammenspiel mit dem Kampfsystem

- **Enterkommando = Reserve + Teile der Besatzung.** Für den Deckkampf wählt man vier Männer aus **allen** Männern an Bord. Wer aus der Reserve kämpft, fehlt keiner Station, kommt aber mit seiner Kraft (er war ja ausgeruht). Das löst die Schwäche des ersten Entwurfs („wer kämpft, fehlt am Ruder“) und macht die Reserve auch im Kampf wertvoll.
- **Schwelle und Tod:** Verwundete werden nach dem Kampf in die Reserve gelegt und erholen sich im Lager (oder im Hafen). Das ist ein Sanatorium ohne eigene Mechanik.
- **Hafen-Anwärter** zeigen später ihre Kampfrolle. Damit baut man die Reserve gezielt (zwei Schildträger und einen Skalden).
- **Vermächtnis:** Veteranen aus dem Gedenkstein starten in der Reserve.

## 5. Technische Folgen

- `CrewMember.State` bekommt `RESERVE` (an Bord, nicht im Dienst, ohne Platz). Viele Schleifen prüfen schon `state == ABOARD` und überspringen die Reserve von selbst; Hunger, Stress, Tod und Kraft-Erholung müssen Reservisten ausdrücklich einbeziehen.
- `Voyage.crew` wächst auf bis zu 12; Mannschaftsansicht, Kartenleiste (heute genau 7 Karten) und `slot_owner` sind auf 7 Plätze ausgelegt: die Reserve braucht eine **eigene Zeile** und die Kartenleiste bleibt bei den sieben Aktiven.
- Speicherformat: `state`, Reservekapazität, Lagerzähler, Ablösung-Schalter. Alte Stände laden ohne Reserve.
- Neue Ansicht: Lager (Aktionsleiste, Punkteanzeige, Tooltips). Mit dem vorhandenen Tooltip-System ist der Erklärteil klein.
- Karte: Knotentyp „Ankerbucht“ (Symbol in `make_ui.py`, Platzierung in `_make_map`, Tooltip).
- Bot: kennt Reserve, Ablösung, Lager (Essen, Schlafen, Wache) mit einfachen Regeln; Selbsttests für Hunger mit Reserve, Verpflegung, Ablösung, Lagerpunkte, Überfall.
- Texte: Lagerzeilen für Skalde und Saga (rund 20).

## 6. Aufwand (grob, im gleichen Maßstab wie `KAMPFSYSTEM.md`: ein Block ≈ eine Arbeitssitzung)

| Paket | Inhalt | Blöcke |
|---|---|---|
| R1 Reserve | `RESERVE`-Zustand, Kapazität, Verpflegung, Hafen mit drei Anwärtern, Entlassen, Aufstellungsansicht, Tests | 2 |
| R2 Erschöpfung | Neue Kraftzahlen, Müdigkeitsstufen mit Symbol, Ablösungsschalter, Tooltips, Simulation und Bots | 1 |
| R3 Lager | Ankerbucht auf der Karte, Lageransicht mit Aktionen und Punkten, Nachtereignisse, Texte, Bot, Tests | 2–3 |
| R4 Politur | Balance per Simulation, Review per Workflow, Konzept-Nachführung | 1 |
| **Summe** | | **6–7 Blöcke** (etwa 2 bis 3 Wochen bei 1–2 Blöcken am Tag) |

Reihenfolge-Vorschlag: **R2 → R1 → R3**, danach erst das Kampfsystem. R2 allein behebt schon das „nervige“ Gefühl (kleiner Eingriff, ohne Reserve nutzbar), R1 gibt dem Kampfsystem die Basis, R3 macht aus Rast ein Spielelement.

## 7. Risiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Mehr Männer, mehr Mikromanagement | Reserve nur über die Aufstellungsansicht, Automatik für Ablösung, Kartenleiste bleibt bei sieben. |
| Reserve ist immer maximal richtig | Verpflegung, Kaufpreis und Platzbedarf; Hunger trifft alle. |
| Lager bricht die Schwierigkeit (immer ausschlafen) | Ein Lager je Etappe, Proviant 2, Nachtereignisse, Bedingung „ruhige See“. |
| Zu viele neue Systeme gleichzeitig | R2 zuerst und einzeln prüfen; Lager erst, wenn R1/R2 sich bewährt haben. |
| Alte Spielstände | Migration beim Laden (keine Reserve, Ablösung aus). |

## 8. Vorschläge zur Entscheidung (mein Vorschlag in Klammern)

1. Reserve-Kapazität Start **2**, höchstens **5** (ja). Alternativ größer, dann aber Verpflegung stärker.
2. Verpflegung wächst mit der Mannschaft **(ja)** gegenüber „Heuer in Beute“ (zu viel Buchhaltung).
3. Trupp-Wechsel mit der Reserve **nur im Hafen und im Lager (ja)**. Alternativ jederzeit (macht die Reserve zum Gratis-Ersatz).
4. Lager nur an **Ankerbuchten und bei ruhiger See**, ein Lager je Etappe **(ja)**.
5. Wachablösung als **Standard an** mit Schalter (ja).
6. Reihenfolge **R2 → R1 → R3**, dann Kampfsystem (ja).
