"""Erzeugt die Kampffiguren mit dem Koerper-Rig: assets/fig/<id>.png (je Figur ein Streifen) und scripts/fig_atlas.gd (Anker).

Je Streifen: 32 Spalten zu 116x108 (Frame-Namen siehe rig_core.FRAMES); Zeile 0 ist die Figur, Zeile 1 dieselbe Figur ganz weiss
(fuer den Trefferblitz ohne Shader). Figuren schauen nach rechts, Fussmitte in Zelle (42, 101), die Stiefelsohle liegt auf Zeile 101;
rundum bleiben 2 px frei. Gegner werden zur Laufzeit gespiegelt.
Fuenf Maenner (Roles.Id), achtzehn menschliche Gegner (Foes.TYPES), dazu Hund und Fangarm. Der Kraken bleibt in assets/kraken.png.

Aufruf (aus dem Projektordner):  python -X utf8 -I tools/make_fig_rig.py            alles erzeugen
                                  python -X utf8 -I tools/make_fig_rig.py sheet <Ordner>   Kontaktblaetter zum Ansehen"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rig_beasts as B  # noqa: E402
import rig_core as R  # noqa: E402
import rig_figures as F  # noqa: E402
from make_art import Img  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT_DIR = os.path.join(ROOT, "assets", "fig")
CELL_W, CELL_H = 116, 108
PAD = 2
ANCHOR = (R.AX + PAD, R.GY + PAD - 0)  # Fussmitte (Spalte), Stiefelsohle: Rechenzeile GY-1 + 2 Rand = 101 (GY ist die Zeile unter der Sohle)


def all_figs():
    """Liste (id, zeichne(frame, joints) -> Img, belegte Frames, Ankerspalte der Rechenzelle)."""
    out = []
    for name, sp in F.HUMANS:
        out.append((name, (lambda fr, j=None, sp=sp: R.person(sp, fr, j)), list(R.FRAMES), R.AX))
    out.append(("hund", (lambda fr, j=None: B.dog(None, fr, j)), [f for f in R.FRAMES if f in B.DOG], R.AX))
    out.append(("tentakel", (lambda fr, j=None: B.tentacle(None, fr, j)), [f for f in R.FRAMES if f in B.TENT], B.T_BASE_X))
    return out


def anchors_for(draw, frames, ax):
    tab = {}
    for fr in frames:
        j = {}
        draw(fr, j)

        def rel(p):
            return [int(round(p[0] - ax)), int(round(R.GY - 1 - p[1]))]
        chest = ((j["hip"][0] + j["top"][0]) / 2.0, (j["hip"][1] + j["top"][1]) / 2.0)
        if "tip" in j and "hand" in j:
            tab[fr] = rel(j["hand"]) + rel(j["tip"]) + rel(chest) + rel(j["head"])
    return tab


def build_strip(draw, frames):
    strip = Img(len(R.FRAMES) * CELL_W, CELL_H * 2)
    for fr in frames:
        col = R.FRAMES.index(fr)
        img = draw(fr)
        strip.blit(img, col * CELL_W + PAD, PAD)
        strip.blit(R.silhouette(img), col * CELL_W + PAD, CELL_H + PAD)
    return strip


def gd_dict(figs_tab):
    lines = []
    for fid, tab in figs_tab.items():
        lines.append('\t"%s": {' % fid)
        for fr, vals in tab.items():
            lines.append('\t\t"%s": [%s],' % (fr, ", ".join(str(v) for v in vals)))
        lines.append("\t},")
    return "\n".join(lines)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    figs = all_figs()
    tab = {}
    overrides = {}
    ids = []
    for fid, draw, frames, ax in figs:
        strip = build_strip(draw, frames)
        strip.save(os.path.join(OUT_DIR, fid + ".png"))
        tab[fid] = anchors_for(draw, frames, ax)
        ids.append(fid)
        if ax != R.AX:
            overrides[fid] = ax + PAD
        print("  %-13s %2d Frames" % (fid, len(frames)))
    gd = ['# Erzeugt von tools/make_fig_rig.py, nicht von Hand aendern.',
          '## Daten der Rig-Figuren (assets/fig/<id>.png): Zelle, Anker und je Frame Hand, Waffenspitze, Brust, Kopf.',
          'class_name FigAtlas', 'extends RefCounted', '',
          'const CELL := Vector2i(%d, %d)' % (CELL_W, CELL_H),
          'const ANCHOR := Vector2i(%d, %d)  # Fussmitte (Spalte) und Stiefelsohle (Zeile) in der Zelle; die Figur blickt nach rechts' % (R.AX + PAD, R.GY + PAD - 0),
          'const COLUMNS := %d' % len(R.FRAMES),
          'const FRAMES := [%s]' % ", ".join('"%s"' % f for f in R.FRAMES),
          'const IDS := [%s]' % ", ".join('"%s"' % i for i in ids),
          '## Figuren mit anderer Fussmitte (Spalte der Zelle)',
          'const ANCHOR_X := {%s}' % ", ".join('"%s": %d' % (k, v) for k, v in overrides.items()),
          '## je Figur und Frame: [Hand x, y, Waffenspitze x, y, Brust x, y, Kopf x, y], ab Fussmitte, x nach vorn, y nach oben',
          'const ANCHORS := {', gd_dict(tab), '}', '']
    with open(os.path.join(ROOT, "scripts", "fig_atlas.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(gd))
    print("fertig:", len(figs), "Streifen in assets/fig/, scripts/fig_atlas.gd")


def sheets(outdir):
    os.makedirs(outdir, exist_ok=True)
    groups = {"draugr": ["rost", "bogner", "totenwart", "waechter", "priester", "beschwoerer", "knochen"],
              "raeuber": ["brecher", "messerkerl", "schuetze", "haken", "antreiber"],
              "haendler_dorf": ["wache", "armbrust", "kaufmann", "bauer", "schmied", "kraeuterfrau"],
              "maenner": ["schild", "axt", "bogen", "skalde", "muskete"]}
    hum = dict(F.HUMANS)
    for g, names in groups.items():
        R.sheet([(n, hum[n]) for n in names], R.KEY_FRAMES, os.path.join(outdir, "rig_%s.png" % g), scale=2, cols=len(R.KEY_FRAMES))
    print("Kontaktblaetter in", outdir)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "sheet":
        sheets(sys.argv[2])
    else:
        main()
