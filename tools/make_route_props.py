"""Erzeugt assets/route_props.png: Bilder der Ereignisse auf der Strecke (reines Python, nutzt tools/make_enemies.py).

Atlas: 4 Spalten x 3 Zeilen Zellen zu 128x96 wie die Kulissen der Begegnungen; Anker (Wasserlinie, Mitte) bei (64, 72).
Die Dinge treiben links neben dem eigenen Heck (rechts liegt die Seekarte), die hintere Wellenschicht deckt ihren Teil unter Wasser.
Reihenfolge = Encounters.Id ab ROUTE_FIRST:
    0 Treibgut  1 Schiffbrüchiger  2 Treibeis  3 Enterhaken  4 Flaschenpost
    5 Wal       6 Irrlichter       7 Strudel   8 Totenfloß   9 Fischschwarm
Aufruf: python -X utf8 -I tools/make_route_props.py [--preview ordner]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_enemies as E  # noqa: E402
from make_art import poly_pixels  # noqa: E402

Img, hx, sh = E.Img, E.hx, E.sh
OUT = E.OUT
WL = E.WL
CW, CH, COLS = E.CELL_W, E.CELL_H, E.COLS

WOOD, WOOD_L, WOOD_D = hx("#6b4b30"), hx("#8a6542"), hx("#3f2c1c")
SKIN, SKIN_D = hx("#c99a7a"), hx("#9a6f55")
CLOTH = hx("#5b5f6a")
WATER_L, WATER_D = hx("#7fa6bd"), hx("#2c4a5e")
FOAM = hx("#e9f1f4")


def poly(img, pts, col):
    for (x, y) in poly_pixels(pts):
        img.set(x, y, col)


def shade_poly(img, pts, light, mid, dark):
    """Fläche mit Licht von links oben: oberste Pixel hell, unterste und rechte dunkel."""
    pix = poly_pixels(pts)
    for (x, y) in pix:
        c = mid
        if (x, y - 1) not in pix or (x - 1, y) not in pix:
            c = light
        elif (x, y + 1) not in pix or (x + 1, y) not in pix:
            c = dark
        img.set(x, y, c)


def barrel(img, x, y, w, h, lying=True):
    img.rect(x, y, x + w, y + h, WOOD)
    img.rect(x, y, x + w, y, WOOD_L)
    img.rect(x, y + h, x + w, y + h, WOOD_D)
    if lying:
        for hx_ in (x + 2, x + w - 2):
            img.rect(hx_, y, hx_, y + h, hx("#2a2a2e"))
        img.rect(x + w, y + 1, x + w, y + h - 1, WOOD_D)
    else:
        for hy in (y + 2, y + h - 2):
            img.rect(x, hy, x + w, hy, hx("#2a2a2e"))


def ripples(img, x0, x1, y, col=WATER_L):
    for x in range(x0, x1, 3):
        if (x // 3) % 2 == 0:
            img.set(x, y, col)
            img.set(x + 1, y, col)


def make_treibgut():
    img = Img(CW, CH)
    barrel(img, 34, WL - 8, 15, 8)
    barrel(img, 70, WL - 11, 9, 13, lying=False)
    img.line(18, WL - 2, 44, WL - 6, WOOD_L, 2)
    img.line(52, WL - 1, 96, WL - 4, WOOD, 2)
    # zerrissenes Segeltuch, rot-weiß wie das eigene
    pts = [(84, WL - 2), (104, WL - 6), (110, WL - 1), (96, WL + 1)]
    poly(img, pts, hx("#d8d0bc"))
    for x in range(86, 110, 6):
        img.line(x, WL - 3, x + 2, WL, hx("#9c2f2a"), 2)
    img.outline(OUT)
    ripples(img, 20, 108, WL + 1)
    return img


def make_schiffbruechiger():
    img = Img(CW, CH)
    img.rect(30, WL - 2, 92, WL, WOOD)
    img.rect(30, WL - 2, 92, WL - 2, WOOD_L)
    img.rect(30, WL, 92, WL, WOOD_D)
    # Kopf und Schultern über der Planke, ein Arm winkt
    E.shaded_disc(img, 58, WL - 7, 4, (hx("#d7aa88"), SKIN, SKIN_D, hx("#6e4c3a")))
    img.rect(54, WL - 12, 62, WL - 10, hx("#3a2e24"))  # nasses Haar
    img.rect(52, WL - 3, 64, WL - 1, CLOTH)
    img.line(63, WL - 4, 72, WL - 15, CLOTH, 2)
    img.rect(71, WL - 18, 73, WL - 15, SKIN)
    img.line(53, WL - 3, 46, WL - 1, CLOTH, 2)  # die andere Hand an der Planke
    img.outline(OUT)
    ripples(img, 26, 98, WL + 1)
    return img


def make_treibeis():
    img = Img(CW, CH)
    top, mid, low = hx("#e6eef2"), hx("#b9cdd8"), hx("#7f9db0")
    for (x0, w, h) in ((14, 34, 12), (50, 26, 8), (80, 32, 16)):
        pts = [(x0, WL + 1), (x0 + 3, WL - h + 3), (x0 + w // 3, WL - h), (x0 + w - 6, WL - h + 2), (x0 + w, WL + 1)]
        shade_poly(img, pts, top, mid, low)
        # Teil unter Wasser, heller und gedithert
        for y in range(WL + 2, WL + 8):
            for x in range(x0 + 2, x0 + w - 2):
                if (x + y) % 2 == 0:
                    img.set(x, y, hx("#5f8aa3"))
    img.outline(OUT)
    return img


def make_enterhaken():
    img = Img(CW, CH)
    # Ruderboot, Bug nach links (dem eigenen Schiff entgegen)
    pts = [(34, WL - 6), (100, WL - 7), (96, WL + 1), (44, WL + 2)]
    shade_poly(img, pts, WOOD_L, WOOD, WOOD_D)
    img.rect(36, WL - 7, 100, WL - 7, hx("#a07a50"))
    # drei Räuber: dunkle Leiber, rote Kopftücher, einer hebt die Axt
    for k, bx in enumerate((50, 66, 82)):
        img.rect(bx - 3, WL - 15, bx + 3, WL - 7, hx("#2c2a30"))
        E.shaded_disc(img, bx, WL - 18, 3, (hx("#d7aa88"), SKIN, SKIN_D, hx("#6e4c3a")))
        img.rect(bx - 3, WL - 21, bx + 3, WL - 20, hx("#b03a32"))
        if k == 1:
            img.line(bx + 3, WL - 14, bx + 9, WL - 26, WOOD, 1)
            img.rect(bx + 8, WL - 29, bx + 11, WL - 25, hx("#9aa3ab"))
    # Ruder und Enterhaken-Taue nach links zum eigenen Schiff
    img.line(40, WL - 4, 28, WL + 3, WOOD_D, 1)
    img.outline(OUT)
    for (y0, y1) in ((WL - 16, WL - 34), (WL - 13, WL - 26)):
        img.line(48, y0, 0, y1, hx("#d9cfae"), 1)
    ripples(img, 30, 104, WL + 2)
    return img


def mirror(img):
    out = Img(img.w, img.h)
    for y in range(img.h):
        out.px[y] = list(reversed(img.px[y]))
    return out


def make_enterhaken_rechts():
    # das Boot liegt links neben dem eigenen Heck: Bug und Taue zeigen nach rechts, zum Schiff
    return mirror(make_enterhaken())


def make_flaschenpost():
    img = Img(CW, CH)
    glass, glass_l, glass_d = hx("#4f8a5a"), hx("#8cc296"), hx("#2f5a3a")
    pts = [(52, WL - 1), (70, WL - 7), (72, WL - 3), (54, WL + 2)]
    shade_poly(img, pts, glass_l, glass, glass_d)
    img.line(70, WL - 6, 76, WL - 8, glass, 2)
    img.rect(76, WL - 10, 78, WL - 8, hx("#8a6240"))  # Korken
    img.line(56, WL - 1, 66, WL - 4, hx("#e9dfc0"), 1)  # der Zettel darin
    img.outline(OUT)
    ripples(img, 44, 86, WL + 1, FOAM)
    return img


def make_wal():
    img = Img(CW, CH)
    back, back_l, back_d = hx("#3e4a58"), hx("#5f6f80"), hx("#252c36")
    pts = []
    for x in range(14, 112, 2):
        u = (x - 14) / 98.0
        pts.append((x, WL - round(16 * math.sin(u * math.pi) ** 0.8)))
    pts += [(112, WL + 2), (14, WL + 2)]
    shade_poly(img, pts, back_l, back, back_d)
    poly(img, [(70, WL - 14), (78, WL - 24), (82, WL - 13)], back)  # Finne
    for (sx, sy) in ((40, WL - 9), (46, WL - 11), (58, WL - 12), (92, WL - 8)):
        img.set(sx, sy, hx("#b8b2a0"))  # Seepocken
    img.outline(OUT)
    # Fontäne über dem Atemloch
    for k in range(9):
        x = 30 + round(5 * math.sin(k * 1.3))
        y = WL - 18 - k * 3
        img.set(x, y, FOAM)
        img.set(x - 2 + k % 3, y - 1, WATER_L)
    ripples(img, 8, 118, WL + 2, FOAM)
    return img


def make_irrlichter():
    img = Img(CW, CH)
    for (cx, cy) in ((34, WL - 26), (58, WL - 40), (78, WL - 22), (98, WL - 34)):
        E.glow(img, cx, cy, hx("#ffffff"), hx("#bfe8ff"), hx("#5d8fc2"), r=6)
        for k in range(1, 4):  # kleiner Schweif
            if (cx + k) % 2 == 0:
                img.set(cx + k * 2, cy + k, hx("#5d8fc2"))
        # Spiegelung im Wasser
        for k in range(3):
            if k % 2 == 0:
                img.set(cx - 1 + k, WL + 2, hx("#8fc4ee"))
    return img


def make_strudel():
    img = Img(CW, CH)
    dark, mid, foam = hx("#4f7c96"), hx("#8fb4c8"), FOAM
    cx, cy = 64, WL + 1
    for ring in range(6):
        rx = 48 - ring * 8
        ry = max(6 - ring, 1)
        col = dark if ring % 2 == 0 else mid
        for a in range(0, 360, 3):
            if (a // 30 + ring) % 3 == 0:
                continue  # Lücken: eine Spirale statt Ringe
            t = math.radians(a + ring * 25)
            x = cx + round(rx * math.cos(t))
            y = cy + round(ry * math.sin(t))
            img.set(x, y, col)
            if a % 24 == 0:
                img.set(x, y - 1, foam)
    img.rect(cx - 2, cy - 1, cx + 2, cy + 1, hx("#0b141c"))
    return img


def make_totenfloss():
    img = Img(CW, CH)
    for k in range(5):
        y = WL - 3 + (k % 2)
        img.rect(28 + k * 2, y - 1, 104 - k * 3, y + 1, WOOD_D if k % 2 else WOOD)
    pale, pale_d = hx("#a8b39a"), hx("#6f7c66")
    for k, bx in enumerate((44, 64, 86)):
        img.rect(bx - 3, WL - 13, bx + 3, WL - 5, hx("#3a3c34"))  # Lumpen
        E.shaded_disc(img, bx, WL - 17, 3, (hx("#c6cfb8"), pale, pale_d, hx("#4c5646")))
        img.set(bx - 1, WL - 18, hx("#0b0a0e"))
        img.set(bx + 1, WL - 18, hx("#0b0a0e"))
        if k == 1:
            img.set(bx - 1, WL - 18, hx("#bff7dc"))  # ein Auge glimmt
            img.set(bx + 1, WL - 18, hx("#bff7dc"))
        img.line(bx + 3, WL - 11, bx + 7, WL - 7, pale, 1)
    img.line(100, WL - 4, 102, WL - 30, WOOD, 1)  # Stange mit Fetzen
    poly(img, [(102, WL - 30), (112, WL - 27), (103, WL - 23)], hx("#4a3c3c"))
    img.outline(OUT)
    ripples(img, 24, 108, WL + 2)
    return img


def make_fischschwarm():
    img = Img(CW, CH)
    silver, silver_d = hx("#cfd8de"), hx("#7f8f9a")
    for (x, y, d) in ((36, WL - 10, 1), (62, WL - 16, -1), (88, WL - 8, 1)):
        img.rect(x - 3, y - 1, x + 3, y + 1, silver)
        img.rect(x - 3, y + 1, x + 3, y + 1, silver_d)
        img.set(x + 4 * d, y - 2, silver_d)
        img.set(x + 4 * d, y + 2, silver_d)
        img.set(x - 2 * d, y - 1, hx("#0b0a0e"))  # Auge
    for (gx, gy) in ((30, 24), (54, 16), (96, 22)):
        img.line(gx - 4, gy - 2, gx, gy, hx("#e6e0cc"), 1)
        img.line(gx, gy, gx + 4, gy - 2, hx("#e6e0cc"), 1)
    img.outline(OUT)
    for x in range(20, 110, 7):  # Spritzer
        img.set(x, WL - 1, FOAM)
        img.set(x + 1, WL - 2, FOAM)
        img.set(x + 2, WL - 1, FOAM)
    return img


MAKERS = [make_treibgut, make_schiffbruechiger, make_treibeis, make_enterhaken_rechts, make_flaschenpost,
          make_wal, make_irrlichter, make_strudel, make_totenfloss, make_fischschwarm]


def build():
    rows = 3
    atlas = Img(CW * COLS, CH * rows)
    for i, fn in enumerate(MAKERS):
        atlas.blit(fn(), (i % COLS) * CW, (i // COLS) * CH)
    return atlas


def main():
    atlas = build()
    out = os.path.join(HERE, "..", "assets", "route_props.png")
    atlas.save(out)
    print("route_props.png", atlas.w, "x", atlas.h)
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(d, exist_ok=True)
        atlas.filled_bg(hx("#22303c")).scaled(3).save(os.path.join(d, "route_props_preview.png"))


if __name__ == "__main__":
    main()
