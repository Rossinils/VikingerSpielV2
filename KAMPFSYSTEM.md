# Kampfsystem nach Darkest-Dungeon-Vorbild — Konzept und Aufwand

> **Stand: MVP gebaut (2026-11).** Eingebaut: Kampfkern (`scripts/combat.gd`), vier Rollen mit je drei bis vier Fertigkeiten (`scripts/roles.gd`: Schildträger, Axtmann, Bogenschütze, Skalde), Gegner und Aufstellungen (`scripts/foes.gd`: Draugr, Räuber, Wachen eines Handelsschiffs, Dorfbewohner), Aufstellungsansicht und Kampfansicht (`scripts/hud.gd`) mit **Pixelart-Figuren** (`tools/make_combat_art.py` → `assets/combat.png`: 4 Rollen und 13 Gegnerarten, je 5 Posen: Stehen A/B, Angriff, Treffer, An der Schwelle; 44×56 Pixel), einem Deck als Bühne, Ausfallschritt beim Angriff, Rückstoß mit rotem Blitz beim Treffer, schwebenden Zahlen (Schaden, Krit, Heilung, „verfehlt“) und Ausblenden der Gefallenen; die Anzeige liest dafür die Ereignisliste `Combat.events`, Einstellung „Kämpfe schnell auflösen“. Der Deckkampf läuft bei **Entern** in der Seeschlacht (Draugr, Räuber), bei **Handelsschiff überfallen** und bei **Dorf überfallen**. **Kraken als Boss gebaut:** Entern am Kraken in der Seeschlacht ist jetzt ein Deckkampf (Fangarme vorn, Körper als Riesenfigur `assets/kraken.png` 88×88 dahinter). Der Körper ist unerreichbar, solange ein Fangarm steht; gefällte Fangarme wachsen nach 4 Runden mit 60 % Kraft nach (höchstens so viele wie am Anfang); der **Würgegriff** eines Fangarms hält einen Mann fest (er setzt aus, der Fangarm presst ihn und zieht ihn im zweiten Zug über Bord: fällt oder betäubt man den Fangarm rechtzeitig, bleibt er an Bord; wer über Bord geht, lebt und wird nach dem Kampf mit dem Rettungsablauf gerettet, höchstens zwei je Kampf); die **Tintenwolke** senkt die Trefferchance aller Männer 2 Runden um 20 Punkte; **Zerquetschen** wird angekündigt (Körper „spannt sich“) und im nächsten Zug auf alle Männer ausgeführt, ein Betäubter kann es nicht. Der Körper hat so viel Kraft, wie der Rumpf des Kraken in der Seeschlacht noch hat (mindestens 45 %). **Wucht gebaut** (scripts/fight_fx.gd): Banner mit Namen der Fertigkeit, Hiebbögen (Hieb, Axt, Schildstoß, Biss), Pfeile und Peitschenhiebe im Flug, Heilleuchten, Lieder, Tinte, Schildblitz, Wackeln, Aufblitzen und kurzes Einfrieren bei Krit und Tod; die Reaktion des Ziels wartet, bis Hieb oder Pfeil ankommt (Kampftempo Voyage.COMBAT_PACE 0,9 s). **Nerven gebaut:** bei 100 Verzweiflung kippt ein Mann mitten im Kampf (einmal je Kampf): mit 30 % (+10 % mit einem anderen Skalden) **Heldenmut** (Kampfrausch: Zug extra und Schaden, Eiserner Wille: Kraft +30 und Schutz, Mitreißend: alle mehr Schaden und weniger Verzweiflung; heilt auch eine Marotte), sonst **Zusammenbruch** (verzagt: erstarrt und steckt an; Berserker: stärker, schlägt in 25 % der Züge einen Kameraden); wer schon gebrochen ist, erstarrt nur (Panik). Verzweiflung wächst jetzt auch durch schwere Treffer (+3), Krit (+10, andere +4), die Schwelle (+12, andere +4) und je Runde bei unter 35 Kraft (+2). Große Ansage, Aufblitzen und Heldenmut-Klang bzw. Zusammenbruch-Klang. **Schritt 3 gebaut (2026-11):** Jede Rolle hat jetzt **sechs Fertigkeiten, vier davon wählt man** in der Aufstellung (Klick auf die Symbole; die Wahl bleibt für alle weiteren Kämpfe, wird gespeichert und hat eine Standardwahl). Neue Rolle **Musketier** (langsam, Schaden 14–20): Musketenschuss, Streuschuss, Gezielter Schuss und Schreckschuss leeren die Muskete, **Nachladen** füllt sie, die **Pistole** braucht nichts. Der **Skalde hat keine Einsatzgrenzen** mehr (Heilsegen 18 Kraft, Trostlied, Kriegslied, neu Weckruf und Hohnlied); sein Zug ist der Preis. Neu bei den anderen: Schild (Deckung, Rundumschlag, Herausforderung), Axt (Wirbelhieb, Kopfspalter, Kampfwut), Bogen (Brandpfeil, Lähmschuss, Rückzugsschuss). **Gegnerrollen** mit Spielarten je Aufstellung: Heiler (Knochenpriester, Kräuterfrau), Beschützer (Grabwächter: Deckung), Beschwörer (ruft Skelette an die Front), Antreiber (Trommler: Kriegshorn), Rammer (schiebt Männer nach hinten); die Aufstellung zeigt ihre Aufgabe. **Bindungen** wirken im Kampf: ein Bruder, der seinen Bruder fallen sieht, kämpft 3 Runden zornig (Rache, +15 Verzweiflung), Gefährten trauern (+8). **Symbole** für jede Fertigkeit (`assets/skill_icons.png`, 48 Felder, `tools/make_skill_icons.py`) auf den Karten, im Banner und in der Wahl. **Dramatik:** Ansage zu Kampfbeginn (beim Kraken "DER KRAKEN"), Schlussansage mit Sieg, Niederlage und Rückzug (Kampf endet erst danach, nur im echten Spiel), große Ansage beim Tod eines Mannes, Kameraschub (Zoom) bei Krit und Tod, Zeitlupe beim letzten Gegner und bei Tod, Funken in der Farbe des Getroffenen, Lichtkegel unter dem aktiven Mann, Vignette. Musketen mit Mündungsfeuer, Pulverrauch und Kugelspur, eigene Klänge (Musketenschuss, Pistole, Nachladen, Knochen). **Hafen-Schmiede gebaut:** In der Werft (Reiter Schmiede) kauft man je Mann Waffe und Rüstung (Stufe 1–4) und Verbesserungen der Fertigkeiten (Kampfschule, Stufe 1–3); sie wirken im Kampf über `Roles.effective` und `Combat.eff_skill`, werden gespeichert und gehen mit dem Mann verloren. **Ausrüstung der Männer gebaut:** Waffe, Rüstung und Amulett mit Seltenheit (`scripts/gear.gd`), Vorrat, Rüstkammer im Hafen, Funde nach Kämpfen, Wirkung im Kampf über `Combat._make_hero` (Schaden, Schutz, Ausweichen, Tempo, Krit, Treffer, Regeneration) und über `CrewMember.stress_factor` (weniger Verzweiflung). Noch offen: Insel-Hinterhalt, Seeungeheuer, Schiffswache-Folgen, Kampferfahrung und Waffenschmied, ~~echte Pixelart und Animationen~~ (gebaut), Heldenmut. **Kampfgeräusche gebaut:** 18 neue Klänge (Schwerthieb, Axt, Schildstoß, Bogen und Pfeiltreffer, Biss, Heilung, Lied, Fall, Tentakel, Tinte, Kraken-Brüllen u. a.), je Fertigkeit zugeordnet in `Sfx.SKILL_SND`, ausgelöst von der Anzeige beim Lesen der Ereignisliste (Ausholen sofort, Treffer 0,2 s später, Mehrfachtreffer gestaffelt). Balance wird mit `tools/combatsim.gd` gemessen.
>
> **Abweichungen vom Entwurf:** Kraft als Lebenspunkte und „An der Schwelle“ wie geplant. Reihenfolge der Aufstellung wählt man mit ▲▼. Gegnerzüge laufen nach festen Gewichten, nicht nach Ansagen. Sonst gilt das Konzept unten.

Stand: Entwurf vor dem Einbau. Ziel: Kämpfe, in denen man **mehrere Züge lang denkt, aufstellt und verliert**, statt einmal zu würfeln.

## 1. Ausgangslage: was heute „gewürfelt“ wird

| Heute | Ablauf | Problem |
|---|---|---|
| Handelsschiff „Entern“, Dorf „Überfallen“, Ungeheuer „Kämpfen“ | Eine Aussicht in Prozent aus `Voyage.strength()`, ein Wurf, Sieg oder Niederlage | Eine Entscheidung, ein Ergebnis. Die Besatzung kämpft nicht, sie ist nur eine Zahl. |
| Seeschlacht (Draugr, Räuber, Kraken) | Bis zu 6 Runden, der Gegner kündigt seinen Zug an, man wählt eine von 7 Schiffstaktiken | Gut als Schiffskampf. Aber „Entern“ ist wieder ein Wurf (`board_chance`), der Gegner-Zug „Enterkommando“ verletzt zwei Zufallsmänner. |
| Wer fällt, wer verletzt wird | `_random_aboard()` | Die Männer, die man aufgebaut hat, spielen im Kampf keine Rolle. |

Schon vorhanden und weiterverwendbar: Kraft und Verzweiflung je Mann, Marotten (verzagt, Berserker), Eigenschaften (Heißsporn `fight`), Bindungen (Brüder, Rivalen, Gefährten), Tod ist endgültig, Gedenkstein, Saga, Tooltips (`scripts/tips.gd`), sieben Decksplätze, Mann über Bord samt Rettung.

## 2. Leitidee

**Zwei Ebenen, zwei Entscheidungen.**

1. **Schiffskampf** bleibt, wie er ist: Rammen, Kanonen, Pfeilhagel, Flicken, Fliehen. Er entscheidet, *ob und wie* es zum Entern kommt (Rumpfzustand, Gegnerbesatzung geschwächt, Schaden vorab).
2. **Deckkampf (neu)**: Wer entert, überfallen wird oder an Land in einen Hinterhalt gerät, kämpft ein **rundenbasiertes Gefecht mit vier Männern gegen bis zu vier Gegner**, wie ein Kampf in Darkest Dungeon: Reihen, Tempo, Fertigkeiten mit Reichweite, Zustände, Stress, „An der Schwelle“.

Der Reiz für dieses Spiel: Von sieben Männern kämpfen nur vier, die anderen halten das Schiff. Die Auswahl **ist** die Entscheidung (siehe 4.1).

## 3. Leitplanken

- **Rundenbasiert, keine Echtzeit, keine Quicktime-Events.** Kein Balken, der läuft. Man darf beliebig lange überlegen.
- **Sichtbar statt versteckt.** Treffer-, Schadens- und Krit-Chancen stehen vor der Wahl da (Tooltip auf der Fertigkeit, Chance beim Zielen). Der Zufall bleibt (wie bei DD), aber er entscheidet einen *Zug*, nie den ganzen Kampf.
- **Der Gegner kündigt an.** Behalten wir aus der Seeschlacht: Das Zeichen („Der Kraken hebt einen Arm“) zeigt, was kommt, sobald man es sehen kann.
- **Kurz und schwer.** Ein Deckkampf dauert 2 bis 4 Minuten, 4 bis 8 Runden. Es gibt pro Etappe eher weniger Kämpfe, jeder wiegt mehr.
- **Verluste tun weh.** Tod ist endgültig, Stress bleibt über den Kampf hinaus, Verletzte fehlen an den Stationen.
- **Kein zweites Spiel im Spiel.** Wenige Rollen, wenige Fertigkeiten, klare Regeln. Alle Zahlen an einer Stelle (wie `Strategy.build`).

## 4. Ablauf eines Deckkampfes

```
Begegnung/Taktik "Entern" -> Aufstellung -> Kampfrunden -> Ausgang -> Folgen
```

### 4.1 Aufstellung (vor dem ersten Zug)

- Anzeige: die sieben Männer mit Rolle, Kraft, Verzweiflung, Eigenschaften.
- Man wählt **vier Kämpfer** und ihre **Reihenfolge (Reihe 1 vorn bis Reihe 4 hinten)**. Die übrigen drei sind **Schiffswache** und behalten ihre Station.
- Folgen der Wache: Fehlt der Zimmermann, flickt niemand während des Kampfes. Fehlt das Ruder, kann man nicht mehr fliehen. Fehlt der Steuermann, treibt das Schiff in der nächsten Welle ab (Stress). Vorschau im Tooltip.
- Bei einem **Hinterhalt** (Insel, Dorf) wählt man nur Reihenfolge und Wache nach einer Zufallsregel: der Gegner greift an, bevor man sich sortiert (erste Runde Nachteil).
- Zwischen den Runden darf man **vorrücken, zurückfallen, tauschen** (kostet einen Zug).

### 4.2 Kampfrunde

1. **Tempo** jedes Beteiligten (Grundwert der Rolle, +/- Eigenschaft, +/- Zustand) plus ein kleiner Wurf: daraus die **Zugreihenfolge der Runde**, sichtbar als Leiste am oberen Rand (wie bei DD).
2. Wer dran ist, wählt **eine Fertigkeit und ein Ziel**, oder bewegt sich, oder übergibt. Die Chancen stehen beim Zielen.
3. Gegner handeln nach ihren Regeln (siehe 6). Ihr **nächster** Zug wird für Elite und Boss angekündigt, für Gewöhnliche nur als Zielrichtung (Pfeil auf einen Mann).
4. Zustände (Blutung, Gift, Betäubung …) wirken am Rundenende oder Zugbeginn.
5. Siegbedingung: alle Gegner tot oder verscheucht. Niederlage: alle Kämpfer tot, bewusstlos oder geflohen. **Rückzug**: nur mit Ruderern in der Schiffswache und nicht, wenn das Schiff eingehakt ist (Enterhaken).

### 4.3 Kernregeln (alles in `scripts/combat.gd`)

| Regel | Umsetzung |
|---|---|
| **Reihen** | Vier Plätze je Seite. Jede Fertigkeit nennt, von welchen Reihen sie genutzt werden darf und welche Reihen sie trifft (wie DD). Tote Plätze rücken auf. |
| **Trefferchance** | `Grundgenauigkeit der Fertigkeit + Genauigkeit des Angreifers − Ausweichen des Ziels`. Auf 5 bis 95 % begrenzt. |
| **Schaden** | Spanne der Fertigkeit × Schadensfaktor des Angreifers, minus **Schutz** (Prozent) des Ziels. |
| **Kritischer Treffer** | Eigene Chance je Fertigkeit; ×1,5 Schaden. Kritische Treffer auf Männer erzeugen Stress bei allen (wie DD). |
| **Kraft als Lebenspunkte** | Die vorhandene Kraft (0–100) ist im Kampf zugleich die Verletzbarkeit. Treffer senken sie. Wer müde in den Kampf geht, geht angeschlagen hinein, und müde Männer (<40) kämpfen schlechter (Genauigkeit −10 %, Schaden −20 %). So hängt der Kampf an der Fahrtplanung davor. |
| **An der Schwelle** | Bei 0 Kraft ist ein Mann nicht tot, sondern „an der Schwelle“: jeder weitere Treffer tötet mit 50 %, er kämpft mit halber Kraft weiter. Wer überlebt, geht mit 10 Kraft aus dem Kampf. Wie „Death’s Door“. |
| **Zustände** | Blutung (Schaden je Runde, hält 3), Gift (stärker, nur mit Gegenmittel), Betäubung (setzt eine Runde aus, Schutz gegen Folgebetäubung), Schwächung (−Schaden), Markierung (+Schaden gegen das Ziel), Brennen, Deckung (Schutz+). Dauer und Widerstand je Figur wie bei DD. |
| **Stress (Verzweiflung)** | Wird zum Kampfwert: Gegner-Fertigkeiten erzeugen Verzweiflung (Schrecken, Spott), kritische Treffer, Verluste. **Bei 100 prüft der Mann seine Nerven (Bindung und Eigenschaft zählen):** meist verzagt oder Berserker (wie heute), in einem Viertel der Fälle **Heldenmut** (neue positive Marotte: ein Kampf lang Bonus, Verzweiflung der Nachbarn sinkt). Verzagte verweigern manchmal den Zug, Berserker greifen ein Zufallsziel an: beides sichtbar vor dem Zug (Ansage). |
| **Bindungen** | Brüder nebeneinander: +Genauigkeit, beim Tod des anderen Stress (heute +30). Rivalen nebeneinander: manchmal „Gerangel“ statt Zug. Gefährten: decken sich (Schutz+ bei Angriff auf den anderen). |
| **Siegesrausch** | Jeder getötete Gegner senkt die Verzweiflung der Kämpfer um 5 (Boss 15). Verlust eines Mannes erhöht sie bei allen. |

## 5. Rollen und Fertigkeiten

Jeder Mann bekommt beim Anheuern/Start eine **Rolle** (ersetzt nicht seine Station und Eigenschaften, sie kommen dazu). Sechs Rollen, je **4 Fertigkeiten** im Kampf (die ersten beiden gleich, die zwei weiteren per Kampferfahrung freischaltbar, siehe 7):

| Rolle | Reihen | Aufgabe | Beispielfertigkeiten |
|---|---|---|---|
| **Schildträger** | 1–2 | Vorn halten, Treffer ziehen | Schildwall (Schutz+ bis nächste Runde), Schildstoß (Betäubung), Beschützen (nimmt Schaden für den Nachbarn), Ausfall (vorrücken und zuschlagen) |
| **Axtmann** | 1–2 | Schaden und Blutung | Hieb, Spaltschlag (Blutung), Ansturm (Reihe 1 tauschen und zuschlagen), Wutschrei (Schaden+, Schutz−) |
| **Speerwerfer** | 2–3 | Reichweite, trifft Reihe 1–2 | Stoß, Durchbohren (trifft zwei Reihen), Zurückdrängen (schiebt Ziel nach hinten), Wurfspeer (Reihe 4) |
| **Bogenschütze** | 3–4 | Fernschaden auf jede Reihe | Schuss, Markieren, Pfeilregen (trifft alle schwach), Gezielter Schuss (Krit, Betäubung) |
| **Skalde** | 3–4 | Mut und Heilung | Kriegslied (Schaden+, Verzweiflung−), Spottlied (Gegner schwächen, ihre Verzweiflung nutzen), Heilsegen (Kraft+), Trostlied (Verzweiflung− für einen) |
| **Enterer** | 1–3 | Beweglichkeit, Kontrolle | Enterhaken (zieht ein Ziel nach vorn, verhindert Rückzug), Messerwurf (Blutung), Tauschschritt (tauscht zwei Plätze), Feuertopf (Brennen, Fläche) |

- **Passive aus Eigenschaften:** *Heißsporn*: Schaden+, Stress anfälliger. *Zäh*: mehr Schwelle. *Gelassen*: weniger Stress. *Starker Arm*: Schaden+ bei Axt und Schild. *Sterngucker*: Genauigkeit bei Fernkampf. So behalten die vorhandenen Eigenschaften Gewicht.
- **Station und Rolle widersprechen sich nicht:** Ein Schildträger kann Ruderer sein, aber im Kampf steht er in Reihe 1. Wer kämpft, fehlt an der Station: der Preis.
- **Anheuern im Hafen:** man sieht Rolle und Eigenschaften der Anwärter (heute nur Eigenschaften). Das macht Anheuern zu einer echten Entscheidung für die Aufstellung.

## 6. Gegner

Jeder Gegner hat: Kraft, Ausweichen, Schutz, Tempo, Reihe(n), 2–4 Fertigkeiten mit **Auswahlregeln** (Reihe, Ziel, Anzahl der Wiederholungen, wie bei DD-Monstern), Widerstände (Blutung, Gift, Betäubung, Verschieben), Stressangriffe. **Formationen** werden aus der Etappe und dem Thema gewürfelt (Piratengewässer → viel Räuber; Totensee → Draugr und Kraken).

| Begegnung | Formation (Beispiel Etappe 1) | Besonderheit |
|---|---|---|
| **Draugr-Schiff** | Rost-Draugr (Reihe 1), Draugr-Bogner (2), Ertrunkener (1), Totenwart (4, ruft Draugr nach) | Immun gegen Blutung, schwach gegen Feuer; **Totenklage**: Stressangriff auf alle |
| **Räuberschiff** | Messerkerl (1), Brecher (1), Hakenwerfer (2, zieht einen Mann nach vorn), Schütze (3) | Rückzug schwerer (Haken). Sie **fliehen**, wenn der Anführer fällt (Moral). |
| **Kraken** (Boss) | **Körper** (Reihe 4, nur durch Schaden an den Tentakeln verwundbar), 2–4 **Tentakel** (Reihen 1–3) | Tentakel wachsen nach (alle 3 Runden); **Greifen** zieht einen Mann *über Bord* (Rettung nach dem Kampf, wie heute); Tintenwolke senkt Genauigkeit; Zerquetschen als Ansage. |
| **Handelsschiff** (Entern) | Schiffswachen (2–3, davon ein Schildmann in Reihe 1), Schütze oder Armbrustträger (3), Kaufmann (4, feige: flieht, wenn allein) | **Ein überfallenes Handelsschiff wird immer bekämpft**, kein Würfelwurf mehr: Entern öffnet die Aufstellung und den Deckkampf. Sieg: viel Beute, aber der Kaufmann kann Beute über Bord werfen, wenn er fällt. Wer nicht kämpfen will, handelt oder zieht vorbei. |
| **Küstendorf** (Überfallen) | Bauern mit Heugabel (1–2), Schmied (3), Dorfhunde | Wenig Stress, viel Beute, Gerechtigkeit: Töten gibt eine Skaldenzeile |
| **Insel-Hinterhalt** | Wilde (zufällig) | Erste Runde Überraschung |
| **Seeungeheuer** | Schlangenhals (1), Rücken (2), Biss (3 bei niedrigem Seegang) | Seegang wirkt mit (siehe 8) |

- Boss-Mechaniken (Kraken) und Elite bekommen **Ansagen**: Beim Kraken steht eine Zeile am Kopf („hebt einen Arm“), eine Wahl (Tentakel kappen oder decken) entscheidet über den Schaden.
- Moral: Gegner fliehen, wenn mehr als die Hälfte gefallen ist, wie in DD-Banditen. Flüchtende Gegner geben weniger Beute.
- **Überfälle sind immer Kämpfe.** Das gilt für Handelsschiffe (Entern), Küstendörfer (Überfallen) und den Hinterhalt auf der Insel. Die Wahl zwischen Überfall und friedlichem Weg bleibt (Handeln, Handwerker, Vorbeiziehen); sobald man angreift, kämpft man. „Heimlich plündern“ im Dorf bleibt eine leise Option mit Chance auf Alarm: Schlägt sie fehl, beginnt der Kampf mit Überraschung gegen den Spieler (erste Runde Nachteil).
- Die Handelsschiff-Wachen wachsen mit der Etappe wie die anderen Gegner (+Kraft, +Schaden, mehr Wachen ab Etappe 3). Die Beute bleibt an die Sieger gebunden: fällt der Kaufmann zuletzt, bleibt die Truhe heil; flieht er, geht ein Teil verloren.

## 7. Fortschritt

- **Kampferfahrung je Mann (Rang 1–3):** Sieg und Kills geben Punkte. Rang 2 schaltet die dritte, Rang 3 die vierte Fertigkeit frei; je Rang mehr Kraft (Schwelle) und etwas Schutz. Verluste sind damit teurer: ein Veteran ist nicht ersetzbar durch einen Anwärter.
- **Waffenschmied im Hafen (Werft):** Waffe und Rüstung eines Mannes um eine Stufe verbessern, gegen Beute (3 Stufen, Preise wachsen wie die Werftpreise). Ersetzt keine Schiffsgegenstände, sondern ergänzt sie.
- **Nicht im ersten Wurf:** Anhänger (Amulette), Waffenwahl pro Rolle, Verbündete an Land.
- **Vermächtnis:** Der Gedenkstein erinnert an Veteranen (Name, Rolle, Rang). Ein Teil der Vermächtnis-Veteranen steigt als Rang-2-Männer ein.

## 8. Bezug zum Schiff und zum Meer

- **Seegang wirkt im Kampf:** Ab Seegang 4 gibt es Wellenschläge: einmal pro Runde mit Wahrscheinlichkeit wirft eine Welle einen Mann der Reihe 1 um (Betäubung) oder über Bord. **Brecher/Böen** auf der Karte zählen als Seegang +1 für diesen Kampf. Ruhige See: Fernkampf +Genauigkeit.
- **Rumpf zählt weiter:** Gegner-Kanonen und Rammen aus der Schiffsphase treffen den Rumpf. Im Deckkampf gibt es Angriffe auf das Schiff (Feuer legen, Leck schlagen), die nur die Schiffswache (Zimmermann) abfangen kann. So bleibt das „Schiff“ im Spiel.
- **Mann über Bord** (Kraken, Welle, Stoß): bleibt als Spielzustand, gerettet wird *nach* dem Kampf mit dem bestehenden Rettungsablauf (Seil werfen, zurücklassen).
- **Proviant** bleibt die Uhr: Lange Kämpfe kosten nichts, aber Verletzte brauchen Rast (Proviant) — beides existiert schon.

## 9. Ausgang und Folgen

- **Beute:** wie heute mit den neuen Meldungen („Beute +95 aus: …“), plus **Beuteverteilung**: nach dem Kampf zeigt eine Zeile die Beute pro Gegnertyp. Fliehende Gegner geben weniger, Eliten mehr, Boss eine Truhe (Gegenstand möglich).
- **Verletzte:** bleiben mit niedriger Kraft, müssen auf die Ladung (Ruheplatz) oder in den Hafen. **Schwerverletzte** bleiben „angeschlagen“ bis zur nächsten Rast (−Kampfwerte).
- **Tote:** Gedenkstein mit Todesursache („gefallen: Räuberschiff, Reihe 1“), Saga schreibt den Kampf aus den Ereignissen (wer fiel, wer den Kraken fällte, wer Heldenmut hatte).
- **Stress:** Mut-Ereignisse gehen in die Saga und in die Marotten.
- **Erfahrung:** wie bisher fürs Schiff (30 + 4 je Etappe) und neu je Mann.

## 10. Oberfläche (480×320, Text wie bisher in Bildschirmauflösung)

```
+-----------------------------------------------------------+
| Kopfzeile wie bisher        Zugleiste: [A][B][a][b][C] ...|
|                                                           |
|  [Reihe 4 3 2 1]  Kämpfer links       Gegner rechts [1 2 3 4]
|   Sprites groß (32×48), Kraft-/Stressbalken über dem Kopf |
|   Ansage-Pfeile vom Gegner auf sein Ziel                  |
|  Erzähltext (zwei Zeilen)                                  |
+-----------------------------------------------------------+
| Fertigkeiten des aktiven Mannes (4 Karten) | Bewegen | Rückzug
| Mannschaftsleiste (alle sieben, Kämpfer markiert)          |
+-----------------------------------------------------------+
```

- Die Fertigkeitskarten bekommen **Tooltips** (Reichweite, Chance, Schaden, Zustände), alles über das vorhandene Tooltip-System.
- **Ziel auswählen:** Maus über Gegner zeigt Trefferchance, Schadensspanne, Krit; Klick führt aus. Tastatur 1–4 für Fertigkeiten, Tab für Ziele.
- **Animation:** kurze Schritt-/Treffer-Animationen (Rückstoß, Blitz, Zahl), nichts Schnelles; wer es sparen will, kann sie abschalten (Einstellungen). Kein Bildschirmwackeln im Takt.
- **Aufstellungsbild** (4.1) ist eine eigene Ansicht, ähnlich der Mannschaftsansicht (Taste C).

## 11. Technische Umsetzung

Neue Dateien (alles Logik ohne Bild, damit **headless testbar**):

| Datei | Inhalt |
|---|---|
| `scripts/combat.gd` | Zustand und Rundenablauf: Reihen, Tempo, Zugliste, Treffer, Schaden, Zustände, Stress, Schwelle, Moral. Reine Logik, keine Anzeige. |
| `scripts/roles.gd` | Rollen, Fertigkeiten, Reihenregeln, Rangstufen, Daten wie `strategy.gd`/`items.gd`. |
| `scripts/foes.gd` | Gegnerdaten, Formationen, Auswahlregeln (Gegner-KI als Tabelle, keine Magie), Bosse. |
| `scripts/combat_view.gd` | Kampfansicht (Zeichnung, Zielwahl, Zugleiste) als Teil von `Hud` oder eigener Ebene. |
| `tools/make_combat_art.py` → `assets/combat.png` | Kampfsprites: 6 Rollen × (Stehen, Angriff, Treffer, Schwelle, Tot) und 8 Gegner × 3 Posen. |

Änderungen:

- `crew_member.gd`: `role`, `rank`, `xp`, Waffe/Rüstung, Zustände. Speicher (`to_dict/resume`) erweitern; alte Spielstände ohne Rolle laden mit zufälliger Rolle.
- `battle.gd`: „Entern“ und Gegner-„Enterkommando“ starten den Deckkampf (`Combat.start(voy, foe_formation, party)`), Seeschlacht bleibt sonst. Kampfzustand wird nicht gespeichert (gespeichert wird nur in der Planung, wie heute).
- `encounters.gd`: die „fight“-Optionen (Handeln: Entern, Überfallen, Kämpfen, Insel-Hinterhalt) rufen den Deckkampf mit der passenden Formation statt eines Wurfs. `chance()` bleibt als Orientierung („Aussicht“ für die Anzeige der Aufstellung).
- `hud.gd`/`tips.gd`: Ansicht, Karten, Tooltips; `main.gd`: Eingaben, Test-Flags (`--forcefight=N`, `--shotfight`).
- `traits.gd`: Kampfwerte je Eigenschaft ergänzen (die meisten sind nur Zahlen).
- `saga.gd`/`skalde.gd`: Zeilen je Rolle und Ereignis (Heldenmut, Schwelle, Kraken-Kappen). Textmenge ist der unterschätzte Posten.
- Bot (`main.gd`: `_bot_battle`) und Selbsttest (`tools/selftest.gd`): Bot wählt Aufstellung und Fertigkeiten nach einfachen Regeln (Schadensmaximum, Heilen bei Schwelle), Tests prüfen Regeln (Reihen, Schutz, Betäubung, Moral, Tod).

Kein Echtzeitanteil, kein neuer Speicherzustand im Kampf, keine neue Abhängigkeit (reines GDScript, Pixelart per Python).

## 12. Balance und Tests

- **Zahlenebene:** alle Werte in Tabellen (`roles.gd`, `foes.gd`), eine Spalte „Etappenfaktor“. Headless-Simulation: 500 Kämpfe pro Formation mit Bot und Zufallsbot, Ausgabe: Siegquote, mittlere Verluste, mittlere Rundenzahl (Ziel: Etappe 1: 85 % Sieg, 0–1 Tote; Etappe 3: 60 %, 1–2 Tote; Boss: 40 %).
- **Mensch-Test bleibt nötig:** Spielgefühl, Länge, Verständlichkeit der Ansagen. Ich kann das Gefühl nicht messen.
- **Rückfallebene:** Schalter „Kämpfe schnell auflösen“ (Einstellungen) rechnet den Deckkampf ohne Ansicht per Bot durch (für Leute, die nur die Schiffsentscheidungen wollen). Verhindert Frust bei vielen Kämpfen.

## 13. Aufwand (grob)

Maßstab: **ein Arbeitsblock** = eine zusammenhängende Arbeitssitzung von mir mit Umsetzung, Tests und Screenshots (etwa 2–4 Stunden Laufzeit, bei großem Umfang wegen des Nutzungslimits mit Pausen). Die Schätzungen enthalten Fehlerbehebung, aber keine lange Balance-Feinarbeit mit echten Läufen von dir.

| Paket | Inhalt | Größe |
|---|---|---|
| A. Kern | `combat.gd` mit Regeln, Zuständen, Stress, Schwelle; Selbsttests | 1 Block |
| B. Rollen und Fertigkeiten | `roles.gd`, Zuordnung zur Besatzung, Anheuern mit Rolle, Speicherformat, Tooltips | 1 Block |
| C. Gegner und KI | `foes.gd`, 5 Formationen, Moral, Bot für die Tests | 1–2 Blöcke |
| D. Kampfansicht | Aufstellung, Zugleiste, Karten, Zielwahl, Tooltips, Texte | 2 Blöcke |
| E. Pixelart | 6 Rollen und 8 Gegner mit Posen, Kulisse, Zahlen/Effekte | 1–2 Blöcke |
| F. Einbau | Entern, Überfallen, Hinterhalt, Kraken-Boss, Beuteablauf, Gedenkstein, Saga, Skalde | 1–2 Blöcke |
| G. Fortschritt | Kampferfahrung, Waffenschmied, Vermächtnis | 1 Block |
| H. Balance und Politur | Simulation, Zahlenfeinschliff, Review per Workflow, Konzepttext | 1 Block |

| Ausbaustufe | Enthalten | Blöcke | Etwa |
|---|---|---|---|
| **MVP (spielbar)** | A, B (4 Rollen), C (3 Formationen), D, F (nur Entern auf Schiffen), einfache Sprites | **6–8** | 2–3 Wochen bei 1–2 Blöcken pro Tag |
| **Voll (wie dieses Konzept)** | alle Pakete | **11–15** | 4–6 Wochen |
| **Erweitert** | + Anhänger, Waffenwahl, Verbündete, mehrere Bosse | +4–6 | +1–2 Wochen |

Die größten Posten sind **D (Ansicht)** und **E (Pixelart)**, weil sie am schwersten zu automatisieren zu prüfen sind (jede Änderung braucht Bilder und Augenmaß). Die Logik (A–C) ist am besten testbar und am zuverlässigsten zu schätzen.

## 14. Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| **Zu viel Spiel im Spiel.** Der Nutzer wollte „wenige schwere Entscheidungen“ und fand die Oberfläche zu überladen. | Sechs Rollen, vier Fertigkeiten, vier Kämpfer, 4–8 Runden. Vorab alles in Tooltips erklärt. Option „schnell auflösen“. |
| **Kämpfe zu häufig oder zu lang.** | Gewichte für Kampfbegegnungen senken, ein Deckkampf pro Etappe ist die Regel. Rundenlimit (8) mit Moralabzug. |
| **Balance von Zufall.** DD lebt von Zufall und lässt Spieler fluchen. Hier ist der Fahrtverlauf drumherum schon schwer. | Chancen sichtbar, Zufallswurf nur je Zug, Krit-Stress abgemildert, Beute-Ausgleich. Tests per Simulation. |
| **Speicherstände.** Rolle und Rang kommen neu dazu. | Migration beim Laden (Rolle zufällig), `to_dict/resume` testen. |
| **Bildmenge.** Viele Sprites in 480×320 sehen schnell uneinheitlich aus. | Einheitlicher Generator mit gemeinsamer Palette wie `make_art.py`; Kritiker-Durchgang (Workflow) für die Bildqualität. |
| **Konflikt mit der Seeschlacht.** Zwei Systeme könnten sich doppeln. | Klare Trennung: Schiffsebene = Rumpf, Kanonen, Rammen, Fliehen. Deckebene = Männer. Entern ist die Brücke. |

## 15. Entscheidungen, die ich dir vorschlage (mit meinem Vorschlag)

1. **Kraft als Lebenspunkte** (statt neuer Stat): ja. Dadurch wirken Fahrtplanung und Kampf aufeinander. Alternative: eigene Lebenspunkte, dann zwei Balken und mehr Regeln.
2. **Vier Kämpfer von sieben, Rest als Schiffswache:** ja. Das ist die zentrale neue Entscheidung des Spiels.
3. **Seeschlacht bleibt als Schiffsphase** und wird nicht ersetzt: ja.
4. **Rollen statt Klassenbaum:** sechs feste Rollen mit Rang 1–3, kein freier Skillbaum.
5. **Heldenmut als neue positive Marotte:** ja, klein, damit Stress nicht nur Strafe ist (wie DD „Tugend“).
6. **Pixelart in 32×48 für Kämpfer:** ja, getrennt vom kleinen Decks-Sprite (14×16), sonst wären Posen unlesbar.
7. **Umfang:** erst MVP, dann nach deinem Test entscheiden, ob Rang/Schmied/Ausbau kommen.

## 16. Vorschlag für die Reihenfolge

1. Paket A und B im Hintergrund (nur Logik, Tests, noch keine Ansicht).
2. Eine **minimale Ansicht** mit Platzhaltern (Rechtecke), damit du die Regeln spielen und beurteilen kannst, bevor die Pixelart entsteht.
3. Erst nach deinem Urteil: Pixelart, Gegner, Boss, Fortschritt.

So steckt kein Bildaufwand in Regeln, die nicht gefallen.
