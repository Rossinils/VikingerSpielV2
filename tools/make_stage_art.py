"""Erzeugt die Bühnenbilder des Deckkampfs (Pixelart in halber Auflösung, reines Python, wie make_sky.py).

Aufruf:
    python -X utf8 -I tools/make_stage_art.py                      -> schreibt assets/stage_*.png und scripts/stage_atlas.gd
    python -X utf8 -I tools/make_stage_art.py --preview ordner     -> zusätzlich vergrößerte Vorschaubilder

Alles ist in halber Auflösung gezeichnet (240 statt 480 Pixel breit) und wird im Spiel doppelt vergrößert gezeichnet:
dann haben Bühne und die doppelt großen Kampffiguren dieselbe Pixelgröße.

assets/stage_back.png   fünf Orte untereinander (Reihenfolge ORTE), je 240x72: Himmel, Meer, Ferne, Reling mit Schilden und Gerät.
assets/stage_rail.png   fünf Reling-Ebenen mit Alpha (Reling, Pfosten, Seile, Schilde, Gerät), je 240x28.
assets/stage_deck.png   fünf Decksstreifen untereinander, je 240x32: Planken beider Schiffe, die Lücke dazwischen.
assets/stage_glow.png   weiche Lichtflecken (Alpha-Verläufe, im Spiel eingefärbt): Kugel, Lichtpfütze.
assets/stage_fog.png    nahtlos kachelnder Nebelstreifen (Alpha).
scripts/stage_atlas.gd  die Reihenfolge und Maße als Konstanten (ERZEUGT, nicht von Hand ändern).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_art import Img, hx, sh, mix  # noqa: E402

ORTE = ["draugr", "raeuber", "haendler", "dorf", "kraken"]
W, H = 240, 72          # Tile des Hintergrunds (halbe Auflösung)
DECK_H = 32
HORIZON = 34
RAIL_Y = 58             # Oberkante der Reling
GAP_X = 118             # Lücke zwischen den Schiffen (Breite 4)
RAIL_TOP = 44           # erste Zeile der Reling-Ebene (Flaggen und Pfosten ragen über die Reling)
RAIL_H = H - RAIL_TOP   # Höhe der Reling-Ebene

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def lerp_col(a, b, t):
    return (int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t), int(a[2] + (b[2] - a[2]) * t), 255)


def stops_color(stops, t):
    """Farbe auf einem Verlauf aus [(Stelle 0..1, Farbe), ...]."""
    t = max(0.0, min(1.0, t))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            return lerp_col(c0, c1, (t - p0) / max(p1 - p0, 1e-6))
    return stops[-1][1]


def dither_gradient(img, x0, x1, y0, y1, stops, bands=9):
    """Senkrechter Verlauf in 'bands' Farbstufen, an den Stufen mit 4x4-Bayer-Raster verzahnt."""
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0 - 1, 1)
        pos = t * (bands - 1)
        lo = int(pos)
        frac = pos - lo
        c_lo = stops_color(stops, lo / (bands - 1))
        c_hi = stops_color(stops, min(lo + 1, bands - 1) / (bands - 1))
        for x in range(x0, x1):
            img.set(x, y, c_hi if BAYER[y % 4][x % 4] / 16.0 < frac else c_lo)


# --- Zufall und Rauschen -----------------------------------------------------------------------

def hash01(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, seed):
    xi, yi = int(math.floor(x)), int(math.floor(y))
    xf, yf = x - xi, y - yi
    xf = xf * xf * (3 - 2 * xf)
    yf = yf * yf * (3 - 2 * yf)
    a, b = hash01(xi, yi, seed), hash01(xi + 1, yi, seed)
    c, d = hash01(xi, yi + 1, seed), hash01(xi + 1, yi + 1, seed)
    return (a + (b - a) * xf) + ((c + (d - c) * xf) - (a + (b - a) * xf)) * yf


def fbm(x, y, seed, octaves=3):
    v, amp, f, tot = 0.0, 1.0, 1.0, 0.0
    for o in range(octaves):
        v += vnoise(x * f, y * f, seed + o * 17) * amp
        tot += amp
        amp *= 0.5
        f *= 2.0
    return v / tot


# --- Orte -----------------------------------------------------------------------------------------

THEME = {
    # Himmel (oben, Mitte, Horizont), Meer (fern, nah), Wolken (hell, dunkel), Himmelskörper, Sterne
    "draugr": dict(sky=[(0.0, hx("#07100e")), (0.55, hx("#12302a")), (1.0, hx("#2f6a58"))], sea=(hx("#16342f"), hx("#060d0c")),
                   cloud=(hx("#3f7c68"), hx("#122a24")), body=("moon", hx("#d7efe4"), 168, 14, 7), stars=70, haze=hx("#4a9a82"),
                   wood=hx("#3c4a3e"), wood_d=hx("#222c25"), wood_l=hx("#6a7e6c")),
    "raeuber": dict(sky=[(0.0, hx("#12090f")), (0.5, hx("#40181a")), (1.0, hx("#c8642c"))], sea=(hx("#5a2a26"), hx("#150a0c")),
                    cloud=(hx("#d98a48"), hx("#341218")), body=("sun", hx("#ffb868"), 196, 33, 9), stars=0, haze=hx("#e07a3a"),
                    wood=hx("#5a3626"), wood_d=hx("#2a170f"), wood_l=hx("#8a5a3c")),
    "haendler": dict(sky=[(0.0, hx("#0d1426")), (0.5, hx("#2c3c64")), (1.0, hx("#e0a874"))], sea=(hx("#4a5a78"), hx("#0f1626")),
                     cloud=(hx("#f0c898"), hx("#2a3050")), body=("sun", hx("#fff0c0"), 60, 33, 8), stars=14, haze=hx("#f0c890"),
                     wood=hx("#7a5a3a"), wood_d=hx("#3a281a"), wood_l=hx("#b08a5a")),
    "dorf": dict(sky=[(0.0, hx("#1a1024")), (0.45, hx("#703040")), (1.0, hx("#f08a3c"))], sea=(hx("#7a3a3c"), hx("#1a0e12")),
                 cloud=(hx("#ffa860"), hx("#4a1a2c")), body=("sun", hx("#ffd890"), 40, 32, 10), stars=0, haze=hx("#ff9a50"),
                 wood=hx("#6a4a30"), wood_d=hx("#2e1e12"), wood_l=hx("#9a7448")),
    "kraken": dict(sky=[(0.0, hx("#06040c")), (0.5, hx("#1a1030")), (1.0, hx("#3e2c60"))], sea=(hx("#241a42"), hx("#07050e")),
                   cloud=(hx("#5a4488"), hx("#0c0818")), body=("none", None, 0, 0, 0), stars=0, haze=hx("#6a52a0"),
                   wood=hx("#3a3042"), wood_d=hx("#1a1420"), wood_l=hx("#6a5a7a")),
}


def draw_sky(img, ox, oy, name, seed):
    t = THEME[name]
    dither_gradient(img, ox, ox + W, oy, oy + HORIZON + 1, t["sky"], bands=10)
    # Sterne
    rnd = random.Random(seed)
    for _ in range(t["stars"]):
        x, y = rnd.randrange(W), rnd.randrange(0, HORIZON - 10)
        k = rnd.random()
        img.set(ox + x, oy + y, rgba(hx("#e8f0e8") if k > 0.7 else hx("#8aa098")))
    # Wolkenbänke, zum Horizont dichter
    for y in range(2, HORIZON - 1):
        for x in range(W):
            v = fbm(x / 22.0, y / 6.5, seed + 5, 3)
            dens = (v - 0.46) * 3.2 + (y / float(HORIZON)) * 0.5 - 0.15
            if dens > 0.05:
                lit = fbm((x + 2) / 22.0, (y + 2) / 6.5, seed + 5, 3) < v
                c = t["cloud"][0] if lit and dens > 0.3 else t["cloud"][1]
                if dens < 0.22 and BAYER[y % 4][x % 4] / 16.0 > dens * 4.0:
                    continue
                base = img.get(ox + x, oy + y)
                img.set(ox + x, oy + y, lerp_col(base, c, min(0.85, 0.35 + dens)) if base else rgba(c))
    # Himmelskörper mit Hof
    kind, col, bx, by, r = t["body"]
    if kind != "none":
        for yy in range(by - r * 3, by + r * 3):
            for xx in range(bx - r * 3, bx + r * 3):
                d = math.hypot(xx - bx, yy - by)
                if r < d < r * 3 and 0 <= xx < W and 0 <= yy <= HORIZON:
                    if BAYER[yy % 4][xx % 4] / 16.0 < ((1.0 - (d - r) / (r * 2.0)) ** 2) * 0.5:
                        c = img.get(ox + xx, oy + yy)
                        if c:
                            img.set(ox + xx, oy + yy, lerp_col(c, col, 0.35))
        for yy in range(by - r, by + r + 1):
            for xx in range(bx - r, bx + r + 1):
                if math.hypot(xx - bx, yy - by) <= r + 0.3 and 0 <= yy <= HORIZON:
                    img.set(ox + xx, oy + yy, rgba(col))
        if kind == "moon":
            for yy in range(by - r, by + r + 1):  # Sichel: ein Teil der Scheibe wird vom Himmel zurückgenommen
                for xx in range(bx - r, bx + r + 1):
                    if math.hypot(xx - (bx + 3), yy - (by - 2)) <= r - 0.5 and math.hypot(xx - bx, yy - by) <= r + 0.3:
                        c = stops_color(t["sky"], yy / float(HORIZON))
                        img.set(ox + xx, oy + yy, c)


def draw_sea(img, ox, oy, name, seed):
    t = THEME[name]
    far, near = t["sea"]
    for y in range(HORIZON, H):
        k = (y - HORIZON) / float(H - HORIZON)
        base = lerp_col(far, near, min(1.0, k * 1.25))
        for x in range(W):
            c = base
            n = fbm(x / 9.0, y / 2.0, seed + 31, 2)
            if n > 0.62 and (x + y) % 2 == 0:
                c = sh(base, 1)
            elif n < 0.32 and (x * 3 + y) % 3 == 0:
                c = sh(base, -1)
            img.set(ox + x, oy + y, c)
    # Spiegelung des Himmelskörpers: eine zerrissene senkrechte Spur
    kind, col, bx, by, r = t["body"]
    if kind != "none":
        for y in range(HORIZON + 1, H):
            width = max(1, int(r * (0.6 + (y - HORIZON) / 18.0)))
            for x in range(bx - width, bx + width + 1):
                if 0 <= x < W and hash01(x, y, seed + 3) > 0.35 + abs(x - bx) / float(width + 1) * 0.5 and y % 2 == 0:
                    img.set(ox + x, oy + y, lerp_col(img.get(ox + x, oy + y), col, 0.55))
    # Horizontlinie und Dunst
    for x in range(W):
        img.set(ox + x, oy + HORIZON, lerp_col(img.get(ox + x, oy + HORIZON), t["haze"], 0.55))
        for dy in range(1, 3):
            if BAYER[(HORIZON - dy) % 4][x % 4] / 16.0 < 0.5 / dy:
                c = img.get(ox + x, oy + HORIZON - dy)
                if c:
                    img.set(ox + x, oy + HORIZON - dy, lerp_col(c, t["haze"], 0.4))


def far_ship(img, ox, oy, x, y, col):
    """Kleine Segelschiff-Silhouette am Horizont."""
    img.rect(ox + x - 3, oy + y, ox + x + 3, oy + y, col)
    img.rect(ox + x - 2, oy + y + 1, ox + x + 2, oy + y + 1, col)
    for k in range(6):
        img.set(ox + x, oy + y - 1 - k, col)
    for k in range(4):
        img.rect(ox + x + 1, oy + y - 5 + k, ox + x + 1 + (3 - k) // 2 + 1, oy + y - 5 + k, col)


def far_scenery(img, ox, oy, name):
    t = THEME[name]
    dark = lerp_col(t["haze"], hx("#000000"), 0.7)
    if name == "draugr":
        far_ship(img, ox, oy, 86, HORIZON, dark)
        far_ship(img, ox, oy, 204, HORIZON, lerp_col(dark, t["haze"], 0.25))
    elif name == "raeuber":
        far_ship(img, ox, oy, 30, HORIZON, dark)
    elif name == "haendler":
        far_ship(img, ox, oy, 150, HORIZON, dark)
        for k in range(3):
            img.set(ox + 20 + k * 9, oy + HORIZON - 5 - (k % 2), dark)
    elif name == "dorf":
        for x in range(W):  # Hügel am Horizont
            h = int(5 + 4 * math.sin(x / 17.0) + 3 * math.sin(x / 7.0 + 1.0))
            for y in range(HORIZON - h, HORIZON):
                img.set(ox + x, oy + y, lerp_col(dark, hx("#1c0e12"), 0.5))
        for hx0 in (150, 170, 196):  # Häuser mit Licht
            img.rect(ox + hx0, oy + HORIZON - 6, ox + hx0 + 4, oy + HORIZON - 3, hx("#1a0c10"))
            img.set(ox + hx0 + 2, oy + HORIZON - 4, hx("#ffc860"))
    elif name == "kraken":
        for x in range(W):  # hohe dunkle Wellen am Horizont
            h = int(3 + 3 * math.sin(x / 9.0) + 2 * math.sin(x / 4.0 + 2.0))
            for y in range(HORIZON - h, HORIZON):
                img.set(ox + x, oy + y, lerp_col(dark, hx("#000000"), 0.4))


def shield(img, x, y, kind):
    pals = [(hx("#b8403a"), hx("#e8e0c8")), (hx("#3a5a9a"), hx("#e8c84a")), (hx("#e8e0c8"), hx("#b8403a")), (hx("#4a8a4a"), hx("#e8e0c8")),
            (hx("#e8c84a"), hx("#3a5a9a"))]
    a, b = pals[kind % len(pals)]
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if dx * dx + dy * dy <= 10:
                img.set(x + dx, y + dy, a if (dx > 0) == (dy > 0) or dx == 0 or dy == 0 else b)
    img.set(x, y, hx("#c8c0b0"))
    for dx in range(-3, 4):
        if dx * dx <= 10:
            img.set(x + dx, y + 3 if dx * dx < 7 else y + 2, hx("#2a2018"))


def barrel(img, x, y, wood, wood_d, wood_l):
    img.rect(x, y, x + 6, y + 8, wood)
    img.rect(x, y, x, y + 8, wood_l)
    img.rect(x + 6, y, x + 6, y + 8, wood_d)
    img.rect(x, y + 2, x + 6, y + 2, hx("#3a3a40"))
    img.rect(x, y + 6, x + 6, y + 6, hx("#3a3a40"))
    img.rect(x + 1, y - 1, x + 5, y - 1, wood_l)


def crate(img, x, y, wood, wood_d, wood_l):
    img.rect(x, y, x + 8, y + 7, wood)
    img.rect(x, y, x + 8, y, wood_l)
    img.rect(x, y + 7, x + 8, y + 7, wood_d)
    img.rect(x + 8, y, x + 8, y + 7, wood_d)
    for k in range(0, 9):
        img.set(x + k, y + 1 + k * 6 // 8, wood_d)
    img.rect(x, y, x, y + 7, wood_l)


def coil(img, x, y):
    c1, c2 = hx("#b89868"), hx("#7a603a")
    for dy in range(0, 5):
        for dx in range(0, 9):
            r = ((dx - 4) / 4.5) ** 2 + ((dy - 2) / 2.5) ** 2
            if r <= 1.0:
                img.set(x + dx, y + dy, c1 if (dx + dy) % 3 else c2)


def gap_color(x, y, seed):
    """Dunkles Wasser zwischen den Schiffen mit blassen Glanzlichtern."""
    n = hash01(x, y // 2, seed)
    if n > 0.86:
        return hx("#24465a")
    if n > 0.55:
        return hx("#10222e")
    return hx("#070e14")


def rail(img, ox, oy, name, seed):
    t = THEME[name]
    wood, wood_d, wood_l = t["wood"], t["wood_d"], t["wood_l"]
    for x in range(W):
        gap = GAP_X <= x < GAP_X + 4
        if gap:
            for y in range(RAIL_Y, H):
                img.set(ox + x, oy + y, gap_color(x, y, 5))
            continue
        # Reling: Balken, oben Licht, unten Schatten; darunter die Bordwand
        img.set(ox + x, oy + RAIL_Y, rgba(wood_l))
        img.set(ox + x, oy + RAIL_Y + 1, rgba(wood))
        img.set(ox + x, oy + RAIL_Y + 2, rgba(wood))
        img.set(ox + x, oy + RAIL_Y + 3, rgba(wood_d))
        for y in range(RAIL_Y + 4, H):
            img.set(ox + x, oy + y, rgba(sh(wood_d, -1 if (x // 6 + y) % 5 else 0)))
    # Pfosten
    for px in list(range(8, 112, 26)) + list(range(138, 236, 26)):
        img.rect(ox + px, oy + RAIL_Y - 6, ox + px + 2, oy + RAIL_Y + 3, rgba(wood))
        img.rect(ox + px, oy + RAIL_Y - 6, ox + px, oy + RAIL_Y + 3, rgba(wood_l))
        img.rect(ox + px + 2, oy + RAIL_Y - 6, ox + px + 2, oy + RAIL_Y + 3, rgba(wood_d))
        img.rect(ox + px - 1, oy + RAIL_Y - 7, ox + px + 3, oy + RAIL_Y - 7, rgba(wood_l))
    # Seil zwischen den Pfosten (durchhängend)
    for a, b in list(zip(range(9, 85, 26), range(35, 111, 26))) + list(zip(range(139, 213, 26), range(165, 239, 26))):
        for x in range(a, b + 1):
            sag = int(2.4 * math.sin(math.pi * (x - a) / float(b - a)))
            img.set(ox + x, oy + RAIL_Y - 5 + sag, hx("#a08a5a"))
    # Linke Seite: Schilde an der Reling (eigenes Langschiff)
    for k, x in enumerate(range(14, 110, 16)):
        shield(img, ox + x, oy + RAIL_Y + 9 if False else oy + RAIL_Y - 1, k + seed)


def props(img, ox, oy, name):
    t = THEME[name]
    wood, wood_d, wood_l = t["wood"], t["wood_d"], t["wood_l"]
    y0 = RAIL_Y - 8
    if name == "haendler":
        crate(img, ox + 140, oy + y0, wood, wood_d, wood_l)
        crate(img, ox + 150, oy + y0 + 1, wood, wood_d, wood_l)
        barrel(img, ox + 212, oy + y0, wood, wood_d, wood_l)
        coil(img, ox + 226, oy + RAIL_Y - 5)
    elif name == "raeuber":
        barrel(img, ox + 146, oy + y0, wood, wood_d, wood_l)
        barrel(img, ox + 154, oy + y0, wood, wood_d, wood_l)
        # Piratenfähnchen am Pfosten
        for k in range(5):
            img.rect(ox + 190, oy + RAIL_Y - 14 + k, ox + 190 + 4 - k, oy + RAIL_Y - 14 + k, hx("#1a1014"))
        img.set(ox + 192, oy + RAIL_Y - 13, hx("#e8e0c8"))
    elif name == "draugr":
        for x in (150, 182, 214):  # Tang und Muscheln an der Reling
            for k in range(7):
                img.set(ox + x + (k % 2), oy + RAIL_Y + 3 + k, hx("#1f5a46") if k % 3 else hx("#2f8a68"))
        coil(img, ox + 146, oy + RAIL_Y - 4)
    elif name == "dorf":
        for x in (146, 190, 230):  # Pfähle des Stegs mit Festmachern
            img.rect(ox + x, oy + RAIL_Y - 10, ox + x + 2, oy + RAIL_Y + 3, wood_l)
            img.rect(ox + x - 1, oy + RAIL_Y - 11, ox + x + 3, oy + RAIL_Y - 10, wood)
        barrel(img, ox + 160, oy + y0, wood, wood_d, wood_l)
        crate(img, ox + 205, oy + y0, wood, wood_d, wood_l)
    elif name == "kraken":
        coil(img, ox + 150, oy + RAIL_Y - 4)
        barrel(img, ox + 214, oy + y0, wood, wood_d, wood_l)


def make_back():
    """Gibt (Hintergrund, Reling-Ebene) zurück: der Hintergrund ist deckend (Himmel, Meer, Ferne), die Reling-Ebene hat
    Alpha und kommt im Spiel NACH den Schiffsaufbauten, damit die Reling vor den Segeln steht."""
    img = Img(W, H * len(ORTE))
    rl = Img(W, RAIL_H * len(ORTE))
    for i, name in enumerate(ORTE):
        oy = i * H
        seed = 100 + i * 13
        draw_sky(img, 0, oy, name, seed)
        draw_sea(img, 0, oy, name, seed)
        far_scenery(img, 0, oy, name)
        ry = i * RAIL_H - RAIL_TOP
        rail(rl, 0, ry, name, i)
        props(rl, 0, ry, name)
    return img, rl


# --- Deck -----------------------------------------------------------------------------------------

DECK = {
    "draugr": dict(own=hx("#6a4a30"), foe=hx("#4a5a4c"), seam=hx("#1a140f")),
    "raeuber": dict(own=hx("#6a4a30"), foe=hx("#5a2e26"), seam=hx("#1a100c")),
    "haendler": dict(own=hx("#6a4a30"), foe=hx("#8a6a44"), seam=hx("#2a1c10")),
    "dorf": dict(own=hx("#6a4a30"), foe=hx("#5a4636"), seam=hx("#1a120c")),
    "kraken": dict(own=hx("#4a3a3c"), foe=hx("#3a2e3a"), seam=hx("#0e0a10")),
}


def make_deck():
    img = Img(W, DECK_H * len(ORTE))
    for i, name in enumerate(ORTE):
        d = DECK[name]
        oy = i * DECK_H
        for y in range(DECK_H):
            row = y // 5
            for x in range(W):
                gap = GAP_X <= x < GAP_X + 4
                if gap:
                    img.set(x, oy + y, lerp_col(gap_color(x, y, 9), hx("#020304"), (y / float(DECK_H - 1)) * 0.6))
                    continue
                base = d["own"] if x < GAP_X else d["foe"]
                off = (row * 23 + (0 if x < GAP_X else 11)) % 41
                tone = 0
                if y % 5 == 0:
                    tone = -2            # Fuge zwischen den Planken
                elif y % 5 == 1:
                    tone = 1             # Lichtkante
                if (x + off) % 41 == 0 and y % 5 != 0:
                    tone = -2            # Stoß
                n = hash01(x // 2, y, 7 + i)
                if n < 0.12 and tone == 0:
                    tone = -1
                elif n > 0.93 and tone == 0:
                    tone = 1
                c = sh(base, tone)
                fade = y / float(DECK_H - 1)  # nach vorn (unten) dunkler
                c = lerp_col(c, hx("#050608"), fade * 0.55)
                img.set(x, oy + y, c)
        # Enterbrücke: zwei Bohlen über die Lücke, mit Tauen
        for y in range(1, 7):
            for x in range(GAP_X - 5, GAP_X + 9):
                tone = 1 if y in (1, 4) else (-1 if y in (3, 6) else 0)
                img.set(x, oy + y, sh(hx("#8a6a44"), tone))
        for x in range(GAP_X - 5, GAP_X + 9):
            img.set(x, oy + 0, hx("#2a1c10"))
            img.set(x, oy + 7, hx("#2a1c10"))
        for x in (GAP_X - 4, GAP_X + 8):
            for y in range(0, 8):
                img.set(x, oy + y, hx("#a08a5a"))
        # Rand zur Lücke: Lichtkante
        for y in range(DECK_H):
            img.set(GAP_X - 1, oy + y, sh(d["own"], -2))
            img.set(GAP_X + 4, oy + y, sh(d["foe"], -2))
        # Nagelköpfe
        for y in range(2, DECK_H, 5):
            for x in range(6, W, 29):
                if not (GAP_X - 3 <= x < GAP_X + 7):
                    img.set(x, oy + y, lerp_col(sh(d["own"], 2), hx("#050608"), y / float(DECK_H) * 0.5))
    return img


# --- Licht und Nebel ------------------------------------------------------------------------------

def make_glow():
    """Links eine runde Lichtkugel (64x64), rechts eine flache Lichtpfütze (96x32); weiß mit Alpha, im Spiel eingefärbt."""
    img = Img(64 + 96, 64)
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - 31.5, y - 31.5) / 32.0
            a = max(0.0, 1.0 - d)
            img.set(x, y, (255, 255, 255, int(255 * a * a * (0.6 + 0.4 * a))))
    for y in range(32):
        for x in range(96):
            d = math.hypot((x - 47.5) / 48.0, (y - 15.5) / 16.0)
            a = max(0.0, 1.0 - d)
            img.set(64 + x, y, (255, 255, 255, int(255 * a * a)))
    return img


def make_fog():
    """Nahtlos kachelnder Nebelstreifen 256x40: weiße Schwaden mit Alpha, oben und unten ausgeblendet."""
    w, h = 256, 40
    img = Img(w, h)
    for y in range(h):
        edge = math.sin(math.pi * (y + 0.5) / h)
        for x in range(w):
            v = 0.0
            amp, f, tot = 1.0, 1.0, 0.0
            for o in range(3):
                # nahtlos in x: Rauschen über einem Kreis
                ang = 2.0 * math.pi * x / w
                r = 2.2 * f
                v += vnoise(math.cos(ang) * r * 3.0 + 40.0, math.sin(ang) * r * 3.0 + y / (7.0 / f), 11 + o) * amp
                tot += amp
                amp *= 0.5
                f *= 2.0
            v = v / tot
            a = max(0.0, (v - 0.4) * 2.6) * edge
            q = BAYER[y % 4][x % 4] / 16.0
            a = min(1.0, a) * 0.85
            img.set(x, y, (255, 255, 255, int(255 * a) if a > q * 0.22 else int(255 * a * 0.5)))
    return img


def write_gd(here):
    src = '''class_name StageAtlas
extends RefCounted

## Lage der Teile in assets/stage_*.png. ERZEUGT von tools/make_stage_art.py, nicht von Hand ändern.

const ORTE := %s
const BACK_SIZE := Vector2i(%d, %d)   # ein Ort im Hintergrund (halbe Auflösung, im Spiel doppelt gezeichnet)
const RAIL_SIZE := Vector2i(%d, %d)   # Reling-Ebene mit Alpha, beginnt in Zeile RAIL_TOP des Hintergrunds
const RAIL_TOP := %d
const DECK_SIZE := Vector2i(%d, %d)
const GLOW_BALL := Rect2(0, 0, 64, 64)
const GLOW_POOL := Rect2(64, 0, 96, 32)
const FOG_SIZE := Vector2i(256, 40)
const HORIZON := %d  # Zeile des Horizonts im Hintergrund
const RAIL_Y := %d   # Oberkante der Reling
const GAP_X := %d    # Lücke zwischen den Schiffen
''' % (str(ORTE).replace("'", '"'), W, H, W, RAIL_H, RAIL_TOP, W, DECK_H, HORIZON, RAIL_Y, GAP_X)
    with open(os.path.join(here, "..", "scripts", "stage_atlas.gd"), "w", encoding="utf-8", newline="\n") as f:
        f.write(src)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    (back, rail_img), deck, glow, fog = make_back(), make_deck(), make_glow(), make_fog()
    back.save(os.path.join(here, "..", "assets", "stage_back.png"))
    rail_img.save(os.path.join(here, "..", "assets", "stage_rail.png"))
    deck.save(os.path.join(here, "..", "assets", "stage_deck.png"))
    glow.save(os.path.join(here, "..", "assets", "stage_glow.png"))
    fog.save(os.path.join(here, "..", "assets", "stage_fog.png"))
    write_gd(here)
    print("assets/stage_back.png, stage_deck.png, stage_glow.png, stage_fog.png und scripts/stage_atlas.gd geschrieben")
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(folder, exist_ok=True)
        bg = hx("#101018")
        # je Ort Hintergrund und Deck übereinander, doppelt vergrößert wie im Spiel
        for i, name in enumerate(ORTE):
            tile = Img(W, H + DECK_H - 5)
            for y in range(H):
                for x in range(W):
                    tile.px[y][x] = back.px[i * H + y][x]
            for y in range(RAIL_H):
                for x in range(W):
                    c = rail_img.px[i * RAIL_H + y][x]
                    if c is not None:
                        tile.px[RAIL_TOP + y][x] = c
            for y in range(DECK_H):
                for x in range(W):
                    tile.px[H - 5 + y][x] = deck.px[i * DECK_H + y][x]
            tile.filled_bg(bg).scaled(4).save(os.path.join(folder, "stage_%s.png" % name))
        print("Vorschau in", folder)


if __name__ == "__main__":
    main()
