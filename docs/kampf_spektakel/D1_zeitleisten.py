# D1: Zeitleisten der Regie. Prüft die Summen der Tabellen aus D1_regie.md und zeichnet img/D1_zeitleisten.svg.
# Aufruf: python -X utf8 -I D1_zeitleisten.py   (nur Standardbibliothek)
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COL = {"in": "#6b7a99", "prep": "#4f86c6", "strike": "#d9b24a", "freeze": "#f2f2f2", "slow": "#9a6ad0",
       "after": "#5b8f64", "text": "#c8453d", "pause": "#8a8a8a"}


def slow_extra(slows):
    # Zeitlupe: Bühnen-ms (b - a) laufen mit Faktor f, also (b - a) / f Echtzeit-ms
    return sum((b - a) * (1.0 / f - 1.0) for a, b, f in slows)


# Fall: Bühnen-ms, Standbilder und Pausen (Echtzeit-ms), Zeitlupenfenster (von, bis, Faktor) in Bühnen-ms,
# Abschnitte (Beschriftung, Art, von, bis) in Echtzeit-ms, erwartete Echtzeit-Dauer
C = {}


def case(name, stage, freezes, slows, segs, expect):
    C[name] = dict(stage=stage, freezes=freezes, slows=slows, segs=segs, expect=expect)


case("Held Nahkampf", 820, [80], [], [("Ausholen", "prep", 0, 200), ("Schlag", "strike", 200, 250), ("Standbild", "freeze", 250, 330), ("Nachschwung, Halten, Rückkehr", "after", 330, 900)], 900)
case("Held Bogen", 820, [80], [], [("Spannen", "prep", 0, 200), ("Pfeilflug", "strike", 200, 340), ("Standbild", "freeze", 340, 420), ("Nachwirkung", "after", 420, 900)], 900)
case("Held Muskete", 820, [80], [], [("Anlegen", "prep", 0, 180), ("Schuss, Flug", "strike", 180, 280), ("Standbild", "freeze", 280, 360), ("Nachwirkung", "after", 360, 900)], 900)
case("Hilfe, ein Ziel", 800, [], [], [("Aufruf", "prep", 0, 200), ("Wirkung", "strike", 200, 300), ("Nachwirkung", "after", 300, 800)], 800)
case("Hilfe, nur selbst", 700, [], [], [("Aufruf", "prep", 0, 150), ("Wirkung", "strike", 150, 250), ("Nachwirkung", "after", 250, 700)], 700)
case("Hilfe, alle", 900, [], [], [("Aufruf", "prep", 0, 200), ("Wirkung, Ringe", "strike", 200, 300), ("Nachwirkung", "after", 300, 900)], 900)
case("Fehlschlag", 700, [], [], [("Ausholen", "prep", 0, 200), ("Schlag ins Leere", "strike", 200, 250), ("Ausweichen, Stolpern", "after", 250, 700)], 700)
case("Held Krit", 1000, [150], [(290, 390, 0.5)], [("Ausholen", "prep", 0, 240), ("Schlag", "strike", 240, 290), ("Standbild", "freeze", 290, 440), ("Zeitlupe 0,5", "slow", 440, 640), ("Nachwirkung", "after", 640, 1250)], 1250)
case("Fläche, zwei Ziele", 840, [60], [], [("Ausholen", "prep", 0, 200), ("Schlag", "strike", 200, 250), ("Standbild", "freeze", 250, 310), ("Treffer 2", "strike", 310, 440), ("Nachwirkung", "after", 440, 900)], 900)
case("Fläche, vier Ziele", 1090, [60], [], [("Ausholen", "prep", 0, 200), ("Schlag", "strike", 200, 250), ("Standbild", "freeze", 250, 310), ("Treffer 2 bis 4", "strike", 310, 700), ("Nachwirkung", "after", 700, 1150)], 1150)
case("Gegner Nahkampf", 840, [60], [], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 420), ("Schlag", "strike", 420, 470), ("Standbild", "freeze", 470, 530), ("Opfer, Nachwirkung", "after", 530, 900)], 900)
case("Gegner Fernkampf", 840, [60], [], [("Ankündigung", "in", 0, 200), ("Spannen", "prep", 200, 470), ("Schuss, Flug", "strike", 470, 520), ("Standbild", "freeze", 520, 580), ("Opfer, Nachwirkung", "after", 580, 900)], 900)
case("Gegner Krit", 1000, [150], [(510, 610, 0.5)], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 460), ("Schlag", "strike", 460, 510), ("Standbild", "freeze", 510, 660), ("Zeitlupe 0,5", "slow", 660, 860), ("Nachwirkung", "after", 860, 1250)], 1250)
case("Gegner fällt (klein)", 850, [100], [], [("Ausholen", "prep", 0, 200), ("Schlag", "strike", 200, 250), ("Standbild", "freeze", 250, 350), ("Fallen, Nachrücken", "after", 350, 950)], 950)
case("Gegner fällt (groß)", 800, [100], [(250, 350, 0.5)], [("Ausholen", "prep", 0, 200), ("Schlag", "strike", 200, 250), ("Standbild", "freeze", 250, 350), ("Zeitlupe 0,5", "slow", 350, 550), ("Fallen, Nachrücken", "after", 550, 1000)], 1000)
case("Mann fällt", 958, [160], [(320, 470, 0.35), (470, 600, 0.3)], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 320), ("Zeitlupe 0,35", "slow", 320, 749), ("Standbild", "freeze", 749, 909), ("Zeitlupe 0,3", "slow", 909, 1342), ("Lösen", "after", 1342, 1700), ("GEFALLEN", "text", 900, 1700)], 1700)
case("Mann fällt an der Schwelle", 958, [160, 300], [(470, 600, 0.3)], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 420), ("Schlag", "strike", 420, 470), ("Standbild", "freeze", 470, 630), ("Prüfung, Herzschlag", "pause", 630, 930), ("Zeitlupe 0,3", "slow", 930, 1363), ("Lösen", "after", 1363, 1721), ("GEFALLEN", "text", 950, 1721)], 1721)
case("Letzter Gegner fällt", 814, [160], [(130, 250, 0.35), (250, 380, 0.3)], [("Ausholen", "prep", 0, 130), ("Zeitlupe 0,35", "slow", 130, 473), ("Standbild", "freeze", 473, 633), ("Zeitlupe 0,3", "slow", 633, 1066), ("Lösen", "after", 1066, 1500), ("SIEG beginnt", "text", 1100, 1500)], 1500)
case("Mann an der Schwelle", 840, [120, 180], [], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 420), ("Schlag", "strike", 420, 470), ("Standbild", "freeze", 470, 590), ("Herzschläge", "pause", 590, 770), ("Nachwirkung", "after", 770, 1140)], 1140)
case("Schwelle hält stand", 840, [160, 300], [], [("Ankündigung", "in", 0, 200), ("Ausholen", "prep", 200, 420), ("Schlag", "strike", 420, 470), ("Standbild", "freeze", 470, 630), ("Prüfung", "pause", 630, 930), ("WIDERSTAND, Nachwirkung", "after", 930, 1300)], 1300)
case("Heldenmut, Zusammenbruch", 1800, [], [], [("Wird geprüft", "in", 0, 400), ("Spannungspause", "pause", 400, 850), ("Ansage", "text", 850, 1800)], 1800)
case("Blutung", 350, [], [], [("Rotblitz, Zahl", "after", 0, 350)], 350)
case("Zug ausgesetzt", 600, [], [], [("Sterne, Hinweis", "after", 0, 600)], 600)
case("Abwarten", 250, [], [], [("Licht wandert", "after", 0, 250)], 250)
case("Platztausch", 360, [], [], [("Tausch im Bogen", "after", 0, 360)], 360)
case("Gegner flieht", 600, [], [], [("Umdrehen, Lauf", "after", 0, 600)], 600)
case("Beschwörung", 1100, [], [], [("Ankündigung", "in", 0, 200), ("Beschwören", "prep", 200, 700), ("Aufstieg des Neuen", "strike", 700, 1100)], 1100)
case("Kraken spannt sich", 1100, [], [], [("Dröhnen, Spannen", "prep", 0, 700), ("Warnung hält", "after", 700, 1100)], 1100)
case("Kraken zerquetscht", 1780, [120], [], [("Ausholen, Schatten", "prep", 0, 500), ("Aufschlag", "freeze", 500, 620), ("Nachwirkung", "after", 620, 1900)], 1900)
case("Würgegriff", 1100, [], [], [("Ankündigung", "in", 0, 200), ("Peitsche", "prep", 200, 500), ("Gepackt", "after", 500, 1100)], 1100)
case("Über Bord", 1400, [], [], [("Ankündigung", "in", 0, 200), ("Fangarm hebt", "prep", 200, 500), ("Flug über die Reling", "strike", 500, 900), ("Platschen", "after", 900, 1400)], 1400)
case("Kampfbeginn", 1300, [], [], [("Einblenden", "in", 0, 350), ("Musterung der Gegner", "prep", 350, 950), ("KAMPF", "text", 150, 1100), ("Licht zum ersten Mann", "after", 950, 1300)], 1300)
case("Kraken-Auftritt", 2600, [], [], [("Blitz, Dunkel", "in", 0, 700), ("Aufsteigen", "prep", 200, 1000), ("Fangarme", "strike", 1000, 1600), ("DER KRAKEN", "text", 700, 2300), ("Lösen", "after", 2300, 2600)], 2600)
case("Sieg", 1900, [], [], [("Licht steigt, Jubel", "after", 0, 1900), ("SIEG", "text", 150, 1900)], 1900)
case("Niederlage", 2000, [], [], [("Entsättigen", "after", 0, 2000), ("NIEDERLAGE", "text", 300, 2000)], 2000)

bad = 0
print("%-28s %8s %8s %8s" % ("Fall", "Echtzeit", "erwartet", "Segmente"))
for k, c in C.items():
    real = c["stage"] + sum(c["freezes"]) + slow_extra(c["slows"])
    seg_end = max(s[3] for s in c["segs"])
    ok = abs(real - c["expect"]) <= 3 and abs(seg_end - c["expect"]) <= 3
    if not ok:
        bad += 1
    print("%-28s %8.0f %8d %8d %s" % (k, real, c["expect"], seg_end, "" if ok else "  <-- STIMMT NICHT"))
print("Abweichungen:", bad)

# Zusatzzeit je Kampf gegenüber dem Takt von 900 ms (Obergrenze: jede Überlänge wird voll gezählt, auch wenn der Spieler ohnehin denkt)
BASE = 900


def extra(name):
    return max(0, C[name]["expect"] - BASE)


# Häufigkeiten je Kampf nach R1 Tabelle 1.6 (Krit M->G, G->M, Gegnertode, Männertode, Heldenmut plus Bruch), Rest geschätzt
profiles = {
    "Draugr, Kraft 100": dict(crit_m=0.8, crit_g=0.7, kill=3.1, hero_dead=0.36, snap=0.38, area=3.0, door=0.5, win=0.9),
    "Räuber, Kraft 100": dict(crit_m=0.5, crit_g=0.5, kill=3.1, hero_dead=0.16, snap=0.0, area=2.5, door=0.3, win=0.95),
    "Kraken, Kraft 100": dict(crit_m=1.3, crit_g=0.3, kill=6.7, hero_dead=0.20, snap=0.15, area=4.0, door=0.4, win=0.9),
}
print()
for name, p in profiles.items():
    nonlast = max(p["kill"] - 1, 0)
    big = nonlast / 3.0
    new = (p["crit_m"] * extra("Held Krit") + p["crit_g"] * extra("Gegner Krit")
           + big * extra("Gegner fällt (groß)") + (nonlast - big) * extra("Gegner fällt (klein)")
           + p["win"] * extra("Letzter Gegner fällt")
           + p["hero_dead"] * extra("Mann fällt") + p["snap"] * extra("Heldenmut, Zusammenbruch")
           + p["door"] * extra("Mann an der Schwelle") + p["area"] * 0.4 * extra("Fläche, vier Ziele")
           + extra("Kampfbeginn"))
    # heute: _slow-Werte über dem Takt (Krit 1,1; Gegnertod 1,2; letzter Gegner 1,2; Mann fällt 1,9; Heldenmut/Bruch 2,4; Einleitung 1,8)
    old = ((p["crit_m"] + p["crit_g"]) * 200 + nonlast * 300 + p["win"] * 300 + p["hero_dead"] * 1000
           + p["snap"] * 1500 + 900)
    print("%-20s neu +%4.1f s   heute +%4.1f s   Unterschied %+4.1f s" % (name, new / 1000, old / 1000, (new - old) / 1000))
print("Vom tödlichen Treffer bis zum Kampfende: neu 1100 + 1900 = 3000 ms (SIEG beginnt in der Szene), heute etwa 1900 ms")

# SVG
LEFT, TOP, LH, SC = 190, 30, 20, 0.36
W = LEFT + int(3000 * SC) + 20
H = TOP + LH * len(C) + 70
o = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="Segoe UI, Arial, sans-serif" font-size="11">' % (W, H, W, H),
     '<rect width="%d" height="%d" fill="#14161c"/>' % (W, H),
     '<text x="10" y="18" fill="#e6e0cc" font-size="13">Zeitleisten der Regie (Echtzeit in ms ab Beginn der Handlung)</text>']
for t in range(0, 3001, 500):
    x = LEFT + t * SC
    o.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#2c303a"/>' % (x, TOP - 4, x, TOP + LH * len(C)))
    o.append('<text x="%.1f" y="%d" fill="#8a8f9c" text-anchor="middle">%d</text>' % (x, TOP + LH * len(C) + 14, t))
o.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#d9b24a" stroke-dasharray="3 3"/>' % (LEFT + 900 * SC, TOP - 4, LEFT + 900 * SC, TOP + LH * len(C)))
for i, (k, c) in enumerate(C.items()):
    y = TOP + i * LH
    o.append('<text x="%d" y="%d" fill="#c9c4b0" text-anchor="end">%s</text>' % (LEFT - 8, y + 13, k))
    for lab, kind, a, b in sorted(c["segs"], key=lambda s: 0 if s[1] == "text" else 1):
        h = 5 if kind == "text" else LH - 6
        yy = y + LH - 8 if kind == "text" else y + 1
        o.append('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"><title>%s %d bis %d ms</title></rect>' % (LEFT + a * SC, yy, max((b - a) * SC, 1), h, COL[kind], lab, a, b))
    o.append('<text x="%.1f" y="%d" fill="#8a8f9c">%d</text>' % (LEFT + c["expect"] * SC + 4, y + 13, c["expect"]))
lx = 10
ly = H - 22
for kind, lab in [("in", "Ankündigung"), ("prep", "Ausholen"), ("strike", "Schlag, Wirkung"), ("freeze", "Standbild"), ("slow", "Zeitlupe"), ("pause", "Spannungspause"), ("after", "Nachwirkung"), ("text", "Ansage (dünn)")]:
    o.append('<rect x="%d" y="%d" width="12" height="10" fill="%s"/><text x="%d" y="%d" fill="#c9c4b0">%s</text>' % (lx, ly, COL[kind], lx + 16, ly + 9, lab))
    lx += 34 + 6 * len(lab)
o.append('<text x="%.1f" y="%d" fill="#d9b24a" font-size="10">900 ms = Takt</text>' % (LEFT + 900 * SC + 4, TOP - 8))
o.append('</svg>')
out = os.path.join(HERE, "img", "D1_zeitleisten.svg")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(o))
print("geschrieben:", out, os.path.getsize(out), "Bytes")
sys.exit(1 if bad else 0)
