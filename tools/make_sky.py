"""Erzeugt die Pixelart-Assets fuer Himmel und Horizont (reines Python, keine Abhaengigkeiten).

Aufruf:
    python -X utf8 -I tools/make_sky.py                  -> schreibt nach assets/
    python -X utf8 -I tools/make_sky.py --preview ordner -> zusaetzlich Vorschaubild

assets/cloud_noise.png   256x256, kachelbares Rauschen (R grob, G fein, B sehr grob), jeweils
                         rangentzerrt (gleichverteilt 0..1): der Himmels-Shader schneidet daraus mit
                         harten Schwellen die Wolken, Bayer-Raster ergibt die Ausfransung.
assets/coast.png         640x40, kachelbarer Kuestenstreifen am Horizont (dunstige Felszaehne,
                         Inseln, Kiefernkamm, ein winziges Leuchtfeuer), Grundlinie unten.
assets/gulls.png         3 Moewen-Frames (12x8): Fluegel hoch, flach, tief.
"""
import math
import os
import random
import struct
import sys
import zlib


def save_png(path, w, h, rows, mode):
    """rows: Liste von Zeilen, je Zeile Liste von Tupeln. mode 'rgb' oder 'rgba'."""
    ct = {"rgb": 2, "rgba": 6}[mode]
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for c in row:
            raw.extend(c)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


# --- Wolkenrauschen --------------------------------------------------------------------


def periodic_noise(size, cells, seed):
    rnd = random.Random(seed)
    lat = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * size for _ in range(size)]
    step = cells / size
    for y in range(size):
        fy = y * step
        j = int(fy)
        ty = fy - j
        ty = ty * ty * (3 - 2 * ty)
        j0, j1 = j % cells, (j + 1) % cells
        for x in range(size):
            fx = x * step
            i = int(fx)
            tx = fx - i
            tx = tx * tx * (3 - 2 * tx)
            i0, i1 = i % cells, (i + 1) % cells
            a = lat[j0][i0] + (lat[j0][i1] - lat[j0][i0]) * tx
            b = lat[j1][i0] + (lat[j1][i1] - lat[j1][i0]) * tx
            out[y][x] = a + (b - a) * ty
    return out


def fbm(size, base_cells, octaves, seed, gain=0.5):
    acc = [[0.0] * size for _ in range(size)]
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = periodic_noise(size, base_cells * (2 ** o), seed + o * 101)
        for y in range(size):
            row, nr = acc[y], n[y]
            for x in range(size):
                row[x] += nr[x] * amp
        total += amp
        amp *= gain
    return acc


def equalize(field, size):
    """Rangtransformation: danach ist die Verteilung gleichmaessig (Schwelle t = Deckung 1-t)."""
    flat = sorted(v for row in field for v in row)
    n = len(flat)
    lut = {}
    for i, v in enumerate(flat):
        lut.setdefault(v, i / (n - 1))
    return [[lut[v] for v in row] for row in field]


def make_cloud_noise(path):
    size = 256
    r = equalize(fbm(size, 4, 4, 11), size)
    g = equalize(fbm(size, 8, 4, 77, 0.55), size)
    b = equalize(fbm(size, 2, 3, 303), size)
    rows = []
    for y in range(size):
        rows.append([(int(r[y][x] * 255), int(g[y][x] * 255), int(b[y][x] * 255)) for x in range(size)])
    save_png(path, size, size, rows, "rgb")


# --- Kueste ------------------------------------------------------------------------------

COAST_W, COAST_H = 640, 40

RIM = hx("#8392a0")
BODY = hx("#566878")
SHADE = hx("#41525f")
DEEP = hx("#34434f")
HAZE = hx("#64757f")
FIRE = hx("#c9a13b")

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def make_coast(path, preview=None):
    rnd = random.Random(5)
    w, h = COAST_W, COAST_H
    base = h - 1  # Grundlinie (wird vom Wasser ueberdeckt)
    height = [0] * w  # Hoehe der Silhouette in Pixeln ueber der Grundlinie

    def hill(x0, x1, peak, rough):
        span = x1 - x0
        for x in range(x0, x1):
            t = (x - x0) / span
            v = math.sin(t * math.pi) ** 0.8 * peak
            v += math.sin(x * 0.31 + x0) * rough + math.sin(x * 0.13) * rough * 1.5
            height[x] = max(height[x], int(round(v)))

    def spike(cx, hh, ww):
        for dx in range(-ww, ww + 1):
            v = hh * (1 - abs(dx) / (ww + 1.0)) ** 1.15
            x = (cx + dx) % w
            height[x] = max(height[x], int(round(v)))

    # Inseln, jeweils mit Luecke zum Nachbarn (der Streifen kachelt nahtlos)
    hill(30, 190, 13, 0.8)
    for cx, hh, ww in ((58, 21, 3), (66, 17, 2), (122, 19, 3), (131, 15, 2), (170, 16, 2)):
        spike(cx, hh, ww)
    hill(250, 318, 9, 0.7)
    for cx, hh, ww in ((266, 18, 2), (273, 23, 3), (282, 14, 2), (301, 11, 2)):
        spike(cx, hh, ww)
    hill(380, 470, 6, 0.6)
    hill(450, 600, 15, 0.9)
    for cx, hh, ww in ((470, 20, 3), (482, 17, 2), (556, 22, 3), (566, 18, 2)):
        spike(cx, hh, ww)
    # Kiefernkamm auf der letzten Insel: winzige Zacken
    for x in range(500, 548, 3):
        spike(x + rnd.randint(-1, 1), height[x % w] + rnd.randint(3, 4), 1)

    px = [[(0, 0, 0, 0)] * w for _ in range(h)]
    for x in range(w):
        top = base - height[x]
        for y in range(max(top, 0), h):
            d = y - top
            if d == 0:
                c = RIM
            elif d == 1 and (x + y) % 2 == 0:
                c = RIM
            elif d < 5:
                c = BODY
            elif d < 11:
                c = BODY if (x * 3 + y * 5) % 7 < 2 and d < 8 else SHADE
            else:
                c = SHADE if BAYER4[y % 4][x % 4] < 9 else DEEP
            # Dunst am Fuss: wird von unten her ins Helle gedithert
            fade = (y - (h - 9)) / 8.0
            if fade > 0 and BAYER4[y % 4][x % 4] / 16.0 < fade:
                c = HAZE
            px[y][x] = c
    # Felsfalten: waagerechte Schattenstriche unter den Zacken
    for x in range(w):
        top = base - height[x]
        if height[x] > 9 and (x * 7) % 5 == 0:
            for y in range(top + 3, min(top + 7, h)):
                if px[y][x][3]:
                    px[y][x] = SHADE
    # Leuchtfeuer (sparsamer warmer Akzent) auf dem Kamm der letzten Insel
    fx = 556
    fy = base - height[fx] - 1
    px[fy][fx] = FIRE
    px[fy - 1][fx] = hx("#8a6c28")
    save_png(path, w, h, px, "rgba")
    if preview:
        bg = hx("#8b97a2")
        rows = []
        for y in range(h):
            rows.append([c if c[3] else bg for c in px[y]])
        save_png(os.path.join(preview, "coast_preview.png"), w, h, rows, "rgba")


# --- Moewen ------------------------------------------------------------------------------


def make_gulls(path):
    body = hx("#c9cfd2")
    tip = hx("#7d8a94")
    frames = []
    # (x, y)-Pixel je Frame, 12x8; Koerper in der Mitte
    up = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 4), (5, 5), (6, 5), (7, 4), (8, 4), (9, 3), (10, 2), (11, 1)]
    flat = [(0, 3), (1, 3), (2, 3), (3, 4), (4, 4), (5, 5), (6, 5), (7, 4), (8, 4), (9, 3), (10, 3), (11, 3)]
    down = [(0, 5), (1, 5), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 5), (11, 5)]
    for pts in (up, flat, down):
        f = [[(0, 0, 0, 0)] * 12 for _ in range(8)]
        for i, (x, y) in enumerate(pts):
            f[y][x] = tip if i in (0, 11) else body
        # Rumpf: 2 Pixel dick
        f[pts[5][1] + 1][5] = body
        f[pts[6][1] + 1][6] = body
        frames.append(f)
    rows = []
    for y in range(8):
        row = []
        for f in frames:
            row.extend(f[y])
        rows.append(row)
    save_png(path, 12 * len(frames), 8, rows, "rgba")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets")
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(preview, exist_ok=True)
    make_cloud_noise(os.path.join(out, "cloud_noise.png"))
    make_coast(os.path.join(out, "coast.png"), preview)
    make_gulls(os.path.join(out, "gulls.png"))
    print("fertig")


if __name__ == "__main__":
    main()
