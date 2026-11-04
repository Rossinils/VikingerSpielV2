"""Erzeugt assets/enemies.png: Kulissen der Begegnungen (reines Python, keine Abhaengigkeiten).

Aufruf:
    python -X utf8 -I tools/make_enemies.py                  -> schreibt nach assets/
    python -X utf8 -I tools/make_enemies.py --preview ordner -> zusaetzlich Vorschaubild in ordner

Atlas: 4 Spalten x 3 Zeilen Zellen zu 128x96 Pixeln. In jeder Zelle liegt der Anker (Wasserlinie,
Mitte) bei (64, 72); ab dort sind 24 Pixel Rumpf/Fels unter Wasser, damit die Wellenschicht davor
keine Luecke laesst. Schiffe schauen mit dem Bug nach links (dem Spieler entgegen).
Die Zellen 9-11 sind Kraken-Tentakel: je zwei Frames zu 64x96, Anker (32, 80).
Lichteinfall wie beim Schiff: von links oben. Umriss #0d0b10. Alles harte Pixel; durchscheinende
Stellen (Nebel, Draugr-Segel) sind gedithert, nie per Alpha.

Zellen (muessen zu scripts/enemy_layer.gd passen):
    0 Draugr-Schiff   1 Raeuberschiff  2 Handelsschiff  3 Insel
    4 Kuestendorf     5 Hafen          6 Wrack          7 Seeungeheuer
    8 Kraken (Kopf)   9/10/11 Tentakel A/B/C (je 2 Frames)
"""
import math
import os
import struct
import sys
import time
import zlib


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def sh(c, k):
    f = {-3: 0.5, -2: 0.64, -1: 0.82, 0: 1.0, 1: 1.14, 2: 1.28}[k]
    cool = 0.07 if k < 0 else 0.0
    return (
        min(255, int(c[0] * f)),
        min(255, int(c[1] * f)),
        min(255, int(c[2] * min(1.0, f + cool * -k))),
        255,
    )


def noise(x, y):
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return (n ^ (n >> 16)) & 0xFF


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

    def put_empty(self, x, y, c):
        """Nur setzen, wo noch nichts ist (Leuchten, Dunst)."""
        if self.get(x, y) is None:
            self.set(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def disc(self, cx, cy, r, c):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r + 1:
                    self.set(cx + dx, cy + dy, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        o = w // 2
        while True:
            for ox in range(w):
                for oy in range(w):
                    self.set(x0 - o + ox, y0 - o + oy, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def polyline(self, pts, c, w=1):
        for a, b in zip(pts, pts[1:]):
            self.line(a[0], a[1], b[0], b[1], c, w)

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


# --- Farben ---------------------------------------------------------------------------

OUT = hx("#0d0b10")
BONE = hx("#cfc7b0")
GOLD = hx("#c9a13b")
RED = hx("#8c2d2d")
STEEL = hx("#8d949b")
SKIN = hx("#cba286")

CELL_W, CELL_H = 128, 96
COLS = 4
AX, WL = 64, 72  # Anker in der Zelle


def shaded_disc(img, cx, cy, r, pal, tex=None):
    """Scheibe mit Licht von links oben. pal = (hell, mittel, dunkel, sehr dunkel)."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + 1:
                continue
            s = (dx * 0.6 + dy * 0.8) / max(r, 1)
            if s < -0.55:
                k = 0
            elif s < 0.2:
                k = 1
            elif s < 0.7:
                k = 2
            else:
                k = 3
            c = pal[k]
            if tex is not None:
                c = tex(cx + dx, cy + dy, c, k)
            img.set(cx + dx, cy + dy, c)


def hull(img, cx, wl, half, mid, end_up, depth, taper, pal, bow_extra=0, stern_extra=0, plank=10):
    """Rumpf mit Sprung (Enden hoeher), Bug links. Gibt top(x) zurueck."""

    def top(x):
        t = (x - cx) / half
        y = wl - mid - round(end_up * t * t)
        if x < cx and bow_extra:
            y -= round(bow_extra * t * t * t * t)
        if x > cx and stern_extra:
            y -= round(stern_extra * t * t * t * t)
        return y

    def bot(x):
        t = abs((x - cx) / half)
        return round(wl + depth - taper * t ** 2.2)

    for x in range(cx - half, cx + half + 1):
        t0, b0 = top(x), bot(x)
        for y in range(t0, b0 + 1):
            row = y - t0
            band = row // 4
            if band == 0:
                c = pal["rail"]
                if row == 0:
                    c = sh(c, 1)
                elif row == 3:
                    c = sh(c, -1)
            else:
                c = pal["L"] if (x // plank + band) % 2 else pal["M"]
                if row % 4 == 0:
                    c = sh(c, 1) if band == 1 else c
                if row % 4 == 3:
                    c = sh(c, -2)
                if x > cx + half * 0.55:
                    c = sh(c, -1)  # Heck im Schatten
                if noise(x, y) < 20:
                    c = sh(c, -1)
            if y > wl - 2:
                c = sh(c, -2)
            img.set(x, y, c)
    return top


def sail_rect(img, x0, x1, y0, bottom, pal, stripes=None, belly=2.0):
    """Rechtecksegel, Bauch nach links (Wind von rechts). bottom(x) = letzte Zeile. stripes(x)->Farbe."""
    for x in range(x0, x1 + 1):
        b = bottom(x)
        edge = round(belly * math.sin((x - x0) / (x1 - x0) * math.pi))
        for y in range(y0 + (0 if edge == 0 else 0), b + 1):
            base = stripes(x) if stripes else pal["M"]
            fold = math.sin((x - x0) * 0.45 + 0.8)
            k = 1 if fold > 0.5 else (-1 if fold < -0.5 else 0)
            if x > x1 - 8:
                k -= 1
            if y > b - 4:
                k -= 1
            if y < y0 + 2:
                k -= 1
            k = max(-3, min(2, k))
            c = sh(base, k)
            if stripes and (x - x0) % 9 == 0:
                c = sh(base, -2)
            img.set(x, y, c)


def pine(img, x, yb, h, dark=False):
    """Kiefer mit Fuss bei (x, yb), Hoehe h."""
    pal = (hx("#2f5a46"), hx("#1f3d32"), hx("#162b24")) if not dark else (hx("#24473a"), hx("#183128"), hx("#101f1b"))
    img.rect(x, yb - 3, x, yb, hx("#2b2118"))
    top = yb - h
    half_max = max(2, h // 4 + 1)
    for s in range(0, h - 3):
        y = top + s
        tier = s // 4
        tiers = max(1, (h - 3) // 4)
        hw = 1 + int((tier + 1) * half_max / (tiers + 0.5)) - (1 if s % 4 == 0 else 0)
        for dx in range(-hw, hw + 1):
            if dx < -hw // 2:
                c = pal[0]
            elif dx > hw // 2:
                c = pal[2]
            else:
                c = pal[1]
            if s % 4 == 3:
                c = sh(c, -1)
            img.set(x + dx, y, c)


def glow(img, cx, cy, core, mid, halo, r=5):
    """Laterne: Kern, Rand und Hof gedithert (kein Alpha)."""
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if 5 < d2 <= r * r and (cx + dx + cy + dy) % 2 == 0:
                img.put_empty(cx + dx, cy + dy, halo)
    img.rect(cx - 1, cy - 1, cx, cy + 1, mid)
    img.set(cx - 1, cy - 1, core)
    img.set(cx, cy, core)


def punch(img, x0, y0, x1, y1, keep):
    """Loescht Pixel in einem Bereich, wo keep(x, y) falsch ist (Dithering von Hand)."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if img.get(x, y) is not None and not keep(x, y):
                img.px[y][x] = None


def mist(img, x0, x1, wl, col, rows=5):
    """Nebelband ueber der Wasserlinie: nach oben immer lichter (Dither-Muster)."""
    for i in range(rows):
        y = wl - 1 - i
        for x in range(x0, x1 + 1):
            if i == 0:
                keep = (x + y) % 2 == 0 or noise(x, y) < 90
            elif i == 1:
                keep = (x + y) % 2 == 0
            elif i == 2:
                keep = (x + y) % 2 == 0 and noise(x // 2, y) < 170
            else:
                keep = x % 4 == (y % 2) * 2 and noise(x, y) < 140
            if keep and img.get(x, y) is not None:
                img.set(x, y, col if i < 2 else sh(col, -1))


# --- 0 Draugr-Schiff ----------------------------------------------------------------------

def make_draugr():
    img = Img(CELL_W, CELL_H)
    pal = {"L": hx("#566057"), "M": hx("#3d4640"), "rail": hx("#6a7468")}
    cx, wl = AX, WL
    top = hull(img, cx, wl, 36, 9, 8, 20, 15, pal, bow_extra=9, stern_extra=8)
    # Bugsteven mit Totenkopf, Achtersteven
    stem = [(cx - 36, top(cx - 36)), (cx - 40, wl - 26), (cx - 41, wl - 33)]
    img.polyline(stem, pal["M"], 3)
    img.polyline([(p[0] - 1, p[1]) for p in stem], pal["L"], 1)
    sx, sy = cx - 42, wl - 38
    img.rect(sx - 2, sy - 2, sx + 3, sy + 2, hx("#b9b8a6"))
    img.rect(sx - 1, sy + 3, sx + 2, sy + 4, hx("#9a9a8a"))
    img.rect(sx - 2, sy - 2, sx + 3, sy - 2, hx("#d4d2c0"))
    img.rect(sx - 1, sy - 1, sx, sy, OUT)
    img.rect(sx + 2, sy - 1, sx + 3, sy, OUT)
    img.set(sx + 1, sy + 1, OUT)
    img.set(sx, sy + 3, OUT)
    img.set(sx + 2, sy + 3, OUT)
    post = [(cx + 36, top(cx + 36)), (cx + 38, wl - 27), (cx + 35, wl - 33)]
    img.polyline(post, pal["M"], 3)
    img.polyline([(p[0] - 1, p[1]) for p in post], pal["L"], 1)
    # Achterdeck
    img.rect(cx + 22, wl - 22, cx + 36, wl - 17, pal["M"])
    img.rect(cx + 22, wl - 22, cx + 36, wl - 22, pal["rail"])
    img.rect(cx + 22, wl - 17, cx + 36, wl - 17, sh(pal["M"], -2))
    for px in range(cx + 24, cx + 36, 4):
        img.rect(px, wl - 20, px, wl - 18, sh(pal["M"], -2))
    # Mast mit Rah
    img.rect(cx - 2, wl - 60, cx, top(cx), pal["M"])
    img.rect(cx - 2, wl - 60, cx - 2, top(cx), pal["L"])
    img.rect(cx, wl - 60, cx, top(cx), sh(pal["M"], -2))
    img.rect(cx - 25, wl - 57, cx + 26, wl - 56, pal["M"])
    img.rect(cx - 25, wl - 57, cx + 26, wl - 57, pal["L"])
    # zerfetztes Segel
    sail = {"L": hx("#8d9a93"), "M": hx("#6f7d78")}

    def bottom(x):
        b = wl - 31 + noise(x // 2, 5) % 5
        if x % 9 in (0, 1):
            b += 9 + noise(x, 3) % 6  # herabhaengende Fetzen
        if cx - 14 < x < cx - 6:
            b -= 5
        return b

    sail_rect(img, cx - 22, cx + 22, wl - 55, bottom, sail, belly=3.0)
    # Totenkopf im Segel (dunkel)
    k = hx("#1f2926")
    img.rect(cx - 5, wl - 48, cx + 4, wl - 41, k)
    img.rect(cx - 4, wl - 49, cx + 3, wl - 49, k)
    img.rect(cx - 3, wl - 40, cx + 2, wl - 38, k)
    img.rect(cx - 4, wl - 46, cx - 2, wl - 44, sail["L"])
    img.rect(cx + 1, wl - 46, cx + 3, wl - 44, sail["L"])
    img.set(cx - 1, wl - 42, sail["L"])
    img.set(cx, wl - 42, sail["L"])
    for tx in (cx - 2, cx, cx + 2):
        img.set(tx, wl - 38, sail["L"])
    # Algenstraehnen an Rah und Reling
    alg, algd = hx("#41614c"), hx("#2b4333")
    for x in range(cx - 33, cx + 36, 5):
        n = noise(x, 9) % 6 + 3
        t = top(x) + 4
        for i in range(n):
            img.set(x, t + i, alg if i % 3 else algd)
    for x in (cx - 22, cx - 12, cx + 6, cx + 20):
        for i in range(noise(x, 4) % 5 + 3):
            img.set(x, wl - 55 + i, algd)
    # Wimpel (zerrissen, nach links)
    for i in range(16):
        th = max(1, 4 - i // 4)
        for j in range(th):
            if i >= 11 and j == th // 2:
                continue
            img.set(cx - 3 - i, wl - 63 + round(1.5 * math.sin(i * 0.5)) + j, hx("#1c2423"))
    # Laterne am Bug (blass gruen)
    lx, ly = cx - 33, wl - 21
    img.rect(lx - 1, ly - 4, lx - 1, ly - 1, OUT)
    img.outline(OUT)
    # Rippen: oberes Plankenband loechrig dithern (Himmel scheint durch)
    punch(img, cx - 34, top(cx) - 6, cx + 34, wl - 2,
          lambda x, y: not (y < top(x) + 8 and y > top(x) + 3 and (x % 7) in (2, 3, 4) and (x + y) % 2 == 0))
    # Loecher im Segel, nach unten dichter
    def sail_keep(x, y):
        d = (y - (wl - 55)) / 30.0
        if d > 0.55 and (x + y) % 2 == 0 and noise(x, y) < 150 * d:
            return False
        return not (noise(x // 2, y // 2) < 14)

    punch(img, cx - 22, wl - 55, cx + 22, wl - 18, sail_keep)
    glow(img, lx, ly, hx("#e2ffe9"), hx("#9fe6b4"), hx("#47856a"), 5)
    glow(img, cx, wl - 63, hx("#e2ffe9"), hx("#7fd6a0"), hx("#47856a"), 4)
    mist(img, cx - 44, cx + 42, wl, hx("#8a9c98"), 5)
    return img


# --- 1 Raeuberschiff ----------------------------------------------------------------------

def make_raeuber():
    img = Img(CELL_W, CELL_H)
    pal = {"L": hx("#43362d"), "M": hx("#2c2420"), "rail": hx("#5e4636")}
    cx, wl = AX, WL
    top = hull(img, cx, wl, 40, 13, 7, 20, 14, pal, bow_extra=6, stern_extra=5, plank=8)
    # rotes Band
    for x in range(cx - 40, cx + 41):
        y = top(x) + 4
        for j in range(2):
            c = RED if j == 0 else sh(RED, -2)
            if x > cx + 24:
                c = sh(c, -1)
            img.set(x, y + j, c)
    # Kanonenpforten
    for px in (cx - 26, cx - 14, cx - 2, cx + 10, cx + 22):
        y = top(px) + 7
        img.rect(px - 1, y - 1, px + 4, y + 4, sh(pal["L"], 1))
        img.rect(px, y, px + 3, y + 3, OUT)
        img.rect(px, y, px + 3, y, hx("#1a0f10"))
        if px in (cx - 14, cx + 22):
            img.rect(px + 1, y + 1, px + 2, y + 2, hx("#5a5f66"))
            img.set(px + 1, y + 1, STEEL)
    # Bugspriet, Steven
    img.polyline([(cx - 38, top(cx - 38) + 1), (cx - 50, wl - 30)], pal["M"], 2)
    img.line(cx - 40, top(cx - 40), cx - 51, wl - 31, pal["L"], 1)
    post = [(cx + 38, top(cx + 38)), (cx + 40, wl - 28)]
    img.polyline(post, pal["M"], 3)
    img.line(cx + 38, top(cx + 38) - 1, cx + 39, wl - 28, pal["L"], 1)
    # Achterdeck mit Laterne
    img.rect(cx + 22, wl - 26, cx + 38, wl - 20, pal["M"])
    img.rect(cx + 22, wl - 26, cx + 38, wl - 26, pal["rail"])
    img.rect(cx + 22, wl - 20, cx + 38, wl - 20, sh(pal["M"], -2))
    for x in range(cx + 24, cx + 38, 3):
        img.rect(x, wl - 24, x, wl - 21, sh(pal["M"], -2))
    # Mast + Marssegel + grosses Segel
    img.rect(cx - 2, wl - 66, cx, top(cx), pal["M"])
    img.rect(cx - 2, wl - 66, cx - 2, top(cx), pal["L"])
    img.rect(cx - 27, wl - 55, cx + 27, wl - 54, pal["M"])
    img.rect(cx - 27, wl - 55, cx + 27, wl - 55, pal["L"])
    img.rect(cx - 15, wl - 66, cx + 15, wl - 65, pal["M"])
    black, redd = hx("#2a2229"), hx("#8c2d2d")

    def stripe(x):
        return redd if ((x - cx + 27) // 6) % 3 == 1 else black

    def bot_main(x):
        b = wl - 21 + noise(x // 3, 2) % 3
        if cx + 14 < x < cx + 19:
            b -= 5
        return b

    sail_rect(img, cx - 25, cx + 25, wl - 53, bot_main, None, stripes=stripe, belly=3.0)
    sail_rect(img, cx - 13, cx + 13, wl - 64, lambda x: wl - 56, None, stripes=stripe, belly=1.5)
    # Flicken im Segel
    img.rect(cx - 12, wl - 38, cx - 7, wl - 33, hx("#4a4048"))
    img.rect(cx + 6, wl - 46, cx + 10, wl - 42, hx("#4a4048"))
    # Fock am Bugspriet
    for i in range(18):
        y = wl - 52 + i
        x_end = cx - 49 + round(i * 0.55)
        x_beg = cx - 31
        for x in range(x_end, x_beg + 1):
            if y - (wl - 52) > (x - x_end) * 1.9 + 0:
                continue
            c = stripe(x + 3)
            img.set(x, y, sh(c, -1 if x > x_beg - 4 else 0))
    img.line(cx - 31, wl - 53, cx - 49, wl - 31, hx("#1c1713"), 1)
    # Wache am Bug / Mannschaft an der Reling
    heads = [hx("#8a6e5a"), hx("#7a5f4e"), hx("#9a7c64")]
    caps = [hx("#3a3a44"), hx("#5a3a3a"), hx("#2c2a30"), STEEL]
    for i, px in enumerate(range(cx - 34, cx + 22, 6)):
        t = top(px)
        img.rect(px, t - 3, px + 2, t - 1, hx("#2a2f3a") if i % 2 else hx("#3a2c2c"))
        img.rect(px, t - 6, px + 2, t - 4, heads[i % 3])
        img.rect(px, t - 7, px + 2, t - 7, caps[i % 4])
        if i % 3 == 0:
            img.line(px + 3, t - 1, px + 4, t - 9, hx("#6a5034"), 1)
            img.set(px + 4, t - 10, STEEL)
    # Flagge am Mast: schwarz mit Totenkopf, weht nach links
    for i in range(16):
        w = 8 if i < 12 else 8 - (i - 11)
        for j in range(w):
            c = hx("#17131a") if j else sh(hx("#17131a"), 1)
            img.set(cx - 3 - i, wl - 76 + j + round(1.2 * math.sin(i * 0.5)), c)
    img.rect(cx - 10, wl - 74, cx - 8, wl - 72, BONE)
    img.set(cx - 10, wl - 74, OUT)
    img.set(cx - 8, wl - 74, OUT)
    img.line(cx - 12, wl - 71, cx - 6, wl - 69, sh(BONE, -1), 1)
    img.disc(cx, wl - 67, 1, GOLD)
    img.outline(OUT)
    # Laterne am Heck (warm, sparsam)
    glow(img, cx + 34, wl - 29, hx("#ffe9a8"), GOLD, hx("#6b5226"), 4)
    return img


# --- 2 Handelsschiff (Knorr) ----------------------------------------------------------------

def make_haendler():
    img = Img(CELL_W, CELL_H)
    pal = {"L": hx("#6b4a33"), "M": hx("#4f3826"), "rail": hx("#7d5a3d")}
    cx, wl = AX, WL
    top = hull(img, cx, wl, 38, 11, 9, 22, 14, pal, bow_extra=3, stern_extra=3, plank=11)
    # Klinkerfugen
    for x in range(cx - 36, cx + 37):
        for dy in (9, 14):
            y = top(x) + dy
            if y < wl + 4:
                img.set(x, y, sh(img.get(x, y) or pal["M"], -2))
    # hohe Steven
    for sgn, ex in ((-1, -1), (1, 1)):
        px = cx + sgn * 38
        pts = [(px, top(px)), (px + sgn * 2, wl - 26), (px + sgn * 1, wl - 31)]
        img.polyline(pts, pal["M"], 3)
        img.polyline([(p[0] - 1, p[1]) for p in pts], pal["L"], 1)
    img.disc(cx - 39, wl - 33, 2, GOLD)
    img.set(cx - 40, wl - 34, sh(GOLD, 1))
    # Ladung: Plane, Fass, Kisten
    img.rect(cx - 14, top(cx) - 7, cx + 20, top(cx) + 1, hx("#5a523e"))
    for x in range(cx - 14, cx + 21):
        h = round(7 * math.sin((x - cx + 14) / 34 * math.pi))
        for y in range(top(cx) + 1 - h - 1, top(cx) + 1):
            c = hx("#5f5841") if (x + y) % 5 else hx("#4a4432")
            if y < top(cx) - h + 1:
                c = hx("#7a7258")
            img.set(x, y, c)
    for bx in (cx + 22, cx + 28):
        img.rect(bx, top(bx) - 7, bx + 4, top(bx), hx("#5a3e28"))
        img.rect(bx, top(bx) - 7, bx, top(bx), hx("#7a5538"))
        img.rect(bx, top(bx) - 5, bx + 4, top(bx) - 5, hx("#2a2218"))
        img.rect(bx, top(bx) - 2, bx + 4, top(bx) - 2, hx("#2a2218"))
    img.rect(cx - 30, top(cx - 30) - 6, cx - 24, top(cx - 30), hx("#7a5a3a"))
    img.rect(cx - 30, top(cx - 30) - 6, cx - 24, top(cx - 30) - 6, hx("#a08058"))
    img.rect(cx - 27, top(cx - 30) - 6, cx - 27, top(cx - 30), hx("#4a3624"))
    img.rect(cx - 23, top(cx - 23) - 4, cx - 18, top(cx - 23), hx("#6a4e34"))
    # Mast, Rah, gestreiftes Segel
    img.rect(cx - 1, wl - 62, cx + 1, top(cx), pal["M"])
    img.rect(cx - 1, wl - 62, cx - 1, top(cx), pal["L"])
    img.rect(cx - 25, wl - 58, cx + 25, wl - 57, pal["M"])
    img.rect(cx - 25, wl - 58, cx + 25, wl - 58, pal["L"])
    blue, cream = hx("#35506a"), hx("#b5a888")

    def stripe(x):
        return blue if ((x - cx + 24) // 8) % 2 == 0 else cream

    def bot(x):
        return wl - 28 + noise(x // 4, 1) % 3 + (2 if x % 8 == 0 else 0)

    sail_rect(img, cx - 24, cx + 24, wl - 56, bot, None, stripes=stripe, belly=3.5)
    img.rect(cx + 6, wl - 47, cx + 12, wl - 41, hx("#8a7a5e"))
    img.rect(cx - 12, wl - 38, cx - 7, wl - 32, hx("#3d4856"))
    # Wimpel in Gold (sparsamer Akzent)
    for i in range(10):
        img.set(cx - 2 - i, wl - 65 + round(math.sin(i * 0.6)), GOLD if i < 8 else sh(GOLD, -2))
        img.set(cx - 2 - i, wl - 64 + round(math.sin(i * 0.6)), sh(GOLD, -2))
    # Wanten
    img.outline(OUT)
    for sgn in (-1, 1):
        for i in range(0, 9):
            x = cx + sgn * (2 + i * 3)
            y = wl - 58 + i * 4 - (0)
            if y > top(x) - 1:
                break
            img.set(x, y, hx("#1c1611"))
    glow(img, cx + 37, wl - 36, hx("#ffe9a8"), GOLD, hx("#6b5226"), 4)
    return img


# --- 3 Insel ---------------------------------------------------------------------------------

def make_insel():
    img = Img(CELL_W, CELL_H)
    rock_l, rock_m, rock_d, rock_dd = hx("#4f5a5e"), hx("#38424a"), hx("#262e36"), hx("#1a2028")
    pal = (rock_l, rock_m, rock_d, rock_dd)

    def tex(x, y, c, k):
        n = noise(x, y // 2)
        if n < 26:
            return sh(c, -1)
        if n > 236:
            return sh(c, 1)
        return c

    # Hauptinsel: zwei Huegel, nach rechts flach zum Strand
    MOUNDS = [(52, 34, 30), (90, 24, 17), (28, 14, 14)]

    def height(x):
        h = 0.0
        for (mcx, r, mh) in MOUNDS:
            u = (x - mcx) / float(r)
            if abs(u) < 1.0:
                h = max(h, mh * (1.0 - u * u) ** 0.85)
        if h <= 0.0:
            return 0
        return max(0, round(h + 1.6 * math.sin(x * 0.55) + 1.2 * math.sin(x * 0.21)))

    for x in range(0, 128):
        h = height(x)
        if h <= 0:
            continue
        for y in range(WL - h, 96):
            depth = y - (WL - h)
            if depth < 3:
                k = 0 if x < 64 else 1
            elif (x // 6 + y // 5) % 3 == 0:
                k = 1
            else:
                k = 1 if (y // 4) % 2 else 2
            if x > 70:
                k = min(3, k + 1)
            if y > WL - 2:
                k = 3
            c = pal[min(3, k)]
            c = tex(x, y, c, k)
            img.set(x, y, c)
    # Huegelkuppe: dunkler Waldboden
    for x in range(14, 96):
        h = height(x)
        if h < 12:
            continue
        for y in range(WL - h, WL - h + 3):
            img.set(x, y, hx("#1f2e27") if (x + y) % 3 else hx("#2a3d33"))
    # Kiefern
    for (px, ph, dk) in [(24, 16, False), (31, 22, True), (39, 20, False), (46, 28, True), (53, 22, False),
                         (60, 26, True), (68, 17, False), (80, 17, True), (88, 15, False), (95, 12, True)]:
        h = height(px)
        pine(img, px, WL - h + 5, ph, dark=dk)
    # Strand (rechts) und Findlinge
    for x in range(100, 118):
        h = height(x)
        if h <= 0:
            continue
        top = WL - h
        for y in range(top, top + 4):
            img.set(x, y, hx("#6f6b58") if y == top else hx("#54503f"))
    for bx, by in [(98, WL - 1), (116, WL), (92, WL + 1)]:
        shaded_disc(img, bx, by - 2, 3, pal)
    # Lagerfeuer
    fx, fy = 110, WL - 4
    img.rect(fx - 3, fy, fx + 3, fy, hx("#2b2118"))
    img.rect(fx - 2, fy + 1, fx + 2, fy + 1, hx("#1c1611"))
    flame = [(0, -1, hx("#f0b040")), (0, -2, hx("#f0b040")), (-1, -1, hx("#d9822b")), (1, -1, hx("#d9822b")),
             (0, -3, hx("#d9822b")), (-1, -2, hx("#a8481f")), (1, -2, hx("#a8481f")), (0, -4, hx("#a8481f"))]
    for dx, dy, c in flame:
        img.set(fx + dx, fy + dy, c)
    img.set(fx, fy - 1, hx("#ffe9a8"))
    # Hof um das Feuer (gedithert)
    for dy in range(-9, 4):
        for dx in range(-9, 10):
            d2 = dx * dx + dy * dy * 1.6
            if 8 < d2 <= 62 and (dx + dy) % 2 == 0:
                img.put_empty(fx + dx, fy + dy, hx("#6b4a26"))
    # Rauchfaden (Dither)
    for i in range(14):
        y = fy - 6 - i
        x = fx + round(2 * math.sin(i * 0.5)) + i // 5
        if i % 2 == 0:
            img.set(x, y, hx("#707a80") if i < 9 else hx("#59636a"))
            if i < 8:
                img.set(x + 1, y, hx("#59636a"))
    # Zelt/Huette und ein Boot am Strand
    img.rect(fx - 14, fy - 5, fx - 9, fy, hx("#4a3a2b"))
    for i in range(6):
        img.set(fx - 14 + i, fy - 6 - (2 - abs(i - 2)) + 1 - 1, hx("#6a5638"))
    img.rect(fx - 13, fy - 3, fx - 11, fy, OUT)
    pine(img, 21, WL - height(21) + 4, 12, dark=True)
    img.outline(OUT)
    return img


# --- 4 Kuestendorf -----------------------------------------------------------------------------

def longhouse(img, x0, base_y, w, h, roof_h, lit=True, flip=False):
    wood_l, wood_m, wood_d = hx("#4f3a2a"), hx("#392a1f"), hx("#261c15")
    # Wand
    for x in range(x0, x0 + w):
        for y in range(base_y - h, base_y):
            c = wood_m if (x // 3) % 2 else wood_l
            if y == base_y - 1:
                c = wood_d
            if x > x0 + w * 0.7:
                c = sh(c, -1)
            img.set(x, y, c)
    # Torf-Dach
    turf_l, turf_m, turf_d = hx("#4a5c3a"), hx("#364630"), hx("#232f20")
    # Giebel als Dreieck
    for y in range(roof_h):
        t = y / max(roof_h - 1, 1)
        hw = 1 + round(t * (w / 2 + 2))
        for x in range(x0 + w // 2 - hw, x0 + w // 2 + hw + 1):
            c = turf_m
            if y == 0 or (x * 3 + y) % 7 == 0:
                c = turf_l
            if x > x0 + w * 0.62:
                c = turf_d if (x + y) % 3 else turf_m
            if y % 4 == 3:
                c = sh(c, -1)
            img.set(x, base_y - h - roof_h + y + 1, c)
    # Drachenbalken am First
    px = x0 + w // 2
    img.line(px, base_y - h - roof_h - 1, px - 3, base_y - h - roof_h - 6, wood_l, 1)
    img.line(px, base_y - h - roof_h - 1, px + 3, base_y - h - roof_h - 6, wood_m, 1)
    # Tuer, Fenster
    img.rect(x0 + 3, base_y - 7, x0 + 5, base_y - 1, OUT)
    if lit:
        win = (x0 + w - 6, base_y - h + 3)
        img.rect(win[0], win[1], win[0] + 1, win[1] + 1, hx("#f0b040"))
        for dx in range(-3, 5):
            for dy in range(-3, 5):
                if (dx + dy) % 2 == 0 and not (0 <= dx <= 1 and 0 <= dy <= 1):
                    img.put_empty(win[0] + dx, win[1] + dy, hx("#6b4a26"))


def smoke(img, x, y, n, seed):
    for i in range(n):
        yy = y - i
        xx = x + round(1.6 * math.sin(i * 0.45 + seed)) + i // 4
        if i % 2 == 0:
            c = hx("#7a838a") if i < n * 0.5 else hx("#5d676e")
            img.set(xx, yy, c)
            if i < n * 0.6:
                img.set(xx + 1, yy, hx("#5d676e"))
        elif i < n * 0.5:
            img.set(xx - 1, yy, hx("#5d676e"))


def make_dorf():
    img = Img(CELL_W, CELL_H)
    pal = (hx("#4a5a52"), hx("#33403c"), hx("#222c2c"), hx("#171e22"))
    grass_l, grass_m, grass_d = hx("#3f5236"), hx("#2c3d2b"), hx("#1c2a1f")
    # Huegelland
    def height(x):
        t = x / 127.0
        h = 16 + 7 * math.sin(t * 5.0 + 0.6) + 12 * math.sin(t * math.pi) - 14 * t * t
        edge = min(1.0, x / 20.0, (127 - x) / 14.0)
        return max(0, round(h * max(edge, 0.0) ** 0.8))

    for x in range(0, 128):
        h = height(x)
        if h <= 0:
            continue
        for y in range(WL - h, 96):
            if y == WL - h:
                c = grass_l
            elif y < WL - h + 3:
                c = grass_m if (x + y) % 4 else grass_l
            elif y < WL - 3 + 2:
                c = grass_d if (x + y) % 5 else grass_m
            else:
                c = pal[2] if y < WL + 4 else pal[3]
                if noise(x, y) < 40:
                    c = pal[3] if y < WL + 4 else sh(pal[3], -1)
            if x > 100 and y >= WL - 4 and y < WL + 1:
                c = hx("#6f6b58") if y == WL - 4 else hx("#54503f")  # Strand
            img.set(x, y, c)
    # Fichten im Hintergrund
    for (px, ph) in [(8, 19), (16, 25), (25, 16), (112, 20), (120, 14)]:
        pine(img, px, WL - height(px) + 4, ph, dark=True)
    # Langhaeuser
    longhouse(img, 34, WL - height(34) + 6, 26, 7, 9, lit=True)
    longhouse(img, 66, WL - height(66) + 7, 22, 6, 8, lit=False)
    longhouse(img, 94, WL - height(94) + 6, 16, 5, 7, lit=True)
    # Palisade
    for x in range(26, 118, 3):
        y0 = WL - height(x) + 7
        if 34 <= x <= 60 or 66 <= x <= 88:
            continue
        img.rect(x, y0 - 4, x, y0 + 1, hx("#32261b"))
        img.set(x, y0 - 5, hx("#6a5038"))
    # Fischgestelle
    for rx in (22, 63):
        y0 = WL - height(rx) + 9
        img.line(rx, y0, rx, y0 - 6, hx("#4a3a2b"))
        img.line(rx + 7, y0, rx + 7, y0 - 6, hx("#4a3a2b"))
        img.line(rx, y0 - 6, rx + 7, y0 - 6, hx("#6a5038"))
        for fx in (rx + 2, rx + 4, rx + 6):
            img.rect(fx, y0 - 5, fx, y0 - 3, hx("#8a8f94"))
    # Boote am Strand
    for bx in (100, 112):
        y0 = WL - 2
        for i in range(10):
            hh = 3 - round(2.0 * abs(i - 4.5) / 4.5)
            img.rect(bx + i, y0 - hh, bx + i, y0, hx("#4f3826") if i % 2 else hx("#6b4a33"))
        img.rect(bx, y0, bx + 9, y0, hx("#261c15"))
    # Glocke am Strand (Gold als Akzent)
    img.rect(120, WL - 14, 120, WL - 2, hx("#32261b"))
    img.rect(116, WL - 15, 124, WL - 15, hx("#4a3a2b"))
    img.rect(119, WL - 13, 121, WL - 11, GOLD)
    img.set(119, WL - 13, sh(GOLD, 1))
    # Rauch aus den Daechern
    smoke(img, 47, WL - height(47) - 11, 18, 0.5)
    smoke(img, 103, WL - height(103) - 8, 14, 2.0)
    img.outline(OUT)
    return img


# --- 5 Hafen ---------------------------------------------------------------------------------

def make_hafen():
    img = Img(CELL_W, CELL_H)
    wood_l, wood_m, wood_d = hx("#5a4130"), hx("#40301f"), hx("#2a1f15")
    stone_l, stone_m, stone_d = hx("#4d565c"), hx("#38414a"), hx("#262e36")
    # Kai-Block rechts
    for x in range(78, 128):
        for y in range(WL - 14, 96):
            c = stone_m if ((x // 7) + (y // 4)) % 2 else stone_l
            if y == WL - 14:
                c = sh(stone_l, 1)
            if noise(x, y) < 24:
                c = stone_d
            if y > WL - 2:
                c = sh(c, -2)
            img.set(x, y, c)
    # Taverne
    tx0, tx1, ty0 = 86, 120, WL - 14
    for x in range(tx0, tx1):
        for y in range(ty0 - 18, ty0):
            c = wood_m if (x // 3) % 2 else wood_l
            if y % 6 == 0:
                c = wood_d
            if x > tx0 + 22:
                c = sh(c, -1)
            img.set(x, y, c)
    # Dach
    roof_l, roof_m, roof_d = hx("#4b3a33"), hx("#352a27"), hx("#241c1a")
    for y in range(11):
        hw = 2 + round(y * 2.0)
        for x in range((tx0 + tx1) // 2 - hw, (tx0 + tx1) // 2 + hw):
            c = roof_m if (y + x // 2) % 3 else roof_l
            if y == 0 or y % 3 == 2:
                c = roof_d if x > (tx0 + tx1) // 2 else c
            if x > (tx0 + tx1) // 2 + 4:
                c = roof_d if (x + y) % 3 else roof_m
            img.set(x, ty0 - 29 + y, c)
    # Fenster (warm), Tuer, Schild
    for wx in (91, 101, 111):
        img.rect(wx, ty0 - 12, wx + 2, ty0 - 8, hx("#f0b040"))
        img.rect(wx, ty0 - 12, wx + 2, ty0 - 12, hx("#ffe9a8"))
        img.rect(wx + 1, ty0 - 12, wx + 1, ty0 - 8, hx("#a8722a"))
        for dx in range(-3, 6):
            for dy in range(-3, 6):
                if (dx + dy) % 2 == 0 and not (0 <= dx <= 2 and 0 <= dy <= 4):
                    img.put_empty(wx + dx, ty0 - 12 + dy, hx("#5e4220"))
    img.rect(100, ty0 - 5, 104, ty0 - 1, OUT)
    img.line(84, ty0 - 12, 84, ty0 - 16, wood_l)
    img.rect(80, ty0 - 15, 84, ty0 - 10, wood_m)
    img.rect(81, ty0 - 14, 83, ty0 - 12, GOLD)
    img.set(81, ty0 - 14, sh(GOLD, 1))
    # Steg
    deck_y = WL - 8
    for x in range(2, 84):
        img.rect(x, deck_y, x, deck_y + 2, wood_l if (x // 6) % 2 else wood_m)
        img.set(x, deck_y, sh(wood_l, 1) if (x // 6) % 2 else wood_l)
        img.set(x, deck_y + 2, sh(wood_m, -2))
    for px in range(6, 84, 13):
        img.rect(px, deck_y + 3, px + 2, 90, wood_m)
        img.rect(px, deck_y + 3, px, 90, wood_l)
        img.rect(px + 2, deck_y + 3, px + 2, 90, wood_d)
        img.rect(px - 1, deck_y - 4, px + 3, deck_y - 1, wood_m)  # Poller
        img.rect(px - 1, deck_y - 4, px + 3, deck_y - 4, wood_l)
    for px in range(6, 70, 13):
        img.line(px + 3, deck_y + 8, px + 13, deck_y + 12, wood_d)
    # Laternenpfaehle
    for lx in (8, 46):
        img.rect(lx, deck_y - 15, lx + 1, deck_y - 1, wood_m)
        img.rect(lx, deck_y - 15, lx, deck_y - 1, wood_l)
        img.rect(lx - 2, deck_y - 16, lx + 3, deck_y - 16, wood_m)
        glow(img, lx + 1, deck_y - 19, hx("#ffe9a8"), GOLD, hx("#6b4a26"), 5)
    # Langboot am Steg (links), vorne im Wasser
    bx, by = 10, WL + 2
    for x in range(bx, bx + 38):
        t = (x - bx - 18.5) / 19.0
        topb = by - 1 - round(5 * t * t * t * t * 2 + 3 * t * t)
        for y in range(topb, by + 5):
            c = hx("#4f3826") if (x // 5) % 2 else hx("#6b4a33")
            if y == topb:
                c = hx("#8a6a48")
            elif y == topb + 1:
                c = sh(c, 1)
            if y >= by:
                c = sh(c, -2)
            img.set(x, y, c)
    img.polyline([(bx, by - 8), (bx - 2, by - 11)], hx("#40301f"), 2)
    img.polyline([(bx + 37, by - 8), (bx + 39, by - 11)], hx("#40301f"), 2)
    for sx in range(bx + 7, bx + 32, 6):
        img.rect(sx, by - 3, sx + 2, by - 2, hx("#8c2d2d"))
        img.set(sx, by - 3, hx("#b14040"))
    img.rect(bx + 14, by - 2, bx + 22, by - 2, hx("#2a1f15"))
    # Fass, Kisten, Seilrolle auf dem Steg
    for fx_ in (58, 66):
        img.rect(fx_, deck_y - 8, fx_ + 5, deck_y - 1, hx("#5a3e28"))
        img.rect(fx_, deck_y - 8, fx_, deck_y - 1, hx("#7a5538"))
        img.rect(fx_, deck_y - 6, fx_ + 5, deck_y - 6, hx("#2a2218"))
        img.rect(fx_, deck_y - 3, fx_ + 5, deck_y - 3, hx("#2a2218"))
    img.rect(72, deck_y - 6, 78, deck_y - 1, hx("#6a4e34"))
    img.rect(72, deck_y - 6, 78, deck_y - 6, hx("#8a6a48"))
    img.outline(OUT)
    return img


# --- 6 Wrack ---------------------------------------------------------------------------------

def make_wrack():
    img = Img(CELL_W, CELL_H)
    wl_, wm, wd = hx("#5a4a38"), hx("#41352a"), hx("#2a2119")
    alg, algd = hx("#41614c"), hx("#2b4333")
    # Kiel
    for x in range(8, 112):
        y = WL + 1 - round(3 * math.sin((x - 8) / 104.0 * math.pi) ** 0.5) + 2
        img.rect(x, y, x, y + 3, wd)
        img.set(x, y, wm)
    # Spanten (Bug links = nackte Rippen, Heck rechts = Plankenreste)
    ribs = [(14, 24), (24, 31), (34, 36), (44, 39), (54, 40), (64, 40)]
    for i, (rx, rh) in enumerate(ribs):
        for k in range(rh):
            u = k / float(rh)
            x = rx - round(7 * u ** 1.6) + round(0.5 * math.sin(i * 2.3 + k * 0.4))
            y = WL + 1 - k
            c = wl_ if k % 5 else wm
            img.set(x, y, wm if u > 0.5 else c)
            img.set(x + 1, y, wd if u > 0.3 else wm)
            img.set(x - 1, y, wl_) if u < 0.8 else None
        # abgebrochene Spitze
        tipx = rx - 7
        img.rect(tipx - 1, WL + 1 - rh, tipx + 1, WL + 1 - rh, wl_)
    # Planken am Heck
    for x in range(66, 108):
        t = (x - 66) / 42.0
        top = WL - 14 - round(16 * t ** 2)
        for y in range(top, WL + 5):
            band = (y - top) // 4
            c = wl_ if (x // 8 + band) % 2 else wm
            if (y - top) % 4 == 3:
                c = wd
            if x > 96:
                c = sh(c, -1)
            if (y - top) == 0:
                c = sh(c, 1)
            if noise(x, y) < 22:
                c = wd
            img.set(x, y, c)
    # Luecken in den Planken (Dither)
    punch(img, 66, WL - 20, 108, WL - 4, lambda x, y: not (noise(x // 2, y // 2) < 38 and (x + y) % 2 == 0))
    # Achtersteven
    post = [(106, WL - 28), (109, WL - 36), (106, WL - 43)]
    img.polyline(post, wm, 3)
    img.line(105, WL - 28, 108, WL - 36, wl_, 1)
    # gebrochener Mast mit Segelfetzen
    img.polyline([(72, WL - 12), (66, WL - 30), (64, WL - 44)], wm, 3)
    img.line(71, WL - 12, 65, WL - 30, wl_, 1)
    for jx, jy in [(63, WL - 46), (64, WL - 47), (66, WL - 45), (62, WL - 45)]:
        img.set(jx, jy, wl_)
    # Rah schraeg, daran Segelfetzen
    img.line(48, WL - 33, 76, WL - 41, wm, 2)
    for i in range(0, 26, 1):
        x = 49 + i
        ln = 5 + noise(x, 3) % 6 + (6 if i % 7 == 0 else 0)
        for j in range(ln):
            if j > 3 and (x + j) % 2 == 0 and j > ln - 4:
                continue
            c = hx("#7a8680") if j < 2 else (hx("#5e6a66") if i % 3 else hx("#4a5654"))
            img.set(x, WL - 32 + round(0.27 * i) - 7 + j + 0, c)
    # Tauwerk
    img.line(76, WL - 41, 98, WL - 22, hx("#241b14"))
    img.line(48, WL - 33, 40, WL - 12, hx("#241b14"))
    # Algen und Seetang
    for x in (14, 24, 34, 44, 54, 66, 80, 94):
        for i in range(noise(x, 7) % 6 + 4):
            img.set(x - 7 + (1 if i % 2 else 0), WL - 8 + i, alg if i % 3 else algd)
    # Moeve? nein. Ein Schild treibt davor (rot)
    shaded_disc(img, 30, WL + 4, 3, (hx("#b14040"), hx("#8c2d2d"), hx("#5e1c1f"), hx("#3c1414")))
    img.outline(OUT)
    return img


# --- 7 Seeungeheuer -------------------------------------------------------------------------------

def make_ungeheuer():
    img = Img(CELL_W, CELL_H)
    pal = (hx("#4a6a66"), hx("#2f4a4a"), hx("#1f3436"), hx("#142428"))

    def tex(x, y, c, k):
        # Schuppen: Rautenmuster, dazwischen Lichter
        if (x + y // 2) % 4 == 0 and y % 2 == 0:
            return sh(c, -1)
        if (x + 2 + y // 2) % 8 == 0 and y % 2 == 1 and k <= 1:
            return sh(c, 1)
        return c

    # Rueckenbuckel im Wasser (rechts)
    for (hx_, r) in [(104, 7), (88, 9)]:
        shaded_disc(img, hx_, WL + 3, r, pal, tex)
    # Hals (S-Kurve) von der Basis nach links oben zum Kopf
    pts = []
    for i in range(0, 61):
        t = i / 60.0
        x = 76 - 40 * t + 6 * math.sin(t * math.pi * 1.4)
        y = WL + 4 - 46 * math.sin(t * math.pi * 0.58) ** 1.1
        pts.append((x, y, 7 - 3.2 * t))
    for (x, y, r) in pts:
        shaded_disc(img, round(x), round(y), max(2, round(r)), pal, tex)
    # Bauchschuppen (hell) an der Vorderseite des Halses
    for (x, y, r) in pts[5:55:2]:
        img.set(round(x) - round(r) + 1, round(y) + 1, hx("#7a8a78"))
    # Rueckenflossen entlang der Halskruemmung
    for (x, y, r) in pts[4:52:6]:
        bx, by = round(x) + round(r) - 1, round(y) - round(r) + 1
        for j in range(5):
            img.set(bx + j // 2 + 1, by - j + 1, hx("#7a3a2a") if j < 3 else hx("#a85a3a"))
            img.set(bx + j // 2, by - j + 1, hx("#4a2a22"))
    # Kopf
    hx0, hy0 = round(pts[-1][0]), round(pts[-1][1])
    shaded_disc(img, hx0 - 2, hy0, 6, pal, tex)
    # Schnauze und Unterkiefer (geoeffnet, zeigt nach links unten)
    img.polyline([(hx0 - 5, hy0 - 1), (hx0 - 13, hy0 + 1)], pal[1], 5)
    img.polyline([(hx0 - 5, hy0 + 3), (hx0 - 12, hy0 + 8)], pal[2], 3)
    img.line(hx0 - 12, hy0 - 3, hx0 - 6, hy0 - 3, pal[0], 1)
    img.line(hx0 - 12, hy0 + 3, hx0 - 6, hy0 + 5, hx("#5a1c1f"), 1)
    for tx in range(hx0 - 12, hx0 - 6, 2):
        img.set(tx, hy0 + 2, BONE)
        img.set(tx + 1, hy0 + 5 + (tx - hx0 + 12) // 3, BONE)
    # Augen: gold, sparsamer Akzent
    img.rect(hx0 - 4, hy0 - 3, hx0 - 3, hy0 - 2, GOLD)
    img.set(hx0 - 4, hy0 - 2, OUT)
    # Hoerner
    img.line(hx0 + 1, hy0 - 5, hx0 + 4, hy0 - 10, hx("#a89c7e"), 1)
    img.line(hx0 + 3, hy0 - 4, hx0 + 8, hy0 - 8, hx("#7a705a"), 1)
    # Wirbel aus Schaum (gedithert) am Fuss des Halses
    for x in range(58, 114):
        for dy in (0, 1):
            if (x + dy) % 2 == 0 and noise(x, dy + 77) < 170:
                img.put_empty(x, WL + dy, hx("#9fb0b2") if dy == 0 else hx("#6a7e82"))
    img.outline(OUT)
    return img


# --- 8 Kraken (Kopf) -----------------------------------------------------------------------------

def make_kraken_kopf():
    img = Img(CELL_W, CELL_H)
    L, M, D, DD = hx("#6a5a82"), hx("#463b5c"), hx("#2e2640"), hx("#1d1829")
    pal = (L, M, D, DD)

    def skin(x, y, c, k):
        n = noise(x // 2, y // 2)
        if n < 34:
            return sh(c, -1)
        if n > 228 and k < 3:
            return sh(c, 1)
        return c

    # Mantel: gekippte Ellipse, nach hinten rechts oben
    ang = math.radians(-52)
    ca, sa = math.cos(ang), math.sin(ang)
    mx, my, ra, rb = 70, WL - 28, 30, 15
    for y in range(WL - 70, WL + 24):
        for x in range(30, 120):
            dx, dy = x - mx, y - my
            u = (dx * ca + dy * sa) / ra
            v = (-dx * sa + dy * ca) / rb
            taper = 1.0 - 0.45 * max(u, 0.0) ** 2
            if u * u + (v / max(taper, 0.2)) ** 2 > 1.0:
                continue
            s = (dx * 0.5 + dy * 0.6) / 18.0
            k = 0 if s < -0.45 else (1 if s < 0.1 else (2 if s < 0.5 else 3))
            c = skin(x, y, pal[k], k)
            # Laengsstreifen des Mantels
            if int(v * 5.0 + 20) % 3 == 0 and k < 3:
                c = sh(c, -1)
            img.set(x, y, c)
    # Flossen an der Spitze
    for sgn in (-1, 1):
        px, py = 92, WL - 52
        for i in range(8):
            img.set(px + i // 2 + sgn * (i // 3), py - i // 2 + i, sh(M, -1) if sgn > 0 else M)
    # Kopf: Scheibe vorne links, mit den Augen
    shaded_disc(img, 52, WL - 7, 17, pal, skin)
    shaded_disc(img, 52, WL - 4, 12, pal, skin)
    for ex in (43, 59):
        ey = WL - 12
        img.rect(ex - 3, ey - 3, ex + 3, ey + 3, DD)
        img.rect(ex - 2, ey - 2, ex + 2, ey + 2, hx("#a8832e"))
        img.rect(ex - 2, ey - 2, ex + 1, ey - 2, GOLD)
        img.rect(ex - 1, ey - 1, ex, ey - 1, hx("#ffe9a8"))
        img.rect(ex, ey - 2, ex, ey + 2, OUT)
        img.rect(ex - 4, ey - 5, ex + 3, ey - 4, DD)
        img.rect(ex - 4, ey - 6, ex - 1, ey - 6, D)
    # Trichter / Schnabel
    img.rect(49, WL - 2, 54, WL + 1, DD)
    img.set(50, WL - 1, hx("#b9a8c8"))
    img.set(53, WL - 1, hx("#b9a8c8"))
    # Hautflecken
    for i in range(16):
        x = 34 + noise(i, 31) % 60
        y = WL - 50 + noise(i, 32) % 40
        if img.get(x, y) is not None and img.get(x, y) != OUT:
            img.set(x, y, sh(L, 1))
            img.set(x + 1, y, L)
    # Schaum am Wasser (gedithert)
    for x in range(26, 112):
        if (x + WL) % 2 == 0 and noise(x, 91) < 180:
            img.put_empty(x, WL, hx("#8f98ac"))
        if x % 3 == 0 and noise(x, 92) < 140:
            img.put_empty(x, WL + 1, hx("#5a6480"))
    img.outline(OUT)
    return img


# --- 9-11 Tentakel (je zwei Frames zu 64x96, Anker (32, 80)) ---------------------------------------

def tentacle_frame(variant, frame):
    img = Img(64, CELL_H)
    pal = (hx("#6a5a82"), hx("#463b5c"), hx("#2e2640"), hx("#1d1829"))
    steps = 74
    x, y = 32.0, 84.0
    theta = -math.pi / 2
    ph = frame * 0.9 + variant * 1.7
    sway = [1.0, -1.0, 0.0][variant]
    curl_dir = [-1.0, 1.0, -1.0][variant]
    pts = []
    for i in range(steps):
        t = i / float(steps - 1)
        k = 0.012 * math.sin(t * 7.0 + ph) * (1.0 + t) + sway * 0.006 * (1 if frame == 0 else 1.6)
        if t > 0.72:
            k += curl_dir * (0.02 + 0.2 * (t - 0.72) ** 1.2) * (1.0 + 0.3 * frame)
        theta += k
        x += math.cos(theta)
        y += math.sin(theta)
        r = 1.0 + 5.4 * (1.0 - t) ** 1.15
        pts.append((x, y, r, theta))
    for (px, py, r, th) in pts:
        shaded_disc(img, round(px), round(py), max(1, round(r)), pal)
    # Saugnaepfe auf der Innenseite (zum Schiff, also je nach Variante)
    side = -curl_dir
    for i in range(6, steps - 4, 5):
        px, py, r, th = pts[i]
        nx, ny = -math.sin(th) * side, math.cos(th) * side
        sx, sy = round(px + nx * (r - 0.6)), round(py + ny * (r - 0.6))
        if r >= 2:
            img.set(sx, sy, hx("#b9a8c8"))
            img.set(sx - round(nx), sy - round(ny), hx("#7a6a92"))
    # Tropfen / Schaum am Fuss (gedithert)
    for dx in range(-9, 10):
        if (dx + 84) % 2 == 0 and noise(dx, 40 + frame) < 190:
            img.put_empty(32 + dx, 80, hx("#8f98ac"))
        if dx % 3 == 0:
            img.put_empty(32 + dx, 81, hx("#5a6480"))
    img.outline(OUT)
    return img


# --- 12 Lokis Spielschiff -------------------------------------------------------------------------

def make_spieler():
    img = Img(CELL_W, CELL_H)
    pal = {"L": hx("#3f4d56"), "M": hx("#2a343c"), "rail": hx("#52656f")}
    cx, wl = AX, WL
    green, green_d, mint = hx("#5fe0a0"), hx("#2c8a62"), hx("#d8ffe8")
    violet, violet_d = hx("#6b3f96"), hx("#3b2356")
    top = hull(img, cx, wl, 38, 11, 9, 22, 14, pal, bow_extra=3, stern_extra=3, plank=11)
    for x in range(cx - 36, cx + 37):
        for dy in (9, 14):
            y = top(x) + dy
            if y < wl + 4:
                img.set(x, y, sh(img.get(x, y) or pal["M"], -2))
    # hohe Steven; am Bug eine grinsende Maske
    for sgn in (-1, 1):
        px = cx + sgn * 38
        pts = [(px, top(px)), (px + sgn * 2, wl - 26), (px + sgn * 1, wl - 31)]
        img.polyline(pts, pal["M"], 3)
        img.polyline([(p[0] - 1, p[1]) for p in pts], pal["L"], 1)
    mx, my = cx - 40, wl - 34
    img.disc(mx, my, 5, hx("#cfd8d0"))
    img.disc(mx - 1, my - 1, 3, hx("#e8f0ea"))
    img.set(mx - 2, my - 1, green)
    img.set(mx + 2, my - 1, green)
    for k in range(-3, 4):
        img.set(mx + k, my + 3 - (1 if abs(k) == 3 else 0), hx("#1c2a24"))
    img.set(mx - 3, my + 2, hx("#1c2a24"))
    img.set(mx + 3, my + 2, hx("#1c2a24"))
    # grünes Leuchten um den Automaten (nur auf leeren Pixeln, gedithert)
    ax, ay = cx + 4, top(cx) - 15
    for dy in range(-17, 18):
        for dx in range(-17, 18):
            d2 = dx * dx + dy * dy
            if 120 < d2 <= 289 and (ax + dx + ay + dy) % 2 == 0:
                img.put_empty(ax + dx, ay + dy, hx("#1f5a42"))
            elif 60 < d2 <= 120 and (ax + dx + ay + dy) % 4 == 0:
                img.put_empty(ax + dx, ay + dy, hx("#2c8a62"))
    # der Automat: Gehäuse, Lampenkranz, Fenster mit drei Walzen, Hebel
    bx0, bx1, by0, by1 = cx - 8, cx + 16, top(cx) - 28, top(cx) + 1
    img.rect(bx0, by0, bx1, by1, violet_d)
    img.rect(bx0, by0, bx0, by1, violet)
    img.rect(bx0, by0, bx1, by0, GOLD)
    img.rect(bx0, by1 - 3, bx1, by1 - 3, GOLD)
    img.rect(bx0 + 1, by0 - 3, bx1 - 1, by0 - 1, violet)
    for k in range(bx0 + 2, bx1 - 1, 3):
        img.set(k, by0 - 2, green if (k // 3) % 2 else GOLD)
    img.rect(bx0 + 3, by0 + 4, bx1 - 3, by0 + 15, hx("#0e1a16"))
    img.rect(bx0 + 3, by0 + 4, bx1 - 3, by0 + 4, GOLD)
    for i, col in enumerate((green, GOLD, hx("#e0645a"))):
        rx = bx0 + 5 + i * 6
        img.rect(rx, by0 + 6, rx + 3, by0 + 13, hx("#d9e8df"))
        img.rect(rx + 1, by0 + 8, rx + 2, by0 + 11, col)
    img.rect(bx0 + 3, by0 + 17, bx1 - 3, by0 + 19, hx("#16102a"))
    img.set(bx0 + 6, by0 + 18, GOLD)
    img.set(bx0 + 12, by0 + 18, GOLD)
    # Hebel an der rechten Seite
    img.line(bx1 + 1, by0 + 12, bx1 + 5, by0 + 4, hx("#9aa6a0"), 1)
    img.disc(bx1 + 5, by0 + 3, 2, hx("#e0645a"))
    # Mast mit zerfetztem violettem Segel
    mxp = cx - 24
    img.rect(mxp - 1, wl - 60, mxp + 1, top(mxp), pal["M"])
    img.rect(mxp - 1, wl - 60, mxp - 1, top(mxp), pal["L"])
    img.rect(mxp - 14, wl - 56, mxp + 12, wl - 55, pal["M"])

    def rag(x):
        return wl - 30 + noise(x // 3, 5) % 6 + (4 if (x // 5) % 3 == 0 else 0)

    sail_rect(img, mxp - 13, mxp + 11, wl - 54, rag, {"M": violet_d}, belly=2.5)
    for hx0, hy0 in ((mxp - 5, wl - 44), (mxp + 4, wl - 38), (mxp - 9, wl - 36)):
        img.rect(hx0, hy0, hx0 + 1, hy0 + 1, None)
    img.set(mxp, wl - 62, green)
    img.outline(OUT)
    glow(img, cx + 37, wl - 36, mint, green, hx("#1f5a42"), 5)
    glow(img, mxp, wl - 64, mint, green, hx("#1f5a42"), 4)
    return img


# --- Atlas ------------------------------------------------------------------------------------------

MAKERS = [make_draugr, make_raeuber, make_haendler, make_insel, make_dorf, make_hafen, make_wrack,
          make_ungeheuer, make_kraken_kopf]


def build():
    rows = 4
    atlas = Img(CELL_W * COLS, CELL_H * rows)
    for i, fn in enumerate(MAKERS):
        atlas.blit(fn(), (i % COLS) * CELL_W, (i // COLS) * CELL_H)
    atlas.blit(make_spieler(), 0, 3 * CELL_H)
    for v in range(3):
        i = 9 + v
        ox, oy = (i % COLS) * CELL_W, (i // COLS) * CELL_H
        for f in range(2):
            atlas.blit(tentacle_frame(v, f), ox + f * 64, oy)
    return atlas


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    assets = os.path.join(here, "..", "assets")
    t0 = time.time()
    atlas = build()
    atlas.save(os.path.join(assets, "enemies.png"))
    print("assets/enemies.png geschrieben (%dx%d, %.1fs)" % (atlas.w, atlas.h, time.time() - t0))
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        bg = hx("#4a5a6a")
        atlas.filled_bg(bg).scaled(3).save(os.path.join(out, "enemies_atlas.png"))
        for i in list(range(9)) + [12]:
            cell = Img(CELL_W, CELL_H)
            for y in range(CELL_H):
                for x in range(CELL_W):
                    cell.px[y][x] = atlas.px[(i // COLS) * CELL_H + y][(i % COLS) * CELL_W + x]
            cell.filled_bg(bg).scaled(5).save(os.path.join(out, "enemy_%d.png" % i))
        print("Vorschau in", out)


if __name__ == "__main__":
    main()
