"""Erzeugt die Pixelart der Oberfläche (reines Python, keine Abhängigkeiten).

Aufruf:
    python -X utf8 -I tools/make_ui.py                  -> assets/ui.png, assets/vignette.png, scripts/ui_atlas.gd
    python -X utf8 -I tools/make_ui.py --preview ordner -> zusätzlich Vorschaubilder (vergrößert)

assets/ui.png ist ein Atlas: Eckbeschläge, Kacheln für Panelflächen, Seekarte (130x178),
Knotensymbole je Begegnungstyp, Statussymbole, Zierleisten. Die Lage jedes Teils schreibt das
Skript nach scripts/ui_atlas.gd (UiAtlas.R), damit der Code nichts abzählen muss.
assets/vignette.png (480x320): dunkle Ränder als Dither-Muster, nur Ränder, kein weicher Verlauf.
"""
import math
import os
import struct
import sys
import zlib


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (a[3],)


def shade(c, f):
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), c[3])


def noise(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n ^ (n >> 16)) & 0xFF


def vnoise(x, y, cell, s=0):
    """Glatte Wertenoise (0..1) für Flecken; wird danach hart gestuft."""
    gx, gy = x // cell, y // cell
    fx, fy = (x % cell) / cell, (y % cell) / cell
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = noise(gx, gy, s) / 255.0
    b = noise(gx + 1, gy, s) / 255.0
    c = noise(gx, gy + 1, s) / 255.0
    d = noise(gx + 1, gy + 1, s) / 255.0
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def outline(self, c):
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is not None:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx] is not None:
                        self.px[y][x] = c
                        break

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y][x]
                if c is not None:
                    self.set(ox + x, oy + y, c)

    def scaled(self, n):
        out = Img(self.w * n, self.h * n)
        for y in range(out.h):
            row = self.px[y // n]
            out.px[y] = [row[x // n] for x in range(out.w)]
        return out

    def filled_bg(self, c):
        out = Img(self.w, self.h)
        for y in range(self.h):
            out.px[y] = [p if p is not None else c for p in self.px[y]]
        return out

    def save(self, path):
        raw = bytearray()
        for row in self.px:
            raw.append(0)
            for c in row:
                raw.extend(c if c else (0, 0, 0, 0))

        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b"")
        )
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "wb") as f:
            f.write(png)


# --- Farben ------------------------------------------------------------------

INK = hx("#0d0b10")
PAL = {
    "o": INK,
    "m": hx("#5e4129"), "w": hx("#9a7149"), "W": hx("#c19560"),
    "s": hx("#dcd6c4"), "S": hx("#a39d8c"),
    "r": hx("#c9514a"), "R": hx("#7e2b2b"),
    "g": hx("#e3bc52"), "G": hx("#a8863f"),
    "n": hx("#6fa84d"), "N": hx("#3f6b3a"),
    "t": hx("#4fb0aa"), "T": hx("#2b6a6a"),
    "b": hx("#6a98e0"), "B": hx("#35538a"),
    "v": hx("#b58be0"), "V": hx("#5e4684"),
    "k": hx("#ece6cc"), "K": hx("#a9a48c"),
    "i": hx("#b4bcc6"), "I": hx("#5f6a7c"), "h": hx("#9aa6b8"), "D": hx("#3b4352"),
    "y": hx("#d9bd7c"), "Y": hx("#9c8450"),
    "p": hx("#7a5530"),
    "c": hx("#c4e2da"), "C": hx("#6aa6a0"),
    "e": INK,
    "z": hx("#e8613c"),  # Glut / Auge des Ungeheuers
}


def art(rows, outline=True):
    h = len(rows)
    w = max(len(r) for r in rows)
    im = Img(w + (2 if outline else 0), h + (2 if outline else 0))
    ox = 1 if outline else 0
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "." and ch != " ":
                im.set(x + ox, y + ox, PAL[ch])
    if outline:
        im.outline(INK)
    return im


# Knotensymbole: 7x7 Zeichnung + 1 Pixel Umriss = 9x9
ICONS = {
    "H": [  # Handelsschiff
        "...m...",
        "..sms..",
        ".ssmss.",
        ".ssmss.",
        "...m...",
        "wwwwwww",
        ".WwwwW.",
    ],
    "I": [  # Insel
        ".nn.nn.",
        "nnnnnnn",
        ".NnpnN.",
        "...p...",
        "..yyy..",
        "yyyyyyy",
        "YYYYYYY",
    ],
    "M": [  # Seeungeheuer
        ".tt....",
        "tzttt.t",
        "tttTttT",
        ".TttTt.",
        "..TTT..",
        "T.....T",
        ".T...T.",
    ],
    "T": [  # Hafen: Anker
        "...g...",
        "..gGg..",
        "..ggg..",
        "g..g..g",
        "gg.g.gg",
        ".ggggg.",
        "..GGG..",
    ],
    "D": [  # Küstendorf: Hütte
        "...r...",
        "..rrr..",
        ".rrrrr.",
        "rrrRrrr",
        ".wwwww.",
        ".wmmmw.",
        ".wmmmw.",
    ],
    "G": [  # Draugr-Schiff: Totenkopf
        ".ccccc.",
        "ccccccc",
        "cetcete",
        "cetcete",
        ".ccCcc.",
        "..cCc..",
        "..c.c..",
    ],
    "L": [  # Lokis Spielschiff: Automat mit drei Walzen
        ".nggn..",
        "vvvvvvv",
        "vknkgkr",
        "vkzkgkv",
        "vvvvvvv",
        "VVgggVV",
        "V.....V",
    ],
    "R": [  # Räuberschiff: gekreuzte Schwerter
        "i.....i",
        ".i...i.",
        "..i.i..",
        "...r...",
        "..i.i..",
        ".g...g.",
        "g.....g",
    ],
    "K": [  # Kraken
        "..vvv..",
        ".vvvvv.",
        ".vzvzv.",
        ".vvvvv.",
        "v.vVv.v",
        "V.v.v.V",
        ".V...V.",
    ],
    "W": [  # Wrack
        "..m....",
        "..mss..",
        "..mSs..",
        "..m....",
        ".wwmwww",
        "wWw.ww.",
        ".ww..w.",
    ],
}

SMALL = {
    "pip": [  # Knoten ohne Begegnung (wird mit der Seefarbe eingefärbt)
        ".kkk.",
        "kkkkK",
        "kkkKK",
        "kkKKK",
        ".KKK.",
    ],
    "seen": [  # besuchter Knoten: Wegstein
        "...g...",
        "..gGG..",
        ".gGGGG.",
        "gGGGGGG",
        ".GGGGG.",
        "..GGG..",
        "...G...",
    ],
    "haz": [  # Gefahrenzeichen
        "..r..",
        ".rzr.",
        "rrzrr",
        "RRRRR",
    ],
    "bond_b": [  # Bruder: zwei Ringe
        ".gg.gg.",
        "g..g..g",
        ".gg.gg.",
    ],
    "bond_r": [  # Rivale: gekreuzte Klingen
        "r...r",
        ".r.r.",
        "..r..",
        ".r.r.",
        "r...r",
    ],
    "bond_c": [  # Gefährte: Handschlag, zwei Punkte mit Band
        ".bbb.",
        "bbwbb",
        ".bbb.",
    ],
    "aff_v": [  # verzagt: Träne
        "..v..",
        ".vvv.",
        "vvvvv",
        "vvVvv",
        ".vvv.",
    ],
    "aff_b": [  # Berserker: Zacken
        "r.r.r",
        "rrrrr",
        ".rzr.",
        "..r..",
    ],
}


def corner_big():
    rows = [
        "oooooooo",
        "ohhhhhho",
        "ohgIIIIo",
        "ohIIDDDo",
        "ohIDoooo",
        "ohIDo...",
        "ohIDo...",
        "ooooo...",
    ]
    return art(rows, outline=False)


def corner_small():
    rows = [
        "ooooo",
        "ohhho",
        "ohIoo",
        "ohIo.",
        "ooo..",
    ]
    return art(rows, outline=False)


def sel_arrow():
    rows = [
        "o......",
        "goo....",
        "gggoo..",
        "ggggGo.",
        "gggGo..",
        "gGGo...",
        "Go.....",
    ]
    rows = [
        "...o...",
        "..ogo..",
        ".ogggo.",
        "ogggGGo",
        ".oGGGo.",
        "..oGo..",
        "...o...",
    ]
    return art(rows, outline=False)


def sword():
    """Waagerechtes Schwert, Griff links; wird gespiegelt für die andere Seite."""
    im = Img(26, 7)
    # Knauf, Griff, Parierstange, Klinge
    im.rect(0, 2, 1, 4, INK)
    im.rect(1, 3, 1, 3, PAL["g"])
    im.rect(2, 3, 6, 3, PAL["m"])
    im.rect(2, 2, 6, 2, INK)
    im.rect(2, 4, 6, 4, INK)
    im.rect(7, 0, 8, 6, INK)
    im.rect(7, 1, 7, 5, PAL["g"])
    im.rect(8, 1, 8, 5, PAL["G"])
    im.rect(9, 2, 25, 4, INK)
    im.rect(9, 3, 24, 3, PAL["i"])
    im.rect(9, 3, 24, 3, PAL["i"])
    for x in range(9, 25):
        im.set(x, 3, PAL["k"] if x % 5 else PAL["i"])
    im.set(25, 3, INK)
    im.set(24, 2, INK)
    im.set(24, 4, INK)
    im.set(25, 2, None)
    im.set(25, 4, None)
    for x in range(9, 23):
        im.set(x, 4, PAL["I"])
    return im


def rune_diamond():
    rows = [
        "....o....",
        "...ogo...",
        "..ogggo..",
        ".ogGgGgo.",
        "ogggGggGo",
        ".ogGgGgo.",
        "..ogggo..",
        "...ogo...",
        "....o....",
    ]
    return art(rows, outline=False)


def knot_band():
    """Geflecht, 16 Pixel breit zum Kacheln, 7 hoch."""
    im = Img(16, 7)
    a_col, b_col = PAL["g"], PAL["G"]
    for x in range(16):
        s = math.sin(2 * math.pi * (x + 0.5) / 16.0)
        ya = int(round(3 + 2.0 * s))
        yb = int(round(3 - 2.0 * s))
        strands = [(yb, b_col), (ya, a_col)]
        if x >= 8:
            strands = [(ya, a_col), (yb, b_col)]
        for y, col in strands:
            im.set(x, y - 1, INK)
            im.set(x, y + 1, INK)
        for y, col in strands:
            im.set(x, y, col)
    # Lichtkante obenauf
    return im


def tile_panel(kind):
    """Tabellierbare Panelfläche, 16x16."""
    t = Img(16, 16)
    if kind == "wood":
        base = (17, 20, 28)
        alpha = 238
        grain, speck = 0.0, 0.0
    elif kind == "band":
        base = (13, 15, 21)
        alpha = 240
    elif kind == "stone":
        base = (31, 35, 43)
        alpha = 255
    for y in range(16):
        for x in range(16):
            n = noise(x, y, 3)
            n2 = noise(x // 4, y, 11)  # waagerechte Maserung
            v = 0
            if kind == "stone":
                if n < 30:
                    v = -5
                elif n > 232:
                    v = 6
                if n2 < 40:
                    v -= 2
                if (x * 3 + y * 5) % 16 == 0:
                    v -= 3
            else:
                if n2 < 50:
                    v = -3
                elif n2 > 215:
                    v = 3
                if n > 244:
                    v += 4
                elif n < 8:
                    v -= 3
                if (x + y) % 4 == 0 and n > 140:
                    v += 1
            if kind == "band" and y in (7, 15):  # Plankenfuge
                v -= 5
            c = (base[0] + v, base[1] + v, base[2] + v + (1 if v > 0 else 0), alpha)
            t.set(x, y, c)
    return t


def chart_bg():
    """Seekarte 130x178: dunkles, altes Pergament mit Meereslinien, Kompassrose, Land oben."""
    W, H = 130, 178
    im = Img(W, H)
    parch = (60, 53, 40)
    for y in range(H):
        for x in range(W):
            v = vnoise(x, y, 9, 5)  # Flecken
            lvl = int(v * 4) - 2  # -2..+1 gestuft
            n = noise(x, y, 9)
            d = lvl * 3
            if n > 238:
                d += 5
            elif n < 14:
                d -= 4
            if (x + y) % 5 == 0 and n > 120:
                d += 1
            edge = min(x, y, W - 1 - x, H - 1 - y)
            # gebrannter Rand als Dither
            if edge < 9:
                thr = (9 - edge) / 9.0
                bay = BAYER[(y % 4) * 4 + (x % 4)] / 16.0
                if bay < thr * 0.85:
                    d -= 12 + (int(thr * 8))
            c = (parch[0] + d, parch[1] + d, parch[2] + int(d * 0.8), 255)
            im.set(x, y, c)
    sea_ink = (74, 88, 86, 255)
    sea_ink2 = (66, 78, 76, 255)
    # Breitenlinien auf Höhe der Meilen (CHART_TOP 42, Schritt 12,5, Karte beginnt bei y=14)
    for c in range(0, 11):
        sy = int(math.floor(42 + (10 - c) * 12.5 + 0.5)) - 14
        for x in range(4, W - 4):
            if x % 6 == 0:
                im.set(x, sy, (80, 70, 52, 255))
        for x in (1, 2, 3, W - 4, W - 3, W - 2):
            im.set(x, sy, (120, 104, 70, 255))
    # Meereslinien: kleine Wellen, deterministisch gestreut
    marks = 0
    for i in range(400):
        x = 6 + noise(i, 1, 21) % (W - 20)
        y = 40 + noise(i, 2, 21) % (H - 60)
        ok = True
        for (mx, my) in getattr(chart_bg, "_m", []):
            if abs(mx - x) < 15 and abs(my - y) < 9:
                ok = False
                break
        if not ok:
            continue
        chart_bg._m = getattr(chart_bg, "_m", []) + [(x, y)]
        col = sea_ink if marks % 2 == 0 else sea_ink2
        for dx, dy in ((0, 1), (1, 0), (2, 0), (3, 1), (4, 1), (5, 0)):
            im.set(x + dx, y + dy, col)
        marks += 1
    chart_bg._m = []
    # Faltlinien
    for y in range(H):
        if y % 7 != 3:
            im.set(65, y, (44, 38, 28, 255))
            im.set(66, y, (72, 64, 48, 255))
    for x in range(W):
        if x % 7 != 5:
            im.set(x, 96, (44, 38, 28, 255))
            im.set(x, 97, (72, 64, 48, 255))
    # Land oben (hinter Spalte 10): dunkles Grün, Küstenlinie, Schraffur
    coast = [22 + int(2.2 * math.sin(x / 5.0) + 1.5 * math.sin(x / 2.3 + 1)) for x in range(W)]
    for x in range(W):
        for y in range(14, coast[x]):
            n = noise(x, y, 31)
            c = (40, 52, 42, 255)
            if n > 220:
                c = (50, 64, 50, 255)
            elif (x + y) % 3 == 0 and n > 90:
                c = (34, 44, 36, 255)
            im.set(x, y, c)
        im.set(x, coast[x], (132, 118, 80, 255))
        im.set(x, coast[x] + 1, (84, 74, 50, 255))
    # Titelleiste (Etappe / Stufe)
    for y in range(0, 14):
        for x in range(W):
            n = noise(x, y, 41)
            base = 20 + (2 if n > 200 else 0)
            im.set(x, y, (base, base + 1, base + 6, 255))
    for x in range(W):
        im.set(x, 13, (92, 76, 44, 255))
        im.set(x, 12, INK)
    # Kompassrose rechts unten
    cx, cy, R = 119, 165, 8
    rose_l, rose_d = (150, 132, 90, 255), (88, 74, 48, 255)
    for ang in range(0, 360, 5):
        a = math.radians(ang)
        im.set(int(round(cx + math.cos(a) * 7)), int(round(cy + math.sin(a) * 7)), (104, 90, 60, 255))
    def spike(dx, dy, length, col_l, col_d):
        px, py = -dy, dx
        for s in range(0, length + 1):
            half = max(0, int(round((length - s) * 0.28)))
            for k in range(-half, half + 1):
                x = cx + dx * s + px * k
                y = cy + dy * s + py * k
                im.set(x, y, col_l if k <= 0 else col_d)
    for (dx, dy) in ((1, 0), (-1, 0), (0, 1)):
        spike(dx, dy, R, rose_l, rose_d)
    spike(0, -1, R, (170, 70, 62, 255), (110, 40, 40, 255))  # Norden rot
    for (dx, dy) in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        for s in range(0, 4):
            im.set(cx + dx * s, cy + dy * s, rose_d)
    im.set(cx, cy, hx("#e3bc52"))
    im.rect(cx - 1, cy - 1, cx + 1, cy + 1, (60, 50, 34, 255))
    im.set(cx, cy, hx("#e3bc52"))
    return im


BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def vignette():
    W, H = 480, 320
    im = Img(W, H)
    span = 22.0
    for y in range(H):
        for x in range(W):
            dx = min(x, W - 1 - x)
            dy = min(y, H - 1 - y)
            ax = max(0.0, 1.0 - dx / span)
            ay = max(0.0, 1.0 - dy / (span * 0.9))
            a = max(ax, ay) + 0.45 * min(ax, ay)
            if a <= 0.0:
                continue
            bay = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
            if bay < a * a * 1.25:
                im.set(x, y, (4, 5, 9, 150))
    return im


# --- Atlas -------------------------------------------------------------------

def build_atlas():
    parts = []  # (Name, Img)
    parts.append(("corner_l", corner_big()))
    parts.append(("corner_s", corner_small()))
    parts.append(("sel", sel_arrow()))
    parts.append(("rune", rune_diamond()))
    parts.append(("sword", sword()))
    parts.append(("knot", knot_band()))
    for k in ("wood", "band", "stone"):
        parts.append(("tile_" + k, tile_panel(k)))
    for k, rows in ICONS.items():
        parts.append(("ic_" + k, art(rows)))
    for k, rows in SMALL.items():
        parts.append((k, art(rows)))
    parts.append(("chart", chart_bg()))

    W = 256
    x = y = rowh = 0
    placed = {}
    # große Teile zuerst nach Höhe sortieren
    order = sorted(parts, key=lambda p: -p[1].h)
    for name, im in order:
        if x + im.w > W:
            x = 0
            y += rowh + 1
            rowh = 0
        placed[name] = (x, y, im)
        x += im.w + 1
        rowh = max(rowh, im.h)
    H = y + rowh
    atlas = Img(W, H)
    for name, (px, py, im) in placed.items():
        atlas.blit(im, px, py)
    return atlas, placed


def write_atlas_gd(path, placed):
    lines = [
        "class_name UiAtlas",
        "extends RefCounted",
        "",
        "## Lage der Teile in assets/ui.png. ERZEUGT von tools/make_ui.py, nicht von Hand ändern.",
        "",
        "const R := {",
    ]
    for name in sorted(placed):
        x, y, im = placed[name]
        lines.append('\t"%s": Rect2i(%d, %d, %d, %d),' % (name, x, y, im.w, im.h))
    lines.append("}")
    lines.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.join(here, "..")
    atlas, placed = build_atlas()
    atlas.save(os.path.join(root, "assets", "ui.png"))
    vignette().save(os.path.join(root, "assets", "vignette.png"))
    write_atlas_gd(os.path.join(root, "scripts", "ui_atlas.gd"), placed)
    print("assets/ui.png (%dx%d), assets/vignette.png, scripts/ui_atlas.gd geschrieben" % (atlas.w, atlas.h))
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(out, exist_ok=True)
        bg = hx("#2a3038")
        atlas.filled_bg(bg).scaled(4).save(os.path.join(out, "ui_atlas.png"))
        placed["chart"][2].filled_bg(bg).scaled(4).save(os.path.join(out, "ui_chart.png"))
        print("Vorschau in", out)


if __name__ == "__main__":
    main()
