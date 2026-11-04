"""Erzeugt die Fertigkeits-Symbole (Pixelart, reines Python, wie make_art.py).

Aufruf:
    python -X utf8 -I tools/make_skill_icons.py                      -> schreibt assets/skill_icons.png
    python -X utf8 -I tools/make_skill_icons.py --preview ordner     -> zusaetzlich ein vergroessertes Vorschaubild

assets/skill_icons.png: ein Streifen aus 16x16-Feldern. Die Reihenfolge steht in scripts/skill_icons.gd (ORDER) und
muss mit ORDER unten uebereinstimmen. Jedes Symbol sitzt auf einer dunklen Platte mit Bronzerand, damit es auf den
Karten und im Banner gut lesbar ist.
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_art import Img, hx, sh  # noqa: E402

OUT = hx("#0b0a0e")
PLATE, PLATE_D, RIM = hx("#26232d"), hx("#1a1820"), hx("#7a5a3a")
STEEL, STEEL_D, STEEL_L = hx("#9aa3ab"), hx("#5d6670"), hx("#dfe6ec")
WOOD, WOOD_D = hx("#8a6240"), hx("#5e432c")
BONE, BONE_D = hx("#e4dcc4"), hx("#a39b84")
GOLD, GOLD_D = hx("#e0b84a"), hx("#a8842a")
RED, RED_D, RED_L = hx("#c8453d"), hx("#7a2424"), hx("#ee7a66")
ORANGE, YELLOW = hx("#e8903a"), hx("#f6dc5a")
GREEN, GREEN_D, GREEN_L = hx("#5cae5a"), hx("#356a38"), hx("#a6e69a")
BLUE, BLUE_D, BLUE_L = hx("#5b8fd0"), hx("#2f5288"), hx("#a9cdf5")
PURPLE, PURPLE_D, PURPLE_L = hx("#8a62a6"), hx("#4a3262"), hx("#c4a0e0")
WHITE = hx("#f4f1e8")
SMOKE = hx("#6f6a70")


def poly(img, pts, c):
    """Gefuelltes Vieleck (Punkt-in-Polygon je Pixel)."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(min(ys), max(ys) + 1):
        for x in range(min(xs), max(xs) + 1):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > y + 0.01) != (yj > y + 0.01) and x + 0.5 < (xj - xi) * (y + 0.5 - yi) / (yj - yi + 1e-9) + xi:
                    inside = not inside
                j = i
            if inside:
                img.set(x, y, c)


def arc(img, cx, cy, r, a0, a1, c, w=1):
    """Kreisbogen von a0 bis a1 (Grad, 0 = rechts, wachsend im Uhrzeigersinn auf dem Bild)."""
    steps = max(8, int(abs(a1 - a0) / 6))
    prev = None
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        p = (int(round(cx + r * math.cos(a))), int(round(cy + r * math.sin(a))))
        if prev is not None:
            img.line(prev[0], prev[1], p[0], p[1], c, w)
        prev = p


def arrow_head(img, x, y, dx, dy, c, size=3):
    """Pfeilspitze bei (x, y), die in Richtung (dx, dy) zeigt."""
    n = math.hypot(dx, dy) or 1.0
    ux, uy = dx / n, dy / n
    px, py = -uy, ux
    poly(img, [(x, y), (int(round(x - ux * size + px * size * 0.7)), int(round(y - uy * size + py * size * 0.7))),
               (int(round(x - ux * size - px * size * 0.7)), int(round(y - uy * size - py * size * 0.7)))], c)


# --- Symbole (alle im Bereich 2..13) ---------------------------------------------------------------

def i_sword(img):
    img.line(5, 10, 12, 3, STEEL_L, 2)
    img.line(11, 3, 12, 2, WHITE, 1)
    img.line(4, 7, 8, 11, GOLD, 2)
    img.line(4, 11, 3, 12, WOOD_D, 2)
    img.set(3, 13, GOLD)


def i_bash(img):
    img.disc(7, 8, 5, BLUE_D)
    img.disc(7, 8, 4, BLUE)
    img.disc(7, 8, 1, STEEL_L)
    img.line(9, 4, 12, 2, YELLOW, 1)
    img.line(11, 6, 13, 6, YELLOW, 1)
    img.line(11, 9, 13, 11, YELLOW, 1)


def i_shield(img):
    poly(img, [(3, 3), (12, 3), (12, 8), (7, 13), (3, 8)], BLUE_D)
    poly(img, [(4, 4), (11, 4), (11, 8), (7, 12), (4, 8)], BLUE)
    img.rect(7, 4, 7, 11, STEEL_L)
    img.rect(4, 7, 11, 7, STEEL_L)
    img.disc(7, 7, 1, GOLD)


def i_guardally(img):
    poly(img, [(2, 4), (9, 4), (9, 8), (5, 12), (2, 8)], BLUE_D)
    poly(img, [(3, 5), (8, 5), (8, 8), (5, 11), (3, 8)], BLUE)
    img.rect(11, 3, 11, 9, GREEN_L)
    img.rect(9, 6, 13, 6, GREEN_L)
    img.rect(11, 4, 11, 8, GREEN)


def i_sweep(img):
    arc(img, 7, 9, 5, 200, 340, STEEL_L, 2)
    arc(img, 7, 9, 3, 215, 325, STEEL, 1)
    img.line(3, 12, 6, 9, GOLD, 2)
    arrow_head(img, 12, 8, 1, 1, STEEL_L, 3)


def i_taunt(img):
    img.rect(7, 3, 8, 9, RED_L)
    img.rect(7, 11, 8, 12, RED_L)
    img.rect(6, 3, 6, 9, RED)
    img.line(3, 5, 4, 4, ORANGE, 1)
    img.line(3, 9, 4, 10, ORANGE, 1)
    img.line(12, 5, 11, 4, ORANGE, 1)
    img.line(12, 9, 11, 10, ORANGE, 1)


def i_axe(img):
    img.line(4, 13, 10, 5, WOOD, 2)
    poly(img, [(8, 3), (13, 3), (13, 8), (10, 8)], STEEL)
    img.line(8, 3, 13, 3, STEEL_L, 1)
    img.line(13, 3, 13, 8, STEEL_D, 1)


def i_cleave(img):
    img.line(3, 11, 8, 4, WOOD, 2)
    poly(img, [(6, 2), (11, 2), (11, 6), (8, 6)], STEEL)
    img.line(6, 2, 11, 2, STEEL_L, 1)
    poly(img, [(11, 8), (13, 12), (11, 13), (9, 12)], RED)
    img.set(11, 10, RED_L)


def i_charge(img):
    img.line(3, 8, 10, 8, ORANGE, 2)
    arrow_head(img, 13, 8, 1, 0, YELLOW, 4)
    img.line(3, 5, 6, 5, STEEL, 1)
    img.line(3, 11, 6, 11, STEEL, 1)
    img.line(2, 8, 4, 8, YELLOW, 1)


def i_whirl(img):
    arc(img, 8, 8, 5, 20, 330, STEEL_L, 2)
    arrow_head(img, 12, 6, 1, -1, STEEL_L, 3)
    poly(img, [(6, 6), (10, 6), (10, 10), (8, 10)], STEEL)
    img.line(6, 6, 10, 6, STEEL_L, 1)
    img.rect(7, 10, 8, 11, WOOD)


def i_axe_big(img):
    img.line(4, 13, 9, 4, WOOD, 2)
    poly(img, [(6, 2), (13, 2), (13, 9), (11, 11), (9, 7)], STEEL)
    poly(img, [(7, 3), (12, 3), (12, 8), (10, 7)], STEEL_L)
    img.line(13, 2, 13, 9, STEEL_D, 1)
    img.set(11, 12, RED)


def i_rage(img):
    poly(img, [(8, 2), (11, 6), (12, 10), (10, 13), (6, 13), (4, 10), (5, 6)], RED)
    poly(img, [(8, 5), (10, 8), (10, 11), (8, 12), (6, 11), (6, 8)], ORANGE)
    poly(img, [(8, 8), (9, 10), (8, 12), (7, 10)], YELLOW)


def i_bow(img):
    arc(img, 5, 8, 6, -70, 70, WOOD, 2)
    img.line(7, 2, 7, 14, hx("#e6dcc0"), 1)
    img.line(3, 8, 12, 8, WOOD, 1)
    arrow_head(img, 13, 8, 1, 0, STEEL_L, 3)
    img.line(3, 7, 4, 8, GREEN_L, 1)
    img.line(3, 9, 4, 8, GREEN_L, 1)


def i_mark(img):
    arc(img, 8, 8, 5, 0, 360, RED, 1)
    arc(img, 8, 8, 2, 0, 360, RED_L, 1)
    img.line(8, 2, 8, 5, RED_L, 1)
    img.line(8, 11, 8, 13, RED_L, 1)
    img.line(2, 8, 5, 8, RED_L, 1)
    img.line(11, 8, 13, 8, RED_L, 1)
    img.set(8, 8, YELLOW)


def i_rain(img):
    for x in (4, 8, 12):
        img.line(x, 2, x, 9, WOOD, 1)
        arrow_head(img, x, 12, 0, 1, STEEL_L, 3)
    img.set(3, 3, GREEN_L)
    img.set(7, 4, GREEN_L)
    img.set(11, 3, GREEN_L)


def i_fire_arrow(img):
    img.line(3, 12, 10, 5, WOOD, 1)
    arrow_head(img, 11, 4, 1, -1, STEEL_L, 3)
    poly(img, [(11, 7), (13, 10), (11, 12), (9, 10)], RED)
    poly(img, [(11, 9), (12, 10), (11, 11), (10, 10)], YELLOW)
    img.line(3, 12, 2, 13, GREEN_L, 1)


def i_stun(img):
    for cx, cy, col in ((5, 5, YELLOW), (11, 6, GOLD), (8, 11, YELLOW)):
        img.rect(cx - 2, cy, cx + 2, cy, col)
        img.rect(cx, cy - 2, cx, cy + 2, col)
        img.rect(cx - 1, cy - 1, cx + 1, cy + 1, col)
    arc(img, 8, 8, 5, 20, 160, STEEL_L, 1)


def i_retreat(img):
    img.line(12, 4, 12, 9, STEEL_L, 2)
    img.line(12, 9, 5, 9, STEEL_L, 2)
    arrow_head(img, 3, 9, -1, 0, STEEL_L, 4)
    img.line(3, 4, 9, 4, WOOD, 1)
    arrow_head(img, 10, 4, 1, 0, STEEL_L, 2)


def i_staff(img):
    img.line(4, 13, 10, 5, WOOD, 2)
    img.disc(11, 4, 2, GOLD)
    img.set(10, 3, YELLOW)
    img.line(11, 1, 11, 1, YELLOW, 1)


def i_note(img, c1, c2, c3=None):
    img.disc(5, 11, 2, c1)
    img.disc(10, 9, 2, c1)
    img.line(7, 11, 7, 3, c2, 1)
    img.line(12, 9, 12, 2, c2, 1)
    img.line(7, 3, 12, 2, c2, 2)
    if c3 is not None:
        img.set(3, 4, c3)
        img.set(14, 6, c3)
        img.set(4, 2, c3)


def i_song_war(img):
    i_note(img, GOLD_D, GOLD, RED_L)
    img.line(2, 13, 6, 9, STEEL_L, 1)


def i_heal(img):
    img.rect(6, 2, 9, 13, GREEN)
    img.rect(2, 6, 13, 9, GREEN)
    img.rect(7, 3, 8, 12, GREEN_L)
    img.rect(3, 7, 12, 8, GREEN_L)
    img.rect(7, 7, 8, 8, WHITE)


def i_song_calm(img):
    i_note(img, BLUE, BLUE_L, GREEN_L)


def i_cleanse(img):
    poly(img, [(8, 2), (11, 8), (8, 14), (5, 8)], BLUE_L)
    poly(img, [(8, 4), (9, 8), (8, 12), (7, 8)], WHITE)
    img.line(2, 8, 4, 8, YELLOW, 1)
    img.line(12, 8, 14, 8, YELLOW, 1)
    img.set(3, 3, YELLOW)
    img.set(13, 13, YELLOW)


def i_mock(img):
    img.disc(8, 8, 5, GOLD)
    img.disc(8, 8, 4, YELLOW)
    img.set(6, 6, OUT)
    img.set(10, 6, OUT)
    arc(img, 8, 8, 3, 20, 160, OUT, 1)
    img.rect(9, 11, 10, 12, RED_L)


def i_musket(img):
    img.line(2, 12, 6, 9, WOOD_D, 3)
    img.line(5, 10, 12, 4, STEEL, 2)
    img.line(6, 9, 12, 3, STEEL_L, 1)
    img.rect(13, 1, 14, 3, YELLOW)
    img.set(12, 2, ORANGE)
    img.rect(5, 10, 6, 11, GOLD_D)


def i_reload(img):
    arc(img, 8, 8, 5, 40, 350, STEEL_L, 2)
    arrow_head(img, 12, 5, 1, -1, STEEL_L, 3)
    img.rect(7, 6, 8, 10, GOLD)
    img.rect(7, 5, 8, 5, ORANGE)
    img.rect(7, 10, 8, 10, GOLD_D)


def i_pistol(img):
    img.rect(3, 4, 12, 7, STEEL_D)
    img.rect(3, 4, 12, 4, STEEL_L)
    img.rect(11, 3, 12, 3, STEEL_L)
    poly(img, [(3, 8), (7, 8), (6, 13), (3, 13)], WOOD)
    img.rect(8, 8, 9, 9, STEEL)
    img.rect(13, 5, 14, 6, YELLOW)


def i_scatter(img):
    img.rect(2, 7, 4, 9, STEEL_D)
    img.rect(3, 7, 4, 7, STEEL_L)
    for dx, dy in ((6, 3), (8, 5), (10, 7), (12, 8), (9, 9), (11, 11), (7, 12), (13, 5), (6, 8)):
        img.disc(dx, dy, 1, ORANGE if (dx + dy) % 2 else YELLOW)


def i_crosshair(img):
    arc(img, 8, 8, 5, 0, 360, WHITE, 1)
    img.line(8, 2, 8, 6, WHITE, 1)
    img.line(8, 10, 8, 13, WHITE, 1)
    img.line(2, 8, 6, 8, WHITE, 1)
    img.line(10, 8, 13, 8, WHITE, 1)
    img.disc(8, 8, 1, RED)


def i_bang(img):
    pts = []
    for k in range(16):
        a = math.radians(k * 22.5)
        r = 6 if k % 2 == 0 else 3
        pts.append((int(round(8 + r * math.cos(a))), int(round(8 + r * math.sin(a)))))
    poly(img, pts, ORANGE)
    img.disc(8, 8, 3, YELLOW)
    img.disc(8, 8, 1, WHITE)


def i_claw(img):
    for x in (4, 7, 10):
        img.line(x, 3, x + 3, 12, BONE, 2)
        img.line(x + 1, 3, x + 3, 11, RED, 1)


def i_wail(img):
    poly(img, [(4, 13), (4, 6), (6, 3), (10, 3), (12, 6), (12, 13), (10, 11), (8, 13), (6, 11)], BONE)
    img.rect(6, 6, 7, 8, OUT)
    img.rect(9, 6, 10, 8, OUT)
    img.rect(7, 10, 9, 11, OUT)
    img.set(6, 6, GREEN_L)
    img.set(9, 6, GREEN_L)


def i_knife(img):
    poly(img, [(4, 11), (11, 3), (13, 4), (7, 12)], STEEL_L)
    img.line(4, 11, 11, 3, WHITE, 1)
    img.line(3, 11, 6, 14, WOOD_D, 3)
    img.line(5, 10, 7, 12, GOLD, 1)


def i_hook(img):
    arc(img, 8, 9, 4, 20, 250, STEEL_L, 2)
    img.line(8, 2, 8, 5, STEEL, 2)
    img.line(2, 3, 7, 3, hx("#c8b88a"), 1)
    arrow_head(img, 5, 11, -1, 1, STEEL_L, 3)


def i_thrown(img):
    img.disc(8, 8, 4, WOOD)
    img.disc(8, 8, 3, hx("#a87a50"))
    img.rect(6, 3, 10, 4, WOOD_D)
    img.line(2, 6, 4, 6, SMOKE, 1)
    img.line(2, 10, 4, 10, SMOKE, 1)
    img.line(13, 12, 14, 13, STEEL_L, 1)


def i_fork(img):
    img.line(8, 13, 8, 6, WOOD, 2)
    img.rect(4, 5, 12, 6, STEEL)
    for x in (4, 8, 12):
        img.rect(x, 2, x, 5, STEEL_L)


def i_hammer(img):
    img.line(4, 13, 10, 5, WOOD, 2)
    img.rect(7, 2, 13, 6, STEEL_D)
    img.rect(7, 2, 13, 3, STEEL)
    img.rect(7, 2, 8, 6, STEEL_L)


def i_fang(img):
    poly(img, [(3, 3), (7, 3), (5, 10)], WHITE)
    poly(img, [(9, 3), (13, 3), (11, 10)], WHITE)
    img.rect(3, 2, 13, 3, RED_D)
    img.disc(5, 12, 1, RED)
    img.disc(11, 12, 1, RED)


def i_push(img):
    img.rect(2, 3, 3, 12, STEEL_D)
    img.line(4, 8, 10, 8, ORANGE, 2)
    arrow_head(img, 13, 8, 1, 0, YELLOW, 4)
    img.line(5, 5, 7, 5, STEEL, 1)
    img.line(5, 11, 7, 11, STEEL, 1)


def i_horn(img):
    arc(img, 6, 11, 5, 200, 340, BONE, 3)
    poly(img, [(9, 5), (13, 2), (14, 6), (10, 8)], GOLD)
    img.set(12, 4, YELLOW)
    img.line(3, 6, 3, 8, ORANGE, 1)
    img.line(2, 5, 2, 9, ORANGE, 1)


def i_summon(img):
    img.disc(8, 7, 4, BONE)
    img.rect(5, 11, 11, 12, BONE_D)
    img.rect(6, 6, 7, 8, OUT)
    img.rect(9, 6, 10, 8, OUT)
    img.set(6, 7, PURPLE_L)
    img.set(9, 7, PURPLE_L)
    for x, y in ((2, 3), (13, 3), (3, 12), (13, 13)):
        img.set(x, y, PURPLE_L)
        img.set(x + (1 if x < 8 else -1), y, PURPLE)


def i_tentacle(img):
    pts = [(4, 13), (5, 10), (8, 9), (10, 6), (9, 3), (6, 3)]
    img.polyline(pts, PURPLE_D, 4)
    img.polyline(pts, PURPLE, 3)
    for x, y in ((5, 10), (8, 8), (10, 5)):
        img.set(x, y, PURPLE_L)


def i_grab(img):
    arc(img, 8, 8, 5, 0, 360, PURPLE_D, 3)
    arc(img, 8, 8, 5, 0, 300, PURPLE, 2)
    img.disc(8, 7, 1, BONE)
    img.rect(7, 8, 8, 10, BONE)


def i_beak(img):
    poly(img, [(3, 3), (12, 5), (13, 9), (6, 8)], BONE)
    poly(img, [(3, 13), (12, 10), (13, 9), (6, 8)], BONE_D)
    img.line(6, 8, 13, 9, OUT, 1)


def i_ink(img):
    poly(img, [(8, 2), (12, 8), (12, 11), (10, 13), (6, 13), (4, 11), (4, 8)], PURPLE_D)
    poly(img, [(8, 4), (11, 8), (11, 11), (9, 12), (7, 12), (5, 11), (5, 8)], hx("#2a1a3a"))
    img.set(6, 9, PURPLE_L)
    img.set(6, 10, PURPLE_L)
    img.set(13, 4, PURPLE)
    img.set(3, 5, PURPLE)


def i_crush(img):
    img.rect(2, 3, 5, 12, STEEL_D)
    img.rect(10, 3, 13, 12, STEEL_D)
    img.rect(2, 3, 5, 3, STEEL_L)
    img.rect(10, 3, 13, 3, STEEL_L)
    arrow_head(img, 8, 8, 1, 0, RED_L, 3)
    arrow_head(img, 8, 8, -1, 0, RED_L, 3)


def i_swap(img):
    img.line(4, 5, 12, 5, STEEL_L, 2)
    arrow_head(img, 13, 5, 1, 0, STEEL_L, 3)
    img.line(4, 11, 12, 11, STEEL_L, 2)
    arrow_head(img, 3, 11, -1, 0, STEEL_L, 3)


def i_flee(img):
    img.line(4, 2, 4, 14, WOOD, 2)
    poly(img, [(5, 3), (13, 4), (11, 6), (13, 8), (5, 9)], WHITE)
    img.line(5, 4, 12, 5, hx("#d4d0c4"), 1)


ORDER = [
    "sword", "bash", "shield", "guardally", "sweep", "taunt",
    "axe", "cleave", "charge", "whirl", "axe_big", "rage",
    "bow", "mark", "rain", "fire_arrow", "stun", "retreat",
    "staff", "song_war", "heal", "song_calm", "cleanse", "mock",
    "musket", "reload", "pistol", "scatter", "crosshair", "bang",
    "claw", "wail", "knife", "hook", "thrown", "fork", "hammer", "fang",
    "push", "horn", "summon",
    "tentacle", "grab", "beak", "ink", "crush",
    "swap", "flee",
]
GLYPHS = {n: globals()["i_" + n] for n in ORDER}
# Kategorie bestimmt die Farbe des Randes: Angriff rot-bronze, Hilfe gruen, Gegner violett
RIMS = {}
for n in ("heal", "song_calm", "cleanse", "guardally", "song_war", "mock"):
    RIMS[n] = hx("#4f8a50")
for n in ("tentacle", "grab", "beak", "ink", "crush", "summon", "wail"):
    RIMS[n] = hx("#7a52a0")


def plate(rim):
    img = Img(16, 16)
    for y in range(16):
        for x in range(16):
            corner = (x in (0, 15) and y in (0, 15))
            if corner:
                continue
            edge = x in (0, 15) or y in (0, 15)
            img.set(x, y, rim if edge else (PLATE if (x + y) % 7 else PLATE_D))
    return img


def build():
    strip = Img(16 * len(ORDER), 16)
    for i, name in enumerate(ORDER):
        glyph = Img(16, 16)
        GLYPHS[name](glyph)
        glyph.outline(OUT)
        tile = plate(RIMS.get(name, RIM))
        tile.blit(glyph, 0, 0)
        strip.blit(tile, i * 16, 0)
    return strip


def check_order():
    """Die Reihenfolge muss die in scripts/skill_icons.gd sein."""
    here = os.path.dirname(os.path.abspath(__file__))
    src = open(os.path.join(here, "..", "scripts", "skill_icons.gd"), encoding="utf-8").read()
    body = src[src.index("const ORDER"):src.index("]", src.index("const ORDER"))]
    names = re.findall(r'"([a-z_]+)"', body)
    if names != ORDER:
        raise SystemExit("ORDER passt nicht zu scripts/skill_icons.gd:\n%s\n%s" % (names, ORDER))


def main():
    check_order()
    here = os.path.dirname(os.path.abspath(__file__))
    strip = build()
    strip.save(os.path.join(here, "..", "assets", "skill_icons.png"))
    print("assets/skill_icons.png geschrieben (%d Symbole)" % len(ORDER))
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(folder, exist_ok=True)
        cols = 12
        rows = (len(ORDER) + cols - 1) // cols
        sheet = Img(cols * 18, rows * 18)
        for i in range(len(ORDER)):
            tile = Img(16, 16)
            for y in range(16):
                for x in range(16):
                    tile.px[y][x] = strip.px[y][i * 16 + x]
            sheet.blit(tile, (i % cols) * 18 + 1, (i // cols) * 18 + 1)
        sheet.filled_bg(hx("#101018")).scaled(6).save(os.path.join(folder, "skill_icons_vorschau.png"))
        print("Vorschau in", folder)


if __name__ == "__main__":
    main()
