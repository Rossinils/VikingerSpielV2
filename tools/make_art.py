"""Erzeugt die Pixelart-Assets (reines Python, keine Abhaengigkeiten).

Aufruf:
    python tools/make_art.py                    -> schreibt nach assets/
    python tools/make_art.py --preview ordner   -> zusaetzlich Vorschaubilder in ordner

assets/ship.png: Atlas aus Neigungsframes (Spalten, -37.5..+37.5 Grad) mal Segelstufen (Zeilen,
eingeholt .. voll). Die Frames werden einmal vorgerendert (RotSprite-aehnlich: 4x4-Supersampling
mit Mehrheitsfarbe), damit Godot das Sprite nicht mit Nearest-Filter verdrehen muss.
assets/crew.png: 7 Gesichter (Zeilen) mal 5 Posen (Spalten: Stehen, Arbeit A, Arbeit B,
Schwimmen A, Schwimmen B).

Licht kommt von oben links: helle Oberkanten, dunkle Unterkanten, Schlagschatten nach unten rechts.
Alles harte Pixel, kein Weichzeichnen.
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
    """Farbe abdunkeln (k<0) oder aufhellen (k>0); Schatten leicht ins Kalte."""
    f = {-3: 0.5, -2: 0.64, -1: 0.82, 0: 1.0, 1: 1.14, 2: 1.28}[k]
    cool = 0.07 if k < 0 else 0.0
    return (
        min(255, int(c[0] * f)),
        min(255, int(c[1] * f)),
        min(255, int(c[2] * min(1.0, f + cool * -k))),
        255,
    )


def mix(a, b, t):
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
        255,
    )


def tone(ramp, i):
    return ramp[max(0, min(len(ramp) - 1, i))]


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

    def outline_sel(self, c, t=0.2):
        """Aussenkontur: fast schwarz, aber leicht in der Farbe des Nachbarn getoent."""
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] is not None:
                    continue
                for nx, ny in ((x, y + 1), (x + 1, y), (x - 1, y), (x, y - 1)):
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx] is not None:
                        self.px[y][x] = mix(c, src[ny][nx], t)
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


def poly_pixels(pts):
    """Pixelmenge eines gefuellten Polygons (Scanline, Pixelmitte)."""
    ys = [p[1] for p in pts]
    out = set()
    n = len(pts)
    for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
        yc = y + 0.5
        xs = []
        for i in range(n):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            if (y0 <= yc < y1) or (y1 <= yc < y0):
                xs.append(x0 + (yc - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(int(math.ceil(xs[i] - 0.5)), int(math.floor(xs[i + 1] - 0.5)) + 1):
                out.add((x, y))
    return out


def shaded(img, pixels, ramp, base, seed=0, grain=True):
    """Fuellt eine Pixelmenge mit Holz/Stoff-Rampe: Licht oben links, Schatten unten rechts."""
    for (x, y) in pixels:
        i = base
        if (x, y - 1) not in pixels:
            i += 2
        elif (x, y - 2) not in pixels:
            i += 1
        if (x - 1, y) not in pixels:
            i += 1
        if (x, y + 1) not in pixels:
            i -= 2
        elif (x + 1, y) not in pixels:
            i -= 1
        if grain:
            n = noise(x + seed, y * 3)
            if n < 26:
                i -= 1
            elif n > 244:
                i += 1
        img.set(x, y, tone(ramp, i))


# --- Farben ------------------------------------------------------------------

OUT = hx("#0d0b10")
# Rampen von dunkel nach hell, Schatten ins Kalte (blauviolett), Licht ins Warme
WOOD = [hx("#2b1f22"), hx("#3d2b26"), hx("#58402b"), hx("#7a5538"), hx("#9a7149"), hx("#b98d5c")]
REDR = [hx("#2e1424"), hx("#4f1c2c"), hx("#6f2530"), hx("#92302e"), hx("#aa4337"), hx("#c25f47")]
BONER = [hx("#45434f"), hx("#6c6a70"), hx("#968f7c"), hx("#c2b797"), hx("#d6ccab"), hx("#e6ddbe")]
GOLDR = [hx("#5a4320"), hx("#8a6b27"), hx("#c9a13b"), hx("#e6c264"), hx("#f6e09a")]
STEELR = [hx("#30353f"), hx("#555c68"), hx("#8d949b"), hx("#bcc3c9"), hx("#e1e5e8")]
WOOD_L, WOOD_M, WOOD_D = WOOD[3], WOOD[2], WOOD[1]
RAIL = WOOD[4]
RED, BONE = REDR[3], BONER[3]
GOLD, STEEL = GOLDR[2], STEELR[2]
SKIN = hx("#cba286")
SKINR = [hx("#7a5546"), hx("#a57b64"), hx("#cba286"), hx("#e3c3a8")]
ROPE = hx("#2e231a")
ROPE_BEHIND = hx("#6a5539")
ROPE_FRONT = hx("#1c1611")
MOUTH = hx("#5e1c1f")
FOAM = hx("#a9c0c4")
FOAM_D = hx("#5f8590")
WET = hx("#1d3a47")
SAIL_R, SAIL_B = REDR[3], BONER[3]
CLOTH = [hx("#3d4a3a"), hx("#4a3a2f"), hx("#2f3a4a"), hx("#5a3a3a"), hx("#3a3a44"), hx("#2f4a4a")]
HAIR = [hx("#7a4a2a"), hx("#c9a55a"), hx("#3a2a22"), hx("#a8a8a0"), hx("#8a3a22"), hx("#5a3a22")]
SHIELD_PAIRS = [
    (hx("#9c2f2f"), BONE),
    (hx("#c9a13b"), hx("#2f4a63")),
    (hx("#2f4a63"), BONE),
    (BONE, hx("#9c2f2f")),
    (hx("#2a2a30"), hx("#c9a13b")),
    (hx("#3f5a3a"), BONE),
]

# --- Langschiff -------------------------------------------------------------
# Bug zeigt nach rechts. Basisbild 172x108, Anker (Wasserlinie, Schiffsmitte) bei (82, 92).
# Die Crew steht NICHT im Schiffsbild, sie wird als eigene Sprites darueber gezeichnet.

BASE_W, BASE_H = 172, 108
CX, AY, L = 82, 92, 62
X0, X1 = CX - L, CX + L
SAIL_X0, SAIL_X1, SAIL_Y0 = 44, 120, 20


def hull_top(x):
    t = (x - CX) / L
    return round(AY - 14 - 12 * t * t)


def hull_bot(x):
    t = abs((x - CX) / L)
    return round(AY + 9 - 24 * t ** 2.2)


def draw_hull(img):
    for x in range(X0, X1 + 1):
        top, bot = hull_top(x), hull_bot(x)
        h = bot - top
        bounds = [top + round(h * k / 5) for k in range(6)]
        for y in range(top, bot + 1):
            k = 4
            for i in range(5):
                if y < bounds[i + 1]:
                    k = i
                    break
            row = y - bounds[k]
            rows = (bounds[k + 1] - bounds[k]) if k < 4 else (bot - bounds[4] + 1)
            last = row == rows - 1
            n = noise(x, y)
            if k == 0:
                # Reling: helle Oberkante, Schattenkante unten, Stossfugen und Kerben
                if row == 0:
                    c = WOOD[5]
                elif last:
                    c = WOOD[2]
                elif row == 1:
                    c = WOOD[4]
                else:
                    c = WOOD[4] if n > 40 else WOOD[3]
                if (x + 5) % 13 == 0 and row > 0 and not last:
                    c = WOOD[2]
                if row == rows - 2 and x % 6 == 2:
                    c = WOOD[3]
            elif k == 2:
                # bemaltes Band mit abgeplatzter Farbe
                a = (x // 5) % 2 == 0
                ramp = REDR if a else BONER
                i = 3
                if row == 0:
                    i = 1
                elif row == 1:
                    i = 4
                elif last:
                    i = 2
                if x % 5 == 0:
                    i -= 1
                if n < 6:
                    c = WOOD[3] if row < 2 else WOOD[2]
                else:
                    c = tone(ramp, i)
            else:
                seam = (x + 11 * k) % 19
                seg = (x + 11 * k) // 19
                i = 2 + (noise(seg * 5 + k, 7) % 2)
                if k == 4:
                    i -= 1
                if row == 0:
                    i = 1  # Schatten unter dem Plankengang darueber
                elif row == 1:
                    i += 1  # beleuchtete Plankenkante
                elif last:
                    i -= 1
                g = noise((x + k * 31) // 8, y * 2 + k)
                if g < 40:
                    i -= 1
                elif g > 238:
                    i += 1
                c = tone(WOOD, i)
                if seam == 0 and row > 0:
                    c = tone(WOOD, i - 2)
                if seam == 0 and row == 1 and k in (1, 3):
                    c = tone(WOOD, i + 1)  # Nagelkopf
            # nasse Dunkelung ueber der Wasserlinie, Salzrand
            if y >= AY - 6 and k != 2:
                c = mix(c, WET, 0.12 + 0.1 * min(3, y - (AY - 6)) / 3)
            if y >= AY - 6 and k == 2:
                c = sh(c, -1)
            img.set(x, y, c)
    # Salzstreifen unter der Reling
    for sx in (30, 47, 73, 96, 118):
        top = hull_top(sx)
        for dy in range(5, 9 + noise(sx, 1) % 3):
            c = img.get(sx, top + dy)
            if c is not None:
                img.set(sx, top + dy, mix(c, BONER[3], 0.22))
    # Flickplanke (heller, frisches Holz) und Riss im Band
    for x in range(52, 60):
        top = hull_top(x)
        for y in range(top + 5, top + 9):
            c = WOOD[4] if y == top + 5 else WOOD[3]
            if x in (52, 59) and y in (top + 5, top + 8):
                c = hx("#c8c0a0")  # Nagel
            img.set(x, y, c)
    for (dx, dy) in ((0, 0), (1, 1), (1, 2), (2, 3)):
        x = 103 + dx
        img.set(x, hull_top(x) + 9 + dy, WOOD[0])
    img.set(104, hull_top(104) + 8, WOOD[0])


def draw_waterline(img):
    """Schaumsaum und Gischt direkt am Rumpf; Teil des Sprites."""
    for x in range(X0, X1 + 1):
        top, bot = hull_top(x), hull_bot(x)
        for dy in (-2, -1, 0):
            y = AY + dy
            if y > bot or y < top + 4:
                continue
            n = noise((x // 2) * 5, dy + 9)
            if dy == 0 and n % 3 != 0:
                img.set(x, y, FOAM)
            elif dy == -1 and n % 4 == 0:
                img.set(x, y, FOAM)
            elif dy == -2 and n % 6 == 0:
                img.set(x, y, FOAM_D)


def draw_ports_and_oar(img):
    # Ruderpforten im bemalten Band
    for i in range(1, 8):
        x = 32 + 12 * i
        y = hull_top(x) + 11
        img.rect(x - 1, y, x + 1, y + 1, WOOD[0])
        img.set(x - 1, y + 2, WOOD[4])
        img.set(x, y + 2, WOOD[4])
        img.set(x + 1, y + 2, WOOD[3])
    # Steuerruder am Heck (Steuerbordseite, dem Betrachter zugewandt)
    img.line(36, 60, 40, 90, WOOD[3], 2)
    img.line(35, 60, 39, 90, WOOD[4], 1)
    img.line(41, 60, 41, 61, WOOD[1], 1)
    img.rect(33, 58, 37, 59, WOOD[2])  # Pinne
    img.set(33, 58, WOOD[4])
    for y in range(88, 99):
        w = 2 + (1 if y > 90 else 0)
        for x in range(39, 39 + w + 1):
            c = WOOD[3] if x == 39 else (WOOD[2] if x < 41 else WOOD[1])
            if y == 88:
                c = WOOD[4]
            img.set(x + (y - 88) // 5, y, c)
    img.set(38, 70, GOLD)
    img.set(39, 78, GOLD)


def draw_stem_and_head(img):
    # Steven: gebogen, mit Lichtkante und Goldringen
    stem = [(141, 66), (146, 58), (149, 50), (150, 45)]
    img.polyline(stem, WOOD[2], 3)
    img.polyline([(p[0] - 1, p[1]) for p in stem], WOOD[4], 1)
    img.polyline([(p[0] + 1, p[1]) for p in stem], WOOD[1], 1)
    for y in (63, 58):
        img.line(141 + (66 - y) // 2, y, 145 + (66 - y) // 2, y, REDR[3], 1)
    for (x, y) in ((147, 58), (149, 52)):
        img.rect(x - 2, y, x + 2, y + 1, GOLD)
        img.rect(x - 2, y, x + 2, y, GOLDR[3])
    # Maehne: drei rote Zacken hinter dem Kopf
    for tri in ([(152, 34), (151, 38), (141, 30)], [(151, 39), (151, 43), (139, 40)],
                [(151, 44), (152, 47), (140, 49)]):
        shaded(img, poly_pixels(tri), REDR, 3, 5, grain=False)
        tip = tri[2]
        img.set(tip[0], tip[1], GOLD)
    # Hals
    neck = poly_pixels([(149, 42), (155, 40), (159, 43), (158, 47), (154, 51), (148, 52), (147, 47)])
    shaded(img, neck, WOOD, 2, 3, grain=False)
    for (x, y) in sorted(neck):
        if (x + 2 * y) % 5 == 0 and (x, y - 1) in neck and (x - 1, y) in neck and (x + 1, y) in neck:
            img.set(x, y, WOOD[1])  # Schuppen
    # Kopf: Oberkiefer mit Stirn und Schnauze (Nase leicht aufgeworfen)
    upper = poly_pixels([(150, 36), (151, 33), (154, 30), (159, 29), (164, 30), (166, 31), (168, 29),
                         (171, 30), (171, 36), (170, 38), (165, 39), (158, 40), (152, 40)])
    shaded(img, upper, WOOD, 3, 11)
    # Maul und Unterkiefer
    img.rect(153, 40, 169, 42, MOUTH)
    img.rect(154, 42, 168, 42, REDR[1])
    for fx in range(161, 166):
        img.set(fx, 41, REDR[4])  # Zunge
    lower = poly_pixels([(154, 43), (167, 43), (170, 44), (168, 46), (162, 48), (156, 48), (153, 46)])
    shaded(img, lower, WOOD, 2, 21)
    for fx in (156, 160, 164, 168):
        img.set(fx, 40, BONER[4])
        img.set(fx, 41, BONER[3])
    for fx in (158, 162, 166):
        img.set(fx, 42, BONER[3])
    # Schnauzenkappe, Nasenloch
    img.rect(170, 31, 171, 36, GOLD)
    img.rect(170, 31, 170, 35, GOLDR[3])
    img.set(171, 36, GOLDR[0])
    img.rect(167, 33, 168, 34, WOOD[0])
    img.set(167, 34, WOOD[2])
    # Auge mit schraeger Braue
    for (x, y) in ((156, 31), (157, 31), (158, 31), (159, 32), (160, 32), (161, 32), (162, 33), (163, 33)):
        img.set(x, y, WOOD[0])
    img.rect(157, 33, 160, 34, GOLDR[3])
    img.rect(157, 33, 157, 34, GOLD)
    img.rect(159, 33, 160, 34, hx("#f0dc88"))
    img.set(159, 34, OUT)
    img.set(160, 34, OUT)
    img.rect(156, 35, 160, 35, WOOD[1])
    # Zierscheibe auf der Wange
    img.rect(153, 36, 155, 38, GOLD)
    img.set(154, 37, WOOD[0])
    img.set(153, 36, GOLDR[3])
    # Kinnbart
    for (x, y) in ((158, 49), (159, 50), (157, 50), (158, 51)):
        img.set(x, y, REDR[2])
    # Hoerner: Knochen vorn, dunkler Stahl hinten
    hh = [(158, 30), (155, 26), (153, 22), (154, 19)]
    h2 = [(163, 29), (162, 25), (164, 21), (167, 20)]
    img.polyline(h2, STEELR[1], 2)
    img.line(163, 28, 162, 25, STEELR[2], 1)
    img.polyline(hh, BONER[2], 2)
    img.polyline([(p[0] - 1, p[1]) for p in hh[:-1]], BONER[4], 1)
    img.set(154, 19, BONER[5])
    img.rect(157, 29, 160, 30, GOLD)
    img.rect(157, 29, 160, 29, GOLDR[3])


def draw_stern(img):
    post = [(22, 66), (18, 58), (15, 50), (15, 45)]
    img.polyline(post, WOOD[2], 3)
    img.polyline([(p[0] - 1, p[1]) for p in post], WOOD[4], 1)
    img.polyline([(p[0] + 1, p[1]) for p in post], WOOD[1], 1)
    # geschnitzte Spirale am Heck
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            d = dx * dx + dy * dy
            if 6 <= d <= 15 and not (dx > 1 and -1 <= dy <= 1):
                lit = (dx + dy) < 0
                img.set(18 + dx, 41 + dy, WOOD[4] if lit and d <= 11 else (WOOD[2] if d <= 11 else WOOD[1]))
    img.set(18, 41, WOOD[0])
    img.set(19, 41, WOOD[2])
    img.rect(21, 40, 22, 42, GOLD)
    img.set(21, 40, GOLDR[3])
    img.set(23, 41, GOLDR[3])
    # Zierwerk: Goldbaender, rote Schnitzstriche
    img.rect(14, 54, 17, 55, GOLD)
    img.rect(14, 54, 17, 54, GOLDR[3])
    img.rect(17, 61, 20, 62, GOLD)
    img.rect(17, 61, 20, 61, GOLDR[3])
    for y in (47, 50, 57, 64):
        x = 16 + (y - 47) * 6 // 18
        img.set(x, y, REDR[3])
        img.set(x + 1, y + 1, REDR[2])


def sail_bottom_full(x):
    u = (x - 82) / 38
    return 60 + round(5 * (1 - u * u)) + noise(x // 3, 1) % 4


SAIL_SEAMS = (34, 48, 62)


def sail_k(x, y, bottom):
    """Helligkeitsstufe der Segelflaeche (relativ zur Grundfarbe)."""
    si = (x - SAIL_X0) // 9
    sx = (x - SAIL_X0) % 9
    hl = 2 + (si * 7) % 3
    d = sx - hl
    if sx == 0:
        k = -2
    elif 0 <= d <= 1:
        k = 1
    elif -1 <= d <= 2:
        k = 0
    elif d < -1:
        k = 0
    else:
        k = -1
    yy = y - SAIL_Y0
    if yy < 2:
        k -= 2
    elif yy < 4:
        k -= 1
    if y > bottom - 3:
        k -= 1
    if x > 104:
        k -= 1
    if x > 113:
        k -= 1
    if y in SAIL_SEAMS:
        k -= 1
    elif y - 1 in SAIL_SEAMS and x % 3 == 0:
        k += 1
    n = noise(x, y + 3)
    if n < 5:
        k -= 1
    elif n > 252:
        k += 1
    return k


def draw_sail(img, frac):
    """frac: 0 = eingeholt (Wulst an der Rah), 1 = voll gesetzt."""
    if frac <= 0.0:
        for x in range(SAIL_X0 - 1, SAIL_X1 + 2):
            si = (x - SAIL_X0) // 9
            ramp = REDR if si % 2 == 0 else BONER
            lump = 1 if (x * 7) % 11 < 3 else 0
            for y in range(20 - lump, 24):
                k = {19: 3, 20: 4, 21: 3, 22: 2, 23: 1}[y]
                if (x - SAIL_X0) % 9 == 0:
                    k -= 1
                if x > 108:
                    k -= 1
                img.set(x, y, tone(ramp, k))
        for tx in range(48, 118, 10):
            img.rect(tx, 19, tx, 24, ROPE)
            img.set(tx + 1, 20, WOOD[3])
        return

    bottoms = {}
    for x in range(SAIL_X0, SAIL_X1 + 1):
        bottoms[x] = SAIL_Y0 + max(4, round((sail_bottom_full(x) - SAIL_Y0) * frac))

    def put(x, y, c):
        if x in bottoms and y <= bottoms[x]:
            img.set(x, y, c)

    for x in range(SAIL_X0, SAIL_X1 + 1):
        bottom = bottoms[x]
        edge_in = round(2 * math.sin(x * 0.2)) if x in (SAIL_X0, SAIL_X1) else 0
        si = (x - SAIL_X0) // 9
        ramp = REDR if si % 2 == 0 else BONER
        for y in range(SAIL_Y0 + (1 if edge_in > 0 else 0), bottom + 1):
            img.set(x, y, tone(ramp, 3 + max(-3, min(2, sail_k(x, y, bottom)))))
        if frac < 1.0 and x % 6 == 0:
            img.set(x, bottom + 1, ROPE_BEHIND)  # Reffbaender
        # ausgefranster Saum: helle Faeden
        if noise(x, 5) % 4 == 0:
            img.set(x, bottom, tone(ramp, 1))
    # Flicken mit gestepptem Rand
    for y in range(36, 44):
        for x in range(56, 64):
            c = hx("#85725a") if y == 36 else hx("#6b5a44")
            if x == 63 or y == 43:
                c = hx("#58493a")
            if (x in (57, 62) and y in (37, 42)):
                c = hx("#3d3226")
            put(x, y, c)
    for y in range(28, 35):
        for x in range(94, 101):
            c = hx("#4d5866") if y == 28 else hx("#3a4350")
            if x == 100 or y == 34:
                c = hx("#2c3440")
            if x in (95, 99) and y in (29, 33):
                c = hx("#8d949b")
            put(x, y, c)
    # Loecher mit dunklem Rand
    holes = [(66, 26), (67, 26), (66, 27), (67, 27), (68, 27), (67, 28),
             (103, 49), (104, 49), (103, 50), (104, 50), (104, 51),
             (52, 52), (53, 52), (52, 53), (88, 54), (89, 54), (89, 55)]
    hs = set(holes)
    for hx_, hy in holes:
        if hx_ in bottoms and hy <= bottoms[hx_]:
            img.set(hx_, hy, None)
    for hx_, hy in holes:
        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
            q = (hx_ + dx, hy + dy)
            if q not in hs and img.get(*q) is not None and q[0] in bottoms and 20 < q[1] < bottoms[q[0]]:
                img.set(q[0], q[1], sh(img.get(*q), -2))
    # Zurrungen an der Rah (Robbander)
    for tx in range(48, 118, 10):
        img.rect(tx, 19, tx, 22, ROPE)
        img.set(tx + 1, 21, WOOD[3])
    # Pfeil im Segel
    if bottoms.get(100, 0) >= 40:
        img.line(100, 40, 111, 33, WOOD[3], 1)
        img.rect(109, 31, 112, 32, REDR[2])
        img.rect(110, 34, 113, 35, REDR[2])
        img.set(109, 31, REDR[4])
        img.set(99, 40, STEELR[3])
        img.set(98, 40, OUT)


def draw_mast(img):
    img.rect(81, 12, 83, 78, WOOD[2])
    img.rect(81, 12, 81, 78, WOOD[4])
    img.rect(83, 12, 83, 78, WOOD[1])
    for y in range(13, 78):
        if noise(y, 77) < 40:
            img.set(82, y, WOOD[3])
    # Rah mit verjuengten Enden
    img.rect(39, 17, 125, 17, WOOD[4])
    img.rect(38, 18, 126, 18, WOOD[2])
    img.rect(39, 19, 125, 19, WOOD[1])
    for x in range(40, 125):
        if noise(x, 91) < 50:
            img.set(x, 18, WOOD[3])
    img.rect(36, 17, 38, 19, None)
    img.rect(126, 17, 128, 19, None)
    img.rect(37, 18, 38, 18, WOOD[3])
    img.rect(126, 18, 127, 18, WOOD[1])
    img.set(36, 18, GOLD)
    img.set(128, 18, GOLD)
    # Mastkopf, Bunde
    img.rect(80, 14, 84, 15, WOOD[1])
    img.rect(80, 14, 84, 14, WOOD[3])
    img.rect(80, 12, 84, 12, GOLDR[1])
    img.disc(82, 10, 1, GOLD)
    img.set(81, 9, GOLDR[3])
    for y in (24, 30, 66):
        img.rect(81, y, 83, y, ROPE)
    img.rect(79, 76, 85, 78, WOOD[1])  # Mastfuss
    img.rect(79, 76, 85, 76, WOOD[3])
    # Wimpel (weht nach links, der Wind kommt von rechts)
    for i in range(18):
        thick = max(1, 6 - int(i * 0.33))
        wave = round(1.5 * math.sin(i * 0.55))
        for j in range(thick):
            c = REDR[4] if j == 0 else (REDR[3] if j < thick - 1 else REDR[1])
            if i >= 15 and j == thick // 2:
                continue
            img.set(80 - i, 8 + wave + j, c)
    img.set(80, 8, GOLD)


def draw_shield(img, cx, cy, pair, pattern):
    a, b = pair
    r = 5
    # Schlagschatten auf dem Rumpf (nach unten rechts)
    for dy in range(-r, r + 2):
        for dx in range(-r, r + 2):
            if (dx - 1) ** 2 + (dy - 1) ** 2 <= r * r + 1 and dx * dx + dy * dy > r * r + 1:
                c = img.get(cx + dx, cy + dy)
                if c is not None:
                    img.set(cx + dx, cy + dy, sh(c, -2))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 > r * r + 1:
                continue
            if d2 > 16:
                c = sh(a, -2)
                if dx + dy < -4:
                    c = sh(a, 0)  # Randlicht oben links
            else:
                c = a
                if pattern == 0 and ((dx >= 0) == (dy >= 0)):
                    c = b
                elif pattern == 1 and (dx == 0 or dy == 0):
                    c = b
                elif pattern == 3 and dx > 0:
                    c = b
                if dx + dy < -3:
                    c = sh(c, 1)
                elif dx + dy > 4:
                    c = sh(c, -1)
            img.set(cx + dx, cy + dy, c)
    img.rect(cx, cy, cx + 1, cy + 1, STEELR[2])
    img.set(cx, cy, STEELR[4])
    img.set(cx + 1, cy + 1, STEELR[1])


def sag_pts(p0, p1, sag, n=28):
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t + sag * 4 * t * (1 - t)))
    return pts


# Seile: "behind" nur vor leerem Hintergrund (duenn, mit Durchhang), "front" ueber allem.
ROPES_BEHIND = [((82, 11), (150, 44), 4), ((82, 11), (17, 46), 4)]
ROPES_FRONT = [((82, 23), (64, hull_top(64) + 1), 0), ((82, 23), (100, hull_top(100) + 1), 0)]


def make_base(sail_frac):
    img = Img(BASE_W, BASE_H)
    draw_hull(img)
    draw_ports_and_oar(img)
    draw_stem_and_head(img)
    draw_stern(img)
    draw_sail(img, sail_frac)
    draw_mast(img)
    for i in range(9):
        x = 32 + 12 * i
        draw_shield(img, x, hull_top(x) + 4, SHIELD_PAIRS[i % len(SHIELD_PAIRS)], i % 4)
    draw_waterline(img)
    return img


# --- Vorgerenderte Neigungsframes ---------------------------------------------

FRAME_W, FRAME_H = 220, 156
FRAME_AX, FRAME_AY = 110, 108  # Anker im Frame
MAX_ANGLE, ANGLE_STEP = 37.5, 2.5
FRAME_COUNT = int(MAX_ANGLE * 2 / ANGLE_STEP) + 1  # 31
SAIL_LEVELS = [0.0, 0.5, 1.0, 1.5, 2.0]  # entspricht enc.sail (0 = eingeholt, 2 = voll)

SUB = [(i + 0.5) / 4 for i in range(4)]


def rotate_frame(base, angle_deg):
    out = Img(FRAME_W, FRAME_H)
    a = math.radians(angle_deg)
    c, s = math.cos(a), math.sin(a)
    for fy in range(FRAME_H):
        for fx in range(FRAME_W):
            dx, dy = fx + 0.5 - FRAME_AX, fy + 0.5 - FRAME_AY
            sx = CX + dx * c + dy * s
            sy = AY - dx * s + dy * c
            if sx < -3 or sx > base.w + 3 or sy < -3 or sy > base.h + 3:
                continue
            counts = {}
            opaque = 0
            for oy in SUB:
                for ox in SUB:
                    dx, dy = fx + ox - FRAME_AX, fy + oy - FRAME_AY
                    px = int(math.floor(CX + dx * c + dy * s))
                    py = int(math.floor(AY - dx * s + dy * c))
                    col = base.get(px, py)
                    if col is not None:
                        counts[col] = counts.get(col, 0) + 1
                        opaque += 1
            if opaque >= 8:
                out.px[fy][fx] = max(counts, key=counts.get)
    return out


def finish_frame(frame, angle_deg):
    frame.outline_sel(OUT)
    a = math.radians(angle_deg)
    c, s = math.cos(a), math.sin(a)

    def tx(p):
        dx, dy = p[0] - CX, p[1] - AY
        return (
            int(round(FRAME_AX + dx * c - dy * s)),
            int(round(FRAME_AY + dx * s + dy * c)),
        )

    for p0, p1, sag in ROPES_BEHIND:
        pts = [tx(p) for p in sag_pts(p0, p1, sag)]
        tmp = Img(frame.w, frame.h)
        tmp.polyline(pts, ROPE_BEHIND)
        for y in range(frame.h):
            for x in range(frame.w):
                if tmp.px[y][x] is not None and frame.px[y][x] is None:
                    frame.px[y][x] = ROPE_BEHIND
    for p0, p1, sag in ROPES_FRONT:
        a0, a1 = tx(p0), tx(p1)
        frame.line(a0[0], a0[1], a1[0], a1[1], ROPE_FRONT)


def build_ship_atlas():
    atlas = Img(FRAME_W * FRAME_COUNT, FRAME_H * len(SAIL_LEVELS))
    rows = []
    for r, level in enumerate(SAIL_LEVELS):
        base = make_base(level / 2.0)
        frames = []
        for i in range(FRAME_COUNT):
            ang = -MAX_ANGLE + ANGLE_STEP * i
            f = rotate_frame(base, ang)
            finish_frame(f, ang)
            atlas.blit(f, i * FRAME_W, r * FRAME_H)
            frames.append(f)
        rows.append(frames)
    return atlas, rows


# --- Crew ---------------------------------------------------------------------
# Zelle 14x16, Koerper (6 breit) ab x=4, Fuesse an Zeile 15 (Reling = Zeile 16).
# Posen: 0 Stehen (Schildarm), 1 Arbeit A (Arme vor), 2 Arbeit B (Arme hoch), 3/4 Schwimmen.

CELL_W, CELL_H = 14, 16
POSES = 5
LOOKS = [
    dict(cloth=0, hair=0, head="helmet"),
    dict(cloth=1, hair=1, head="long"),
    dict(cloth=2, hair=2, head="band"),
    dict(cloth=3, hair=3, head="helmet"),
    dict(cloth=4, hair=4, head="band"),
    dict(cloth=5, hair=5, head="horns"),
    dict(cloth=1, hair=2, head="hood"),
]
EYE = hx("#141015")
LEATHER = hx("#33241a")


def draw_crew(img, x, top, look, pose):
    cloth = CLOTH[look["cloth"]]
    hair = HAIR[look["hair"]]
    sleeve = sh(cloth, -1)
    head = look["head"]
    hairs = [sh(hair, -2), sh(hair, -1), hair, sh(hair, 1)]
    r = lambda n: top - 16 + n  # Zeile n der Zelle

    # Beine, Stiefel, Rock der Tunika
    for lx in (x + 1, x + 3):
        img.rect(lx, r(14), lx + 1, r(14), sh(cloth, -3))
        img.rect(lx, r(15), lx + 1, r(15), LEATHER)
    img.set(x + 5, r(15), LEATHER)
    img.set(x + 1, r(15), sh(LEATHER, 1))
    img.rect(x, r(13), x + 5, r(14), sh(cloth, -1))
    img.rect(x, r(14), x + 5, r(14), sh(cloth, -2))
    # Rumpf: Licht links, Schatten rechts, Schulter hell
    for yy in range(r(11), r(13)):
        for xx in range(x, x + 6):
            k = 0
            if xx == x:
                k = 1
            elif xx >= x + 4:
                k = -1
            if yy == r(11):
                k += 1
            if yy == r(12) and xx == x + 5:
                k = -2
            img.set(xx, yy, sh(cloth, max(-3, min(2, k))))
    img.rect(x + 2, r(12), x + 3, r(12), sh(cloth, -1))
    # Guertel mit Goldschnalle
    img.rect(x, r(13), x + 5, r(13), LEATHER)
    img.set(x + 3, r(13), GOLDR[3])
    img.set(x + 2, r(13), GOLD)

    # Kopf
    img.rect(x + 1, r(8), x + 4, r(9), SKINR[2])
    img.set(x + 1, r(8), SKINR[3])
    img.set(x + 4, r(9), SKINR[1])
    img.set(x + 2, r(8), EYE)
    img.set(x + 4, r(8), EYE)
    beard_full = look["hair"] % 2 == 0
    # Bart
    img.rect(x + 1, r(10), x + 4, r(10), hairs[2])
    img.set(x + 1, r(10), hairs[3])
    img.set(x + 4, r(10), hairs[1])
    if beard_full:
        img.set(x, r(9), hairs[3])
        img.set(x + 5, r(9), hairs[1])
        img.rect(x + 1, r(9), x + 1, r(9), hairs[2])
        img.rect(x + 4, r(9), x + 4, r(9), hairs[1])
        img.rect(x + 2, r(10), x + 3, r(10), hairs[1])
        img.set(x + 2, r(9), SKINR[1])
        img.set(x + 3, r(9), SKINR[1])
    else:
        img.rect(x + 2, r(9), x + 3, r(9), hairs[2])
        img.set(x + 2, r(9), hairs[3])
        img.set(x + 1, r(10), hairs[1])
        img.set(x + 4, r(10), hairs[0])
        img.rect(x + 2, r(10), x + 3, r(10), hairs[2])
        img.set(x + 3, r(10), hairs[1])
    if head in ("helmet", "horns"):
        img.rect(x + 1, r(5), x + 4, r(5), STEELR[2])
        img.rect(x, r(6), x + 5, r(6), STEELR[2])
        img.rect(x, r(7), x + 5, r(7), STEELR[1])
        img.set(x + 1, r(5), STEELR[4])
        img.set(x + 2, r(5), STEELR[3])
        img.set(x, r(6), STEELR[3])
        img.set(x + 1, r(6), STEELR[3])
        img.set(x + 5, r(6), STEELR[1])
        img.set(x + 4, r(5), STEELR[1])
        img.set(x, r(7), STEELR[2])
        img.set(x + 3, r(8), STEELR[2])  # Nasenschutz
        img.set(x + 3, r(9), STEELR[1])
        img.set(x + 3, r(6), GOLD)
        if head == "horns":
            for (hx_, hy) in ((x - 1, 6), (x - 1, 5), (x - 1, 4), (x, 3),
                              (x + 6, 6), (x + 6, 5), (x + 6, 4), (x + 5, 3)):
                img.set(hx_, r(hy), BONER[3] if hx_ < x + 6 and hy > 3 else BONER[2])
            img.set(x - 1, r(6), BONER[4])
            img.set(x + 6, r(6), BONER[1])
    elif head == "long":
        img.rect(x + 1, r(5), x + 4, r(5), hairs[3])
        img.rect(x, r(6), x + 5, r(7), hairs[2])
        img.rect(x + 1, r(7), x + 4, r(7), SKINR[3])
        img.set(x + 3, r(5), hairs[2])
        img.rect(x, r(8), x, r(10), hairs[2])
        img.rect(x + 5, r(8), x + 5, r(9), hairs[1])
        img.set(x, r(8), hairs[3])
        img.set(x - 1, r(8), hairs[1])
        img.set(x - 1, r(9), hairs[0])
    elif head == "band":
        img.rect(x + 1, r(5), x + 4, r(5), hairs[3])
        img.rect(x, r(6), x + 5, r(6), hairs[2])
        img.rect(x, r(7), x + 5, r(7), REDR[4])
        img.set(x + 5, r(7), REDR[2])
        img.set(x, r(7), REDR[5])
        img.set(x - 1, r(7), REDR[3])
        img.set(x - 1, r(8), REDR[2])
        img.set(x + 5, r(8), hairs[1])
        img.set(x, r(8), hairs[2])
    elif head == "hood":
        hood = sh(cloth, -1)
        img.rect(x + 1, r(5), x + 4, r(5), sh(cloth, 1))
        img.rect(x, r(6), x + 5, r(7), hood)
        img.rect(x, r(8), x, r(9), sh(cloth, -2))
        img.rect(x + 5, r(8), x + 5, r(9), sh(cloth, -2))
        img.set(x, r(6), sh(cloth, 1))
        img.rect(x + 1, r(8), x + 4, r(8), SKINR[2])
        img.set(x + 2, r(8), EYE)
        img.set(x + 4, r(8), EYE)

    # Arme
    if pose == 0:
        img.rect(x + 3, r(11), x + 4, r(12), sleeve)
        img.set(x + 4, r(13), SKINR[2])
        # Rundschild vor dem Koerper (Schildarm)
        a, b = SHIELD_PAIRS[look["cloth"] % len(SHIELD_PAIRS)]
        for (sx, sy, cc) in ((5, 10, a), (6, 10, a), (4, 11, a), (5, 11, a), (6, 11, b), (7, 11, b),
                             (4, 12, a), (5, 12, a), (6, 12, b), (7, 12, b), (5, 13, a), (6, 13, b)):
            img.set(x + sx, r(sy + 1), cc)
        for (sx, sy) in ((5, 10), (6, 10), (4, 11), (4, 12), (5, 13)):
            img.set(x + sx, r(sy + 1), sh(a, 1 if sy < 12 and sx < 6 else -2))
        for (sx, sy) in ((7, 11), (7, 12), (6, 13)):
            img.set(x + sx, r(sy + 1), sh(b, -2))
        img.set(x + 5, r(12), STEELR[4])
    elif pose == 1:
        img.rect(x + 4, r(11), x + 7, r(12), sleeve)
        img.rect(x + 4, r(11), x + 7, r(11), sh(cloth, 0))
        img.rect(x + 8, r(11), x + 8, r(12), SKINR[2])
    elif pose == 2:
        img.rect(x + 6, r(8), x + 7, r(12), sleeve)
        img.set(x + 6, r(8), sh(cloth, 0))
        img.rect(x + 6, r(7), x + 7, r(7), SKINR[2])
    elif pose == 3:
        img.rect(x - 2, r(7), x - 1, r(11), sleeve)
        img.set(x - 2, r(6), SKINR[2])
        img.set(x - 1, r(6), SKINR[3])
        img.rect(x + 6, r(7), x + 7, r(11), sleeve)
        img.set(x + 7, r(6), SKINR[2])
        img.set(x + 6, r(6), SKINR[1])
    elif pose == 4:
        img.rect(x - 2, r(8), x - 1, r(11), sleeve)
        img.set(x - 2, r(7), SKINR[2])
        img.rect(x + 6, r(8), x + 7, r(11), sleeve)
        img.set(x + 7, r(7), SKINR[2])
        img.set(x + 3, r(9), MOUTH)
        img.set(x + 2, r(9), MOUTH)


def build_crew_atlas():
    atlas = Img(CELL_W * POSES, CELL_H * len(LOOKS))
    for row, look in enumerate(LOOKS):
        for pose in range(POSES):
            cell = Img(CELL_W, CELL_H)
            draw_crew(cell, 4, 16, look, pose)
            cell.outline(OUT)
            atlas.blit(cell, pose * CELL_W, row * CELL_H)
    return atlas


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    assets = os.path.join(here, "..", "assets")
    t0 = time.time()
    crew = build_crew_atlas()
    crew.save(os.path.join(assets, "crew.png"))
    atlas, rows = build_ship_atlas()
    atlas.save(os.path.join(assets, "ship.png"))
    print("assets/ship.png, assets/crew.png geschrieben (%d Frames x %d Segelstufen, %.1fs)"
          % (FRAME_COUNT, len(SAIL_LEVELS), time.time() - t0))
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        bg = hx("#1a2a36")
        mid = FRAME_COUNT // 2
        rows[-1][mid].filled_bg(bg).scaled(5).save(os.path.join(out, "ship_0.png"))
        strip = Img(FRAME_W * len(SAIL_LEVELS), FRAME_H)
        for i, r in enumerate(rows):
            strip.blit(r[mid], i * FRAME_W, 0)
        strip.filled_bg(bg).scaled(2).save(os.path.join(out, "ship_sail.png"))
        crew.filled_bg(bg).scaled(8).save(os.path.join(out, "crew.png"))
        # Lesbarkeit der Kontur auf hellem Himmel und dunklem Wasser, plus Neigungen
        both = Img(FRAME_W * 4, FRAME_H)
        both.blit(rows[-1][mid].filled_bg(hx("#9aa6ad")), 0, 0)
        both.blit(rows[-1][mid].filled_bg(hx("#16313f")), FRAME_W, 0)
        both.blit(rows[-1][FRAME_COUNT - 6].filled_bg(hx("#223644")), FRAME_W * 2, 0)
        both.blit(rows[-1][5].filled_bg(hx("#223644")), FRAME_W * 3, 0)
        both.scaled(2).save(os.path.join(out, "ship_ctx.png"))
        print("Vorschau in", out)


if __name__ == "__main__":
    main()
