"""Erzeugt die Kampffiguren (Pixelart, reines Python, wie make_art.py).

Aufruf:
    python -X utf8 -I tools/make_combat_art.py                      -> schreibt assets/combat.png
    python -X utf8 -I tools/make_combat_art.py --preview ordner     -> zusaetzlich Vorschaubogen

assets/combat.png: Zeilen = Figuren (4 Rollen der Maenner, dann die Gegner in FOE_ORDER), Spalten = Posen
(Stehen A, Stehen B, Angriff, Treffer, An der Schwelle). Zelle 44x56, die Fuesse stehen auf Zeile 52, die Mitte
auf Spalte 22. Maenner schauen nach rechts, Gegner nach links (schon gespiegelt). Die Reihenfolge der Zeilen muss zu
scripts/foes.gd (ROW) und scripts/roles.gd (Id) passen.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_art import Img, hx, sh, noise  # noqa: E402

CELL_W, CELL_H = 44, 56
CX, Y0 = 22, 52
POSES = ["idle", "idle2", "attack", "hit", "door"]
OUT = hx("#0b0a0e")

SKIN, SKIN_D = hx("#d3a98b"), hx("#a87c63")
STEEL, STEEL_D, STEEL_L = hx("#9aa3ab"), hx("#5d6670"), hx("#cfd6dc")
WOOD_L, WOOD_M, WOOD_D = hx("#8a6240"), hx("#5e432c"), hx("#3a2a1c")
BONE, BONE_D = hx("#dcd3ba"), hx("#a39b84")
GOLD = hx("#d9b24a")
RED, RED_D = hx("#a23a35"), hx("#6e2424")
LEATHER, LEATHER_D = hx("#7a5236"), hx("#4e3422")
GLOW = hx("#bff7dc")
RUST, RUST_D = hx("#8a5a3a"), hx("#5a3a26")

FOE_ORDER = ["rost", "bogner", "totenwart", "brecher", "messerkerl", "schuetze", "haken", "wache", "armbrust",
             "kaufmann", "bauer", "schmied", "hund", "tentakel", "priester", "waechter", "beschwoerer", "knochen",
             "antreiber", "kraeuterfrau"]

# Riesenfigur: assets/kraken.png, eine Zeile, Zellen BIG_W x BIG_H, Posen wie oben (die fuenfte ist "spannt sich")
BIG_W, BIG_H = 88, 88
HERO_ORDER = ["schild", "axt", "bogen", "skalde", "muskete"]


def mirror(img):
    out = Img(img.w, img.h)
    for y in range(img.h):
        out.px[y] = list(reversed(img.px[y]))
    return out


# --- Koerper ---------------------------------------------------------------------------

def pose_geometry(pose, build):
    """Verschiebungen je Pose: lean (Oberkoerper nach vorn), bob, Handposition relativ zur Mitte."""
    hip = Y0 - 14
    geo = {"lean": 0, "bob": 0, "hip": hip, "kneel": False, "hand": (CX + 7, hip - 3), "arm_up": False}
    if pose == "idle2":
        geo["bob"] = -1
    elif pose == "attack":
        geo["lean"] = 4
        geo["hand"] = (CX + 15, hip - 14)
    elif pose == "hit":
        geo["lean"] = -4
        geo["bob"] = 1
        geo["hand"] = (CX + 2, hip - 18)
        geo["arm_up"] = True
    elif pose == "door":
        geo["kneel"] = True
        geo["hip"] = Y0 - 6
        geo["lean"] = 1
        geo["bob"] = 2
        geo["hand"] = (CX + 4, geo["hip"] - 9)
    return geo


def shade_rect(img, x0, y0, x1, y1, c):
    """Flaeche mit Licht links oben: helle linke Spalte, dunkle rechte Spalte und Unterkante."""
    img.rect(x0, y0, x1, y1, c)
    img.rect(x0, y0, x0, y1, sh(c, 1))
    img.rect(x1, y0, x1, y1, sh(c, -1))
    img.rect(x0, y1, x1, y1, sh(c, -2))


def draw_legs(img, spec, geo):
    pants = spec.get("pants", hx("#4a3a2f"))
    boots = spec.get("boots", hx("#2c2118"))
    w = spec.get("legw", 3)
    if spec.get("robe"):
        return
    if geo["kneel"]:
        # hinteres Bein liegt am Boden, vorderes Knie angewinkelt
        img.rect(CX - 9, Y0 - 3, CX - 1, Y0 - 1, pants)
        img.rect(CX - 10, Y0 - 3, CX - 9, Y0, boots)
        img.rect(CX, Y0 - 9, CX + 6, Y0 - 6, pants)
        img.rect(CX + 5, Y0 - 9, CX + 7, Y0, pants)
        img.rect(CX + 5, Y0 - 2, CX + 8, Y0, boots)
        return
    hip = geo["hip"]
    gap = 1 + spec.get("gap", 1)
    for lx in (CX - gap - w + 1, CX + gap):
        img.rect(lx, hip, lx + w - 1, Y0 - 3, pants)
        img.rect(lx, hip, lx, Y0 - 3, sh(pants, 1))
        img.rect(lx, Y0 - 3, lx + w - 1 + (1 if lx > CX else 0), Y0, boots)
        img.rect(lx, Y0 - 3, lx, Y0, sh(boots, 1))


def draw_torso(img, spec, geo):
    lean, bob, hip = geo["lean"], geo["bob"], geo["hip"]
    w = spec.get("build", 12)
    h = spec.get("torso", 13)
    x0 = CX - w // 2 + lean
    x1 = x0 + w - 1
    top = hip - h + bob
    cloth = spec.get("cloth", hx("#4a5a6a"))
    if spec.get("robe"):
        # langes Gewand bis zum Boden
        bottom = Y0 - 1 if not geo["kneel"] else Y0 - 1
        shade_rect(img, x0 - 1, top, x1 + 1, bottom, cloth)
        img.rect(x0 - 1, bottom - 1, x1 + 1, bottom, sh(cloth, -2))
        for yy in range(top + 6, bottom, 4):
            img.rect(x0 + 2, yy, x0 + 2, yy + 1, sh(cloth, -1))
    else:
        shade_rect(img, x0, top, x1, hip, cloth)
        img.rect(x0, hip + 1, x1, hip + 2, sh(spec.get("pants", cloth), 0))
    cloth2 = spec.get("cloth2")
    if cloth2 is not None:
        img.rect(x0 + 2, top, x1 - 2, top + 2, cloth2)  # Kragen / Ausschnitt
        img.rect(x0 + w // 2 - 1, top + 2, x0 + w // 2, hip - 1, sh(cloth2, -1))
    if spec.get("mail"):
        for yy in range(top + 1, hip, 2):
            for xx in range(x0 + 1 + (yy % 4 == 1), x1, 2):
                img.set(xx, yy, sh(cloth, 1))
    if spec.get("apron"):
        img.rect(x0 + 2, top + 4, x1 - 1, hip + 3, spec["apron"])
        img.rect(x0 + 2, top + 4, x0 + 2, hip + 3, sh(spec["apron"], 1))
    belt = spec.get("belt", hx("#2c2118"))
    if not spec.get("robe"):
        img.rect(x0, hip - 1, x1, hip, belt)
        img.rect(x0 + w // 2 - 1, hip - 1, x0 + w // 2, hip, GOLD)
    else:
        img.rect(x0, top + 8, x1, top + 9, belt)
    if spec.get("cape"):
        img.rect(x0 - 3, top + 1, x0 - 1, hip + 8, spec["cape"])
        img.rect(x0 - 3, top + 1, x0 - 3, hip + 8, sh(spec["cape"], 1))
    return top, x0, x1


def draw_head(img, spec, geo, top):
    lean = geo["lean"]
    ht = top - 9
    hx0 = CX - 4 + lean
    skin = spec.get("skin", SKIN)
    skin_d = sh(skin, -2)
    # Kopf: 9x9 mit abgerundeten Ecken
    img.rect(hx0, ht + 1, hx0 + 8, ht + 8, skin)
    img.rect(hx0 + 1, ht, hx0 + 7, ht, skin)
    img.rect(hx0 + 1, ht + 9, hx0 + 7, ht + 9, skin_d)
    img.rect(hx0 + 8, ht + 2, hx0 + 8, ht + 8, skin_d)
    img.set(hx0 + 9, ht + 5, skin_d)  # Nase
    eye = spec.get("eye", hx("#14110f"))
    img.set(hx0 + 5, ht + 4, eye)
    img.set(hx0 + 7, ht + 4, eye)
    if spec.get("eye_glow"):
        img.set(hx0 + 5, ht + 4, GLOW)
        img.set(hx0 + 7, ht + 4, GLOW)
        img.set(hx0 + 4, ht + 4, sh(GLOW, -2))
    if spec.get("skull"):
        img.rect(hx0, ht + 1, hx0 + 8, ht + 8, BONE)
        img.rect(hx0 + 1, ht, hx0 + 7, ht, BONE)
        img.rect(hx0 + 8, ht + 2, hx0 + 8, ht + 8, BONE_D)
        img.rect(hx0 + 4, ht + 3, hx0 + 5, ht + 5, OUT)
        img.rect(hx0 + 6, ht + 3, hx0 + 7, ht + 5, OUT)
        img.set(hx0 + 5, ht + 4, GLOW if spec.get("eye_glow") else BONE)
        img.set(hx0 + 7, ht + 4, GLOW if spec.get("eye_glow") else BONE)
        for tx in range(hx0 + 3, hx0 + 8, 2):
            img.rect(tx, ht + 8, tx, ht + 9, OUT)
    hair = spec.get("hair", hx("#6a4a2a"))
    helm = spec.get("helm")
    beard = spec.get("beard")
    if helm is None and not spec.get("skull"):
        img.rect(hx0, ht, hx0 + 8, ht + 2, hair)  # Haare oben
        img.rect(hx0 - 1, ht + 1, hx0, ht + 6, hair)  # Haare hinten
        img.rect(hx0 + 1, ht - 1, hx0 + 6, ht - 1, hair)
        if spec.get("longhair"):
            img.rect(hx0 - 2, ht + 3, hx0, ht + 11, hair)
    if beard:
        img.rect(hx0 + 2, ht + 7, hx0 + 8, ht + 10, beard)
        img.rect(hx0 + 3, ht + 11, hx0 + 6, ht + 12, sh(beard, -1))
        img.rect(hx0 + 5, ht + 6, hx0 + 8, ht + 6, beard)
    if helm == "nasal":
        img.rect(hx0, ht - 1, hx0 + 8, ht + 3, STEEL)
        img.rect(hx0 - 1, ht + 1, hx0, ht + 5, STEEL_D)
        img.rect(hx0, ht - 1, hx0 + 8, ht - 1, STEEL_L)
        img.rect(hx0 + 7, ht + 3, hx0 + 8, ht + 6, STEEL)  # Nasenschutz
    elif helm in ("round", "rusty"):
        c = STEEL if helm == "round" else RUST
        img.rect(hx0, ht - 1, hx0 + 8, ht + 2, c)
        img.rect(hx0 + 1, ht - 2, hx0 + 7, ht - 2, sh(c, 1))
        img.rect(hx0 - 1, ht + 2, hx0 + 9, ht + 2, sh(c, -1))
        img.rect(hx0, ht - 1, hx0, ht + 1, sh(c, 1))
    elif helm == "hood":
        c = spec.get("hood", hx("#3b4a3a"))
        img.rect(hx0 - 1, ht - 1, hx0 + 8, ht + 2, c)
        img.rect(hx0 - 2, ht, hx0 + 1, ht + 9, c)
        img.rect(hx0 + 2, ht - 2, hx0 + 6, ht - 2, c)
        img.rect(hx0 - 1, ht - 1, hx0 - 1, ht + 8, sh(c, 1))
    elif helm == "cap":
        c = spec.get("hood", hx("#3a3f4f"))
        img.rect(hx0, ht - 1, hx0 + 8, ht + 1, c)
        img.rect(hx0 + 7, ht + 1, hx0 + 11, ht + 1, sh(c, -1))
    elif helm == "bandana":
        c = spec.get("hood", RED)
        img.rect(hx0, ht + 1, hx0 + 8, ht + 2, c)
        img.rect(hx0 - 3, ht + 2, hx0 - 1, ht + 3, c)
    elif helm == "straw":
        c = hx("#c9aa5c")
        img.rect(hx0 - 3, ht + 1, hx0 + 11, ht + 2, c)
        img.rect(hx0 + 1, ht - 2, hx0 + 7, ht, c)
        img.rect(hx0 - 3, ht + 2, hx0 + 11, ht + 2, sh(c, -2))
    elif helm == "fur":
        c = hx("#7a5a3a")
        img.rect(hx0 - 1, ht - 3, hx0 + 9, ht + 1, c)
        img.rect(hx0 - 2, ht - 1, hx0 + 10, ht + 1, sh(c, -1))
        img.rect(hx0, ht - 3, hx0 + 8, ht - 3, sh(c, 1))
    elif helm == "circlet":
        img.rect(hx0, ht + 1, hx0 + 8, ht + 1, GOLD)
        img.rect(hx0 + 3, ht, hx0 + 5, ht, GOLD)
    elif helm == "tricorn":
        c = spec.get("hood", hx("#26262c"))
        img.rect(hx0 - 3, ht + 1, hx0 + 11, ht + 2, c)  # breite Krempe
        img.rect(hx0 - 1, ht - 3, hx0 + 9, ht, c)
        img.rect(hx0 - 3, ht + 1, hx0 + 11, ht + 1, GOLD)  # Tresse
        img.rect(hx0 + 5, ht - 5, hx0 + 8, ht - 3, hx("#d9d2c0"))  # Feder
        img.rect(hx0 - 1, ht - 3, hx0 - 1, ht, sh(c, 1))
    elif helm == "antler":
        img.rect(hx0, ht, hx0 + 8, ht + 1, hx("#26302a"))
        for ax in (hx0 - 1, hx0 + 8):
            img.rect(ax, ht - 5, ax, ht, BONE)
            img.rect(ax + (1 if ax > hx0 else -1), ht - 4, ax + (2 if ax > hx0 else -2), ht - 4, BONE)
            img.rect(ax + (1 if ax > hx0 else -1), ht - 7, ax + (1 if ax > hx0 else -1), ht - 5, BONE)
    return ht


def draw_arms(img, spec, geo, top, x0, x1):
    lean = geo["lean"]
    sleeve = spec.get("sleeve", spec.get("cloth", hx("#4a5a6a")))
    skin = spec.get("skin", SKIN)
    bare = spec.get("bare_arms", False)
    col = skin if bare else sleeve
    # hinterer Arm
    bx = x0 - 2
    img.rect(bx, top + 2, bx + 2, top + 9, col)
    img.rect(bx, top + 9, bx + 2, top + 11, skin)
    # vorderer Arm zur Hand
    hx_, hy_ = geo["hand"]
    sx, sy = x1 - 1, top + 3
    img.line(sx, sy, hx_ - 1, hy_ + 1, col, 3)
    img.rect(hx_ - 1, hy_ - 1, hx_ + 1, hy_ + 1, skin)
    return hx_, hy_


# --- Waffen und Zubehoer --------------------------------------------------------------------------

def maxi_(a, b):
    return a if a > b else b


def blade(img, hand, pose, length=15, color=STEEL, hilt=GOLD):
    x, y = hand
    if pose == "attack":
        img.line(x, y, x + length, y - 2, color, 2)
        img.rect(x + length, y - 3, x + length + 1, y - 2, STEEL_L)
        img.rect(x - 1, y - 3, x - 1, y + 1, hilt)
    elif pose == "door":
        img.line(x - 4, Y0 - 2, x + 6, Y0 - 3, color, 2)
    elif pose == "hit":
        img.line(x, y, x + 2, y - length + 2, color, 2)
    else:
        img.line(x, y, x + 3, y - length, color, 2)
        img.rect(x - 1, y - 2, x + 2, y - 2, hilt)
        img.set(x + 3, y - length, STEEL_L)


def axe(img, hand, pose, big=False, head=STEEL):
    x, y = hand
    s = 2 if big else 1
    if pose == "attack":
        img.line(x - 4, y - 6, x + 8, y + 4, WOOD_M, 2)
        img.rect(x + 7, y + 1, x + 7 + 3 * s, y + 6 + 3 * s, head)
        img.rect(x + 7, y + 1, x + 7 + 3 * s, y + 1, STEEL_L)
    elif pose == "door":
        img.line(x - 6, Y0 - 2, x + 6, Y0 - 3, WOOD_M, 2)
        img.rect(x + 5, Y0 - 6, x + 8, Y0 - 1, head)
    elif pose == "hit":
        img.line(x, y, x + 1, y - 13, WOOD_M, 2)
        img.rect(x - 2, y - 14, x + 3 + s, y - 10, head)
    else:
        img.line(x + 1, y + 4, x + 5, y - 17, WOOD_M, 2)
        img.rect(x + 2, y - 21, x + 6 + 2 * s, y - 15, head)
        img.rect(x + 2, y - 21, x + 6 + 2 * s, y - 21, STEEL_L)


def spear(img, hand, pose, length=22):
    x, y = hand
    if pose == "attack":
        img.line(x - 8, y + 3, x + 14, y - 2, WOOD_M, 2)
        img.rect(x + 14, y - 4, x + 17, y - 1, STEEL_L)
    elif pose == "door":
        img.line(x - 6, Y0 - 2, x + 10, Y0 - 3, WOOD_M, 2)
    else:
        img.line(x, y + 6, x + 2, y - length + 6, WOOD_M, 2)
        img.rect(x + 1, y - length + 2, x + 3, y - length + 6, STEEL_L)


def bow(img, hand, pose, crossbow=False):
    x, y = hand
    if crossbow:
        if pose == "door":
            return
        yy = y - (6 if pose == "attack" else 2)
        img.rect(x - 8, yy, x + 4, yy + 2, WOOD_M)
        img.rect(x + 2, yy - 5, x + 3, yy + 7, STEEL_D)
        img.line(x + 2, yy - 5, x - 2, yy + 1, hx("#c8c0a8"), 1)
        img.line(x + 2, yy + 7, x - 2, yy + 1, hx("#c8c0a8"), 1)
        if pose == "attack":
            img.rect(x + 4, yy + 1, x + 11, yy + 1, hx("#e6dcc0"))
        return
    if pose == "door":
        img.line(x, Y0 - 12, x + 3, Y0 - 3, WOOD_M, 2)
        return
    cx_ = x + 2
    top = y - 13
    pts = [(cx_ + 1, top), (cx_ + 4, top + 4), (cx_ + 5, top + 9), (cx_ + 4, top + 14), (cx_ + 1, top + 18)]
    img.polyline(pts, WOOD_L, 2)
    img.line(pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], hx("#e6dcc0"), 1)
    if pose == "attack":
        img.line(cx_ - 7, top + 9, cx_ + 18, top + 9, hx("#e6dcc0"), 1)
        img.rect(cx_ + 17, top + 8, cx_ + 20, top + 10, STEEL_L)


def staff(img, hand, pose, orb=GOLD):
    x, y = hand
    if pose == "door":
        img.line(x - 2, Y0 - 3, x + 8, Y0 - 3, WOOD_M, 2)
        return
    top = maxi_(y - 24 + (3 if pose == "attack" else 0), 5)
    img.line(x, y + 6, x + 1, top, WOOD_M, 2)
    img.disc(x + 1, top - 1, 2, orb)
    img.set(x, top - 2, sh(orb, 2))


def round_shield(img, cx, cy, r, c1, c2):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 > r * r + 1:
                continue
            c = sh(c1, -2) if d2 > (r - 1) * (r - 1) else c1
            if d2 <= (r - 1) * (r - 1) and ((dx > 0) == (dy > 0)) and abs(dx) > 1 and abs(dy) > 1 and c2 is not None:
                c = c2
            if dx + dy < -r // 2 and d2 <= (r - 1) * (r - 1):
                c = sh(c, 1)
            img.set(cx + dx, cy + dy, c)
    img.rect(cx - 1, cy - 1, cx + 1, cy + 1, STEEL)
    img.set(cx - 1, cy - 1, STEEL_L)


def hammer(img, hand, pose):
    x, y = hand
    if pose == "attack":
        img.line(x - 4, y - 5, x + 8, y + 3, WOOD_M, 2)
        img.rect(x + 7, y + 1, x + 12, y + 7, STEEL_D)
        img.rect(x + 7, y + 1, x + 12, y + 1, STEEL)
    elif pose == "door":
        img.line(x - 6, Y0 - 2, x + 6, Y0 - 3, WOOD_M, 2)
        img.rect(x + 5, Y0 - 7, x + 9, Y0 - 1, STEEL_D)
    else:
        img.line(x + 1, y + 4, x + 4, y - 14, WOOD_M, 2)
        img.rect(x + 1, y - 19, x + 8, y - 13, STEEL_D)
        img.rect(x + 1, y - 19, x + 8, y - 19, STEEL)


def pitchfork(img, hand, pose):
    x, y = hand
    if pose == "attack":
        img.line(x - 8, y + 3, x + 12, y - 1, WOOD_M, 2)
        for dy in (-3, -1, 1):
            img.rect(x + 12, y + dy, x + 16, y + dy, STEEL_L)
    elif pose == "door":
        img.line(x - 6, Y0 - 2, x + 10, Y0 - 3, WOOD_M, 2)
    else:
        img.line(x, y + 6, x + 1, y - 16, WOOD_M, 2)
        for dx in (-2, 1, 4):
            img.rect(x + dx, y - 21, x + dx, y - 16, STEEL_L)
        img.rect(x - 2, y - 17, x + 4, y - 16, STEEL)


def knives(img, hand, pose, spec, geo):
    x, y = hand
    if pose == "door":
        return
    if pose == "attack":
        img.line(x, y, x + 8, y - 2, STEEL_L, 2)
        img.line(x - 8, y + 4, x - 1, y + 2, STEEL_L, 2)
    else:
        img.line(x, y, x + 2, y - 7, STEEL_L, 2)
        bx, by = x - 14, geo["hip"] - 2
        img.line(bx, by, bx + 2, by - 7, STEEL_L, 2)


def hook(img, hand, pose):
    x, y = hand
    if pose == "door":
        return
    ox = 4 if pose == "attack" else 0
    img.line(x, y, x + 2 + ox, y - 8, hx("#b8a888"), 1)
    img.polyline([(x + 2 + ox, y - 8), (x + 6 + ox, y - 10), (x + 8 + ox, y - 6), (x + 5 + ox, y - 4)], STEEL_L, 2)
    img.rect(x - 14, y - 2, x - 9, y + 2, hx("#b8a888"))  # Seilrolle am Gürtel


def club(img, hand, pose):
    x, y = hand
    if pose == "attack":
        img.line(x - 4, y - 6, x + 9, y + 3, WOOD_M, 3)
        img.rect(x + 7, y, x + 12, y + 6, WOOD_L)
    elif pose == "door":
        img.line(x - 6, Y0 - 2, x + 6, Y0 - 3, WOOD_M, 3)
    else:
        img.line(x + 1, y + 4, x + 4, y - 12, WOOD_M, 3)
        img.rect(x + 2, y - 18, x + 8, y - 11, WOOD_L)
        img.rect(x + 2, y - 18, x + 8, y - 18, sh(WOOD_L, 1))


def musket(img, hand, pose):
    x, y = hand
    if pose == "attack":
        img.line(x - 9, y + 3, x + 6, y - 2, WOOD_M, 2)  # Schaft
        img.line(x - 1, y, x + 8, y - 3, STEEL_D, 1)  # Lauf
        img.rect(x + 8, y - 5, x + 10, y - 2, hx("#ffd24a"))  # Mündungsfeuer
    elif pose == "door":
        img.line(x - 7, Y0 - 2, x + 9, Y0 - 3, WOOD_M, 2)
        img.line(x + 1, Y0 - 3, x + 9, Y0 - 3, STEEL_D, 1)
    elif pose == "hit":
        img.line(x - 1, y + 3, x + 2, y - 13, WOOD_M, 2)
        img.line(x + 1, y - 6, x + 2, y - 15, STEEL_D, 1)
    else:
        img.line(x - 2, y + 6, x + 3, y - 15, WOOD_M, 2)
        img.line(x + 1, y - 5, x + 3, y - 17, STEEL_D, 1)
        img.set(x + 3, y - 17, STEEL_L)
        img.rect(x - 3, y + 4, x - 1, y + 7, LEATHER_D)  # Kolben


def horn(img, hand, pose):
    x, y = hand
    if pose == "door":
        return
    up = 0 if pose == "attack" else 3
    img.polyline([(x, y - up), (x + 3, y - 5 - up), (x + 7, y - 7 - up), (x + 11, y - 5 - up)], hx("#d9c9a0"), 3)
    img.rect(x + 10, y - 9 - up, x + 13, y - 4 - up, BONE)
    img.rect(x + 11, y - 8 - up, x + 12, y - 5 - up, hx("#4a3a2a"))


def basket(img, hand, pose):
    x, y = hand
    if pose == "door":
        return
    img.rect(x - 2, y - 1, x + 7, y + 5, LEATHER)
    img.rect(x - 2, y - 1, x + 7, y - 1, sh(LEATHER, 1))
    img.rect(x - 1, y + 3, x + 6, y + 3, sh(LEATHER, -1))
    for dx, col in ((0, hx("#7ab05a")), (2, hx("#5a9a4a")), (4, hx("#9ad07a")), (6, hx("#c27ab0"))):
        img.rect(x + dx - 1, y - 4, x + dx, y - 2, col)


def quiver(img, geo, top, x0):
    img.rect(x0 - 3, top - 1, x0 - 1, top + 12, LEATHER_D)
    for k in range(3):
        img.rect(x0 - 3 + k, top - 4 - (k % 2), x0 - 3 + k, top - 1, hx("#e6dcc0"))


def purse(img, geo, x0):
    img.disc(x0 - 1, geo["hip"] + 2, 2, LEATHER)
    img.set(x0 - 1, geo["hip"] + 4, GOLD)


# --- Figuren zusammenstellen -------------------------------------------------------------------------

def person(spec, pose):
    img = Img(CELL_W, CELL_H)
    geo = pose_geometry(pose, spec.get("build", 12))
    if spec.get("hunch"):
        geo["bob"] += 1
    # Gegenstaende hinter dem Koerper
    draw_legs(img, spec, geo)
    top, x0, x1 = draw_torso(img, spec, geo)
    if spec.get("quiver"):
        quiver(img, geo, top, x0)
    ht = draw_head(img, spec, geo, top)
    hand = draw_arms(img, spec, geo, top, x0, x1)
    gear = spec.get("gear", [])
    for g in gear:
        kind = g[0]
        if kind == "sword":
            blade(img, hand, pose)
        elif kind == "rustsword":
            blade(img, hand, pose, 11, RUST, RUST_D)
        elif kind == "axe":
            axe(img, hand, pose, big=g[1] if len(g) > 1 else False)
        elif kind == "spear":
            spear(img, hand, pose)
        elif kind == "bow":
            bow(img, hand, pose)
        elif kind == "crossbow":
            bow(img, hand, pose, crossbow=True)
        elif kind == "staff":
            staff(img, hand, pose, g[1] if len(g) > 1 else GOLD)
        elif kind == "hammer":
            hammer(img, hand, pose)
        elif kind == "pitchfork":
            pitchfork(img, hand, pose)
        elif kind == "knives":
            knives(img, hand, pose, spec, geo)
        elif kind == "hook":
            hook(img, hand, pose)
        elif kind == "club":
            club(img, hand, pose)
        elif kind == "musket":
            musket(img, hand, pose)
        elif kind == "horn":
            horn(img, hand, pose)
        elif kind == "basket":
            basket(img, hand, pose)
        elif kind == "purse":
            purse(img, geo, x0)
        elif kind == "shield":
            sy = geo["hip"] - 8 + geo["bob"] + (3 if pose == "door" else 0)
            sx = x1 + 1 + (2 if pose == "attack" else 0) - (3 if pose == "hit" else 0)
            round_shield(img, sx, sy, g[1] if len(g) > 1 else 6, g[2], g[3] if len(g) > 3 else None)
    img.outline(OUT)
    return img


def dog(pose):
    img = Img(CELL_W, CELL_H)
    fur, fur_d = hx("#6b5a46"), hx("#43372a")
    lean = {"idle": 0, "idle2": 0, "attack": 5, "hit": -4, "door": -4}[pose]
    bob = {"idle": 0, "idle2": -1, "attack": 2, "hit": 1, "door": 1}[pose]
    y = Y0 - 10 + bob
    # Beine
    for lx in (CX - 9, CX - 6, CX + 5, CX + 8):
        img.rect(lx + (lean if lx > CX else 0), y + 6, lx + 1 + (lean if lx > CX else 0), Y0, fur_d)
    # Koerper
    img.rect(CX - 11, y, CX + 8 + lean, y + 7, fur)
    img.rect(CX - 11, y, CX + 8 + lean, y, sh(fur, 1))
    img.rect(CX - 11, y + 7, CX + 8 + lean, y + 7, fur_d)
    # Kopf
    hx0 = CX + 8 + lean
    img.rect(hx0, y - 5, hx0 + 6, y + 3, fur)
    img.rect(hx0 + 6, y - 1, hx0 + 10, y + 2, sh(fur, -1))  # Schnauze
    img.set(hx0 + 10, y - 1, OUT)
    img.rect(hx0 + 1, y - 8, hx0 + 2, y - 5, fur_d)  # Ohr
    img.set(hx0 + 4, y - 3, hx("#e6dcc0"))
    if pose == "attack":
        img.rect(hx0 + 6, y + 2, hx0 + 9, y + 2, BONE)  # Zaehne
    # Schwanz
    tw = 1 if pose == "idle2" else 0
    img.line(CX - 11, y + 1, CX - 15, y - 4 - tw, fur, 2)
    img.outline(OUT)
    return img


# --- Kraken ---------------------------------------------------------------------------------------------

K_SKIN, K_SKIN_D, K_SKIN_L = hx("#5b3d78"), hx("#3a2552"), hx("#8a62a6")
K_BELLY = hx("#a88bc0")
K_SUCK = hx("#ecc9d6")
K_WATER, K_WATER_D, K_FOAM = hx("#1f4257"), hx("#132b3a"), hx("#cfe8ee")
K_EYE, K_EYE_HOT, K_PUPIL = hx("#f5d44a"), hx("#ff7048"), hx("#1a0f20")
K_RAMP = [hx("#2c1c40"), hx("#3d2858"), hx("#573a76"), hx("#765096"), hx("#97709e")]


def thick_curve(img, pts, r0, r1, suckers=True):
    """Gewundener Arm entlang pts (x, y): dunkler Rand, Koerper, Licht links oben, Saugnaepfe vorn."""
    n = len(pts)
    rs = [r0 + (r1 - r0) * i / max(n - 1, 1) for i in range(n)]
    for (x, y), r in zip(pts, rs):
        img.disc(int(round(x)), int(round(y)), max(int(round(r)), 1), K_SKIN_D)
    for (x, y), r in zip(pts, rs):
        img.disc(int(round(x - 0.5)), int(round(y - 0.5)), max(int(round(r - 1)), 0), K_SKIN)
    for (x, y), r in zip(pts, rs):
        if r >= 3:
            img.disc(int(round(x - r * 0.35)), int(round(y - r * 0.35)), max(int(round(r - 3.2)), 0), K_SKIN_L)
    if suckers:
        for i in range(2, n - 1, 3):
            x, y = pts[i]
            r = rs[i]
            if r >= 2:
                img.set(int(round(x + r * 0.45)), int(round(y + r * 0.3)), K_SUCK)


def tentacle(pose):
    """Ein Fangarm, der aus dem Wasser/Deck ragt und sich einrollt. Schaut nach rechts (wird gespiegelt)."""
    img = Img(CELL_W, CELL_H)
    base_y = Y0
    phase = {"idle": 0.0, "idle2": 0.9, "attack": 0.3, "hit": 1.6, "door": 1.6}[pose]
    height = {"idle": 40, "idle2": 41, "attack": 32, "hit": 30, "door": 30}[pose]
    lean = {"idle": 0.0, "idle2": 0.0, "attack": 9.0, "hit": -5.0, "door": -5.0}[pose]
    # Pfuetze am Fuss
    for dx in range(-11, 12):
        for dy in range(-1, 2):
            if (dx / 11.0) ** 2 + (dy / 1.6) ** 2 <= 1.0:
                img.set(CX + dx, base_y + dy, K_WATER if (dx + dy) % 4 else K_WATER_D)
    img.set(CX - 7, base_y - 1, K_FOAM)
    img.set(CX + 6, base_y, K_FOAM)
    pts = []
    steps = 30
    for i in range(steps + 1):
        s = i / steps
        y = base_y - 2 - s * height
        x = CX - 2 + 4.0 * math.sin(s * 3.4 + phase) + lean * s * s
        pts.append((x, y))
    xe, ye = pts[-1]
    if pose in ("idle", "idle2", "hit", "door"):
        r0 = 5.0 if pose in ("idle", "idle2") else 3.6
        for k in range(1, 16):
            a = k / 15.0 * 1.55 * math.pi
            rr = r0 * (1.0 - 0.3 * a / math.pi)
            pts.append((xe + rr - rr * math.cos(a), ye - rr * math.sin(a)))
    else:
        # Angriff: die Spitze peitscht nach vorn und unten
        for k in range(1, 9):
            pts.append((xe + k * 1.0, ye + k * 2.0))
    thick_curve(img, pts, 6.0, 1.6)
    img.outline(OUT)
    return img


def shaded_ellipse(img, cx, cy, rx, ry, seed=0, spots=True):
    """Gefuellte Ellipse mit Licht links oben, Raster-Schattierung und gefleckter Haut."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            if nx * nx + ny * ny > 1.0:
                continue
            v = 0.55 - 0.55 * nx - 0.5 * ny
            v += (noise(x + seed, y) - 128) / 128.0 * 0.12
            if spots and noise(x // 3 + seed, y // 3 + 7) > 215:
                v -= 0.22
            idx = max(0, min(4, int(v * 5.0)))
            img.set(x, y, K_RAMP[idx])


def kraken_body(pose):
    """Der Kraken-Koerper, bis zur Brust aus dem Wasser (88x88). Der untere Rand liegt auf der Wasserlinie."""
    img = Img(BIG_W, BIG_H)
    cx = 44
    big = 3 if pose == "door" else 0
    dx = {"idle": 0, "idle2": 0, "attack": -9, "hit": 3, "door": 0}[pose]
    dy = {"idle": 0, "idle2": -1, "attack": 4, "hit": 2, "door": -2}[pose]
    arms_up = pose == "door"
    # Arme unter Wasser zuerst, links und rechts vom Koerper, rollen sich auf den Wellen ein
    for side in (-1, 1):
        for k, (ax, ay, reach) in enumerate(((20, 62, 1.0), (28, 68, 0.85), (14, 71, 0.6))):
            pts = []
            for i in range(0, 17):
                s = i / 16.0
                x = cx + side * (ax - 8 + reach * (14.0 if arms_up else 21.0) * s + (6 if arms_up else 0) * s) + dx * 0.4
                if arms_up:
                    y = ay - 8 - 30 * math.sin(s * 1.9) * reach + dy
                else:
                    y = ay + 7 * math.sin(s * 3.0 + k + (0.6 if pose == "idle2" else 0.0)) - 14.0 * s * reach + dy * 0.5
                pts.append((x, y))
            thick_curve(img, pts, 6.0, 1.6)
    # Mantel (Kopf oben) und Augenpartie
    shaded_ellipse(img, cx + dx * 0.6, 30 + dy, 20 + big, 26 + big, seed=3)
    shaded_ellipse(img, cx + dx, 54 + dy, 26 + big, 17 + big // 2, seed=11, spots=False)
    # Rippen und Narbe auf dem Mantel
    for yy in (14, 22, 30):
        img.line(int(cx + dx * 0.6 - 9), yy + dy, int(cx + dx * 0.6 + 9), yy + dy + 1, K_SKIN_D, 1)
    img.line(int(cx + dx * 0.6 - 3), 8 + dy, int(cx + dx * 0.6 + 8), 30 + dy, K_BELLY, 1)
    img.line(int(cx + dx * 0.6 - 4), 8 + dy, int(cx + dx * 0.6 + 7), 30 + dy, K_SKIN_D, 1)
    # Augen
    hot = pose == "door"
    for ex in (cx + dx - 12, cx + dx + 12):
        ey = 52 + dy
        if pose == "hit":
            img.line(ex - 5, ey, ex + 5, ey + 1, K_PUPIL, 2)
            continue
        img.disc(ex, ey, 6, OUT)
        img.disc(ex, ey, 5, K_EYE_HOT if hot else K_EYE)
        img.disc(ex - 1, ey - 1, 3, sh(K_EYE_HOT if hot else K_EYE, 1))
        px = ex - 2 if pose == "attack" else ex - 1
        img.rect(px, ey - 5, px + 1, ey + 5, K_PUPIL)
        img.set(ex - 2, ey - 3, hx("#ffffff"))
        # Brauen: finster nach innen geneigt
        img.line(ex - 7 if ex < cx + dx else ex + 7, ey - 10, ex + (4 if ex < cx + dx else -4), ey - 4, K_SKIN_D, 3)
    # Schnabel
    by = 66 + dy
    open_beak = pose in ("attack", "door")
    img.rect(cx + dx - 5, by - 2, cx + dx + 5, by + 1, BONE)
    img.rect(cx + dx - 4, by + 2, cx + dx + 4, by + 4, BONE_D)
    img.rect(cx + dx - 2, by + 5, cx + dx + 2, by + 6, BONE_D)
    if open_beak:
        img.rect(cx + dx - 3, by + 2, cx + dx + 3, by + 6, hx("#4a1020"))
        img.rect(cx + dx - 4, by + 1, cx + dx + 4, by + 1, BONE)
        img.rect(cx + dx - 3, by + 7, cx + dx + 3, by + 8, BONE_D)
    # Brust mit Saugnapfreihe
    for i in range(-3, 4):
        img.set(cx + dx + i * 5, 72 + dy, K_SUCK)
    # Wasser: Wellenband am unteren Rand, Schaum
    def water_top(x):
        # ein flacher Wasserhuegel: zu den Raendern sinkt die Flaeche ab
        return 76 + 2 * math.sin(x * 0.45 + (1.2 if pose == "idle2" else 0.0)) + max(0, abs(x - 44) - 27) * 0.85

    for y in range(76, BIG_H):
        for x in range(BIG_W):
            if y >= water_top(x):
                col = K_WATER if (x + y // 2) % 5 else K_WATER_D
                img.set(x, y, col)
    for x in range(0, BIG_W, 6):
        yy = int(water_top(x))
        if yy < BIG_H - 1:
            img.set(x, yy, K_FOAM)
            img.set(x + 1, yy, K_FOAM)
    img.outline(OUT)
    return img


# --- Beschreibungen -----------------------------------------------------------------------------------

HEROES = {
    "schild": dict(build=14, cloth=hx("#5f6d7a"), cloth2=hx("#8a95a0"), mail=True, pants=hx("#3a3a44"), helm="nasal",
                   beard=None, hair=hx("#5a3a22"), sleeve=hx("#5f6d7a"),
                   gear=[("shield", 7, hx("#3e5f8f"), hx("#e0d8c0")), ("sword",)]),
    "axt": dict(build=13, cloth=hx("#8a3a30"), cloth2=LEATHER, pants=hx("#4a3a2f"), helm=None, hair=hx("#9a5a2a"),
                beard=hx("#9a5a2a"), sleeve=hx("#8a3a30"), longhair=True, belt=LEATHER_D, gear=[("axe", True)]),
    "bogen": dict(build=11, cloth=hx("#4c6a3f"), cloth2=hx("#6f8f5a"), pants=hx("#3f3a2c"), helm="hood", hood=hx("#3d5a33"),
                  hair=hx("#5a4a30"), sleeve=hx("#4c6a3f"), quiver=True, gap=1, gear=[("bow",)]),
    "skalde": dict(build=12, cloth=hx("#35507a"), cloth2=GOLD, robe=True, helm="circlet", hair=hx("#bdb7a6"),
                   beard=hx("#bdb7a6"), sleeve=hx("#35507a"), cape=hx("#2a3a5a"), belt=LEATHER, gear=[("staff", GOLD)]),
    "muskete": dict(build=12, cloth=hx("#7a3a36"), cloth2=hx("#d0a84a"), pants=hx("#3a342e"), helm="tricorn", hood=hx("#26262c"),
                    hair=hx("#3a2a1c"), beard=hx("#3a2a1c"), sleeve=hx("#7a3a36"), belt=LEATHER_D, gap=1, gear=[("musket",)]),
}

FOES = {
    "rost": dict(build=13, skin=hx("#7d9a86"), cloth=RUST_D, cloth2=RUST, mail=True, pants=hx("#3c3a34"), helm="rusty",
                 eye_glow=True, sleeve=RUST_D, hunch=True, gear=[("rustsword",)]),
    "bogner": dict(build=10, skin=BONE, skull=True, eye_glow=True, cloth=hx("#34402f"), cloth2=hx("#4b5a43"), pants=hx("#2d2a25"),
                   helm="hood", hood=hx("#2f3a2a"), sleeve=hx("#34402f"), hunch=True, gear=[("bow",)]),
    "totenwart": dict(build=12, skull=True, eye_glow=True, cloth=hx("#27342d"), cloth2=hx("#4a6a58"), robe=True, helm="antler",
                      sleeve=hx("#27342d"), belt=hx("#4a6a58"), gear=[("staff", GLOW)]),
    "brecher": dict(build=17, torso=14, cloth=hx("#5a2a2a"), cloth2=LEATHER, pants=hx("#26262c"), helm="round", hair=hx("#2a2018"),
                    beard=hx("#2a2018"), sleeve=hx("#5a2a2a"), bare_arms=True, legw=4, gear=[("club",)]),
    "messerkerl": dict(build=10, cloth=hx("#33333c"), cloth2=RED, pants=hx("#26262c"), helm="bandana", hood=RED, hair=hx("#1c1814"),
                       sleeve=hx("#33333c"), gap=2, gear=[("knives",)]),
    "schuetze": dict(build=11, cloth=hx("#4a3f33"), cloth2=hx("#6b5a46"), pants=hx("#2a2a2e"), helm="cap", hood=hx("#2f2f3a"),
                     hair=hx("#3a2a1c"), sleeve=hx("#4a3f33"), gear=[("bow",)]),
    "haken": dict(build=12, cloth=hx("#4a3a55"), cloth2=hx("#6a5a7a"), pants=hx("#2a2a30"), helm="bandana", hood=hx("#3a2a44"),
                  hair=hx("#2a1c14"), sleeve=hx("#4a3a55"), gear=[("hook",)]),
    "wache": dict(build=14, cloth=hx("#3e5f8f"), cloth2=hx("#d9b24a"), mail=False, pants=hx("#3a3a44"), helm="round", hair=hx("#4a3a28"),
                  sleeve=hx("#6b5a46"), gear=[("shield", 6, hx("#d9b24a"), hx("#3e5f8f")), ("spear",)]),
    "armbrust": dict(build=11, cloth=hx("#4a5a6a"), cloth2=LEATHER, pants=hx("#3a3a40"), helm="cap", hood=hx("#3a4a5a"),
                     hair=hx("#3a2a1c"), sleeve=hx("#4a5a6a"), gear=[("crossbow",)]),
    "kaufmann": dict(build=18, torso=14, cloth=hx("#6a3a6a"), cloth2=GOLD, pants=hx("#3a2a3a"), helm="fur", hair=hx("#7a5a3a"),
                     beard=hx("#5a4030"), sleeve=hx("#6a3a6a"), gap=1, gear=[("purse",)]),
    "bauer": dict(build=12, cloth=hx("#7a6240"), cloth2=hx("#a0865a"), pants=hx("#5a4a35"), helm="straw", hair=hx("#6a4a2a"),
                  sleeve=hx("#7a6240"), gear=[("pitchfork",)]),
    "schmied": dict(build=17, torso=14, cloth=hx("#7a5236"), cloth2=None, apron=hx("#4e3a2a"), pants=hx("#2f2a26"), helm=None,
                    hair=hx("#2a2018"), beard=hx("#2a2018"), sleeve=hx("#d3a98b"), bare_arms=True, legw=4, gear=[("hammer",)]),
    "priester": dict(build=12, skull=True, eye_glow=True, cloth=hx("#34223a"), cloth2=hx("#8a5ab0"), robe=True, helm="hood",
                     hood=hx("#2a1a30"), sleeve=hx("#34223a"), belt=hx("#8a5ab0"), gear=[("staff", hx("#c27aff"))]),
    "waechter": dict(build=16, torso=14, skull=True, eye_glow=True, cloth=hx("#4a5058"), cloth2=STEEL_D, mail=True, pants=hx("#2c2c34"),
                     helm="round", sleeve=hx("#4a5058"), legw=4, gear=[("shield", 8, hx("#5a6068"), hx("#8a8f96")), ("rustsword",)]),
    "beschwoerer": dict(build=11, skull=True, eye_glow=True, cloth=hx("#3a1f26"), cloth2=hx("#a03a3a"), robe=True, helm="antler",
                        sleeve=hx("#3a1f26"), belt=hx("#a03a3a"), gear=[("staff", hx("#ff5a4a"))]),
    "knochen": dict(build=9, torso=11, skull=True, eye_glow=True, cloth=BONE_D, cloth2=BONE, pants=BONE_D, boots=BONE_D, sleeve=BONE,
                    bare_arms=True, skin=BONE, hunch=True, gear=[("rustsword",)]),
    "antreiber": dict(build=14, cloth=hx("#7a3a2a"), cloth2=GOLD, pants=hx("#2a2a30"), helm="bandana", hood=hx("#7a2a2a"),
                      hair=hx("#2a1c14"), beard=hx("#2a1c14"), sleeve=hx("#7a3a2a"), gear=[("horn",)]),
    "kraeuterfrau": dict(build=11, cloth=hx("#5a6a4a"), cloth2=hx("#9ab07a"), robe=True, helm="hood", hood=hx("#7a6a4a"),
                         hair=hx("#8a7a6a"), sleeve=hx("#5a6a4a"), gear=[("basket",)]),
}


def build_atlas():
    rows = len(HERO_ORDER) + len(FOE_ORDER)
    atlas = Img(CELL_W * len(POSES), CELL_H * rows)
    sheets = []
    r = 0
    for key in HERO_ORDER:
        sheets.append([person(HEROES[key], p) for p in POSES])
    for key in FOE_ORDER:
        if key == "hund":
            row = [dog(p) for p in POSES]
        elif key == "tentakel":
            row = [tentacle(p) for p in POSES]
        else:
            row = [person(FOES[key], p) for p in POSES]
        sheets.append([mirror(im) for im in row])
    for r, row in enumerate(sheets):
        for c, im in enumerate(row):
            atlas.blit(im, c * CELL_W, r * CELL_H)
    return atlas, sheets


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    atlas, sheets = build_atlas()
    out = os.path.join(here, "..", "assets", "combat.png")
    atlas.save(out)
    print("assets/combat.png geschrieben (%d Figuren x %d Posen)" % (len(sheets), len(POSES)))
    big = Img(BIG_W * len(POSES), BIG_H)
    kraken = [kraken_body(p) for p in POSES]
    for c, im in enumerate(kraken):
        big.blit(im, c * BIG_W, 0)
    big.save(os.path.join(here, "..", "assets", "kraken.png"))
    print("assets/kraken.png geschrieben (%d Posen)" % len(POSES))
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(folder, exist_ok=True)
        bg = hx("#2a3340")
        for name, part in (("helden", sheets[:5]), ("gegner_a", sheets[5:10]), ("gegner_b", sheets[10:16]), ("gegner_c", sheets[16:])):
            sheet = Img(CELL_W * len(POSES), CELL_H * len(part))
            for r, row in enumerate(part):
                for c, im in enumerate(row):
                    sheet.blit(im, c * CELL_W, r * CELL_H)
            sheet.filled_bg(bg).scaled(4).save(os.path.join(folder, "kampf_%s.png" % name))
        big.filled_bg(bg).scaled(3).save(os.path.join(folder, "kampf_kraken.png"))
        print("Vorschau in", folder)


if __name__ == "__main__":
    main()
