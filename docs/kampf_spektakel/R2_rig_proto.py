"""PROTOTYP v2: gemeinsames Koerper-Rig fuer die Kampffiguren (Weg B), reines Python, nur Standardbibliothek + tools/make_art.py.

Idee: Eine Figur ist nur eine Beschreibung (Koerperbau, Farben, Kopf, Waffe). Jede Pose ist eine Tabelle von Gelenkzielen
(Huefte, Lehnen, Fuesse, Haende, Waffenwinkel). Die Gelenke werden per Zwei-Knochen-IK berechnet und als Vektorformen
(Kapseln, Polygone) in Pixel gesetzt. So drehen sich Arme und Waffen als Geometrie, nicht als Pixelbild: alles bleibt scharf,
alle Figuren teilen dieselbe Haltung und dieselben Bewegungen.

Zelle 112x104, Fussmitte bei x=AX, Fusszeile GY, Figuren schauen nach rechts (Gegner werden zur Laufzeit gespiegelt).
Aufruf (aus dem Projektordner): python -X utf8 docs/kampf_spektakel/R2_rig_proto.py <Ausgabeordner> [sheets|key:axt,schild|stats|atlas]
"""
import math
import os
import sys

TOOLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools")  # make_art.py (Img, hx, sh, poly_pixels)
sys.path.insert(0, TOOLS)
from make_art import Img, hx, sh, poly_pixels  # noqa: E402

CW, CH = 112, 104
AX, GY = 40, 99  # Fussmitte (Spalte) und unterste Fusszeile (mit Kontur)
OUT = hx("#0b0a0e")

SKIN = hx("#d3a98b")
STEEL, STEEL_D, STEEL_L = hx("#9aa3ab"), hx("#5d6670"), hx("#cfd6dc")
WOOD, WOOD_D, WOOD_L = hx("#5e432c"), hx("#3a2a1c"), hx("#8a6240")
GOLD = hx("#d9b24a")
LEATHER, LEATHER_D = hx("#7a5236"), hx("#4e3422")
RUST, RUST_D = hx("#8a5a3a"), hx("#5a3a26")
BONE, BONE_D = hx("#dcd3ba"), hx("#a39b84")
GLOW = hx("#bff7dc")
CREAM = hx("#e6dcc0")


# --- Geometrie -------------------------------------------------------------------------------------

def ik2(p0, p1, l1, l2, sign):
    """Zwei-Knochen-IK: Gelenk (Knie, Ellbogen) und erreichbares Ende. sign: auf welcher Seite der Linie das Gelenk liegt."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    d = math.hypot(dx, dy)
    if d < 1e-6:
        dx, dy, d = 0.0, 1.0, 1.0
    ux, uy = dx / d, dy / d
    dd = max(min(d, l1 + l2 - 0.05), abs(l1 - l2) + 0.05)
    a = (l1 * l1 - l2 * l2 + dd * dd) / (2 * dd)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    px, py = -uy, ux
    joint = (p0[0] + ux * a + px * h * sign, p0[1] + uy * a + py * h * sign)
    end = (p0[0] + ux * dd, p0[1] + uy * dd)
    return joint, end


def rot_about(p, pivot, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y = p[0] - pivot[0], p[1] - pivot[1]
    return (pivot[0] + x * c - y * s, pivot[1] + x * s + y * c)


def seg_pixels(a, b, w):
    r = w / 2.0
    n = max(int(math.hypot(b[0] - a[0], b[1] - a[1]) * 2), 1)
    pix = set()
    for i in range(n + 1):
        t = i / n
        cx, cy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        for yy in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
            for xx in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
                if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r:
                    pix.add((xx, yy))
    return pix


def disc_pixels(c, r):
    return seg_pixels(c, c, r * 2)


def paint(img, pix, col, shade=True):
    """Flaeche mit Licht von links oben: Schatten rechts/unten, Licht links/oben."""
    for (x, y) in pix:
        c = col
        if shade:
            if (x + 1, y) not in pix or (x, y + 1) not in pix:
                c = sh(col, -1)
            elif (x - 1, y) not in pix or (x, y - 1) not in pix:
                c = sh(col, 1)
        img.set(x, y, c)


def flat(img, pix, col):
    for (x, y) in pix:
        img.set(x, y, col)


# --- Posen ---------------------------------------------------------------------------------------------
# Werte in Pixeln/Grad, Figur schaut nach rechts. hf/hb: Handziel relativ zur Schulter (vorderer/hinterer Arm).
# eb_*: Ellbogenseite (+1 unten/hinten, -1 oben/vorn). wa: Waffenwinkel (0 = senkrecht nach oben, + = nach vorn).
# face: n normal, a grimmig, h Schmerz, d tot, j Jubel/Ruf, s benommen.

BASE = dict(crouch=0, hipx=0, lean=3, ff=(5, 0), fb=(-5, 0), head=(0, 0), hf=(8, 4), eb_f=1, hb=(3, 10), eb_b=1, wa=14,
            face="n", breath=0, kneel=False, lying=False, draw=0, drop=False, hold=True)


def P(**kw):
    d = dict(BASE)
    d.update(kw)
    return d


COMMON = {
    "idle_0": P(),
    "idle_1": P(breath=1, hf=(8, 3), wa=13),
    "idle_2": P(breath=2, hf=(8, 3), wa=12, head=(0, -1)),
    "idle_3": P(breath=1, hf=(8, 4), wa=13),
    "ready_0": P(crouch=2, lean=7, ff=(7, 0), fb=(-7, 0), hf=(11, 1), wa=26, face="a", head=(1, 0)),
    "ready_1": P(crouch=3, lean=8, ff=(7, 0), fb=(-7, 0), hf=(11, 0), wa=28, face="a", head=(1, 0), breath=1),
    "windup_0": P(crouch=2, hipx=-1, lean=-6, ff=(6, 0), fb=(-8, 0), hf=(0, -8), eb_f=-1, wa=-30, face="a"),
    "windup_1": P(crouch=4, hipx=-2, lean=-14, ff=(7, 0), fb=(-9, 0), head=(-1, -1), hf=(-4, -17), eb_f=-1, hb=(1, 6), wa=-58, face="a"),
    "strike_0": P(crouch=6, hipx=3, lean=22, ff=(12, 0), fb=(-9, 0), head=(3, 1), hf=(17, 5), wa=98, face="a", hb=(-5, 8)),
    "strike_1": P(crouch=8, hipx=4, lean=26, ff=(13, 0), fb=(-9, 0), head=(3, 2), hf=(15, 8), wa=114, face="a", hb=(-6, 8)),
    "follow_0": P(crouch=8, hipx=5, lean=28, ff=(14, 0), fb=(-8, 0), head=(4, 3), hf=(11, 9), wa=132, face="a", hb=(-6, 10)),
    "follow_1": P(crouch=4, hipx=2, lean=14, ff=(9, 0), fb=(-6, 0), head=(2, 1), hf=(10, 9), wa=85, hb=(-1, 10)),
    "cast_0": P(crouch=1, lean=0, hf=(7, 3), wa=4, hb=(5, -5), eb_b=-1, face="j", head=(0, -1), breath=1),
    "cast_1": P(crouch=0, lean=-4, hf=(7, 3), wa=4, hb=(7, -16), eb_b=-1, face="j", head=(0, -2), breath=2),
    "cast_2": P(crouch=2, lean=8, hf=(9, 2), wa=18, hb=(15, -6), eb_b=-1, face="a", head=(1, 0)),
    "block_0": P(crouch=5, hipx=0, lean=8, ff=(7, 0), fb=(-7, 0), head=(0, 1), hf=(10, -3), wa=60, hb=(11, 4), face="a"),
    "block_1": P(crouch=6, hipx=-2, lean=2, ff=(6, 0), fb=(-8, 0), head=(-1, 1), hf=(8, -2), wa=55, hb=(8, 4), face="h"),
    "dodge": P(crouch=3, hipx=-5, lean=-18, ff=(3, 0), fb=(-9, 0), head=(-3, -1), hf=(4, 6), wa=30, hb=(0, 8), face="a"),
    "hit_0": P(crouch=3, hipx=-3, lean=-18, ff=(2, 0), fb=(-10, 0), head=(-3, -1), hf=(5, 2), wa=40, hb=(-3, 8), face="h"),
    "hit_1": P(crouch=4, hipx=-2, lean=-9, ff=(3, 0), fb=(-9, 0), head=(-2, 0), hf=(6, 5), wa=30, hb=(-1, 9), face="h"),
    "stun_0": P(crouch=2, hipx=0, lean=10, ff=(4, 0), fb=(-5, 0), head=(2, 3), hf=(4, 12), wa=165, hb=(1, 12), face="s"),
    "stun_1": P(crouch=2, hipx=1, lean=12, ff=(5, 0), fb=(-4, 0), head=(3, 3), hf=(5, 12), wa=170, hb=(2, 12), face="s", breath=1),
    "door_0": P(crouch=16, hipx=-2, lean=14, kneel=True, head=(2, 2), hf=(7, 9), wa=4, hb=(4, 11), face="h"),
    "door_1": P(crouch=16, hipx=-2, lean=16, kneel=True, head=(2, 3), hf=(7, 9), wa=4, hb=(4, 11), face="h", breath=1),
    "fall_0": P(crouch=9, hipx=-5, lean=-32, ff=(3, 0), fb=(-12, 0), head=(-3, 1), hf=(2, 7), wa=60, hb=(-4, 9), face="h"),
    "fall_1": P(crouch=17, hipx=-3, lean=-58, ff=(16, 4), fb=(9, 0), head=(-3, 2), hf=(-2, 8), wa=75, hb=(-6, 8), face="h"),
    "fall_2": P(crouch=19, hipx=4, lean=-80, ff=(27, 4), fb=(23, 1), head=(-2, 2), hf=(8, -1), wa=80, hb=(7, -1), face="d"),
    "dead": P(lying=True, face="d", drop=True, hf=(11, 0), hb=(10, -1), eb_f=1, eb_b=-1),
    "cheer_0": P(crouch=-1, lean=-4, head=(0, -1), hf=(5, -12), eb_f=-1, wa=8, face="j"),
    "cheer_1": P(crouch=-3, lean=-6, ff=(5, 3), fb=(-5, 3), head=(0, -2), hf=(5, -13), eb_f=-1, hb=(2, -11), eb_b=-1, wa=10, face="j", breath=1),
    "cheer_2": P(crouch=2, lean=-2, hf=(5, -10), eb_f=-1, wa=6, face="j"),
}

BOW = {
    # Bogen: vorderer Arm streckt sich nach vorn, hinterer zieht die Sehne
    "idle_0": P(hf=(8, 4), wa=6, hb=(3, 10)),
    "idle_1": P(breath=1, hf=(8, 3), wa=5, hb=(3, 10)),
    "idle_2": P(breath=2, hf=(8, 3), wa=4, hb=(3, 10), head=(0, -1)),
    "idle_3": P(breath=1, hf=(8, 4), wa=5, hb=(3, 10)),
    "ready_0": P(crouch=2, lean=5, ff=(7, 0), fb=(-7, 0), hf=(15, 0), wa=2, hb=(4, 8), face="a"),
    "ready_1": P(crouch=3, lean=6, ff=(7, 0), fb=(-7, 0), hf=(15, -1), wa=2, hb=(4, 8), face="a", breath=1),
    "windup_0": P(crouch=3, lean=2, ff=(7, 0), fb=(-8, 0), hf=(17, -3), wa=0, hb=(8, -1), eb_b=-1, face="a", draw=0.5),
    "windup_1": P(crouch=4, lean=-4, ff=(8, 0), fb=(-9, 0), hf=(18, -3), wa=0, hb=(2, -3), eb_b=-1, face="a", draw=1.0, head=(-1, 0)),
    "strike_0": P(crouch=4, lean=0, ff=(8, 0), fb=(-9, 0), hf=(19, -3), wa=0, hb=(0, 1), eb_b=-1, face="a", draw=0.0, head=(0, 0)),
    "strike_1": P(crouch=3, lean=2, ff=(7, 0), fb=(-8, 0), hf=(18, -2), wa=-2, hb=(1, 4), face="a", draw=0.0),
    "follow_0": P(crouch=2, lean=5, hf=(14, 2), wa=2, hb=(2, 8), draw=0.0),
    "follow_1": P(crouch=1, lean=4, hf=(10, 4), wa=4, hb=(3, 9), draw=0.0),
    "block_0": P(crouch=5, lean=10, ff=(7, 0), fb=(-7, 0), hf=(10, -5), wa=60, hb=(8, -6), face="a"),
    "block_1": P(crouch=6, lean=6, ff=(7, 0), fb=(-8, 0), hf=(9, -4), wa=60, hb=(8, -6), face="h"),
}

GUN = {
    # Muskete: zwei Haende am Gewehr
    "idle_0": P(hf=(9, 7), wa=12, hb=(7, 9)),
    "idle_1": P(breath=1, hf=(9, 6), wa=11, hb=(7, 9)),
    "idle_2": P(breath=2, hf=(9, 6), wa=10, hb=(7, 9), head=(0, -1)),
    "idle_3": P(breath=1, hf=(9, 7), wa=11, hb=(7, 9)),
    "ready_0": P(crouch=2, lean=5, ff=(7, 0), fb=(-7, 0), hf=(12, 4), wa=45, hb=(8, 6), face="a"),
    "ready_1": P(crouch=3, lean=6, ff=(7, 0), fb=(-7, 0), hf=(12, 3), wa=48, hb=(8, 6), face="a", breath=1),
    "windup_0": P(crouch=3, lean=2, ff=(7, 0), fb=(-8, 0), hf=(15, 0), wa=75, hb=(7, 2), face="a"),
    "windup_1": P(crouch=4, lean=0, ff=(8, 0), fb=(-9, 0), hf=(17, -2), wa=88, hb=(6, 0), eb_b=-1, face="a", head=(1, 0)),
    "strike_0": P(crouch=4, lean=-4, hipx=-1, ff=(8, 0), fb=(-10, 0), hf=(15, -4), wa=83, hb=(4, -2), eb_b=-1, face="a", head=(0, 0)),
    "strike_1": P(crouch=3, lean=-5, hipx=-2, ff=(8, 0), fb=(-10, 0), hf=(14, -8), wa=70, hb=(3, -3), eb_b=-1, face="a"),
    "follow_0": P(crouch=2, lean=2, hf=(11, 2), wa=50, hb=(7, 6)),
    "follow_1": P(crouch=1, lean=3, hf=(10, 5), wa=30, hb=(7, 8)),
    "block_0": P(crouch=5, lean=8, ff=(7, 0), fb=(-7, 0), hf=(10, -2), wa=60, hb=(8, 0), face="a"),
    "block_1": P(crouch=6, lean=3, ff=(7, 0), fb=(-8, 0), hf=(9, -1), wa=55, hb=(7, 0), face="h"),
}

STAFF = {
    # Stabtraeger (Skalde, Totenwart ...): Stab hoch, dann nach vorn herabgeschlagen
    "idle_0": P(hf=(8, 5), wa=3, hb=(3, 10)),
    "idle_1": P(breath=1, hf=(8, 4), wa=2, hb=(3, 10)),
    "idle_2": P(breath=2, hf=(8, 4), wa=2, hb=(3, 10), head=(0, -1)),
    "idle_3": P(breath=1, hf=(8, 5), wa=3, hb=(3, 10)),
    "ready_0": P(crouch=1, lean=5, hf=(9, 3), wa=10, hb=(4, 8), face="a"),
    "ready_1": P(crouch=2, lean=6, hf=(9, 2), wa=12, hb=(4, 8), face="a", breath=1),
    "windup_0": P(crouch=1, lean=-2, hf=(5, -7), eb_f=-1, wa=2, hb=(6, -4), eb_b=-1, face="a"),
    "windup_1": P(crouch=2, lean=-8, hipx=-1, hf=(3, -15), eb_f=-1, wa=-18, hb=(8, -12), eb_b=-1, face="a", head=(-1, -1)),
    "strike_0": P(crouch=5, hipx=2, lean=16, ff=(11, 0), fb=(-8, 0), head=(2, 1), hf=(14, 0), wa=62, hb=(8, 4), eb_b=-1, face="a"),
    "strike_1": P(crouch=6, hipx=3, lean=20, ff=(12, 0), fb=(-8, 0), head=(3, 2), hf=(14, 5), wa=82, hb=(8, 6), face="a"),
    "follow_0": P(crouch=5, hipx=3, lean=18, ff=(11, 0), fb=(-7, 0), head=(3, 2), hf=(12, 8), wa=60, hb=(5, 10), face="a"),
    "follow_1": P(crouch=2, lean=8, hf=(9, 6), wa=20, hb=(3, 10)),
    "block_0": P(crouch=4, lean=6, ff=(6, 0), fb=(-6, 0), hf=(11, -2), wa=82, hb=(9, 0), face="a"),
    "block_1": P(crouch=5, lean=2, ff=(6, 0), fb=(-7, 0), hf=(9, -2), wa=78, hb=(7, 0), face="h"),
}

CLASSES = {"melee": {}, "shield": {}, "bow": BOW, "gun": GUN, "staff": STAFF}


def pose_of(cls, name):
    t = CLASSES.get(cls, {})
    if name in t:
        return t[name]
    return COMMON[name]


FRAMES = ["idle_0", "idle_1", "idle_2", "idle_3", "ready_0", "ready_1", "windup_0", "windup_1", "strike_0", "strike_1",
          "follow_0", "follow_1", "cast_0", "cast_1", "cast_2", "block_0", "block_1", "dodge", "hit_0", "hit_1", "stun_0", "stun_1",
          "door_0", "door_1", "fall_0", "fall_1", "fall_2", "dead", "cheer_0", "cheer_1", "cheer_2"]
KEY_FRAMES = ["idle_0", "windup_1", "strike_0", "follow_0", "block_0", "hit_0", "cast_1", "door_0", "fall_1", "dead", "cheer_0"]


# --- Figurbeschreibungen -----------------------------------------------------------------------------

def spec(**kw):
    d = dict(leg=28, torso=19, wt=17, wb=14, skin=SKIN, cloth=hx("#8a3a30"), cloth2=LEATHER, pants=hx("#4a3a2f"), boots=hx("#2c2118"),
             belt=LEATHER_D, sleeve=None, cls="melee", gear="sword")
    d.update(kw)
    if d["sleeve"] is None:
        d["sleeve"] = d["cloth"]
    return d


AXT = spec(cloth=hx("#8a3a30"), hair=hx("#9a5a2a"), beard=hx("#9a5a2a"), longhair=True, gear="axe")
SCHILD = spec(wt=18, wb=15, cloth=hx("#5f6d7a"), cloth2=hx("#8a95a0"), pants=hx("#3a3a44"), belt=hx("#2c2118"), hair=hx("#5a3a22"),
              helm="nasal", mail=True, gear="sword", shield=(hx("#3e5f8f"), hx("#e0d8c0")), cls="shield")
BOGEN = spec(wt=15, wb=13, torso=18, cloth=hx("#4c6a3f"), cloth2=hx("#6f8f5a"), pants=hx("#3f3a2c"), hair=hx("#5a4a30"), helm="hood",
             hood=hx("#3d5a33"), gear="bow", cls="bow", quiver=True)
SKALDE = spec(wt=16, wb=15, cloth=hx("#35507a"), cloth2=GOLD, pants=hx("#35507a"), robe=True, belt=LEATHER, hair=hx("#bdb7a6"),
              beard=hx("#bdb7a6"), helm="circlet", gear="staff", cls="staff", cape=hx("#2a3a5a"), orb=GOLD)
MUSKETE = spec(wt=16, wb=14, cloth=hx("#7a3a36"), cloth2=hx("#d0a84a"), pants=hx("#3a342e"), belt=LEATHER_D, hair=hx("#3a2a1c"),
               beard=hx("#3a2a1c"), helm="tricorn", hood=hx("#26262c"), gear="musket", cls="gun")
ROST = spec(wt=17, wb=14, skin=hx("#7d9a86"), cloth=RUST_D, cloth2=RUST, pants=hx("#3c3a34"), belt=hx("#2c2118"), helm="rusty",
            eye_glow=True, mail=True, hunch=3, gear="rustsword")
BRECHER = spec(wt=25, wb=20, torso=21, cloth=hx("#5a2a2a"), cloth2=LEATHER, pants=hx("#26262c"), belt=LEATHER_D, hair=hx("#2a2018"),
               beard=hx("#2a2018"), helm="round", bare_arms=True, gear="club", legw=6)
TOTENWART = spec(wt=16, wb=15, cloth=hx("#27342d"), cloth2=hx("#4a6a58"), pants=hx("#27342d"), robe=True, belt=hx("#4a6a58"), skull=True,
                 eye_glow=True, helm="antler", gear="staff", cls="staff", orb=GLOW)

PROTOS = {"axt": AXT, "schild": SCHILD, "bogen": BOGEN, "skalde": SKALDE, "muskete": MUSKETE, "rost": ROST, "brecher": BRECHER,
          "totenwart": TOTENWART}


# --- Zeichnen ------------------------------------------------------------------------------------------

def draw_head(spec_, cx, cy, face, rot=0):
    """Kopf 12x12 auf eigenem Bild (damit er fuer die Liegepose verlustfrei um 90 Grad gedreht werden kann)."""
    img = Img(24, 24)
    skin = spec_["skin"]
    sd = sh(skin, -2)
    x0, y0 = 6, 8
    skull = spec_.get("skull")
    if skull:
        skin, sd = BONE, BONE_D
    img.rect(x0 + 1, y0, x0 + 10, y0 + 11, skin)
    img.rect(x0, y0 + 1, x0 + 11, y0 + 10, skin)
    img.rect(x0 + 10, y0 + 2, x0 + 11, y0 + 10, sh(skin, -1))
    img.rect(x0 + 1, y0 + 11, x0 + 10, y0 + 11, sd)
    img.rect(x0, y0 + 2, x0, y0 + 9, sh(skin, 1))
    if not skull:
        img.rect(x0 + 12, y0 + 5, x0 + 12, y0 + 6, sh(skin, -1))  # Nase
    eye = hx("#14110f")
    glow = spec_.get("eye_glow")
    ec = GLOW if glow else eye
    hair = spec_.get("hair")
    brow = sh(hair, -1) if (hair is not None and not glow and not skull) else sd
    if skull:
        img.rect(x0 + 3, y0 + 4, x0 + 5, y0 + 7, OUT)
        img.rect(x0 + 7, y0 + 4, x0 + 9, y0 + 7, OUT)
        if face != "d":
            img.set(x0 + 4, y0 + 5, ec)
            img.set(x0 + 8, y0 + 5, ec)
        for tx in range(x0 + 4, x0 + 10, 2):
            img.rect(tx, y0 + 9, tx, y0 + 11, OUT)
    elif face in ("n", "a", "j", "s"):
        for ex in (x0 + 5, x0 + 9):
            if face == "s":
                img.set(ex - 1, y0 + 5, eye)
                img.set(ex + 1, y0 + 5, eye)
                img.set(ex, y0 + 6, eye)
                img.set(ex, y0 + 4, eye)
            else:
                img.rect(ex, y0 + 5, ex, y0 + 6, ec)
        if face == "a":
            img.rect(x0 + 4, y0 + 4, x0 + 6, y0 + 4, brow)
            img.rect(x0 + 8, y0 + 3, x0 + 10, y0 + 4, brow)
        elif face != "s":
            img.rect(x0 + 4, y0 + 3, x0 + 6, y0 + 3, brow)
            img.rect(x0 + 8, y0 + 3, x0 + 10, y0 + 3, brow)
        if face in ("j", "s"):
            img.rect(x0 + 6, y0 + 9, x0 + 10, y0 + 9, hx("#3a1a1a"))
            img.rect(x0 + 7, y0 + 10, x0 + 9, y0 + 10, hx("#3a1a1a"))
    elif face == "h":
        for ex in (x0 + 5, x0 + 9):
            img.rect(ex - 1, y0 + 5, ex + 1, y0 + 5, eye)
        img.rect(x0 + 6, y0 + 9, x0 + 9, y0 + 9, hx("#4a1818"))
    elif face == "d":
        for ex in (x0 + 5, x0 + 9):
            img.set(ex - 1, y0 + 4, eye)
            img.set(ex, y0 + 5, eye)
            img.set(ex + 1, y0 + 6, eye)
            img.set(ex + 1, y0 + 4, eye)
            img.set(ex - 1, y0 + 6, eye)
    if face in ("n", "a") and not spec_.get("beard") and not skull:
        img.rect(x0 + 8, y0 + 9, x0 + 10, y0 + 9, sd)
    helm = spec_.get("helm")
    if hair is not None and helm is None and not skull:
        img.rect(x0, y0 - 1, x0 + 11, y0 + 2, hair)
        img.rect(x0 + 1, y0 - 2, x0 + 9, y0 - 2, hair)
        img.rect(x0 - 1, y0, x0 + 1, y0 + 7, hair)
        img.rect(x0, y0 - 1, x0 + 11, y0 - 1, sh(hair, 1))
        if spec_.get("longhair"):
            img.rect(x0 - 3, y0 + 2, x0 + 1, y0 + 14, hair)
            img.rect(x0 - 3, y0 + 2, x0 - 3, y0 + 14, sh(hair, -1))
    beard = spec_.get("beard")
    if beard is not None and not skull:
        img.rect(x0 + 3, y0 + 8, x0 + 11, y0 + 12, beard)
        img.rect(x0 + 4, y0 + 13, x0 + 9, y0 + 14, sh(beard, -1))
        img.rect(x0 + 7, y0 + 7, x0 + 11, y0 + 7, beard)
        img.rect(x0 + 3, y0 + 8, x0 + 3, y0 + 12, sh(beard, 1))
    if helm in ("nasal", "rusty", "round"):
        c = STEEL if helm in ("nasal", "round") else RUST
        img.rect(x0, y0 - 2, x0 + 11, y0 + 3, c)
        img.rect(x0 + 1, y0 - 3, x0 + 10, y0 - 3, sh(c, 1))
        img.rect(x0 - 1, y0 + 1, x0, y0 + 7, sh(c, -1))
        img.rect(x0, y0 + 3, x0 + 11, y0 + 3, sh(c, -1))
        img.rect(x0, y0 - 2, x0 + 11, y0 - 2, sh(c, 1))
        if helm == "nasal":
            img.rect(x0 + 10, y0 + 3, x0 + 11, y0 + 8, c)
            img.rect(x0 + 11, y0 + 3, x0 + 11, y0 + 8, sh(c, -1))
        if helm == "round":
            img.rect(x0 - 1, y0 + 3, x0 + 12, y0 + 3, sh(c, -1))
    elif helm == "hood":
        c = spec_.get("hood", hx("#3b4a3a"))
        img.rect(x0 - 1, y0 - 2, x0 + 11, y0 + 3, c)
        img.rect(x0 - 3, y0 - 1, x0 + 1, y0 + 12, c)
        img.rect(x0 + 2, y0 - 3, x0 + 8, y0 - 3, c)
        img.rect(x0 - 1, y0 - 2, x0 - 1, y0 + 11, sh(c, 1))
    elif helm == "circlet":
        img.rect(x0, y0 + 1, x0 + 11, y0 + 2, GOLD)
        img.rect(x0 + 4, y0 - 1, x0 + 7, y0, GOLD)
    elif helm == "tricorn":
        c = spec_.get("hood", hx("#26262c"))
        img.rect(x0 - 4, y0 + 1, x0 + 15, y0 + 3, c)
        img.rect(x0 - 1, y0 - 4, x0 + 12, y0 + 1, c)
        img.rect(x0 - 4, y0 + 1, x0 + 15, y0 + 1, GOLD)
        img.rect(x0 + 6, y0 - 7, x0 + 11, y0 - 4, hx("#d9d2c0"))
        img.rect(x0 - 1, y0 - 4, x0 - 1, y0 + 1, sh(c, 1))
    elif helm == "antler":
        img.rect(x0, y0 - 1, x0 + 11, y0 + 1, hx("#26302a"))
        for ax_, sg in ((x0 - 1, -1), (x0 + 12, 1)):
            img.rect(ax_, y0 - 8, ax_ + 1, y0 - 1, BONE)
            img.rect(ax_ + sg * 2, y0 - 6, ax_ + sg * 3, y0 - 5, BONE)
            img.rect(ax_ + sg * 2, y0 - 10, ax_ + sg * 2, y0 - 7, BONE)
    img.rect(x0 + 3, y0 + 12, x0 + 7, y0 + 13, sd)  # Hals
    return img


def blit_rot(dst, src, cx, cy, rot):
    """src (24x24, Kopfmitte bei (12,14)) um rot*90 Grad verlustfrei drehen und mit Kopfmitte auf (cx, cy) setzen."""
    ox, oy = 12, 14
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y][x]
            if c is None:
                continue
            rx, ry = x - ox, y - oy
            for _ in range(rot % 4):
                rx, ry = -ry, rx  # 90 Grad im Uhrzeigersinn (y nach unten)
            dst.set(int(round(cx)) + rx, int(round(cy)) + ry, c)


def draw_shield(img, c, r, col1, col2):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 > r * r + 1:
                continue
            c0 = sh(col1, -2) if d2 > (r - 1) * (r - 1) else col1
            if d2 <= (r - 1) * (r - 1) and ((dx > 0) == (dy > 0)) and abs(dx) > 1 and abs(dy) > 1:
                c0 = col2
            if dx + dy < -r // 2 and d2 <= (r - 1) * (r - 1):
                c0 = sh(c0, 1)
            img.set(int(c[0]) + dx, int(c[1]) + dy, c0)
    img.rect(int(c[0]) - 1, int(c[1]) - 1, int(c[0]) + 1, int(c[1]) + 1, STEEL)
    img.set(int(c[0]) - 1, int(c[1]) - 1, STEEL_L)


def draw_weapon(img, sp, hf, hb, wa, P_, dropped_at=None):
    g = sp["gear"]
    if dropped_at is not None:
        hf = dropped_at
        wa = 90 if g not in ("bow", "musket") else 88

    def T(p):
        return rot_about((hf[0] + p[0], hf[1] + p[1]), hf, wa)

    if g == "axe":
        paint(img, seg_pixels(T((0, 9)), T((0, -25)), 2.4), WOOD)
        head = [T((1, -26)), T((11, -30)), T((13, -23)), T((11, -15)), T((1, -19))]
        paint(img, poly_pixels(head), STEEL)
        flat(img, seg_pixels(T((12, -28)), T((12.5, -16)), 1.2), STEEL_L)
        flat(img, seg_pixels(T((2, -25)), T((10, -28)), 1.0), STEEL_L)
        flat(img, seg_pixels(T((1, -20)), T((9, -17)), 1.0), STEEL_D)
    elif g in ("sword", "rustsword"):
        bl = STEEL_L if g == "sword" else RUST
        bd = STEEL if g == "sword" else RUST_D
        ln = 24 if g == "sword" else 19
        paint(img, seg_pixels(T((0, -4)), T((0, -ln)), 3.0), bd)
        flat(img, seg_pixels(T((-0.6, -6)), T((-0.6, -ln + 2)), 1.0), bl)
        flat(img, seg_pixels(T((-4, -4)), T((4, -4)), 2.0), GOLD if g == "sword" else RUST_D)
        flat(img, seg_pixels(T((0, 0)), T((0, -3)), 2.0), LEATHER_D)
        flat(img, disc_pixels(T((0, 2)), 1.5), GOLD if g == "sword" else RUST)
    elif g == "club":
        paint(img, seg_pixels(T((0, 9)), T((0, -20)), 3.4), WOOD)
        paint(img, seg_pixels(T((0, -14)), T((0, -27)), 8.0), WOOD_L)
        flat(img, disc_pixels(T((-2, -22)), 0.7), STEEL_D)
        flat(img, disc_pixels(T((2, -18)), 0.7), STEEL_D)
    elif g == "staff":
        paint(img, seg_pixels(T((0, 12)), T((0, -30)), 2.6), WOOD)
        orb = sp.get("orb", GOLD)
        paint(img, disc_pixels(T((0, -33)), 3.6), orb)
        flat(img, disc_pixels(T((-1, -34)), 0.8), sh(orb, 2))
    elif g == "bow":
        pts = [T((0, -19)), T((4, -10)), T((6, 0)), T((4, 10)), T((0, 19))]
        for a, b in zip(pts, pts[1:]):
            paint(img, seg_pixels(a, b, 2.2), WOOD_L)
        s0, s1 = pts[0], pts[-1]
        draw = P_.get("draw", 0.0)
        if draw > 0:
            nock = (hb[0] * draw + (s0[0] + s1[0]) / 2 * (1 - draw), hb[1] * draw + (s0[1] + s1[1]) / 2 * (1 - draw))
            flat(img, seg_pixels(s0, nock, 1.0), CREAM)
            flat(img, seg_pixels(nock, s1, 1.0), CREAM)
            # Pfeil: von der Sehne ueber die Faust nach vorn
            dx, dy = hf[0] - nock[0], hf[1] - nock[1]
            ln = math.hypot(dx, dy) or 1.0
            tip = (hf[0] + dx / ln * 9, hf[1] + dy / ln * 9)
            flat(img, seg_pixels(nock, tip, 1.0), hx("#c8c0a8"))
            flat(img, seg_pixels((tip[0] - dx / ln * 3, tip[1] - dy / ln * 3), tip, 2.0), STEEL_L)
        else:
            flat(img, seg_pixels(s0, s1, 1.0), CREAM)
    elif g == "musket":
        # Achse von der hinteren zur vorderen Hand
        dx, dy = hf[0] - hb[0], hf[1] - hb[1]
        ln = math.hypot(dx, dy) or 1.0
        ux, uy = dx / ln, dy / ln
        # Waffenwinkel wa bestimmt die Achse, wenn die Haende nahe beieinander liegen
        a = math.radians(wa)
        ux, uy = math.sin(a), -math.cos(a)
        butt = (hb[0] - ux * 7, hb[1] - uy * 7)
        muz = (hf[0] + ux * 17, hf[1] + uy * 17)
        paint(img, seg_pixels(butt, (hb[0] + ux * 2, hb[1] + uy * 2), 5.4), WOOD)
        paint(img, seg_pixels((hb[0] + ux * 2, hb[1] + uy * 2), (hf[0] + ux * 3, hf[1] + uy * 3), 3.8), WOOD_L)
        flat(img, seg_pixels((hf[0] - ux * 2, hf[1] - uy * 2), muz, 2.6), STEEL_D)
        flat(img, seg_pixels((hf[0] + ux * 3, hf[1] + uy * 3), muz, 1.0), STEEL)


def person(sp, pname, joints=None):
    """Zeichnet eine Figur in einer Pose. joints (optional, ein dict) bekommt die Ankerpunkte der Pose: hand, hand_b, head, hip, top, tip."""
    P_ = pose_of(sp["cls"], pname)
    img = Img(CW, CH)
    L, T_ = sp["leg"], sp["torso"]
    robe = sp.get("robe", False)
    lying = P_["lying"]
    kneel = P_["kneel"]
    if lying:
        hip = (AX + 4, GY - 11)
        lean = -90
    else:
        hip = (AX + P_["hipx"], GY - L + P_["crouch"])
        lean = P_["lean"] + sp.get("hunch", 0)
    up = (math.sin(math.radians(lean)), -math.cos(math.radians(lean)))
    right = (math.cos(math.radians(lean)), math.sin(math.radians(lean)))
    bob = -P_["breath"]
    top = (hip[0] + up[0] * T_, hip[1] + up[1] * T_ + (bob if not lying else 0))
    wt, wb = sp["wt"], sp["wb"]
    tl, tr = (top[0] - right[0] * wt / 2, top[1] - right[1] * wt / 2), (top[0] + right[0] * wt / 2, top[1] + right[1] * wt / 2)
    bl, br = (hip[0] - right[0] * wb / 2, hip[1] - right[1] * wb / 2 + 1), (hip[0] + right[0] * wb / 2, hip[1] + right[1] * wb / 2 + 1)
    arm = 9.5 if sp["wt"] < 22 else 11.0
    sh_f = (top[0] + right[0] * (wt / 2 - 3) - up[0] * 2, top[1] + right[1] * (wt / 2 - 3) - up[1] * 2)
    sh_b = (top[0] - right[0] * (wt / 2 - 3) - up[0] * 2, top[1] - right[1] * (wt / 2 - 3) - up[1] * 2)
    pants, boots, sleeve, skin = sp["pants"], sp["boots"], sp["sleeve"], sp["skin"]
    if sp.get("bare_arms"):
        sleeve = skin
    aw = 5.0 if sp["wt"] >= 22 else 4.0  # Armdicke

    # fallengelassene Waffe liegt unter dem Koerper auf dem Deck
    if P_["drop"]:
        draw_weapon(img, sp, (AX + 14, GY - 3), (AX + 10, GY - 3), 90, P_, (AX + 14, GY - 3))

    # hinterer Arm
    hb_t = (sh_b[0] + P_["hb"][0], sh_b[1] + P_["hb"][1])
    eb, hb_end = ik2(sh_b, hb_t, arm, arm, P_["eb_b"])
    paint(img, seg_pixels(sh_b, eb, aw), sh(sleeve, -1))
    paint(img, seg_pixels(eb, hb_end, aw - 0.4), sh(sleeve, -1))
    flat(img, disc_pixels(hb_end, 2.0), sh(skin, -1))

    # Beine
    legw = sp.get("legw", 5)
    for side in (-1, 1):
        hp = (hip[0] + side * 2.5, hip[1] + 1)
        if lying:
            ft = (hip[0] + 25 + (2 if side > 0 else 0), GY - 3 - (2 if side > 0 else 0))
            kn, ft_end = ik2(hp, ft, L / 2 - 0.8, L / 2 - 0.8, 1)
        elif kneel and side < 0:
            kn = (hip[0] + 1, GY - 3)
            ft_end = (hip[0] - 11, GY - 3)
        else:
            fx, fl = P_["ff"] if side > 0 else P_["fb"]
            ft = (AX + fx, GY - fl - 2)
            kn, ft_end = ik2(hp, ft, L / 2 - 0.8, L / 2 - 0.8, -1)
        col = sh(pants, -1) if side < 0 else pants
        bx0, by0 = int(round(ft_end[0])) - 2, int(round(ft_end[1]))
        boot_c = sh(boots, -1) if side < 0 else boots
        if not robe:
            paint(img, seg_pixels(hp, kn, legw), col)
            paint(img, seg_pixels(kn, ft_end, legw - 0.6), col)
            img.rect(bx0 - 1, by0 - 3, bx0 + 3, by0 + 1, boot_c)
            img.rect(bx0 + 3, by0 - 1, bx0 + 6, by0 + 1, boot_c)
            img.rect(bx0 - 1, by0 - 3, bx0 - 1, by0 + 1, sh(boot_c, 1))
        else:
            img.rect(bx0 + 2, by0 - 1, bx0 + 6, by0 + 1, sh(boots, -1 if side < 0 else 0))

    # Koecher hinter dem Koerper
    if sp.get("quiver"):
        qa = (tl[0] - 1, tl[1] - 2)
        qb = (bl[0] - 3, hip[1] - 2)
        paint(img, seg_pixels(qa, qb, 4.0), LEATHER_D)
        for k in range(3):
            flat(img, seg_pixels((qa[0] - 1 + k * 1.5, qa[1] - 5 + (k % 2)), (qa[0] - 1 + k * 1.5, qa[1] + 1), 1.0), CREAM)

    # Rumpf
    if robe:
        hem_l = (bl[0] - 3, GY - 1)
        hem_r = (br[0] + 4, GY - 1)
        pix = poly_pixels([tl, tr, br, hem_r, hem_l, bl])
        if lying:
            pix = poly_pixels([tl, tr, br, bl])
    else:
        pix = poly_pixels([tl, tr, br, bl])
    paint(img, pix, sp["cloth"])
    c2 = sp.get("cloth2")
    if robe:
        for (x, y) in list(pix):
            if y >= GY - 3 and (x + y) % 2 == 0:
                img.set(x, y, sh(sp["cloth"], -2))
        if c2 is not None:
            flat(img, seg_pixels((top[0], top[1] + 2), (hip[0], hip[1] + 6), 2.2), c2)
        flat(img, seg_pixels((bl[0], hip[1] - 2), (br[0], hip[1] - 2), 2), sp["belt"])
    else:
        belt = seg_pixels((bl[0] - 0.5, bl[1] - 2), (br[0] + 0.5, br[1] - 2), 2.6)
        flat(img, belt, sp["belt"])
        bx, by = int((bl[0] + br[0]) / 2) + 1, int((bl[1] + br[1]) / 2) - 3
        img.rect(bx - 1, by, bx + 1, by + 2, GOLD)
        if sp.get("mail"):
            for (x, y) in pix:
                if (x + y) % 2 == 0 and (x + 1, y) in pix and (x, y + 1) in pix and (x - 1, y) in pix and y < hip[1] - 4:
                    img.set(x, y, sh(sp["cloth"], 1))
            if c2 is not None:
                flat(img, seg_pixels((top[0] - 4, top[1] + 1), (top[0] + 4, top[1] + 1), 2.4), c2)
        elif c2 is not None:
            flat(img, seg_pixels((top[0] - 3, top[1] + 1), (top[0] + 3, top[1] + 1), 2.4), c2)
            if sp["cls"] == "gun":
                flat(img, seg_pixels((top[0], top[1] + 2), (hip[0], hip[1] - 3), 1.6), c2)
    if sp.get("cape") and not lying:
        cp = poly_pixels([(tl[0] - 1, tl[1] + 1), (tl[0] - 6, hip[1] + 15), (bl[0] - 1, hip[1] + 15), (bl[0] + 1, hip[1])])
        paint(img, cp, sp["cape"])

    # Kopf
    hd = (top[0] + up[0] * 7 + P_["head"][0] + (1 if lean > 0 else 0) * lean * 0.12, top[1] + up[1] * 7 + P_["head"][1] - 1)
    head_img = draw_head(sp, 0, 0, P_["face"])
    blit_rot(img, head_img, hd[0] + 1 + (0 if not lying else -1), hd[1] + 1, 3 if lying else 0)

    # Schild am hinteren Arm
    if sp.get("shield"):
        sc = (hb_end[0] + 4, hb_end[1] - 2)
        if P_["hb"][0] >= 9:
            sc = (hb_end[0] + 3, hb_end[1] + 1)
        draw_shield(img, sc, 8, sp["shield"][0], sp["shield"][1])

    # vorderer Arm und Waffe
    hf_t = (sh_f[0] + P_["hf"][0], sh_f[1] + P_["hf"][1])
    el, hf_end = ik2(sh_f, hf_t, arm, arm, P_["eb_f"])
    if not P_["drop"]:
        draw_weapon(img, sp, hf_end, hb_end, P_["wa"], P_, None)
    paint(img, seg_pixels(sh_f, el, aw + 0.4), sleeve)
    paint(img, seg_pixels(el, hf_end, aw), sleeve)
    flat(img, disc_pixels(hf_end, 2.1), skin)
    flat(img, disc_pixels(sh_f, 2.6), sh(sleeve, 1))
    if sp["cls"] == "gun":  # hintere Hand am Abzug sichtbar
        flat(img, disc_pixels(hb_end, 2.1), skin)

    if joints is not None:
        # Ankerpunkte als Nebenprodukt des Rigs: in Zellkoordinaten; WAFFENLAENGE ueber der Hand in Richtung des Waffenwinkels
        ln = WEAPON_LEN.get(sp["gear"], 0)
        a = math.radians(P_["wa"])
        joints.update(hand=hf_end, hand_b=hb_end, head=hd, hip=hip, top=top,
                      tip=(hf_end[0] + math.sin(a) * ln, hf_end[1] - math.cos(a) * ln))

    img.outline(OUT)
    return img


WEAPON_LEN = {"axe": 30, "sword": 24, "rustsword": 19, "club": 27, "staff": 33, "bow": 0, "musket": 17}


def anchors(names, frames):
    """Ankertabelle fuer die Anzeige: je Figur und Frame Hand, Waffenspitze, Brust, Kopf relativ zur Fussmitte (x nach vorn, y nach oben)."""
    out = {}
    for nm in names:
        out[nm] = {}
        for fr in frames:
            j = {}
            person(PROTOS[nm], fr, j)

            def rel(p):
                return [round(p[0] - AX, 1), round(GY - 1 - p[1], 1)]
            chest = ((j["hip"][0] + j["top"][0]) / 2.0, (j["hip"][1] + j["top"][1]) / 2.0)
            out[nm][fr] = {"hand": rel(j["hand"]), "tip": rel(j["tip"]), "chest": rel(chest), "head": rel(j["head"])}
    return out


def mirror(img):
    out = Img(img.w, img.h)
    for y in range(img.h):
        out.px[y] = list(reversed(img.px[y]))
    return out


# --- Ausgabe -----------------------------------------------------------------------------------------------

def bbox(img):
    xs = [x for y in range(img.h) for x in range(img.w) if img.px[y][x] is not None]
    ys = [y for y in range(img.h) for x in range(img.w) if img.px[y][x] is not None]
    return (min(xs), min(ys), max(xs), max(ys))


FONT = {
    "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
    "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
    "K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
    "P": "110101110100100", "Q": "010101101111011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
    "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
    "4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010100100", "8": "111101111101111",
    "9": "111101111001110", " ": "000000000000000", "-": "000000111000000", ":": "000010000010000", ".": "000000000000010",
    "_": "000000000000111",
}


def text(img, x, y, s, c, k=2):
    for ch in s.upper():
        g = FONT.get(ch, FONT[" "])
        for i, b in enumerate(g):
            if b == "1":
                gx, gy = i % 3, i // 3
                img.rect(x + gx * k, y + gy * k, x + gx * k + k - 1, y + gy * k + k - 1, c)
        x += 4 * k


def sheet(names, frames, outpath, scale=2, bg=hx("#2a3340"), cols=None, labels=True):
    pad = 3
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    cw, ch = CW * scale, CH * scale
    head = 14 if labels else 0
    out = Img(cols * (cw + pad) + pad, len(names) * rows * (ch + pad + head) + pad)
    out.rect(0, 0, out.w - 1, out.h - 1, bg)
    for r, nm in enumerate(names):
        sp = PROTOS[nm]
        for i, fr in enumerate(frames):
            c, rr = i % cols, i // cols
            cell = person(sp, fr).filled_bg(hx("#323d4c")).scaled(scale)
            x0 = pad + c * (cw + pad)
            y0 = pad + (r * rows + rr) * (ch + pad + head) + head
            out.blit(cell, x0, y0)
            out.rect(x0, y0 + (GY + 1) * scale, x0 + cw - 1, y0 + (GY + 1) * scale, hx("#5a2a2a"))
            out.rect(x0 + AX * scale, y0, x0 + AX * scale, y0 + 3, hx("#d9b24a"))
            if labels:
                lab = fr if (i > 0 or rr > 0) else nm + "  " + fr
                text(out, x0 + 2, y0 - head + 3, lab if i > 0 or rr > 0 else fr, hx("#c9d3dd"), 1)
                if i == 0 and rr == 0:
                    text(out, x0 + 4, y0 + 4, nm, hx("#d9b24a"), 2)
    out.save(outpath)

def atlas(names, outpath):
    at = Img(CW * len(FRAMES), CH * len(names))
    for r, nm in enumerate(names):
        for c, fr in enumerate(FRAMES):
            at.blit(person(PROTOS[nm], fr), c * CW, r * CH)
    at.save(outpath)


def stats(names):
    mx = [999, 999, -1, -1]
    worst = {}
    for nm in names:
        for fr in FRAMES:
            bb = bbox(person(PROTOS[nm], fr))
            mx = [min(mx[0], bb[0]), min(mx[1], bb[1]), max(mx[2], bb[2]), max(mx[3], bb[3])]
            clip = bb[0] <= 0 or bb[1] <= 0 or bb[2] >= CW - 1 or bb[3] >= CH - 1
            if clip:
                worst[(nm, fr)] = bb
    return mx, worst


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(outdir, exist_ok=True)
    mode = sys.argv[2] if len(sys.argv) > 2 else "sheets"
    if mode == "stats":
        mx, worst = stats(list(PROTOS))
        print("bbox min/max", mx, "Anker", AX, GY, " links", AX - mx[0], "rechts", mx[2] - AX, "oben", GY - mx[1])
        for k, v in worst.items():
            print("CLIP", k, v)
    elif mode == "anchors":
        import json
        tab = anchors(list(PROTOS), FRAMES)
        with open(os.path.join(outdir, "rig_anker.json"), "w", encoding="utf-8") as fh:
            json.dump(tab, fh, indent=0)
        for nm in PROTOS:
            print(nm, {fr: tab[nm][fr] for fr in ("idle_1", "windup_1", "strike_0")})
    elif mode == "atlas":
        atlas(list(PROTOS), os.path.join(outdir, "rig_proto.png"))
        print("atlas", CW * len(FRAMES), CH * len(PROTOS))
    elif mode.startswith("key:"):
        # Kernposen je Figur: key:name1,name2 [Ausgabedatei]
        names = mode[4:].split(",")
        fname = sys.argv[3] if len(sys.argv) > 3 else "key.png"
        sheet(names, KEY_FRAMES, os.path.join(outdir, fname), cols=len(KEY_FRAMES))
        print("ok", fname)
    else:
        names = mode.split(",") if mode != "sheets" else ["axt", "schild"]
        sheet(names, FRAMES[:16], os.path.join(outdir, "v2_a.png"), cols=8)
        sheet(names, FRAMES[16:], os.path.join(outdir, "v2_b.png"), cols=8)
        print("ok")


