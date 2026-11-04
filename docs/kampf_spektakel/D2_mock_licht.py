"""D2: Python-Mock des Lichtmodells (KEIN Engine-Bild, nur eine Rechenprobe der Algorithmen, die D2_bild.md als Shader vorschreibt).

Zeigt auf der vorgesehenen Bühne (480 x 215, Füße y 172) die Rig-Figuren aus R2 (Körper 65 px) mit:
  * Abstufung der Kulisse (Entsättigen, Farbstich, Abdunkeln, gedithertes Rampenlicht, gedithertes Vignette),
  * additivem Leuchten der Laternen/Fackeln/Irrlichter (6 Stufen mit Bayer-Dithering),
  * Figuren: Ortsfarbe (Umgebungslicht), Lampenlicht, Randlicht (nur die Pixel INNEN neben der dunklen Kontur, zur Lampe hin und oben),
    Kontaktschatten, geworfener Schatten (platt gedrückte Silhouette, von der Lampe weggeneigt), Spiegelung auf nassem Deck,
  * Angreifer im Rampenlicht mit Nachbildern, Ziel im weißen Treffer-Blitz, Halo am Einschlag.
Aufruf (Projektordner): python -X utf8 docs/kampf_spektakel/D2_mock_licht.py docs/kampf_spektakel/img
Reine Standardbibliothek; benutzt R2_rig_proto.py (liegt im selben Ordner) und tools/make_art.py.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import R2_rig_proto as rig  # noqa: E402
from make_art import Img  # noqa: E402

W, H = 480, 215
FEET = 172
BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def bay(x, y):
    return (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0


def clamp(v, a=0.0, b=255.0):
    return a if v < a else (b if v > b else v)


def noise(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 982451653) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFF) / 255.0


def vnoise(x, y, s=0):
    xi, yi = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - xi, y - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = noise(xi, yi, s)
    b = noise(xi + 1, yi, s)
    c = noise(xi, yi + 1, s)
    d = noise(xi + 1, yi + 1, s)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy


THEMES = {
    "raeuber": dict(
        zen=(26, 20, 26), hor=(120, 62, 34), sea=(26, 20, 24), tint=(0.95, 0.50, 0.30), tint_amt=0.30, dark=0.30, desat=0.30,
        lamp=(255, 158, 64), key=(255, 214, 128), rim=(255, 170, 90), wet=False,
        lamps=[(26, 120, "torch"), (240, 112, "brazier"), (454, 120, "torch")],
        plank=((59, 42, 29), (66, 48, 31), (56, 40, 27)), sail=((70, 18, 20), (24, 20, 24)), fog=(0.30, (120, 80, 60)),
    ),
    "draugr": dict(
        zen=(8, 18, 18), hor=(40, 84, 72), sea=(12, 24, 26), tint=(0.35, 0.90, 0.72), tint_amt=0.45, dark=0.38, desat=0.45,
        lamp=(110, 255, 200), key=(230, 255, 230), rim=(120, 255, 210), wet=True,
        lamps=[(70, 92, "wisp"), (246, 70, "wisp"), (408, 98, "wisp")],
        plank=((48, 44, 38), (54, 49, 41), (44, 41, 35)), sail=((58, 74, 66), (36, 48, 44)), fog=(0.95, (150, 200, 190)),
    ),
}


def build_background(th):
    """Roh-Kulisse ohne Licht: Himmel, Meer, Schiffe, Reling, Deck, Requisiten. Liefert (Pixel, Tiefenmaske der Lampen)."""
    px = [[(0.0, 0.0, 0.0)] * W for _ in range(H)]
    hor = 104
    zen, hz = th["zen"], th["hor"]
    for y in range(H):
        for x in range(W):
            if y < hor:
                g = (y / hor) ** 1.6
                q = int(g * 5 + bay(x, y) - 0.25)
                g2 = min(5, max(0, q)) / 5.0
                c = tuple(zen[i] + (hz[i] - zen[i]) * g2 for i in range(3))
                # Wolken
                n = vnoise(x * 0.018 + 3, y * 0.07, 1) * 0.7 + vnoise(x * 0.05, y * 0.16, 2) * 0.3
                if n > 0.58 and 20 < y < 96:
                    k = 0.5 if n < 0.68 else 0.35
                    c = tuple(c[i] * k + zen[i] * (1 - k) * 0.5 for i in range(3))
                px[y][x] = c
            elif y < 156:
                t = (y - hor) / 52.0
                c = tuple(th["sea"][i] * (1.0 - 0.35 * t) + hz[i] * 0.25 * (1 - t) for i in range(3))
                if int(y + vnoise(x * 0.05, y * 0.5, 3) * 3) % 5 == 0 and noise(x // 3, y, 4) > 0.55:
                    c = tuple(clamp(c[i] * 1.5 + 6) for i in range(3))
                px[y][x] = c
    # Mond / Schein
    mx, my = (330, 46) if th is THEMES["raeuber"] else (250, 40)
    for y in range(my - 9, my + 10):
        for x in range(mx - 9, mx + 10):
            if (x - mx) ** 2 + (y - my) ** 2 <= 64 and (th is THEMES["draugr"] and (x - mx) ** 2 + (y - my + 2) ** 2 > 40 or th is THEMES["raeuber"]):
                px[y][x] = (232, 226, 200) if (x + y) % 7 else (210, 206, 180)
    # Segel und Mast, eigene Seite (links) und Gegnerseite (rechts)
    def sail(x0, x1, y0, y1, cols, stripe):
        for y in range(y0, y1):
            for x in range(x0, x1):
                k = ((x - x0) // stripe) % 2
                c = cols[k]
                n = noise(x, y, 7) * 14 - 7
                px[y][x] = tuple(clamp(c[i] + n) for i in range(3))
        for y in range(y0 - 3, y1 + 40):
            for x in range((x0 + x1) // 2 - 1, (x0 + x1) // 2 + 2):
                if 0 <= y < H:
                    px[y][x] = (38, 28, 20)
        for x in range(x0 - 4, x1 + 4):
            px[y0 - 3][x] = (46, 34, 24)
            px[y0 - 2][x] = (30, 22, 16)
            px[y1][x] = (30, 22, 16)
    own = ((120, 40, 40), (200, 184, 150))
    sail(70, 150, 14, 96, own, 10)
    sail(318, 410, 26, 100, th["sail"], 12)
    # Takelage: gespannte Linien
    for i in range(0, 110):
        x = 110 + i * 3
        y = int(14 + (x - 110) * 0.55) if x < 320 else 80
        if 0 <= y < H - 1 and x < W:
            px[y][x] = (30, 24, 20)
    # Reling hinten (Balken + Pfosten)
    for x in range(W):
        for y, c in ((136, (96, 70, 46)), (137, (62, 44, 30)), (138, (42, 30, 20)), (139, (42, 30, 20)), (140, (18, 13, 10)), (141, (18, 13, 10))):
            px[y][x] = c
    for x0 in range(10, W, 58):
        for y in range(118, 137):
            for x in range(x0, x0 + 4):
                px[y][x] = (82, 60, 40) if x == x0 else (46, 33, 22)
    # Deck
    pl = th["plank"]
    for y in range(142, H):
        row = (y - 142) // 8
        for x in range(W):
            c = pl[row % 3]
            if (y - 142) % 8 == 0:
                c = (24, 17, 12)
            elif (y - 142) % 8 == 1:
                c = tuple(c[i] * 1.18 for i in range(3))
            off = (row % 3) * 23
            if (x + off) % 69 == 0 and (y - 142) % 8 > 1:
                c = (24, 17, 12)
            px[y][x] = c
    # Fuge
    for y in range(130, H):
        for x in range(237, 243):
            px[y][x] = (11, 10, 14) if x not in (237, 242) else (107, 74, 48)
    # Requisiten: Fässer, Kisten, Tau
    def barrel(x, base, w, h):
        for y in range(base - h, base):
            for x2 in range(x, x + w):
                c = (79, 52, 32)
                if x2 == x:
                    c = (122, 87, 51)
                if x2 == x + w - 1:
                    c = (46, 29, 16)
                if y in (base - h + 3, base - h + 4, base - 6, base - 5):
                    c = (23, 18, 14)
                px[y][x2] = c
    barrel(8, 160, 17, 22)
    barrel(24, 158, 13, 16)
    for (x0, b, w, h) in ((456, 162, 20, 18), (443, 164, 14, 12)):
        for y in range(b - h, b):
            for x in range(x0, x0 + w):
                c = (91, 63, 38)
                if x in (x0, x0 + w - 1) or y in (b - h, b - 1):
                    c = (46, 29, 16)
                px[y][x] = c
    # Vordergrund-Silhouetten (Mastfüße) links und rechts: dunkel, werden nicht abgestuft
    return px


def grade(px, th, spot, amt, lit=True):
    """Abstufung wie stage_grade.gdshader: entsättigen, Ortsfarbe, abdunkeln, Rampenlicht (Ellipse, 5 Stufen gedithert), Vignette."""
    out = [row[:] for row in px]
    sx, sy, rx, ry = spot
    for y in range(H):
        for x in range(W):
            c = px[y][x]
            lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
            d = th["desat"]
            c1 = tuple(c[i] * (1 - d) + lum * d for i in range(3))
            ta = th["tint_amt"]
            t = th["tint"]
            c1 = tuple(c1[i] * (1 - ta) + c1[i] * t[i] * 1.7 * ta for i in range(3))
            c1 = tuple(v * (1 - th["dark"]) for v in c1)
            dd = math.hypot((x + 0.5 - sx) / rx, (y + 0.5 - sy) / ry)
            L = (1.0 - min(1.0, max(0.0, (dd - 0.2) / 0.8))) * amt
            Lq = clamp(math.floor(L * 5 + bay(x, y)) / 5.0, 0.0, 1.0)
            w = (1.0, 0.88, 0.7)
            litc = tuple(clamp(c[i] * (1 - 0.25) + c[i] * w[i] * 1.1 * 0.25) for i in range(3))
            cc = tuple(c1[i] * (1 - Lq) + litc[i] * Lq for i in range(3))
            ex, ey = (x - 240) / 240.0, (y - 107) / 107.0
            vd = math.hypot(ex, ey * 1.1)
            V = clamp((vd - 0.55) / 0.75, 0.0, 1.0) * 0.55
            Vq = math.floor(V * 5 + bay(x, y)) / 5.0
            out[y][x] = tuple(v * (1 - Vq * 0.85) for v in cc)
    return out


def add_glow(px, cx, cy, r, col, amt, bands=6, squash=1.0):
    x0, x1 = max(0, int(cx - r)), min(W, int(cx + r) + 1)
    y0, y1 = max(0, int(cy - r * squash)), min(H, int(cy + r * squash) + 1)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) / squash) / r
            if d >= 1.0:
                continue
            v = (1.0 - d) ** 2
            v = math.floor(v * bands + bay(x, y)) / bands
            if v <= 0:
                continue
            c = px[y][x]
            px[y][x] = tuple(clamp(c[i] + col[i] * v * amt) for i in range(3))


def fog_band(px, y0, y1, dens, col, drift):
    for y in range(y0, y1):
        band = 1.0 - abs((y - y0) / max(1, (y1 - y0)) * 2 - 1)
        for x in range(W):
            n = vnoise((x + drift) * 0.02, y * 0.09, 9) * 0.7 + vnoise((x + drift) * 0.05, y * 0.2, 10) * 0.3
            v = max(0.0, min(1.0, (n * (0.55 + band * 0.7) - 0.35) / 0.45)) * dens
            q = math.floor(v * 4 + bay(x, y)) / 4.0
            if q > 0:
                c = px[y][x]
                a = q * 0.5
                px[y][x] = tuple(c[i] * (1 - a) + col[i] * a for i in range(3))


def lamps_draw(px, th, t=0.0):
    for i, (lx, ly, kind) in enumerate(th["lamps"]):
        fl = 0.85 + 0.15 * math.sin(t * 9 + i * 2) * math.sin(t * 5.3 + i)
        col = th["lamp"]
        if kind == "torch":
            for y in range(ly + 4, 160):  # Ständer
                for x in range(lx - 1, lx + 2):
                    px[y][x] = (28, 20, 14)
            for y in range(ly - 6, ly + 6):  # Flamme
                for x in range(lx - 3, lx + 4):
                    w = 3 - abs(y - ly + 6) // 3
                    if abs(x - lx) <= max(0, w - (1 if y < ly - 2 else 0)):
                        px[y][x] = (255, 214, 110) if abs(x - lx) < 2 else (255, 130, 40)
        elif kind == "brazier":
            for y in range(ly + 6, 160):
                for x in range(lx - 1, lx + 2):
                    px[y][x] = (20, 15, 12)
            for y in range(ly + 2, ly + 8):
                for x in range(lx - 7, lx + 8):
                    if y - (ly + 2) < 6 - abs(x - lx) // 2:
                        px[y][x] = (40, 30, 24)
            for y in range(ly - 8, ly + 3):
                for x in range(lx - 5, lx + 6):
                    w = 5 - (ly + 3 - y) // 2
                    if abs(x - lx) <= max(0, w):
                        px[y][x] = (255, 226, 130) if abs(x - lx) < 3 else (255, 120, 30)
        else:  # Irrlicht
            for y in range(ly - 4, ly + 5):
                for x in range(lx - 2, lx + 3):
                    if (x - lx) ** 2 + (y - ly) ** 2 <= 5:
                        px[y][x] = (220, 255, 240)
        add_glow(px, lx, ly - (3 if kind != "wisp" else 0), 70 * (0.92 + 0.08 * fl), col, 0.75 * fl)
        add_glow(px, lx, ly - 3, 12, (255, 255, 230), 0.8 * fl)


# --- Figuren ----------------------------------------------------------------------------------------------

def figure_pixels(spec_name, frame, mirrored):
    im = rig.person(rig.PROTOS[spec_name], frame)
    if mirrored:
        im = rig.mirror(im)
    ax = (rig.CW - 1 - rig.AX) if mirrored else rig.AX
    return im, ax


def is_outline(c):
    return c is not None and c[0] + c[1] + c[2] < 90


def shade_fig(im, th, lit, flash=0.0, red=0.0, lamp_xs=()):
    """Wie fighter_lit.gdshader: entsättigen, Ortsfarbe, abdunkeln, Randlicht innen neben der Kontur, weißer Blitz."""
    out = Img(im.w, im.h)
    d = th["desat"] * (0.0 if lit else 0.6)
    ta = th["tint_amt"] * 0.7 * (0.5 if lit else 1.0)
    dim = 0.0 if lit else th["dark"] * 0.95
    for y in range(im.h):
        for x in range(im.w):
            c = im.px[y][x]
            if c is None:
                continue
            lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
            v = [c[i] * (1 - d) + lum * d for i in range(3)]
            v = [v[i] * (1 - ta) + v[i] * th["tint"][i] * 1.7 * ta for i in range(3)]
            v = [x_ * (1 - dim) for x_ in v]
            if lit:
                v = [v[0] * 1.06, v[1] * 1.0, v[2] * 0.92]
            # Randlicht: Nachbar oben bzw. zur Lampe hin ist Kontur
            if not is_outline(c):
                top = is_outline(im.get(x, y - 1)) or im.get(x, y - 1) is None
                side = False
                if lamp_xs:
                    sgn = lamp_xs[0]
                    nb = im.get(x + sgn, y)
                    side = is_outline(nb) or nb is None
                k = 0.0
                if side:
                    k += 0.9 if lit else 0.7
                if top:
                    k += 0.45 if lit else 0.25
                if k > 0:
                    rc = th["key"] if lit else th["rim"]
                    v = [clamp(v[i] + rc[i] * k * 0.6) for i in range(3)]
            if flash > 0:
                v = [v[i] * (1 - flash) + 255 * flash for i in range(3)]
            if red > 0:
                v = [v[0] * (1 + 0.7 * red), v[1] * (1 - 0.5 * red), v[2] * (1 - 0.5 * red)]
            out.px[y][x] = tuple(int(clamp(q)) for q in v) + (255,)
    return out


def put_img(px, im, ox, oy, alpha=1.0, tint=None):
    for y in range(im.h):
        for x in range(im.w):
            c = im.px[y][x]
            if c is None:
                continue
            X, Y = ox + x, oy + y
            if 0 <= X < W and 0 <= Y < H:
                if tint:
                    c = tuple(clamp(c[i] * (1 - tint[3]) + tint[i] * tint[3]) for i in range(3))
                b = px[Y][X]
                px[Y][X] = tuple(b[i] * (1 - alpha) + c[i] * alpha for i in range(3))


def cast_shadow(px, im, ax, feet_x, feet_y, lean, flat=0.28, alpha=0.5):
    """Geworfener Schatten: Silhouette platt gedrückt (y * flat) und von der Lampe weggeneigt (lean Pixel je Pixel Höhe)."""
    for y in range(im.h):
        for x in range(im.w):
            c = im.px[y][x]
            if c is None:
                continue
            hgt = (rig.GY - y)
            if hgt < 0:
                continue
            X = feet_x + (x - ax) + int(round(hgt * lean))
            Y = feet_y + 1 + int(round(hgt * flat))
            if 0 <= X < W and 0 <= Y < H and (X + Y) % 2 == 0 or alpha > 0.4 and 0 <= X < W and 0 <= Y < H:
                b = px[Y][X]
                px[Y][X] = tuple(b[i] * (1 - alpha) for i in range(3))


def reflection(px, im, ax, feet_x, feet_y, alpha=0.22):
    for y in range(im.h):
        for x in range(im.w):
            c = im.px[y][x]
            if c is None or is_outline(c):
                continue
            hgt = rig.GY - y
            if hgt < 0 or hgt > 40:
                continue
            X = feet_x + (x - ax)
            Y = feet_y + 3 + int(hgt * 0.5)
            if 0 <= X < W and 0 <= Y < H and (Y % 2 == 0):
                b = px[Y][X]
                a = alpha * (1 - hgt / 40.0)
                px[Y][X] = tuple(b[i] * (1 - a) + c[i] * a for i in range(3))


def contact(px, fx, fy, w=13):
    for dy, ww, a in ((0, w, 0.5), (1, w - 4, 0.3), (-1, w - 2, 0.4)):
        for x in range(fx - ww, fx + ww + 1):
            Y = fy + dy + 1
            if 0 <= x < W and 0 <= Y < H:
                b = px[Y][x]
                px[Y][x] = tuple(v * (1 - a) for v in b)


def nearest_lamp(th, x):
    best = min(th["lamps"], key=lambda l: abs(l[0] - x))
    return best


def scene(name, light):
    th = THEMES[name]
    px = build_background(th)
    heroes = [("axt", 212), ("schild", 156), ("bogen", 100), ("skalde", 44)]
    if name == "raeuber":
        foes = [("brecher", 268), ("axt", 324), ("muskete", 380), ("brecher", 436)]
    else:
        foes = [("rost", 268), ("rost", 324), ("totenwart", 380), ("rost", 436)]
    actor_x, target_x = 212 + 12, 268
    if light:
        spot = (240, FEET - 34, 190, 110)
        px = grade(px, th, spot, 1.0)
        fog_band(px, 120, 152, th["fog"][0] * 0.8, th["fog"][1], 0)
        lamps_draw(px, th, 0.3)
        # Lichtpfütze unter dem Angreifer (additiv, gedithert) und kaltes Gegenstück am Ziel
        add_glow(px, actor_x, FEET - 2, 46, th["key"], 0.38, 5, 0.32)
        add_glow(px, target_x, FEET - 2, 34, th["rim"], 0.18, 5, 0.32)
    else:
        lamps_draw(px, th, 0.3)
    # Figuren zeichnen: erst Schatten/Spiegelung, dann die Figuren von hinten (Reihe 4) nach vorn, Angreifer zuletzt
    order = []
    for i, (n, x) in enumerate(foes):
        order.append((n, x, True, i))
    for i, (n, x) in enumerate(heroes):
        order.append((n, x, False, i))
    order.sort(key=lambda o: (-o[3]))
    drawn = []
    for (n, x, mir, i) in order:
        is_actor = (not mir and i == 0)
        is_target = (mir and i == 0)
        frame = "idle_%d" % ((i + (1 if mir else 0)) % 4)
        fx_ = x
        if is_actor:
            frame = "strike_0"
            fx_ = actor_x
        if is_target:
            frame = "hit_0"
        drawn.append((n, fx_, mir, frame, is_actor, is_target))
    # Schatten zuerst
    for (n, fx_, mir, frame, is_actor, is_target) in drawn:
        im, ax = figure_pixels(n, frame, mir)
        if light:
            lx = nearest_lamp(th, fx_)[0]
            lean = -0.55 if lx > fx_ else 0.55
            cast_shadow(px, im, ax, fx_, FEET, lean, flat=0.2, alpha=0.34 if is_actor else 0.26)
            if th["wet"]:
                reflection(px, im, ax, fx_, FEET)
        contact(px, fx_, FEET)
    # Nachbilder des Angreifers (windup_1 und Zwischenstand), warm getönt
    if light:
        for k, (frm, off, a) in enumerate((("windup_1", -22, 0.16), ("windup_1", -13, 0.24), ("strike_0", -5, 0.30))):
            im, ax = figure_pixels("axt", frm, False)
            put_img(px, shade_fig(im, th, True), actor_x + off - ax, FEET - rig.GY, a, (255, 190, 90, 0.55))
    for (n, fx_, mir, frame, is_actor, is_target) in drawn:
        im, ax = figure_pixels(n, frame, mir)
        lamp = nearest_lamp(th, fx_)
        sgn = 1 if lamp[0] > fx_ else -1
        if light:
            sh_im = shade_fig(im, th, is_actor or is_target, flash=0.55 if is_target else 0.0, lamp_xs=(sgn,))
            # Lampenlicht auf die Figur: Abstand zur Lampe
            dl = math.hypot(fx_ - lamp[0], (FEET - 30) - lamp[1])
            f = max(0.0, 1.0 - dl / 170.0) ** 2
            if f > 0.02:
                for y in range(sh_im.h):
                    for x in range(sh_im.w):
                        c = sh_im.px[y][x]
                        if c:
                            sh_im.px[y][x] = tuple(int(clamp(c[i] + th["lamp"][i] * f * 0.22 * (c[0] + c[1] + c[2]) / 300.0 * 3)) for i in range(3)) + (255,)
        else:
            sh_im = im
        ox = fx_ - ax
        put_img(px, sh_im, ox, FEET - rig.GY)
    if light:
        # Halo am Einschlag + Funken, additiv
        hx_, hy_ = 262, FEET - 40
        add_glow(px, hx_, hy_, 34, (255, 210, 140), 0.85, 6)
        for k in range(14):
            a = k * 0.9 + 0.3
            r = 8 + (k * 5) % 22
            sx_, sy_ = int(hx_ + math.cos(a) * r), int(hy_ - abs(math.sin(a)) * r * 0.8)
            if 0 <= sx_ < W and 0 <= sy_ < H:
                px[sy_][sx_] = (255, 226, 150)
                px[sy_][min(W - 1, sx_ + 1)] = (255, 170, 80)
    # Vordergrund-Silhouetten (nach der Abstufung, nicht abgestuft): Mastfuss links, Pfosten rechts, Tau oben
    fg = (9, 8, 10)
    for y in range(128, H):
        for x in range(0, 14):
            px[y][x] = fg
        for x in range(468, 480):
            px[y][x] = fg
    for x in range(0, W):
        y = int(3 + math.sin(x / 480.0 * math.pi) * 12)
        px[y][x] = fg
        px[y + 1][x] = fg
    # in Bild wandeln
    img = Img(W, H)
    for y in range(H):
        for x in range(W):
            c = px[y][x]
            img.px[y][x] = (int(clamp(c[0])), int(clamp(c[1])), int(clamp(c[2])), 255)
    return img


def stack(a, b, label_a, label_b, scale=3):
    out = Img(W * scale, (H * 2 + 20) * scale // 1)
    out.rect(0, 0, out.w - 1, out.h - 1, (6, 6, 10, 255))
    out.blit(a.scaled(scale), 0, 0)
    out.blit(b.scaled(scale), 0, (H + 10) * scale)
    return out


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(outdir, exist_ok=True)
    for nm in ("raeuber", "draugr"):
        a = scene(nm, False)
        b = scene(nm, True)
        a.scaled(3).save(os.path.join(outdir, "D2_mock_%s_ohne.png" % nm))
        b.scaled(3).save(os.path.join(outdir, "D2_mock_%s_mit.png" % nm))
        print("ok", nm)
