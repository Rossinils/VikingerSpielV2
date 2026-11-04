"""Erzeugt die Gegenstands-Symbole und die Segen-Embleme (Pixelart, reines Python, wie make_skill_icons.py).

Aufruf:
    python -X utf8 -I tools/make_item_icons.py                      -> assets/item_icons.png, assets/perk_emblems.png, scripts/item_icons.gd
    python -X utf8 -I tools/make_item_icons.py --preview ordner     -> zusaetzlich vergroesserte Vorschaubilder

assets/item_icons.png: 4 Zeilen (Seltenheit gewoehnlich, selten, episch, legendaer) mal einem Streifen aus 20x20-Feldern
(Symbol auf dunkler Platte, Rand und Glanz in der Farbe der Seltenheit, Farben wie Items.RARITY_COLORS).
assets/perk_emblems.png: die Segen als 32x32-Embleme in einem Streifen (fuer den Stufenaufstieg).
scripts/item_icons.gd wird mit erzeugt (Reihenfolge der Symbole), nicht von Hand aendern.
Gezeichnet wird auf 16x16 (Form im Bereich 1..14, Umriss kommt automatisch), Licht von oben links.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_art import Img, hx, sh, mix  # noqa: E402
from make_skill_icons import poly, arc  # noqa: E402

TILE = 20
EMBLEM = 32
OUT = hx("#0b0a0e")
PLATE, PLATE_D = hx("#26232d"), hx("#1a1820")
RARITY_RIMS = [hx("#8a857a"), hx("#5b9be8"), hx("#b070e0"), hx("#f2a53a")]  # wie Items.RARITY_COLORS (gewoehnlich dunkler)
RARITY_NAMES = ["gewoehnlich", "selten", "episch", "legendaer"]

STEEL, STEEL_D, STEEL_L = hx("#9aa3ab"), hx("#5d6670"), hx("#dfe6ec")
IRON_D = hx("#3a4048")
WOOD, WOOD_D, WOOD_L = hx("#8a6240"), hx("#5e432c"), hx("#b58a58")
LEATHER, LEATHER_D, LEATHER_L = hx("#7a4e2e"), hx("#4e301c"), hx("#a8714a")
BONE, BONE_D = hx("#e4dcc4"), hx("#a39b84")
GOLD, GOLD_D, GOLD_L = hx("#e0b84a"), hx("#a8842a"), hx("#f8e08a")
BRONZE, BRONZE_D, BRONZE_L = hx("#b8743a"), hx("#7a4a24"), hx("#e2a064")
RED, RED_D, RED_L = hx("#c8453d"), hx("#7a2424"), hx("#ee7a66")
ORANGE, YELLOW = hx("#e8903a"), hx("#f6dc5a")
GREEN, GREEN_D, GREEN_L = hx("#5cae5a"), hx("#356a38"), hx("#a6e69a")
BLUE, BLUE_D, BLUE_L = hx("#5b8fd0"), hx("#2f5288"), hx("#a9cdf5")
PURPLE, PURPLE_D, PURPLE_L = hx("#8a62a6"), hx("#4a3262"), hx("#c4a0e0")
CLOTH, CLOTH_D = hx("#e7dcc0"), hx("#b8ab8a")
TAR, TAR_L = hx("#2b2630"), hx("#4a4152")
WHITE = hx("#f4f1e8")
SMOKE, SMOKE_L = hx("#6f6a70"), hx("#a7a2a8")
TEAL, TEAL_D, TEAL_L = hx("#3f8a86"), hx("#235553"), hx("#7fc9c0")
FUR, FUR_D, FUR_L = hx("#7a6048"), hx("#4a3a2a"), hx("#a8896a")
WOLF, WOLF_D, WOLF_L = hx("#8e939c"), hx("#565b64"), hx("#c8ccd2")
AMBER, AMBER_D, AMBER_L = hx("#d88a2a"), hx("#8a5418"), hx("#f6bc5a")


# --- kleine Helfer ------------------------------------------------------------------------------------------

def box(img, x0, y0, x1, y1, base, hi=True, lo=True):
    """Gefuelltes Rechteck mit Licht oben links (heller Rand oben und links, dunkler unten und rechts)."""
    img.rect(x0, y0, x1, y1, base)
    if hi:
        img.rect(x0, y0, x1, y0, sh(base, 1))
        img.rect(x0, y0, x0, y1, sh(base, 1))
    if lo:
        img.rect(x0, y1, x1, y1, sh(base, -1))
        img.rect(x1, y0, x1, y1, sh(base, -1))


def put(img, pts, c):
    for p in pts:
        img.set(p[0], p[1], c)


def ring(img, cx, cy, r, c, w=1):
    """Kreislinie (Radius r, Staerke w)."""
    for dy in range(-r - 1, r + 2):
        for dx in range(-r - 1, r + 2):
            d = math.hypot(dx, dy)
            if r - w + 0.5 < d <= r + 0.5:
                img.set(cx + dx, cy + dy, c)


def dither(img, x0, y0, x1, y1, a, b):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img.set(x, y, a if (x + y) % 2 == 0 else b)


def ell(img, cx, cy, rx, ry, c):
    """Gefuellte Ellipse."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / (rx + 0.3)) ** 2 + ((y - cy) / (ry + 0.3)) ** 2 <= 1.0:
                img.set(x, y, c)


def leaf(img, base, tip, w, main, hi=None, lo=None):
    """Klinge/Blatt von base nach tip, groesste Breite w (Halbbreite) bei 40 % der Laenge."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    n = math.hypot(dx, dy) or 1.0
    ux, uy = dx / n, dy / n
    px, py = -uy, ux
    mx, my = bx + dx * 0.4, by + dy * 0.4
    a = (int(round(mx + px * w)), int(round(my + py * w)))
    b = (int(round(mx - px * w)), int(round(my - py * w)))
    poly(img, [(bx, by), a, (tx, ty), b], main)
    if hi is not None:
        img.line(bx, by, a[0], a[1], hi)
        img.line(a[0], a[1], tx, ty, hi)
    if lo is not None:
        img.line(bx, by, b[0], b[1], lo)
        img.line(b[0], b[1], tx, ty, lo)


def tube(img, pts, radii, c, hi=None):
    """Gebogene Roehre: Scheiben entlang der Punkte mit wechselndem Radius (Horn, Schweif)."""
    for (x, y), r in zip(pts, radii):
        img.disc(x, y, r, c)
    if hi is not None:
        for (x, y), r in zip(pts, radii):
            img.set(x - r + 1 if r > 1 else x, y - r + 1 if r > 1 else y, hi)


# --- Schiffsgegenstaende (Schluessel wie in scripts/items.gd) ---------------------------------------------------

def i_sporn(img):  # Eiserner Rammsporn: Balken mit eisernem Dorn
    box(img, 1, 5, 6, 11, WOOD)
    img.line(2, 8, 5, 8, WOOD_D)
    box(img, 6, 4, 8, 12, STEEL)
    poly(img, [(9, 5), (14, 8), (9, 11)], STEEL)
    img.line(9, 5, 14, 8, STEEL_L)
    img.line(9, 11, 14, 8, STEEL_D)
    img.line(10, 8, 12, 8, STEEL_L)
    put(img, [(3, 6), (3, 10)], STEEL_L)


def i_drachenkopf(img):  # Drachenkopf am Bug: S-Hals, Rachen offen, Zacken im Nacken
    poly(img, [(2, 14), (2, 11), (3, 7), (5, 4), (8, 3), (11, 3), (14, 5), (14, 7), (10, 7), (8, 9), (7, 14)], WOOD)
    img.line(5, 4, 8, 3, WOOD_L)
    img.line(8, 3, 11, 3, WOOD_L)
    img.line(3, 7, 3, 12, WOOD_L)
    poly(img, [(8, 9), (14, 9), (13, 11), (9, 12)], WOOD_D)
    img.rect(9, 8, 13, 8, RED)
    put(img, [(10, 7), (12, 7), (11, 9), (13, 9)], WHITE)
    img.line(6, 3, 4, 0, BONE, 1)
    img.set(3, 0, BONE_D)
    put(img, [(9, 5)], YELLOW)
    put(img, [(10, 5)], TAR)
    put(img, [(1, 10), (2, 7), (4, 4)], RED)
    img.line(5, 8, 5, 12, WOOD_D)
    img.line(13, 5, 14, 6, WOOD_D)


def i_teer(img):  # Teerung: Topf mit kochendem Teer und Pinsel
    ell(img, 6.5, 10, 5, 4, IRON_D)
    ell(img, 6.5, 10, 4, 3, STEEL_D)
    img.line(3, 8, 3, 12, STEEL)
    img.line(4, 13, 9, 13, TAR)
    ell(img, 6.5, 7, 4.5, 2, STEEL)
    ell(img, 6.5, 7, 3.5, 1.3, TAR)
    put(img, [(5, 6), (6, 6)], TAR_L)
    put(img, [(9, 7)], TAR_L)
    put(img, [(2, 12), (11, 12)], IRON_D)
    img.line(8, 6, 13, 1, WOOD_L, 1)
    img.line(9, 6, 14, 2, WOOD, 1)
    poly(img, [(12, 1), (14, 0), (15, 3), (13, 3)], TAR)
    put(img, [(5, 4), (6, 3)], SMOKE_L)
    put(img, [(9, 4)], SMOKE)


def i_beschlag(img):  # Eisenbeschlaege: genietete Platten
    box(img, 1, 3, 7, 9, STEEL)
    box(img, 8, 6, 14, 12, STEEL)
    box(img, 2, 10, 7, 14, STEEL_D)
    put(img, [(2, 4), (6, 4), (2, 8), (6, 8), (9, 7), (13, 7), (9, 11), (13, 11), (3, 11), (6, 13)], STEEL_L)
    img.line(4, 3, 4, 9, STEEL_D)
    img.line(11, 6, 11, 12, STEEL_D)


def i_planken(img):  # Doppelte Planken: zwei dicke Bohlen gekreuzt, genagelt
    poly(img, [(1, 3), (4, 1), (14, 11), (14, 14), (11, 14)], WOOD)
    img.line(4, 1, 14, 11, WOOD_L)
    img.line(1, 3, 11, 14, WOOD_D)
    poly(img, [(1, 12), (11, 1), (14, 3), (4, 14)], WOOD_L)
    img.line(11, 1, 14, 3, WOOD_D)
    img.line(1, 12, 4, 14, WOOD_D)
    img.line(4, 14, 14, 3, WOOD_D)
    img.line(3, 11, 11, 3, WOOD)
    put(img, [(8, 7), (2, 3), (13, 12), (12, 3), (3, 13)], STEEL_L)
    img.line(6, 10, 9, 7, WOOD_D)


def i_tuch(img):  # Gutes Segeltuch: gerolltes helles Tuch
    box(img, 2, 3, 13, 6, CLOTH)
    img.line(3, 4, 12, 4, CLOTH_D)
    poly(img, [(2, 7), (13, 7), (13, 13), (11, 14), (8, 13), (5, 14), (2, 13)], CLOTH)
    img.line(2, 7, 13, 7, CLOTH_D)
    img.line(5, 8, 5, 13, CLOTH_D)
    img.line(9, 8, 9, 13, CLOTH_D)
    img.line(3, 9, 4, 9, WHITE)
    img.rect(1, 2, 14, 2, WOOD_L)
    put(img, [(1, 2), (14, 2)], WOOD_D)


def i_prunk(img):  # Prunksegel: rot-weisse Streifen, Goldsaum
    img.rect(2, 3, 13, 12, RED)
    for x in range(2, 14):
        if (x // 2) % 2 == 1:
            img.rect(x, 3, x, 12, CLOTH)
    img.line(2, 3, 13, 3, GOLD)
    img.line(2, 12, 13, 12, GOLD)
    img.line(2, 3, 2, 12, GOLD_D)
    img.line(13, 3, 13, 12, GOLD_D)
    img.rect(1, 1, 14, 2, WOOD_L)
    img.set(7, 7, GOLD_L)
    img.set(8, 7, GOLD)
    img.set(7, 8, GOLD)
    img.set(8, 8, GOLD_D)


def i_sturm(img):  # Sturmsegel: klein, dunkel, geflickt, mit Blitz
    poly(img, [(3, 2), (12, 2), (12, 11), (7, 13), (3, 11)], BLUE_D)
    img.line(3, 2, 12, 2, BLUE)
    img.line(3, 2, 3, 11, BLUE)
    img.line(3, 6, 12, 6, IRON_D)
    img.line(3, 9, 12, 9, IRON_D)
    poly(img, [(8, 3), (6, 7), (8, 7), (6, 11), (10, 6), (8, 6), (9, 3)], YELLOW)
    img.set(7, 11, BLUE_D)


def i_riemen(img):  # Lange Riemen: ein Riemen schraeg, breites flaches Blatt
    img.line(2, 2, 8, 8, WOOD, 2)
    img.line(2, 1, 8, 7, WOOD_L, 1)
    poly(img, [(8, 9), (9, 8), (14, 10), (14, 14), (10, 14)], WOOD_L)
    img.line(9, 8, 14, 10, hx("#d8b07a"))
    img.line(14, 10, 14, 14, WOOD_D)
    img.line(10, 14, 14, 14, WOOD_D)
    img.line(10, 11, 13, 13, WOOD)
    put(img, [(1, 1), (2, 1)], WOOD_D)
    img.rect(5, 5, 6, 6, STEEL_D)


def i_esche(img):  # Eschenriemen: zwei gekreuzte Riemen, ein Eschenblatt dazwischen
    for flip in (0, 1):
        def X(x):
            return 15 - x if flip else x
        img.line(X(1), 1, X(9), 9, WOOD_L if flip else WOOD, 1)
        poly(img, [(X(8), 9), (X(9), 8), (X(14), 10), (X(14), 14), (X(10), 14)], hx("#d8b07a") if flip else WOOD_L)
        img.line(X(14), 10, X(14), 14, WOOD_D)
    leaf(img, (7, 8), (10, 2), 2, GREEN, GREEN_L, GREEN_D)


def i_kanone(img):  # Bronzekanone: waagerechtes Rohr mit Ringen auf Holzlafette
    poly(img, [(2, 5), (12, 4), (12, 9), (2, 9)], BRONZE)
    img.line(2, 5, 12, 4, BRONZE_L)
    img.line(2, 6, 11, 5, hx("#cf8a4e"))
    img.line(2, 9, 12, 9, BRONZE_D)
    img.line(2, 8, 12, 8, hx("#9a5e2e"))
    img.rect(4, 5, 4, 9, BRONZE_D)
    img.rect(5, 5, 5, 7, BRONZE_L)
    img.rect(8, 4, 8, 9, BRONZE_D)
    img.rect(9, 4, 9, 7, BRONZE_L)
    box(img, 12, 3, 14, 10, BRONZE)
    img.rect(14, 5, 14, 8, TAR)
    img.disc(1, 7, 1, BRONZE_D)
    img.set(1, 6, BRONZE_L)
    box(img, 3, 10, 10, 11, WOOD)
    img.disc(6, 12, 2, WOOD_D)
    img.disc(6, 12, 1, WOOD_L)
    img.set(6, 12, IRON_D)
    img.rect(11, 11, 12, 12, WOOD_D)


def i_schwere(img):  # Schwere Kanone: dickes dunkles Eisenrohr, Goldringe, Muendungsfeuer
    poly(img, [(1, 4), (11, 3), (11, 10), (1, 10)], IRON_D)
    img.line(1, 4, 11, 3, STEEL)
    img.line(1, 5, 11, 4, STEEL_D)
    img.line(1, 10, 11, 10, TAR)
    img.rect(3, 4, 3, 10, GOLD_D)
    img.rect(4, 4, 4, 6, GOLD)
    img.rect(8, 3, 8, 10, GOLD_D)
    img.rect(9, 3, 9, 6, GOLD)
    box(img, 11, 2, 12, 11, STEEL_D)
    img.rect(12, 5, 12, 8, TAR)
    poly(img, [(13, 4), (15, 3), (14, 6), (15, 9), (13, 8)], ORANGE)
    put(img, [(13, 6), (14, 6), (14, 5)], YELLOW)
    box(img, 2, 11, 9, 12, WOOD)
    img.disc(5, 13, 1, WOOD_D)
    img.disc(10, 13, 1, WOOD_D)
    img.set(2, 4, STEEL_L)


def i_fass(img):  # Proviantfass: Fass mit Eisenreifen
    poly(img, [(4, 2), (11, 2), (13, 5), (13, 11), (11, 14), (4, 14), (2, 11), (2, 5)], WOOD)
    img.line(4, 2, 11, 2, WOOD_L)
    img.line(2, 5, 2, 11, WOOD_L)
    img.line(13, 5, 13, 11, WOOD_D)
    img.rect(2, 5, 13, 5, STEEL_D)
    img.rect(2, 10, 13, 10, STEEL_D)
    img.line(5, 6, 5, 9, WOOD_D)
    img.line(8, 6, 8, 9, WOOD_D)
    img.line(11, 6, 11, 9, WOOD_D)
    img.line(5, 11, 5, 13, WOOD_D)
    img.line(10, 11, 10, 13, WOOD_D)
    img.set(7, 3, WOOD_D)


def i_pulver(img):  # Pulverkammer: schwarzes Fass, Lunte brennt
    poly(img, [(4, 5), (11, 5), (12, 7), (12, 12), (11, 14), (4, 14), (3, 12), (3, 7)], TAR)
    img.line(4, 5, 11, 5, TAR_L)
    img.line(3, 7, 3, 12, TAR_L)
    img.rect(3, 8, 12, 8, RED_D)
    img.rect(3, 11, 12, 11, RED_D)
    img.line(7, 5, 8, 3, BONE_D)
    img.line(8, 3, 10, 2, BONE_D)
    put(img, [(11, 1), (12, 2), (10, 1), (11, 2)], YELLOW)
    img.set(11, 1, WHITE)
    put(img, [(12, 1), (10, 3)], ORANGE)
    # Totenkopf
    put(img, [(6, 9), (9, 9), (7, 10), (8, 10)], BONE)
    img.set(6, 12, BONE_D)


def i_haengematte(img):  # Haengematten: Stoff zwischen zwei Haken, ein Schlafender
    box(img, 1, 3, 2, 14, WOOD)
    box(img, 13, 3, 14, 14, WOOD)
    arc(img, 7, 3, 7, 25, 155, CLOTH_D, 1)
    poly(img, [(3, 6), (12, 6), (11, 9), (8, 11), (4, 9)], RED)
    img.line(3, 6, 12, 6, RED_L)
    img.line(4, 9, 8, 11, RED_D)
    img.line(8, 11, 11, 9, RED_D)
    img.disc(5, 5, 1, hx("#e8b890"))
    put(img, [(10, 2), (11, 2), (11, 1), (10, 0)], BLUE_L)
    img.line(3, 6, 2, 5, STEEL_D)
    img.line(12, 6, 13, 5, STEEL_D)


def i_werkzeug(img):  # Werkzeugkiste: Truhe mit Hammer und Saege
    box(img, 2, 7, 13, 13, WOOD)
    img.rect(2, 9, 13, 9, WOOD_D)
    img.rect(6, 7, 6, 13, STEEL_D)
    img.rect(9, 7, 9, 13, STEEL_D)
    img.rect(7, 10, 8, 11, GOLD)
    img.line(6, 5, 9, 5, STEEL_D)
    img.line(6, 5, 6, 7, STEEL_D)
    img.line(9, 5, 9, 7, STEEL_D)
    img.line(3, 6, 9, 1, WOOD_L)
    box(img, 8, 1, 12, 3, STEEL)
    put(img, [(10, 2)], STEEL_L)
    img.line(12, 5, 13, 6, STEEL_L)


def i_truhe(img):  # Beutetruhe: offene Truhe, Gold glaenzt
    poly(img, [(2, 3), (13, 3), (14, 6), (1, 6)], WOOD_L)
    img.line(2, 3, 13, 3, WOOD)
    img.line(1, 6, 14, 6, WOOD_D)
    box(img, 1, 7, 14, 13, WOOD)
    img.rect(1, 9, 14, 9, GOLD_D)
    img.rect(6, 7, 9, 10, GOLD)
    img.rect(7, 8, 8, 9, GOLD_D)
    img.rect(2, 5, 13, 5, TAR)
    put(img, [(3, 4), (5, 4), (7, 4), (9, 4), (11, 4), (12, 4)], GOLD)
    put(img, [(4, 3), (8, 3), (11, 3)], GOLD_L)
    put(img, [(1, 1), (14, 2)], YELLOW)


# --- Ausruestung (Schluessel wie in scripts/gear.gd) ----------------------------------------------------------

def i_schwert(img):  # Eisenschwert
    leaf(img, (5, 10), (14, 1), 1, STEEL_L, WHITE, STEEL_D)
    img.line(6, 9, 12, 3, STEEL, 1)
    img.line(3, 8, 8, 13, GOLD, 2)
    img.line(3, 8, 4, 8, GOLD_L)
    img.line(4, 11, 2, 13, LEATHER, 2)
    img.disc(1, 14, 1, GOLD)


def i_axt(img):  # Bartaxt: langer Stiel, breites Blatt mit Bart
    img.line(2, 14, 10, 6, WOOD, 2)
    img.line(2, 13, 9, 6, WOOD_L, 1)
    poly(img, [(8, 3), (12, 1), (14, 2), (14, 8), (12, 11), (11, 8), (9, 7)], STEEL)
    img.line(12, 1, 14, 2, STEEL_L)
    img.line(14, 2, 14, 8, STEEL_L)
    img.line(8, 3, 12, 1, STEEL_L)
    img.line(12, 11, 14, 8, STEEL_D)
    img.line(9, 7, 11, 8, STEEL_D)
    put(img, [(11, 4), (12, 5)], WHITE)


def i_speer(img):  # Langspeer: langer Schaft, Blattspitze
    img.line(1, 14, 10, 5, WOOD, 2)
    img.line(1, 13, 9, 5, WOOD_L, 1)
    leaf(img, (9, 6), (14, 1), 2, STEEL, STEEL_L, STEEL_D)
    img.line(8, 7, 11, 4, LEATHER, 2)
    put(img, [(12, 3)], WHITE)


def i_dolch(img):  # Kurzer Dolch: kurze Klinge, Parierstange, Griff
    leaf(img, (6, 9), (13, 2), 2, STEEL_L, WHITE, STEEL_D)
    img.line(7, 8, 11, 4, STEEL, 1)
    img.line(4, 8, 8, 12, GOLD_D, 2)
    img.line(4, 8, 5, 8, GOLD)
    img.line(5, 11, 3, 13, LEATHER, 2)
    img.set(2, 14, GOLD)


def i_hammer(img):  # Kriegshammer: schwerer Kopf mit Dorn
    img.line(2, 14, 9, 7, WOOD, 2)
    img.line(2, 13, 8, 7, WOOD_L, 1)
    box(img, 7, 1, 13, 6, STEEL)
    img.rect(8, 2, 12, 2, STEEL_L)
    img.line(7, 3, 7, 5, STEEL_D)
    poly(img, [(13, 2), (15, 3), (13, 5)], STEEL_D)
    put(img, [(9, 4), (11, 4)], STEEL_D)
    img.rect(7, 6, 13, 6, IRON_D)
    img.rect(8, 7, 9, 8, LEATHER)


def i_runenstab(img):  # Runenstab: Holz mit leuchtendem Stein
    img.line(2, 14, 9, 7, WOOD, 2)
    img.line(2, 13, 8, 7, WOOD_L, 1)
    img.line(9, 7, 10, 6, GOLD, 2)
    img.disc(11, 4, 3, BLUE_D)
    img.disc(11, 4, 2, BLUE)
    img.set(10, 3, BLUE_L)
    put(img, [(11, 3), (11, 4), (11, 5), (10, 4), (12, 4)], WHITE)
    put(img, [(14, 1), (14, 7), (7, 1)], BLUE_L)


def i_leder(img):  # Lederwams: Weste mit Schnuerung und Guertel
    poly(img, [(2, 4), (5, 2), (7, 3), (9, 3), (11, 2), (14, 4), (14, 8), (12, 8), (12, 14), (3, 14), (3, 8), (1, 8)], LEATHER)
    img.line(5, 2, 7, 3, LEATHER_L)
    img.line(11, 2, 9, 3, LEATHER_L)
    img.line(2, 4, 5, 2, LEATHER_L)
    img.line(14, 4, 11, 2, LEATHER_L)
    img.line(3, 8, 3, 14, LEATHER_L)
    img.rect(3, 10, 12, 10, LEATHER_D)
    img.rect(7, 10, 8, 11, GOLD)
    put(img, [(7, 4), (8, 5), (7, 6), (8, 7), (7, 8)], LEATHER_D)
    put(img, [(8, 4), (7, 5), (8, 6), (7, 7)], CLOTH)
    img.line(12, 8, 12, 14, LEATHER_D)
    img.line(4, 14, 11, 14, LEATHER_D)


def i_kette(img):  # Kettenhemd: Ringgeflecht, kurze Aermel
    poly(img, [(1, 5), (4, 2), (7, 3), (9, 3), (12, 2), (15, 5), (15, 8), (12, 8), (12, 14), (3, 14), (3, 8), (0, 8)], STEEL)
    for y in range(3, 14):
        for x in range(1, 15):
            c = img.get(x, y)
            if c == STEEL and (x + y) % 2 == 0:
                img.set(x, y, STEEL_D if (x // 2 + y) % 3 else STEEL_L)
    img.line(4, 2, 7, 3, STEEL_L)
    img.line(12, 2, 9, 3, STEEL_L)
    img.rect(3, 14, 12, 14, STEEL_D)
    put(img, [(5, 14), (7, 14), (9, 14), (11, 14)], STEEL_L)
    img.rect(7, 2, 8, 3, STEEL_D)


def i_fell(img):  # Baerenfell: Pelz mit Baerenkopf (Ohren, Schnauze), Pranken unten
    poly(img, [(3, 6), (4, 5), (12, 5), (13, 6), (14, 10), (13, 14), (11, 13), (10, 14), (6, 14), (5, 13), (3, 14), (2, 10)], FUR)
    ell(img, 8, 4, 3.5, 3, FUR)
    ell(img, 4.5, 2, 1.5, 1.5, FUR_D)
    ell(img, 11.5, 2, 1.5, 1.5, FUR_D)
    put(img, [(4, 2), (11, 2)], hx("#c9a081"))
    for y in range(5, 14):
        for x in range(2, 14):
            if img.get(x, y) == FUR and (x * 3 + y * 5) % 7 == 0:
                img.set(x, y, FUR_D)
            elif img.get(x, y) == FUR and (x * 5 + y * 3) % 11 == 0:
                img.set(x, y, FUR_L)
    ell(img, 8, 5, 2, 1.4, FUR_L)
    put(img, [(7, 4), (9, 4)], TAR)
    put(img, [(8, 5), (8, 6)], TAR)
    put(img, [(5, 14), (10, 14), (3, 13), (12, 13)], BONE)
    img.line(4, 8, 6, 12, FUR_D)


def i_schuppen(img):  # Schuppenpanzer: Reihen aus Schuppen
    poly(img, [(2, 4), (5, 2), (7, 3), (9, 3), (11, 2), (14, 4), (14, 8), (12, 8), (12, 14), (3, 14), (3, 8), (1, 8)], TEAL_D)
    for row, y in enumerate(range(3, 14, 2)):
        off = 0 if row % 2 == 0 else 1
        for x in range(2 + off, 14, 2):
            if img.get(x, y) is not None:
                img.set(x, y, TEAL)
                if img.get(x, y + 1) is not None:
                    img.set(x, y + 1, TEAL_D)
                if img.get(x - 1, y) is not None:
                    img.set(x - 1, y, TEAL_L)
    img.rect(7, 2, 8, 4, TEAL_D)
    img.line(3, 14, 12, 14, TEAL_D)


def i_mantel(img):  # Wolfsmantel: grauer Pelzumhang mit Spange
    poly(img, [(4, 2), (11, 2), (14, 6), (15, 14), (1, 14), (2, 6)], WOLF_D)
    poly(img, [(5, 3), (10, 3), (12, 6), (12, 14), (3, 14), (3, 6)], WOLF)
    img.line(5, 3, 10, 3, WOLF_L)
    img.line(3, 6, 3, 14, WOLF_L)
    for x in range(4, 12, 2):
        img.set(x, 14, WOLF_D)
    img.line(7, 5, 7, 13, WOLF_D)
    img.line(9, 7, 10, 13, WOLF_D)
    for x in range(4, 12):
        img.set(x, 3, WOLF_L if x % 2 else WHITE)
    put(img, [(7, 3), (8, 3)], GOLD)
    img.set(8, 4, GOLD_D)
    put(img, [(5, 9), (5, 11), (10, 9)], WOLF_L)


def i_helm(img):  # Hoernerhelm: Stahlkappe, Nasenschutz, zwei Hoerner
    poly(img, [(3, 12), (3, 7), (5, 4), (8, 3), (11, 4), (13, 7), (13, 12)], STEEL)
    img.line(5, 4, 8, 3, STEEL_L)
    img.line(8, 3, 11, 4, STEEL_L)
    img.line(3, 7, 3, 12, STEEL_L)
    img.line(13, 7, 13, 12, STEEL_D)
    img.rect(3, 8, 13, 9, STEEL_D)
    put(img, [(4, 8), (8, 8), (12, 8)], GOLD)
    img.rect(8, 9, 8, 13, STEEL_D)
    img.rect(7, 10, 7, 13, STEEL_L)
    img.line(3, 7, 1, 4, BONE, 1)
    img.line(1, 4, 1, 2, BONE, 1)
    img.line(13, 7, 15, 4, BONE, 1)
    img.line(15, 4, 15, 2, BONE, 1)
    put(img, [(1, 1), (15, 1)], BONE_D)
    put(img, [(5, 10), (10, 10)], TAR)


def _cord(img):
    img.line(3, 1, 8, 5, LEATHER_L, 1)
    img.line(13, 1, 8, 5, LEATHER, 1)


def i_rune(img):  # Schutzrune: Stein an der Schnur, blaue Rune
    _cord(img)
    poly(img, [(5, 6), (10, 5), (12, 8), (11, 13), (6, 14), (4, 10)], SMOKE)
    img.line(5, 6, 10, 5, SMOKE_L)
    img.line(4, 10, 5, 6, SMOKE_L)
    img.line(6, 14, 11, 13, hx("#4a464c"))
    img.line(8, 7, 8, 12, BLUE_L)
    img.line(6, 6, 8, 8, BLUE_L)
    img.line(10, 6, 8, 8, BLUE_L)
    put(img, [(8, 9)], WHITE)
    put(img, [(7, 10), (9, 10)], BLUE)


def i_zahn(img):  # Wolfszahn: Fang an der Schnur, Goldfassung
    _cord(img)
    poly(img, [(5, 6), (11, 6), (10, 10), (8, 14), (7, 10)], BONE)
    img.line(5, 6, 7, 10, WHITE)
    img.line(7, 10, 8, 14, BONE_D)
    img.line(11, 6, 10, 10, BONE_D)
    img.line(10, 10, 8, 14, BONE_D)
    img.rect(5, 5, 11, 6, GOLD_D)
    img.rect(5, 5, 11, 5, GOLD)
    put(img, [(8, 5)], GOLD_L)


def i_hammeranhaenger(img):  # Hammeranhaenger: kleiner Mjoelnir an der Schnur
    _cord(img)
    box(img, 4, 6, 12, 10, STEEL)
    img.rect(5, 7, 11, 7, STEEL_L)
    put(img, [(6, 8), (8, 8), (10, 8)], STEEL_D)
    box(img, 7, 10, 9, 14, WOOD)
    img.rect(7, 11, 9, 11, GOLD)
    img.rect(7, 13, 9, 13, GOLD_D)


def i_muenze(img):  # Gluecksmuenze: Goldmuenze mit Kleeblatt, Schnur durch das Loch
    img.line(3, 1, 8, 4, LEATHER_L, 1)
    img.line(13, 1, 8, 4, LEATHER, 1)
    img.disc(8, 9, 5, GOLD_D)
    img.disc(8, 9, 4, GOLD)
    ring(img, 8, 9, 3, GOLD_L, 1)
    put(img, [(7, 8), (9, 8), (7, 10), (9, 10), (8, 9)], GOLD_D)
    put(img, [(8, 7), (8, 11), (6, 9), (10, 9)], GOLD_D)
    img.set(6, 6, WHITE)
    put(img, [(7, 5)], TAR)


def i_horn(img):  # Trinkhorn: Mondsichel, links die Oeffnung mit Goldrand und Schaum, rechts die Spitze
    cx, cy, rout = 8.0, 5.0, 6.8
    outer, inner = [], []
    for k in range(18):
        t = k / 17.0
        a = math.radians(176 - 168 * t)
        rin = 3.0 + 3.1 * (t ** 0.8)
        outer.append((int(round(cx + rout * math.cos(a))), int(round(cy + rout * math.sin(a)))))
        inner.append((int(round(cx + rin * math.cos(a))), int(round(cy + rin * math.sin(a)))))
    poly(img, outer + inner[::-1], BONE)
    for (x, y) in outer[3:12]:
        img.set(x, y, BONE_D)
    for (x, y) in inner[2:9]:
        img.set(x, y, WHITE)
    img.set(outer[-1][0], outer[-1][1], BONE_D)
    img.set(outer[-2][0], outer[-2][1], BONE_D)
    # Oeffnung links: Goldrand, Schaumkrone
    img.line(outer[0][0], outer[0][1], inner[0][0], inner[0][1], GOLD, 2)
    img.line(outer[1][0], outer[1][1], inner[1][0], inner[1][1], GOLD_D, 1)
    put(img, [(1, 4), (2, 3), (3, 4), (4, 3), (2, 5)], WHITE)
    put(img, [(3, 2)], WHITE)
    img.set(1, 5, GOLD_L)


def i_auge(img):  # Odinsauge: Auge im Goldring, Schnur oben
    img.line(5, 1, 8, 3, LEATHER_L, 1)
    img.line(11, 1, 8, 3, LEATHER, 1)
    ring(img, 8, 9, 6, GOLD_D, 2)
    ring(img, 8, 9, 6, GOLD, 1)
    poly(img, [(3, 9), (6, 6), (10, 6), (13, 9), (10, 12), (6, 12)], WHITE)
    img.disc(8, 9, 2, BLUE)
    img.set(8, 9, TAR)
    img.set(7, 8, BLUE_L)
    img.line(4, 9, 6, 7, CLOTH_D)
    img.line(10, 11, 12, 9, CLOTH_D)
    put(img, [(8, 5), (8, 13), (2, 9), (14, 9)], GOLD_L)


def i_pfand(img):  # Pfandflasche: Bernsteinflasche mit Goldmuenze als Etikett
    box(img, 7, 2, 9, 3, GOLD)
    img.rect(7, 4, 9, 6, AMBER)
    poly(img, [(7, 6), (9, 6), (12, 8), (12, 14), (4, 14), (4, 8)], AMBER)
    img.line(4, 8, 4, 14, AMBER_L)
    img.line(7, 4, 7, 6, AMBER_L)
    img.line(12, 8, 12, 14, AMBER_D)
    img.line(5, 14, 11, 14, AMBER_D)
    img.disc(8, 11, 2, GOLD)
    img.set(7, 10, GOLD_L)
    img.set(8, 11, GOLD_D)
    put(img, [(5, 9)], YELLOW)
    put(img, [(14, 3), (2, 6)], YELLOW)
    img.set(1, 12, WHITE)


# --- Segen-Embleme (32x32, Schluessel wie in scripts/perks.gd); gezeichnet im Kreis um (16, 16), Radius ~11 -----------

def e_odin(img):  # Odins Gunst: Rabe auf dem Ast
    RAVEN, RAVEN_D, RAVEN_L = hx("#25233a"), hx("#15131f"), hx("#4a4a72")
    poly(img, [(9, 15), (2, 21), (5, 23), (11, 21)], RAVEN_D)
    poly(img, [(3, 21), (6, 25), (9, 22)], RAVEN)
    ell(img, 15, 17, 7.5, 5.5, RAVEN)
    ell(img, 14, 16, 5, 3, RAVEN_L)
    img.line(9, 16, 19, 14, hx("#6a6a96"), 1)
    ell(img, 21, 11, 4, 3.6, RAVEN)
    poly(img, [(24, 10), (30, 12), (24, 14)], ORANGE)
    img.line(24, 12, 29, 12, hx("#a8641c"), 1)
    img.set(22, 10, YELLOW)
    img.set(23, 10, WHITE)
    img.line(14, 22, 14, 26, ORANGE, 1)
    img.line(18, 22, 18, 26, ORANGE, 1)
    img.line(7, 26, 25, 26, WOOD, 2)
    img.line(7, 25, 25, 25, WOOD_L, 1)
    put(img, [(27, 5), (6, 6), (28, 18)], YELLOW)


def e_vorrat(img):  # Gut gelagert: Fass, darauf ein dicker Fisch
    poly(img, [(8, 13), (24, 13), (26, 17), (26, 25), (24, 28), (8, 28), (6, 25), (6, 17)], WOOD)
    img.line(8, 13, 24, 13, WOOD_L)
    img.line(6, 17, 6, 25, WOOD_L)
    img.line(26, 17, 26, 25, WOOD_D)
    for yy in (17, 24):
        img.rect(6, yy, 26, yy + 1, STEEL_D)
        img.rect(6, yy, 26, yy, STEEL)
    for xx in (10, 14, 18, 22):
        img.line(xx, 19, xx, 22, WOOD_D)
    FISH, FISH_D, FISH_L = hx("#6f93b0"), hx("#445f78"), hx("#c4dcea")
    ell(img, 15, 8, 9, 4, FISH)
    ell(img, 14, 7, 7, 2, FISH_L)
    poly(img, [(23, 8), (29, 3), (28, 8), (29, 13)], FISH_D)
    poly(img, [(12, 4), (16, 2), (18, 4)], FISH_D)
    img.line(8, 10, 21, 11, FISH_D, 1)
    img.set(8, 7, WHITE)
    img.set(8, 8, TAR)
    img.line(11, 6, 11, 10, FISH_D, 1)
    img.line(14, 5, 14, 11, FISH_D, 1)


def e_wind(img):  # Frischer Wind: drei Boen mit Kringeln
    for (y, x1, col, curl) in ((10, 20, WHITE, 3), (16, 24, BLUE_L, 3), (22, 18, WHITE, 3)):
        img.line(5, y, x1, y, col, 2)
        arc(img, x1, y - curl, curl, 90, -150, col, 2)
    put(img, [(6, 13), (9, 13), (7, 19), (11, 19), (8, 25), (13, 25)], BLUE)
    img.line(24, 22, 28, 22, BLUE_L, 1)
    arc(img, 28, 19, 3, 90, -130, BLUE_L, 1)


def e_arme(img):  # Starke Arme: angewinkelter Arm mit Goldreif, Faust oben
    SK, SK_D, SK_L = hx("#d99a68"), hx("#a8683c"), hx("#f0c294")
    poly(img, [(3, 26), (3, 19), (8, 15), (15, 15), (19, 18), (19, 26)], SK)
    ell(img, 12, 14, 6.5, 4, SK)
    poly(img, [(16, 26), (21, 26), (27, 12), (23, 10)], SK)
    ell(img, 25, 9, 4.2, 4.2, SK)
    img.line(22, 7, 28, 10, SK_D, 1)
    img.line(23, 9, 28, 12, SK_D, 1)
    img.line(9, 11, 15, 12, SK_L, 1)
    img.line(4, 25, 18, 25, SK_D, 1)
    img.line(3, 20, 3, 25, SK_L, 1)
    img.line(9, 16, 9, 21, GOLD, 2)
    img.line(9, 16, 9, 21, GOLD, 2)
    img.line(10, 16, 10, 20, GOLD_L, 1)
    put(img, [(25, 6), (26, 6)], SK_L)


def e_haende(img):  # Geuebte Haende: Hammer schlaegt einen Nagel in die Planke
    box(img, 4, 22, 28, 27, WOOD)
    img.line(5, 24, 27, 24, WOOD_D)
    img.line(9, 26, 20, 26, WOOD_D)
    img.rect(15, 14, 16, 23, STEEL, )
    img.rect(15, 14, 15, 23, STEEL_L)
    box(img, 12, 12, 19, 14, STEEL_D)
    box(img, 9, 4, 22, 10, STEEL)
    img.rect(10, 5, 21, 5, STEEL_L)
    poly(img, [(9, 5), (4, 8), (9, 9)], STEEL_D)
    img.rect(9, 10, 22, 10, IRON_D)
    img.line(18, 10, 27, 2, WOOD, 3)
    img.line(19, 10, 28, 3, WOOD_L, 1)
    put(img, [(10, 13), (21, 13), (12, 16), (19, 16)], YELLOW)
    put(img, [(8, 15), (23, 15)], WHITE)


def e_lieder(img):  # Heldenlieder: nordische Leier mit geschwungenen Armen, goldene Saiten, Noten
    poly(img, [(10, 21), (22, 21), (25, 28), (7, 28)], WOOD)
    img.line(10, 21, 22, 21, WOOD_L)
    img.line(7, 28, 25, 28, WOOD_D)
    img.line(9, 24, 23, 24, WOOD_D)
    ell(img, 16, 24, 2, 1.5, TAR)
    for sign in (-1, 1):
        pts = [(16 + sign * 6, 21), (16 + sign * 8, 18), (16 + sign * 9, 14), (16 + sign * 8, 10), (16 + sign * 6, 7)]
        for a, b in zip(pts, pts[1:]):
            img.line(a[0], a[1], b[0], b[1], WOOD, 2)
        img.disc(pts[-1][0], pts[-1][1] - 1, 1, GOLD)
    img.line(10, 7, 22, 7, WOOD_L, 2)
    for xx in (12, 14, 16, 18, 20):
        img.line(xx, 9, xx, 20, GOLD_L if xx % 4 == 0 else GOLD, 1)
    img.disc(5, 21, 1, YELLOW)
    img.line(6, 21, 6, 15, YELLOW, 1)
    put(img, [(7, 15), (8, 16)], YELLOW)
    img.disc(27, 14, 1, WHITE)
    img.line(28, 14, 28, 8, WHITE, 1)
    put(img, [(29, 8), (29, 9)], WHITE)


def e_zaeh(img):  # Zaehe Burschen: Rundschild mit rotem Herz
    img.disc(16, 16, 11, BLUE_D)
    img.disc(16, 16, 10, hx("#3a5a96"))
    for a in range(0, 360, 90):
        poly(img, [(16, 16), (int(round(16 + 10 * math.cos(math.radians(a - 22)))), int(round(16 + 10 * math.sin(math.radians(a - 22))))),
                   (int(round(16 + 10 * math.cos(math.radians(a + 22)))), int(round(16 + 10 * math.sin(math.radians(a + 22)))))], CLOTH_D)
    ring(img, 16, 16, 10, STEEL, 1)
    ring(img, 16, 16, 11, STEEL_D, 1)
    img.disc(16, 16, 7, hx("#26324e"))
    poly(img, [(16, 24), (8, 15), (9, 11), (13, 10), (16, 13), (19, 10), (23, 11), (24, 15)], RED)
    img.line(10, 12, 13, 11, RED_L)
    img.line(9, 13, 9, 15, RED_L)
    img.line(16, 24, 24, 15, RED_D)
    put(img, [(11, 12), (12, 12)], WHITE)


def e_glueck(img):  # Glueckspfennig: Goldmuenze mit vierblaettrigem Kleeblatt
    img.disc(16, 16, 11, GOLD_D)
    img.disc(16, 16, 10, GOLD)
    ring(img, 16, 16, 8, GOLD_L, 1)
    ring(img, 16, 16, 9, GOLD_D, 1)
    for (dx, dy) in ((-3, -3), (3, -3), (-3, 3), (3, 3)):
        img.disc(16 + dx, 16 + dy, 3, GREEN_D)
        img.disc(16 + dx, 16 + dy, 2, GREEN)
        img.set(16 + dx - 1, 16 + dy - 1, GREEN_L)
    img.line(16, 16, 20, 22, GREEN_D, 2)
    img.disc(16, 16, 1, GREEN_D)
    put(img, [(7, 7), (8, 6), (25, 8), (26, 25), (6, 24)], WHITE)
    img.line(10, 8, 14, 6, GOLD_L, 1)


def e_karte(img):  # Seekarte der Alten: Pergament, gestrichelte Route, rotes Kreuz
    poly(img, [(6, 7), (26, 7), (27, 11), (26, 15), (27, 20), (26, 25), (6, 25), (5, 20), (6, 15), (5, 11)], CLOTH)
    img.line(6, 7, 26, 7, hx("#fff4d6"))
    img.line(6, 25, 26, 25, CLOTH_D)
    img.line(26, 8, 26, 24, CLOTH_D)
    ell(img, 6, 16, 2, 10, hx("#d8c9a2"))
    ell(img, 26, 16, 2, 10, hx("#d8c9a2"))
    img.line(5, 7, 5, 25, CLOTH_D)
    img.line(27, 7, 27, 25, CLOTH_D)
    for (x, y) in ((9, 21), (12, 19), (14, 20), (17, 17), (19, 14), (21, 13)):
        img.set(x, y, RED_D)
    img.line(21, 10, 25, 14, RED, 2)
    img.line(25, 10, 21, 14, RED, 2)
    put(img, [(10, 10), (11, 9), (12, 10), (11, 11), (11, 10)], BLUE_D)
    img.line(9, 13, 12, 13, BLUE)
    img.line(8, 23, 13, 23, BLUE)
    ring(img, 10, 10, 3, GOLD_D, 1)


def e_pulver(img):  # Ein Fass Pulver: dunkles Fass mit roten Reifen, Totenkopf, brennende Lunte
    BODY, BODY_L = hx("#3d3548"), hx("#5e5470")
    poly(img, [(8, 11), (24, 11), (26, 14), (26, 25), (24, 28), (8, 28), (6, 25), (6, 14)], BODY)
    img.line(8, 11, 24, 11, BODY_L)
    img.line(6, 14, 6, 25, BODY_L)
    img.line(26, 14, 26, 25, TAR)
    for yy in (15, 24):
        img.rect(6, yy, 26, yy + 1, RED_D)
        img.rect(6, yy, 26, yy, RED)
    ell(img, 16, 19.5, 3.4, 2.6, BONE)
    put(img, [(14, 19), (18, 19)], TAR)
    img.line(14, 22, 18, 22, BONE_D)
    put(img, [(15, 22), (17, 22)], TAR)
    img.line(16, 11, 17, 7, hx("#d8c9a2"), 1)
    img.line(17, 7, 22, 5, hx("#d8c9a2"), 1)
    poly(img, [(21, 2), (24, 4), (22, 7), (20, 5)], ORANGE)
    put(img, [(22, 4), (22, 5), (23, 4)], YELLOW)
    img.set(22, 4, WHITE)
    put(img, [(26, 6), (19, 2), (25, 1), (27, 9)], YELLOW)


def e_ramm(img):  # Rammbock: Widderkopf mit gedrehten Hoernern
    H, H_D, H_L = hx("#c8a864"), hx("#8a7038"), hx("#e8d094")
    arc(img, 9, 13, 6, 20, 330, H, 4)
    arc(img, 23, 13, 6, 160, -150, H, 4)
    arc(img, 9, 13, 6, 40, 300, H_L, 1)
    arc(img, 23, 13, 6, 140, -120, H_D, 1)
    ell(img, 16, 17, 6, 8, hx("#d8d0c0"))
    ell(img, 16, 15, 4.5, 5, hx("#ece6d8"))
    ell(img, 16, 24, 3.2, 2.4, hx("#5a4a46"))
    put(img, [(14, 24), (18, 24)], TAR)
    img.set(13, 15, TAR)
    img.set(19, 15, TAR)
    img.set(13, 14, WHITE)
    img.set(19, 14, WHITE)
    img.line(16, 19, 16, 22, hx("#a89c8a"), 1)
    put(img, [(12, 11), (14, 10), (18, 10), (20, 11)], hx("#f6f0e2"))


def e_schilde(img):  # Schilde an die Reling: drei Rundschilde an einer Holzreling
    cols = [(RED, RED_D, CLOTH), (BLUE, BLUE_D, GOLD), (GREEN, GREEN_D, CLOTH)]
    for k, (cx, cy) in enumerate(((10, 15), (16, 14), (22, 15))):
        a, b, c = cols[k]
        img.disc(cx, cy, 5, b)
        img.disc(cx, cy, 4, a)
        for ang in (45, 135, 225, 315):
            img.line(cx, cy, int(round(cx + 4 * math.cos(math.radians(ang)))), int(round(cy + 4 * math.sin(math.radians(ang)))), c, 1)
        ring(img, cx, cy, 5, STEEL_D, 1)
        img.disc(cx, cy, 1, STEEL_L)
    box(img, 5, 21, 27, 24, WOOD)
    img.rect(5, 22, 27, 22, WOOD_L)
    img.rect(5, 24, 27, 24, WOOD_D)
    for xx in (7, 15, 24):
        img.rect(xx, 21, xx + 1, 27, WOOD_D)
    put(img, [(7, 22), (15, 22), (24, 22)], STEEL_L)


def e_sturm(img):  # Sturmfest: Gewitterwolke, Blitz, kleines Schiff
    for (cx, cy, rx, ry, c) in ((11, 9, 6, 4, SMOKE), (19, 8, 7, 5, SMOKE), (15, 11, 9, 3.5, hx("#545058"))):
        ell(img, cx, cy, rx, ry, c)
    ell(img, 18, 6, 4, 2, SMOKE_L)
    poly(img, [(17, 12), (12, 19), (16, 19), (11, 27), (21, 17), (17, 17), (20, 12)], YELLOW)
    img.line(17, 12, 12, 19, WHITE)
    poly(img, [(3, 26), (29, 26), (26, 29), (6, 29)], WOOD)
    img.line(3, 26, 29, 26, WOOD_L)
    img.line(6, 29, 26, 29, WOOD_D)
    img.line(24, 26, 24, 19, WOOD_D, 1)
    poly(img, [(24, 19), (28, 26), (24, 25)], CLOTH)
    put(img, [(5, 15), (7, 17), (26, 14), (27, 17), (8, 12)], BLUE_L)


def e_wellen(img):  # Wellenreiter: brechende Welle mit Gischt, Schiff auf dem Kamm
    poly(img, [(4, 27), (4, 22), (7, 17), (12, 13), (18, 12), (23, 14), (26, 18), (23, 18), (20, 16), (16, 16), (13, 19), (13, 23), (28, 23), (28, 27)], BLUE)
    arc(img, 17, 20, 9, 205, 340, BLUE_L, 2)
    arc(img, 18, 20, 6, 215, 330, hx("#d8ecfa"), 1)
    img.line(4, 27, 28, 27, BLUE_D)
    img.line(13, 23, 28, 23, BLUE_L)
    put(img, [(4, 22), (5, 20), (7, 17), (9, 15)], BLUE_L)
    put(img, [(25, 15), (27, 14), (28, 17), (24, 12), (22, 11), (10, 12), (8, 14)], WHITE)
    poly(img, [(15, 11), (24, 11), (22, 14), (17, 14)], WOOD)
    img.line(15, 11, 24, 11, WOOD_L)
    img.line(19, 11, 19, 4, WOOD_D, 1)
    poly(img, [(19, 4), (23, 10), (19, 10)], RED)
    img.line(21, 5, 21, 9, CLOTH, 1)


SHIP_ICONS = ["sporn", "drachenkopf", "teer", "beschlag", "planken", "tuch", "prunk", "sturm", "riemen", "esche", "kanone",
              "schwere", "fass", "pulver", "haengematte", "werkzeug", "truhe"]

GEAR_ICONS = ["schwert", "axt", "speer", "dolch", "hammer", "runenstab", "leder", "kette", "fell", "schuppen", "mantel", "helm",
              "rune", "zahn", "hammeranhaenger", "muenze", "horn", "auge"]
PERK_EMBLEMS = ["odin", "vorrat", "wind", "arme", "haende", "lieder", "zaeh", "glueck", "karte", "pulver", "ramm", "schilde", "sturm", "wellen"]
SPECIAL_ICONS = ["pfand"]


def glyph_of(name):
    return globals()["i_" + name]


def plate(rim, rarity):
    """Platte 20x20: dunkel, Rand in Seltenheitsfarbe, ab 'selten' ein heller Innenrand, legendaer mit Glanzpunkten."""
    img = Img(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            if x in (0, TILE - 1) and y in (0, TILE - 1):
                continue
            edge = x in (0, TILE - 1) or y in (0, TILE - 1)
            if edge:
                c = rim
            else:
                c = PLATE if (x + y) % 7 else PLATE_D
            img.set(x, y, c)
    if rarity >= 1:
        inner = mix(PLATE, rim, 0.35)
        for k in range(1, TILE - 1):
            img.set(k, 1, inner)
            img.set(1, k, inner)
        img.set(1, 1, rim)
    if rarity >= 2:
        for k in range(1, TILE - 1):
            img.set(k, TILE - 2, mix(PLATE_D, rim, 0.3))
            img.set(TILE - 2, k, mix(PLATE_D, rim, 0.3))
    if rarity >= 3:
        for (x, y) in ((1, 1), (TILE - 2, 1), (1, TILE - 2), (TILE - 2, TILE - 2)):
            img.set(x, y, hx("#ffe9a8"))
    return img


def build_items():
    names = SHIP_ICONS + GEAR_ICONS + SPECIAL_ICONS
    sheet = Img(TILE * len(names), TILE * 4)
    for col, name in enumerate(names):
        g = Img(16, 16)
        glyph_of(name)(g)
        g.outline(OUT)
        for row in range(4):
            tile = plate(RARITY_RIMS[row], row)
            tile.blit(g, 2, 2)
            sheet.blit(tile, col * TILE, row * TILE)
    return names, sheet


def medallion():
    """Runde Platte 32x32: goldener Doppelrand, dunkler Grund mit leichtem Verlauf."""
    img = Img(EMBLEM, EMBLEM)
    c = (EMBLEM - 1) / 2.0
    for y in range(EMBLEM):
        for x in range(EMBLEM):
            d = math.hypot(x - c, y - c)
            if d > 15.6:
                continue
            if d > 14.7:
                col = hx("#7a5a22")
            elif d > 13.6:
                col = GOLD if (x + y) % 5 else GOLD_L
            elif d > 12.8:
                col = OUT
            else:
                t = y / float(EMBLEM)
                base = mix(hx("#34303f"), hx("#17151d"), t)
                col = base if (x + y) % 6 else mix(base, hx("#000000"), 0.2)
            img.set(x, y, col)
    for (x, y) in ((3, 8), (28, 8), (16, 0), (16, 31)):
        if img.get(x, y) is not None:
            img.set(x, y, hx("#ffe9a8"))
    return img


def build_emblems():
    sheet = Img(EMBLEM * len(PERK_EMBLEMS), EMBLEM)
    for col, name in enumerate(PERK_EMBLEMS):
        g = Img(EMBLEM, EMBLEM)
        globals()["e_" + name](g)
        g.outline(OUT)
        tile = medallion()
        # nur innerhalb des Innenkreises zeichnen, damit nichts auf den Goldrand ragt
        c = (EMBLEM - 1) / 2.0
        for y in range(EMBLEM):
            for x in range(EMBLEM):
                px = g.px[y][x]
                if px is not None and math.hypot(x - c, y - c) <= 13.2:
                    tile.set(x, y, px)
        sheet.blit(tile, col * EMBLEM, 0)
    return sheet


def write_gd(here, names, emblems):
    path = os.path.join(here, "..", "scripts", "item_icons.gd")
    lines = ",\n\t".join(", ".join('"%s"' % n for n in names[i:i + 6]) for i in range(0, len(names), 6))
    elines = ("\n\t" + ",\n\t".join(", ".join('"%s"' % n for n in emblems[i:i + 6]) for i in range(0, len(emblems), 6)) + ",\n") if emblems else ""
    src = '''class_name ItemIcons
extends RefCounted

## Symbole der Gegenstaende und Embleme der Segen. ERZEUGT von tools/make_item_icons.py, nicht von Hand aendern.
## assets/item_icons.png: Zeile = Seltenheit (0 gewoehnlich .. 3 legendaer), Spalte = Symbol (Reihenfolge ORDER), Feld 20x20.
## assets/perk_emblems.png: ein Streifen aus 32x32-Emblemen (Reihenfolge EMBLEMS).

const TILE := 20
const INNER := 16  # das Symbol ohne Platte (Mitte des Feldes), fuer enge Zeilen
const EMBLEM := 32
const PATH := "res://assets/item_icons.png"
const EMBLEM_PATH := "res://assets/perk_emblems.png"
const ORDER := [
	%s,
]
const EMBLEMS := [%s]

static var _tex: Texture2D = null
static var _etex: Texture2D = null


static func _load() -> void:
	if _tex == null and DisplayServer.get_name() != "headless":
		_tex = load(PATH) as Texture2D
		if ResourceLoader.exists(EMBLEM_PATH):
			_etex = load(EMBLEM_PATH) as Texture2D


## Spalte eines Schluessels: "teer@2" -> Spalte von "teer" (Schiff); Ausruestung und Pfandflasche haben eigene Namen.
static func index_of(key: String) -> int:
	return ORDER.find(key.get_slice("@", 0))


## Gegenstandsschluessel (Schiff oder Ausruestung, mit oder ohne "@Seltenheit") in der Platte zeichnen: 20x20 ab pos.
static func draw(ci: CanvasItem, key: String, pos: Vector2, rarity: int, tint: Color = Color.WHITE) -> void:
	_load()
	var i := index_of(key)
	if _tex == null or i < 0:
		return
	ci.draw_texture_rect_region(_tex, Rect2(pos, Vector2(TILE, TILE)), Rect2(float(i * TILE), float(clampi(rarity, 0, 3) * TILE), float(TILE), float(TILE)), tint)


## Nur das Symbol (16x16, ohne Rand der Platte), z. B. in Zeilen, die selbst einen Seltenheitsrahmen haben.
static func draw_inner(ci: CanvasItem, key: String, pos: Vector2, rarity: int, tint: Color = Color.WHITE) -> void:
	_load()
	var i := index_of(key)
	if _tex == null or i < 0:
		return
	var off := float((TILE - INNER) / 2)
	ci.draw_texture_rect_region(_tex, Rect2(pos, Vector2(INNER, INNER)), Rect2(float(i * TILE) + off, float(clampi(rarity, 0, 3) * TILE) + off, float(INNER), float(INNER)), tint)


## Emblem eines Segens (Schluessel wie in Perks.DATA), 32x32 ab pos.
static func draw_emblem(ci: CanvasItem, perk_id: String, pos: Vector2, tint: Color = Color.WHITE) -> void:
	_load()
	var i := EMBLEMS.find(perk_id)
	if _etex == null or i < 0:
		return
	ci.draw_texture_rect_region(_etex, Rect2(pos, Vector2(EMBLEM, EMBLEM)), Rect2(float(i * EMBLEM), 0.0, float(EMBLEM), float(EMBLEM)), tint)
''' % (lines, elines)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)


def contact_sheet(sheet, names, folder, scale=6):
    os.makedirs(folder, exist_ok=True)
    for row in range(4):
        cols = len(names)
        per = 12
        rows_n = (cols + per - 1) // per
        out = Img(per * (TILE + 2), rows_n * (TILE + 2))
        for i in range(cols):
            tile = Img(TILE, TILE)
            for y in range(TILE):
                for x in range(TILE):
                    tile.px[y][x] = sheet.px[row * TILE + y][i * TILE + x]
            out.blit(tile, (i % per) * (TILE + 2) + 1, (i // per) * (TILE + 2) + 1)
        out.filled_bg(hx("#101018")).scaled(scale).save(os.path.join(folder, "item_icons_%s.png" % RARITY_NAMES[row]))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    names, sheet = build_items()
    sheet.save(os.path.join(here, "..", "assets", "item_icons.png"))
    print("assets/item_icons.png geschrieben (%d Symbole x 4 Seltenheiten)" % len(names))
    emb = build_emblems()
    emb.save(os.path.join(here, "..", "assets", "perk_emblems.png"))
    print("assets/perk_emblems.png geschrieben (%d Embleme)" % len(PERK_EMBLEMS))
    write_gd(here, names, PERK_EMBLEMS)
    print("scripts/item_icons.gd geschrieben")
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        contact_sheet(sheet, names, folder)
        per = 7
        rows_n = (len(PERK_EMBLEMS) + per - 1) // per
        out = Img(per * (EMBLEM + 2), rows_n * (EMBLEM + 2))
        for i in range(len(PERK_EMBLEMS)):
            tile = Img(EMBLEM, EMBLEM)
            for y in range(EMBLEM):
                for x in range(EMBLEM):
                    tile.px[y][x] = emb.px[y][i * EMBLEM + x]
            out.blit(tile, (i % per) * (EMBLEM + 2) + 1, (i // per) * (EMBLEM + 2) + 1)
        out.filled_bg(hx("#1c1a24")).scaled(5).save(os.path.join(folder, "perk_emblems.png"))
        print("Vorschau in", folder)


if __name__ == "__main__":
    main()
