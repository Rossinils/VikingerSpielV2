#!/usr/bin/env python3
"""Pixelbilder für die Spielautomaten: assets/slots.png.

Zeile 0: die elf Symbole zu 32x32 in der Reihenfolge von Slots.Sym
         (Schild, Axt, Horn, Rabe, Drachenschiff, Mjölnir, Draugr, Odinsauge, Blitzrune, Wolf, Maske),
         danach als zwölftes Bild die Pfandflasche.
Zeile 1: Münze in vier Drehstellungen (je 12x12) ab x=0, dann ein Funke (4x4) bei x=60.

Aufruf:  python tools/make_slot_art.py [--preview ordner]
"""

import math
import os
import struct
import sys
import zlib


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def sh(c, k):
    f = {-3: 0.5, -2: 0.64, -1: 0.82, 0: 1.0, 1: 1.14, 2: 1.28}[k]
    return (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), 255)


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

    def disc(self, cx, cy, r, c):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy <= r * r + r * 0.4:
                    self.set(cx + dx, cy + dy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

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

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        n = len(pts)
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                    xs.append(x0 + (y + 0.5 - y0) / (y1 - y0) * (x1 - x0))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(round(xs[k]), round(xs[k + 1])):
                    self.set(x, y, c)

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

        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, "wb") as f:
            f.write(png)


INK = hx("#0d0b10")
CREAM = hx("#e8dfc2")
GOLD = hx("#e3b94a")
STEEL = hx("#a9b3c0")
WOOD = hx("#8a5a34")
RED = hx("#c4493f")
GREEN = hx("#62e0a0")


def bez(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]))
    return out


def new():
    return Img(32, 32)


def schild():
    im = new()
    im.disc(16, 16, 14, hx("#5c6672"))
    im.disc(16, 16, 12, CREAM)
    for y in range(32):
        for x in range(32):
            dx, dy = x - 16, y - 16
            if dx * dx + dy * dy <= 144 and im.get(x, y) is not None:
                a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 8
                if int(a) % 2 == 0:
                    im.set(x, y, RED)
                if dx * dx + dy * dy > 121:
                    im.set(x, y, sh(RED if int(a) % 2 == 0 else CREAM, -1))
    im.disc(16, 16, 5, STEEL)
    im.disc(15, 15, 3, sh(STEEL, 1))
    im.set(14, 14, hx("#ffffff"))
    im.disc(16, 16, 1, GOLD)
    im.outline(INK)
    return im


def axt():
    im = new()
    im.line(8, 28, 21, 7, WOOD, 3)
    im.line(7, 28, 20, 7, sh(WOOD, 1), 1)
    im.poly([(17, 5), (24, 2), (29, 8), (28, 16), (22, 14), (19, 10)], STEEL)
    im.poly([(19, 6), (24, 4), (27, 8)], sh(STEEL, 2))
    im.line(23, 14, 28, 15, sh(STEEL, -2), 1)
    im.line(19, 10, 22, 14, sh(STEEL, -1), 1)
    im.rect(8, 25, 10, 28, GOLD)
    im.outline(INK)
    return im


def horn():
    im = new()
    pts = bez((5, 25), (6, 6), (27, 5), 30)
    for i, (x, y) in enumerate(pts):
        t = i / (len(pts) - 1)
        r = round(4.5 * (1 - t) + 1.2 * t)
        im.disc(round(x), round(y), max(r, 1), CREAM if t > 0.3 else sh(CREAM, -1))
    for i, (x, y) in enumerate(pts):
        t = i / (len(pts) - 1)
        r = round(4.5 * (1 - t) + 1.2 * t)
        im.set(round(x) - 1, round(y) - max(r - 1, 0), sh(CREAM, 1))
    # Goldrand an der Öffnung, Band in der Mitte
    for t0, col in ((0.0, GOLD), (0.5, GOLD)):
        x, y = pts[int(t0 * (len(pts) - 1))]
        im.disc(round(x), round(y), 4 if t0 == 0.0 else 3, col)
    x, y = pts[0]
    im.disc(round(x), round(y), 2, hx("#3b2a18"))
    im.outline(INK)
    return im


def rabe():
    im = new()
    dark, mid = hx("#2a2c3a"), hx("#454a60")
    im.ellipse(15, 19, 9, 6, dark)
    im.poly([(8, 17), (2, 8), (9, 11), (17, 15)], mid)
    im.poly([(6, 19), (1, 28), (10, 24)], dark)
    im.ellipse(23, 12, 5, 4.5, dark)
    im.poly([(26, 11), (31, 13), (26, 15)], hx("#e08a2e"))
    im.set(24, 10, hx("#ffffff"))
    im.set(25, 10, hx("#ffe9a8"))
    im.line(14, 25, 14, 29, hx("#e08a2e"), 1)
    im.line(18, 25, 19, 29, hx("#e08a2e"), 1)
    im.line(10, 17, 14, 21, sh(mid, 1), 1)
    im.outline(INK)
    return im


def schiff():
    im = new()
    for x in range(2, 31):
        t = (x - 16) / 14.0
        top = 20 - round(4 * t * t)
        bot = 26 - round(5 * abs(t) ** 1.8)
        for y in range(top, bot + 1):
            im.set(x, y, WOOD if (y - top) > 1 else sh(WOOD, 1))
    im.line(2, 20, 3, 13, WOOD, 2)
    im.disc(3, 12, 2, GOLD)
    im.line(29, 19, 30, 16, WOOD, 1)
    im.rect(15, 5, 16, 20, hx("#5a3b22"))
    for x in range(9, 24):
        for y in range(6, 17):
            if abs(x - 16) <= 7 - (y - 6) // 6:
                im.set(x, y, RED if (x // 3) % 2 == 0 else CREAM)
    im.line(4, 27, 28, 27, hx("#4d86c9"), 1)
    im.set(8, 28, hx("#a8d4ff"))
    im.set(20, 28, hx("#a8d4ff"))
    im.outline(INK)
    return im


def hammer():
    im = new()
    im.rect(14, 12, 18, 29, WOOD)
    im.rect(14, 12, 14, 29, sh(WOOD, 1))
    for y in range(15, 29, 4):
        im.rect(14, y, 18, y, sh(WOOD, -2))
    im.rect(5, 4, 27, 13, STEEL)
    im.rect(5, 4, 27, 5, sh(STEEL, 2))
    im.rect(5, 12, 27, 13, sh(STEEL, -2))
    im.rect(3, 6, 5, 11, sh(STEEL, -1))
    im.rect(27, 6, 29, 11, sh(STEEL, -1))
    for x in (9, 13, 17, 21):
        im.line(x, 7, x + 1, 10, GOLD, 1)
    im.set(10, 6, hx("#ffffff"))
    im.outline(INK)
    return im


def draugr():
    im = new()
    skin, dk = hx("#9db39a"), hx("#5d7a63")
    # Elektroden am Hals (Frankenstein-Gruß)
    im.rect(3, 21, 7, 23, STEEL)
    im.rect(24, 21, 28, 23, STEEL)
    im.disc(3, 22, 2, GOLD)
    im.disc(28, 22, 2, GOLD)
    # Schädel mit flachem Scheitel
    im.rect(8, 5, 23, 24, skin)
    im.rect(7, 8, 24, 21, skin)
    im.rect(8, 5, 23, 7, sh(skin, 1))
    im.rect(8, 22, 23, 24, dk)
    # Helm mit Hörnern
    im.rect(7, 3, 24, 7, hx("#5c6672"))
    im.rect(7, 3, 24, 3, hx("#8d99a8"))
    im.poly([(7, 5), (2, 2), (4, 9)], CREAM)
    im.poly([(24, 5), (29, 2), (27, 9)], CREAM)
    # Narbe quer über die Stirn, Nähte
    im.line(10, 9, 21, 10, hx("#2a3a2c"), 1)
    for x in range(11, 21, 3):
        im.line(x, 8, x, 11, hx("#2a3a2c"), 1)
    # Augen: grün leuchtend
    for ex in (11, 19):
        im.rect(ex - 2, 12, ex + 2, 15, hx("#16241a"))
        im.rect(ex - 1, 13, ex + 1, 14, GREEN)
        im.set(ex, 13, hx("#e8fff2"))
    im.rect(15, 16, 16, 18, dk)
    for x in range(10, 22):
        if x % 3 != 0:
            im.rect(x, 20, x, 22, hx("#d9d2b8"))
    im.line(10, 20, 21, 20, hx("#16241a"), 1)
    im.outline(INK)
    return im


def auge():
    im = new()
    # Strahlen
    for a in range(0, 360, 30):
        r0, r1 = 13, 15.5
        x0 = 16 + r0 * math.cos(math.radians(a))
        y0 = 16 + r0 * math.sin(math.radians(a))
        x1 = 16 + r1 * math.cos(math.radians(a))
        y1 = 16 + r1 * math.sin(math.radians(a))
        im.line(round(x0), round(y0), round(x1), round(y1), GOLD, 1)
    im.disc(16, 16, 12, hx("#3a2a58"))
    # Mandelauge
    for x in range(3, 30):
        t = (x - 16) / 13.5
        h = round(7 * math.sqrt(max(0.0, 1 - t * t)))
        for y in range(16 - h, 17 + h):
            im.set(x, y, hx("#f4efe0"))
        im.set(x, 16 - h, GOLD)
        im.set(x, 16 + h, GOLD)
    im.disc(16, 16, 5, hx("#3f8de0"))
    im.disc(16, 16, 3, hx("#0d0b10"))
    im.set(14, 14, hx("#ffffff"))
    im.set(15, 14, hx("#ffffff"))
    im.outline(INK)
    return im


def blitz():
    im = new()
    im.disc(16, 16, 14, hx("#3a2f66"))
    im.disc(16, 16, 12, hx("#241c47"))
    for a in range(0, 360, 45):
        x = 16 + 13 * math.cos(math.radians(a))
        y = 16 + 13 * math.sin(math.radians(a))
        im.set(round(x), round(y), hx("#7fd3ff"))
    bolt = [(19, 3), (8, 18), (15, 18), (11, 29), (25, 12), (17, 12), (22, 3)]
    im.poly(bolt, hx("#ffe14a"))
    im.poly([(19, 5), (11, 17), (16, 17), (13, 25), (22, 13), (16, 13), (20, 5)], hx("#fff6b0"))
    im.set(20, 4, hx("#ffffff"))
    im.outline(INK)
    return im


def wolf():
    im = new()
    fur, dk = hx("#8f98a8"), hx("#5a6272")
    im.poly([(6, 4), (11, 11), (7, 12)], dk)
    im.poly([(26, 4), (21, 11), (25, 12)], dk)
    im.ellipse(16, 17, 11, 10, fur)
    im.poly([(10, 22), (22, 22), (19, 30), (13, 30)], sh(fur, 1))
    im.rect(14, 27, 18, 29, hx("#1c1c24"))
    im.set(10, 13, hx("#ffd84a"))
    im.rect(9, 14, 11, 15, hx("#16141c"))
    im.rect(21, 14, 23, 15, hx("#16141c"))
    im.rect(10, 13, 12, 14, hx("#ffd84a"))
    im.rect(20, 13, 22, 14, hx("#ffd84a"))
    for x in (13, 15, 17, 19):
        im.poly([(x, 24), (x + 2, 24), (x + 1, 27)], hx("#f4efe0"))
    im.line(12, 9, 14, 12, dk, 1)
    im.line(20, 9, 18, 12, dk, 1)
    im.outline(INK)
    return im


def maske():
    im = new()
    pale, dk = hx("#d7e8d8"), hx("#4b8a6a")
    im.poly([(9, 8), (2, 1), (6, 13)], dk)
    im.poly([(23, 8), (30, 1), (26, 13)], dk)
    im.ellipse(16, 17, 11, 13, pale)
    for y in range(4, 31):
        for x in range(16, 28):
            c = im.get(x, y)
            if c == pale:
                im.set(x, y, dk)
    im.poly([(7, 12), (14, 14), (13, 17), (6, 16)], hx("#16141c"))
    im.poly([(25, 12), (18, 14), (19, 17), (26, 16)], hx("#16141c"))
    im.set(10, 14, GREEN)
    im.set(11, 14, GREEN)
    im.set(21, 14, GREEN)
    im.set(22, 14, GREEN)
    for x in range(8, 25):
        yy = 23 + round(3 * math.sin((x - 8) / 16 * math.pi))
        im.set(x, yy, hx("#16141c"))
        im.set(x, yy + 1, hx("#16141c"))
    for x in range(10, 23, 2):
        im.set(x, 24 + round(3 * math.sin((x - 8) / 16 * math.pi)) - 1, hx("#fff8e0"))
    im.line(16, 15, 16, 19, sh(pale, -2), 1)
    im.outline(INK)
    return im


def flasche():
    """Die Pfandflasche: Bügelflasche aus Bernsteinglas, Etikett mit Goldmünze, ein paar goldene Funken (legendär)."""
    im = new()
    glass, dk, hi = hx("#c7852b"), hx("#7a4a14"), hx("#f1c66a")
    im.rect(13, 7, 18, 14, glass)
    im.poly([(13, 13), (19, 13), (24, 19), (8, 19)], glass)
    im.rect(8, 19, 23, 28, glass)
    im.rect(10, 20, 11, 27, hi)
    im.rect(14, 8, 14, 13, hi)
    im.rect(21, 20, 22, 27, dk)
    im.rect(17, 8, 18, 13, dk)
    im.rect(12, 3, 19, 6, hx("#efe9d8"))
    im.rect(12, 3, 19, 3, hx("#ffffff"))
    im.line(19, 5, 23, 9, hx("#b0b6bf"), 1)
    im.line(23, 9, 23, 14, hx("#b0b6bf"), 1)
    im.rect(9, 21, 22, 26, hx("#efe5c4"))
    im.disc(15, 23, 2, GOLD)
    im.set(15, 22, hx("#fff6b0"))
    im.rect(8, 28, 23, 29, dk)
    for x, y in ((4, 8), (27, 10), (3, 20), (28, 25), (6, 3)):
        im.set(x, y, GOLD)
        im.set(x - 1, y, hx("#fff6b0"))
        im.set(x + 1, y, hx("#fff6b0"))
        im.set(x, y - 1, hx("#fff6b0"))
        im.set(x, y + 1, hx("#fff6b0"))
    im.outline(INK)
    return im


def coin(phase):
    """Münze in vier Stellungen: breit, schmal, Kante, schmal (Spiegelung)."""
    im = Img(12, 12)
    widths = [5, 3, 1, 3]
    w = widths[phase]
    im.ellipse(5.5, 5.5, w + 0.5, 5.2, GOLD)
    if w >= 3:
        im.ellipse(5.5, 5.5, max(w - 1.5, 0.7), 3.6, sh(GOLD, 1))
        im.set(4, 4, hx("#fff6b0"))
    im.outline(hx("#5c3d12"))
    return im


def build():
    syms = [schild, axt, horn, rabe, schiff, hammer, draugr, auge, blitz, wolf, maske, flasche]  # Zelle 11: Pfandflasche
    atlas = Img(32 * len(syms), 48)
    for i, fn in enumerate(syms):
        atlas.blit(fn(), i * 32, 0)
    for p in range(4):
        atlas.blit(coin(p), p * 12, 32)
    for dx, dy in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
        atlas.set(60 + dx, 33 + dy, hx("#fff6b0"))
    return atlas


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    atlas = build()
    atlas.save(os.path.join(here, "..", "assets", "slots.png"))
    print("assets/slots.png geschrieben (%dx%d)" % (atlas.w, atlas.h))
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(out, exist_ok=True)
        atlas.filled_bg(hx("#2a3038")).scaled(4).save(os.path.join(out, "slots_atlas.png"))
        print("Vorschau in", out)


if __name__ == "__main__":
    main()
