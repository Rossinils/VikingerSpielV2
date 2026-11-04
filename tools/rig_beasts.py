"""Hund und Fangarm fuer den Rig (tools/rig_core.py): Figuren ohne Menschenkoerper, gleiche Zelle, gleicher Anker.
Der Hund ist ein Vierbeiner aus Kapseln mit IK-Beinen, der Fangarm eine Kette von Segmenten mit Saugnaepfen.
Beide kennen nur die Posen, die sie brauchen; fehlende Namen loest die Anzeige ueber ihre Rueckfalltabelle auf."""
import math

from rig_core import (AX, GY, CW, CH, OUT, Img, hx, sh, poly_pixels, seg_pixels, disc_pixels, paint, flat, ik2, BONE)

# ---------------------------------------------------------------- Hund
FUR, FUR_D, FUR_L = hx("#7a5a3e"), hx("#4f3a26"), hx("#9a7a56")
MUZZLE = hx("#b08d62")
NOSE = hx("#171210")
TONGUE = hx("#c8505a")
EAR = hx("#46301f")

D0 = dict(dy=0, hp=(0, 0), sh=(0, 0), neck=(9, -8), hpitch=10, jaw=0, tail=50, wag=0, ear=0.0,
          ff=(8, 0), fb=(5, 0), bf=(-10, 0), bb=(-14, 0), eye="n", tongue=False, lying=0)


def DP(**kw):
    d = dict(D0)
    d.update(kw)
    return d


DOG = {
    "idle_0": DP(),
    "idle_1": DP(dy=-1, wag=18, neck=(9, -9)),
    "idle_2": DP(dy=-1, wag=-12, neck=(9, -9), hpitch=12),
    "idle_3": DP(dy=0, wag=14),
    "ready_0": DP(sh=(0, 3), hp=(0, -1), neck=(10, -4), hpitch=-8, jaw=14, tail=20, ear=0.6, ff=(10, 0), fb=(7, 0)),
    "ready_1": DP(sh=(0, 3), hp=(0, -1), neck=(10, -4), hpitch=-10, jaw=20, tail=24, ear=0.7, ff=(10, 0), fb=(7, 0), dy=1),
    "windup_0": DP(dy=3, sh=(0, 2), hp=(-1, 1), neck=(8, -5), hpitch=4, jaw=6, tail=60, bf=(-11, 0), bb=(-8, 0)),
    "windup_1": DP(dy=4, sh=(-1, 3), hp=(-3, 2), neck=(7, -4), hpitch=14, jaw=24, tail=75, ear=0.3, bf=(-11, 0), bb=(-8, 0), ff=(7, 0), fb=(4, 0)),
    "strike_0": DP(dy=-8, sh=(2, -1), hp=(-2, 0), neck=(10, -3), hpitch=-4, jaw=40, tail=4, ear=0.8, ff=(20, 7), fb=(16, 4), bf=(-21, 6), bb=(-17, 3)),
    "strike_1": DP(dy=-5, sh=(3, 0), hp=(-1, 1), neck=(12, -2), hpitch=-14, jaw=6, tail=10, ear=0.8, ff=(18, 5), fb=(14, 3), bf=(-17, 4), bb=(-13, 2)),
    "follow_0": DP(dy=1, sh=(1, 2), neck=(11, -4), hpitch=-6, jaw=12, tail=30, ear=0.5, ff=(12, 0), fb=(9, 0)),
    "follow_1": DP(dy=0, sh=(0, 1), neck=(11, -6), hpitch=16, jaw=4, tail=38, ear=0.2, ff=(9, 0), fb=(6, 0)),
    "hit_0": DP(dy=0, sh=(-4, -1), hp=(-3, 0), neck=(7, -9), hpitch=38, jaw=28, tongue=True, tail=-18, ear=1.0, eye="h", ff=(4, 0), fb=(1, 0), bf=(-12, 0), bb=(-16, 0)),
    "hit_1": DP(dy=0, sh=(-2, 0), hp=(-2, 0), neck=(8, -8), hpitch=20, jaw=10, tail=-8, ear=0.8, eye="h", ff=(6, 0), fb=(3, 0)),
    "stun_0": DP(dy=1, sh=(1, 2), neck=(9, -3), hpitch=-28, jaw=6, tongue=True, tail=10, ear=0.9, eye="s", ff=(11, 0), fb=(7, 0), bf=(-12, 0), bb=(-16, 0)),
    "stun_1": DP(dy=1, sh=(0, 2), neck=(10, -2), hpitch=-32, jaw=8, tongue=True, tail=12, ear=0.9, eye="s", ff=(10, 0), fb=(6, 0), bf=(-13, 0), bb=(-17, 0)),
    "dodge": DP(dy=-2, sh=(-4, -5), hp=(-4, -1), neck=(8, -9), hpitch=24, jaw=4, tail=70, ear=0.5, ff=(3, 7), fb=(0, 5), bf=(-14, 2), bb=(-17, 1)),
    "fall_0": DP(dy=5, sh=(-1, 3), hp=(-1, 2), neck=(8, -3), hpitch=-8, jaw=10, tail=-10, ear=1.0, eye="h", ff=(8, 0), fb=(4, 0)),
    "fall_1": DP(dy=7, sh=(-1, 5), hp=(0, 3), neck=(9, -1), hpitch=-14, jaw=14, tongue=True, tail=-25, ear=1.0, eye="d", ff=(12, 0), fb=(8, 0), bf=(-14, 0), bb=(-18, 0)),
    "fall_2": DP(lying=1, eye="d", tongue=True, jaw=12, ear=1.0, tail=-30),
    "dead": DP(lying=2, eye="d", tongue=True, jaw=14, ear=1.0, tail=-40),
}


def dog(sp, pname, joints=None):
    P_ = DOG[pname]
    img = Img(CW, CH)
    lying = P_["lying"]
    dy = P_["dy"]
    if lying:
        hp_ = (AX - 11, GY - 6)
        sh_ = (AX + 8, GY - 6)
        head_c = (AX + 18, GY - 5)
        hp_ang = -6 if lying == 1 else 0
    else:
        hp_ = (AX - 11 + P_["hp"][0], GY - 18 + dy + P_["hp"][1])
        sh_ = (AX + 9 + P_["sh"][0], GY - 18 + dy + P_["sh"][1])
        head_c = (sh_[0] + P_["neck"][0], sh_[1] + P_["neck"][1])
        hp_ang = P_["hpitch"]
    # Beine (hinten zuerst, die fernen dunkler)
    legs = []
    if lying:
        legs = [((hp_[0] + 2, hp_[1] + 2), (hp_[0] + 14, hp_[1] + 3), FUR_D, 1), ((sh_[0], sh_[1] + 2), (sh_[0] + 13, sh_[1] + 3), FUR_D, 1),
                ((hp_[0] + 1, hp_[1] + 3), (hp_[0] + 12, hp_[1] + 5), FUR, 1), ((sh_[0] - 1, sh_[1] + 3), (sh_[0] + 12, sh_[1] + 5), FUR, 1)]
    else:
        spec_legs = [((hp_[0] + 1, hp_[1] + 3), P_["bf"], FUR_D, -1), ((sh_[0] - 1, sh_[1] + 3), P_["ff"], FUR_D, 1),
                     ((hp_[0] + 3, hp_[1] + 3), P_["bb"], FUR, -1), ((sh_[0] + 2, sh_[1] + 3), P_["fb"], FUR, 1)]
        for (root, (fx, fl), col, sg) in spec_legs:
            tgt = (AX + fx, GY - fl - 1)
            if root[0] < AX - 4 and fx > -3 and False:
                pass
            legs.append((root, tgt, col, sg))
    for (root, tgt, col, sg) in legs:
        if lying:
            paint(img, seg_pixels(root, tgt, 3.0), col)
            flat(img, disc_pixels(tgt, 1.8), sh(col, 1))
        else:
            kn, foot = ik2(root, tgt, 6.2, 6.4, sg)
            if kn[1] > GY - 3:
                kn = (kn[0], GY - 3)
            paint(img, seg_pixels(root, kn, 3.6), col)
            paint(img, seg_pixels(kn, foot, 3.0), col)
            fx0, fy0 = int(round(foot[0])), int(round(foot[1]))
            img.rect(fx0 - 1, fy0 - 1, fx0 + 3, fy0 + 1, sh(col, 1))
    # Schwanz
    tail_a = math.radians(P_["tail"] + P_["wag"])
    t0 = (hp_[0] - 5, hp_[1] - 3)
    dxn, dyn = -math.cos(tail_a), -math.sin(tail_a)
    t1 = (t0[0] + dxn * 7, t0[1] + dyn * 7)
    tail_b = math.radians(P_["tail"] + P_["wag"] * 1.6 + 18)
    t2 = (t1[0] - math.cos(tail_b) * 6, t1[1] - math.sin(tail_b) * 6)
    paint(img, seg_pixels(t0, t1, 3.0), FUR)
    paint(img, seg_pixels(t1, t2, 2.4), FUR_L)
    # Rumpf: zwei Scheiben und ein Verbindungsstueck, heller Bauch
    body = seg_pixels(hp_, sh_, 11.0 if not lying else 9.0) | disc_pixels(hp_, 6.0 if not lying else 4.6) | disc_pixels((sh_[0] + 1, sh_[1] + 1), 6.8 if not lying else 5.0)
    paint(img, body, FUR)
    belly = {(x, y) for (x, y) in body if (x, y + 2) not in body and y > hp_[1] - 1}
    flat(img, belly, FUR_L)
    flat(img, seg_pixels((hp_[0] + 1, hp_[1] - 5), (sh_[0] - 1, sh_[1] - 6), 1.2), sh(FUR, 1))  # Ruecken
    # Hals und Kopf
    paint(img, seg_pixels((sh_[0] + 2, sh_[1] - 2), head_c, 7.0), FUR)
    a = math.radians(hp_ang)
    dirv = (math.cos(a), -math.sin(a))
    down = (math.sin(a), math.cos(a))
    snout_a = (head_c[0] + dirv[0] * 3, head_c[1] + dirv[1] * 3)
    snout_b = (head_c[0] + dirv[0] * 10.5, head_c[1] + dirv[1] * 10.5)
    jaw = math.radians(P_["jaw"])
    # Unterkiefer (klappt nach unten auf)
    ja = (head_c[0] + dirv[0] * 3 + down[0] * 2, head_c[1] + dirv[1] * 3 + down[1] * 2)
    jdir = (math.cos(a - jaw), -math.sin(a - jaw))
    jb = (ja[0] + jdir[0] * 7.2, ja[1] + jdir[1] * 7.2)
    if P_["jaw"] > 4:
        flat(img, seg_pixels(ja, jb, 2.4), FUR_D)
        if P_["tongue"]:
            flat(img, seg_pixels((ja[0] + jdir[0] * 2, ja[1] + jdir[1] * 2 - 1), (jb[0], jb[1] + 1.5), 1.6), TONGUE)
    paint(img, disc_pixels(head_c, 5.2), FUR)
    paint(img, seg_pixels(snout_a, snout_b, 4.4), MUZZLE)
    if P_["jaw"] > 4:
        # offenes Maul: dunkler Spalt zwischen den Kiefern
        gm = (snout_a[0] + down[0] * 1.5, snout_a[1] + down[1] * 1.5)
        flat(img, seg_pixels(gm, (snout_b[0] - dirv[0] * 1, snout_b[1] - dirv[1] * 1 + 1.2), 1.4), hx("#2a1414"))
        flat(img, disc_pixels((snout_b[0] - dirv[0] * 1.5 + down[0], snout_b[1] - dirv[1] * 1.5 + down[1]), 0.7), hx("#e8e0cc"))  # Zahn
    flat(img, disc_pixels((snout_b[0] + dirv[0] * 0.5, snout_b[1] + dirv[1] * 0.5), 1.7), NOSE)
    # Ohr: klappt mit "ear" nach hinten
    ear_a = math.radians(-35 - 70 * P_["ear"])
    e0 = (head_c[0] - 2, head_c[1] - 3)
    e1 = (e0[0] + math.cos(ear_a) * -5 + 1, e0[1] + math.sin(ear_a) * 5 - 1 + 4 * P_["ear"])
    flat(img, poly_pixels([e0, (e0[0] + 4, e0[1] + 1), (e1[0] + 1, e1[1]), (e1[0] - 1, e1[1] + 1)]), EAR)
    # Auge
    ex, ey = int(round(head_c[0] + dirv[0] * 2.5 - down[0] * 0.5)), int(round(head_c[1] + dirv[1] * 2.5 - down[1] * 0.5 - 1))
    eye = P_["eye"]
    if eye == "d":
        img.set(ex - 1, ey - 1, NOSE); img.set(ex + 1, ey - 1, NOSE); img.set(ex, ey, NOSE); img.set(ex - 1, ey + 1, NOSE); img.set(ex + 1, ey + 1, NOSE)
    elif eye == "h":
        img.rect(ex - 1, ey, ex + 1, ey, NOSE)
    elif eye == "s":
        img.set(ex, ey - 1, NOSE); img.set(ex - 1, ey, NOSE); img.set(ex + 1, ey, NOSE); img.set(ex, ey + 1, NOSE)
    else:
        img.rect(ex, ey, ex + 1, ey + 1, NOSE)
        img.set(ex, ey, hx("#e8e0cc"))
    if joints is not None:
        joints.update(hand=snout_b, tip=(snout_b[0] + dirv[0] * 3, snout_b[1] + dirv[1] * 3), head=(head_c[0], head_c[1] - 9),
                      hip=hp_, top=sh_)
    for yy in range(GY, CH):
        img.px[yy] = [None] * CW
    img.outline(OUT)
    return img


# ---------------------------------------------------------------- Fangarm
SKIN_T, SKIN_D, SKIN_L = hx("#5b3a82"), hx("#3a2552"), hx("#8a62a6")
SUCK = hx("#d6c2ea")
WATER, WATER_L = hx("#161a2e"), hx("#2b3d63")

T_BASE_X = 34  # Fussmitte des Fangarms in der Rechenzelle (statt 40): mehr Platz fuer den Peitschenhieb nach vorn
T0 = dict(h=1.0, lean=0.0, curl=12.0, wave=5.5, phase=0.0, tipcurl=30.0, w=1.0, ripple=1.0)


def TP(**kw):
    d = dict(T0)
    d.update(kw)
    return d


TENT = {
    "idle_0": TP(phase=0.0),
    "idle_1": TP(phase=1.57, lean=1.0, curl=10.0),
    "idle_2": TP(phase=3.14, lean=2.0, curl=14.0, h=1.02),
    "idle_3": TP(phase=4.71, lean=1.0, curl=11.0),
    "ready_0": TP(h=1.04, lean=8.0, curl=6.0, wave=3.5, tipcurl=46.0),
    "ready_1": TP(h=1.06, lean=12.0, curl=4.0, wave=3.5, tipcurl=54.0, phase=1.2),
    "windup_0": TP(h=1.0, lean=-2.0, curl=-8.0, wave=3.0, tipcurl=-16.0),
    "windup_1": TP(h=0.94, lean=-4.0, curl=-14.0, wave=2.0, tipcurl=-24.0),
    "strike_0": TP(h=1.0, lean=50.0, curl=-4.0, wave=1.5, tipcurl=12.0),
    "strike_1": TP(h=1.0, lean=66.0, curl=-6.0, wave=1.0, tipcurl=2.0),
    "follow_0": TP(h=1.02, lean=44.0, curl=-14.0, wave=2.5, tipcurl=-6.0),
    "follow_1": TP(h=1.02, lean=20.0, curl=4.0, wave=3.5, tipcurl=14.0),
    "hit_0": TP(h=0.92, lean=-4.0, curl=-14.0, wave=3.5, tipcurl=-16.0, w=1.1),
    "hit_1": TP(h=0.96, lean=-2.0, curl=-8.0, wave=3.5, tipcurl=-10.0, w=1.05),
    "stun_0": TP(h=0.85, lean=4.0, curl=12.0, wave=1.5, tipcurl=76.0, phase=0.5),
    "stun_1": TP(h=0.85, lean=6.0, curl=16.0, wave=1.5, tipcurl=84.0, phase=2.1),
    "dodge": TP(h=0.95, lean=-14.0, curl=-10.0, wave=3.0, tipcurl=-8.0),
    "fall_0": TP(h=0.7, lean=-14.0, curl=-18.0, wave=2.5, tipcurl=-16.0, ripple=1.2),
    "fall_1": TP(h=0.45, lean=-6.0, curl=-10.0, wave=1.5, tipcurl=0.0, ripple=1.4),
    "fall_2": TP(h=0.22, lean=0.0, curl=0.0, wave=0.0, tipcurl=0.0, ripple=1.6),
    "dead": TP(h=0.08, lean=0.0, curl=0.0, wave=0.0, tipcurl=0.0, ripple=1.8),
    "cast_0": TP(h=1.1, lean=0.0, curl=0.0, wave=5.0, tipcurl=10.0, phase=0.4),
    "grab": TP(h=1.0, lean=40.0, curl=14.0, wave=2.0, tipcurl=40.0),
}
N_SEG = 13
SEG_LEN = 6.2


def tentacle_points(P_):
    """Mittellinie als Punktliste (Zellkoordinaten) und Breite je Punkt."""
    pts = [(float(T_BASE_X), float(GY - 5))]
    ws = [14.0 * P_["w"]]
    ang = P_["lean"]
    ln = SEG_LEN * P_["h"]
    for i in range(N_SEG):
        u = i / float(N_SEG - 1)
        ang += P_["curl"] / N_SEG + P_["wave"] * math.sin(P_["phase"] + i * 0.85) + P_["tipcurl"] * (u ** 3) / N_SEG * 3.0
        a = math.radians(ang)
        x, y = pts[-1]
        pts.append((x + math.sin(a) * ln, y - math.cos(a) * ln))
        ws.append(max(14.0 * P_["w"] * (1.0 - 0.82 * (i + 1) / N_SEG), 2.4))
    return pts, ws


def tentacle(sp, pname, joints=None):
    P_ = TENT[pname]
    img = Img(CW, CH)
    # Wasser um den Ansatz
    rp = min(P_["ripple"], 1.45)
    for (cx, cy, rx, ry, col) in ((T_BASE_X, GY - 3, 18 * rp, 3.6, WATER), (T_BASE_X, GY - 4, 14 * rp, 2.6, WATER_L), (T_BASE_X, GY - 3, 9 * rp, 1.8, WATER)):
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    img.set(xx, yy, col)
    pts, ws = tentacle_points(P_)
    # dunkle Grundform, dann hellere Form leicht nach oben links verschoben (Licht von links oben)
    for i in range(len(pts) - 1):
        paint(img, seg_pixels(pts[i], pts[i + 1], ws[i]), SKIN_D, shade=False)
    for i in range(len(pts) - 1):
        a = (pts[i][0] - 0.8, pts[i][1] - 0.6)
        b = (pts[i + 1][0] - 0.8, pts[i + 1][1] - 0.6)
        flat(img, seg_pixels(a, b, max(ws[i] - 2.4, 1.2)), SKIN_T)
    for i in range(len(pts) - 1):
        a = (pts[i][0] - 1.6, pts[i][1] - 1.2)
        b = (pts[i + 1][0] - 1.6, pts[i + 1][1] - 1.2)
        if ws[i] > 6:
            flat(img, seg_pixels(a, b, max(ws[i] - 7.0, 1.0)), SKIN_L)
    # Saugnaepfe auf der Vorderseite
    for i in range(1, len(pts) - 1, 2):
        dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = dy / ln, -dx / ln  # nach vorn (rechts), senkrecht zur Linie
        r = ws[i] / 2.0 - 1.2
        sx, sy = int(round(pts[i][0] + nx * r)), int(round(pts[i][1] + ny * r))
        img.set(sx, sy, SUCK)
        if ws[i] > 7:
            img.set(sx, sy + 1, sh(SUCK, -1))
    if joints is not None:
        mid = pts[len(pts) // 2]
        joints.update(hand=pts[-1], tip=pts[-1], head=(pts[-1][0], pts[-1][1] - 2), hip=pts[0], top=mid)
    img.outline(OUT)
    return img
