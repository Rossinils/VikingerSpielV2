"""Wucht-Schrift: 5x7-Pixelschrift fuer Schadenszahlen, Krit-Schriftzug und Kurzrufe (reines Python, nur Standardbibliothek).

PROTOTYP aus dem Entwurf D3 (docs/kampf_spektakel/D3_wucht.md). Wird zu tools/make_fight_font.py.
Aufruf:
    python -X utf8 -I tools/make_fight_font.py                       -> schreibt assets/fight_font.png
    python -X utf8 -I tools/make_fight_font.py --preview ordner/b.png  -> zusaetzlich ein Vorschaubild (6-fach, Beispielwoerter)
    python -X utf8 -I tools/make_fight_font.py --out pfad.png          -> anderer Zielpfad

Atlas assets/fight_font.png: Zelle 7x9 (Glyph 5x7 plus 1 Pixel Rand rundum), Spalte = Index in GLYPHS, Zeilen:
    0 Koerper (weiss, nur das Glyph)
    1 Rand (weiss; das um 1 Pixel verdickte Glyph, also Rand plus Koerper)
    2 untere Haelfte (nur Glyphpixel der Zeilen 4 bis 6): zweiter Farbton fuer einen Verlauf, z. B. Gold oben, Orange unten
Zeichnen (siehe FightFont in scripts/fight_font.gd): erst ALLE Raender eines Wortes, dann alle Koerper, sonst uebermalt ein Rand den Nachbarn.
Schritt je Zeichen: 6 Pixel (Ziffern sind gleich breit).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for cand in (os.path.join(HERE, "..", "..", "tools"), os.path.join(HERE, "..", "tools"), HERE):
    if os.path.exists(os.path.join(cand, "make_art.py")):
        sys.path.insert(0, cand)
        break
from make_art import Img  # noqa: E402

GLYPHS = "0123456789+-!?%.:xABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜ"
CW, CH = 7, 9          # Zelle
GW, GH = 5, 7          # Glyph

G = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    ".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
    ":": [".....", ".....", "..#..", ".....", ".....", "..#..", "....."],
    "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "Ä": [".#.#.", ".###.", "#...#", "#...#", "#####", "#...#", "#...#"],
    "Ö": [".#.#.", ".###.", "#...#", "#...#", "#...#", "#...#", ".###."],
    "Ü": [".#.#.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
}


def build_atlas():
    img = Img(CW * len(GLYPHS), CH * 3)
    white = (255, 255, 255, 255)
    for i, ch in enumerate(GLYPHS):
        rows = G[ch]
        assert len(rows) == GH and all(len(r) == GW for r in rows), ch
        for y in range(GH):
            for x in range(GW):
                if rows[y][x] != "#":
                    continue
                px, py = i * CW + 1 + x, 1 + y
                img.set(px, py, white)                       # Zeile 0: Koerper
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        img.set(px + dx, CH + py + dy, white)  # Zeile 1: Rand plus Koerper
                if y >= 4:
                    img.set(px, 2 * CH + py, white)           # Zeile 2: untere Haelfte
    return img


def preview(path):
    """Beispielwoerter in den Klassen der Schadenszahlen, 6-fach vergroessert, auf Deckbraun und Nachtblau."""
    atlas = build_atlas()
    W, H, S = 176, 80, 5
    out = Img(W, H)
    for y in range(H):
        for x in range(W):
            out.set(x, y, (36, 26, 20, 255) if x < 82 else (14, 17, 26, 255))

    def glyph_pixels(row, idx):
        return [(x, y) for y in range(CH) for x in range(CW) if atlas.get(idx * CW + x, row * CH + y) is not None]

    def word(text, x0, y0, body, low=None, rim=(12, 8, 10, 255), scale=1):
        step = 6 * scale
        for layer in ("rim", "body", "low"):
            for k, ch in enumerate(text):
                if ch == " ":
                    continue
                idx = GLYPHS.index(ch)
                row = {"rim": 1, "body": 0, "low": 2}[layer]
                if layer == "low" and low is None:
                    continue
                col = {"rim": rim, "body": body, "low": low}[layer]
                for (gx, gy) in glyph_pixels(row, idx):
                    for sy in range(scale):
                        for sx in range(scale):
                            out.set(x0 + k * step + gx * scale + sx, y0 + gy * scale + sy, col)

    word("-14", 6, 6, (245, 238, 220, 255))                       # normal
    word("-27", 44, 6, (255, 170, 60, 255), (230, 110, 40, 255))  # schwer
    word("-9", 6, 20, (240, 100, 82, 255))                        # empfangen
    word("+18", 30, 20, (110, 220, 120, 255))                     # Heilung
    word("-3", 56, 20, (190, 60, 56, 255))                        # Blutung
    word("VERFEHLT", 6, 34, (170, 170, 176, 255))
    word("KRIT!", 6, 46, (255, 226, 120, 255), (255, 150, 40, 255), (70, 24, 6, 255), 2)
    word("-31", 50, 50, (255, 226, 120, 255), (255, 150, 40, 255), (70, 24, 6, 255), 1)
    word("BLOCK", 86, 6, (150, 200, 255, 255))
    word("WIDERSTAND", 86, 20, (200, 225, 255, 255))
    word("RUNDE 3", 86, 36, (230, 190, 90, 255), None, (12, 8, 10, 255), 2)
    word("ÄÖÜ ABC XYZ", 86, 58, (230, 225, 210, 255))
    word("0123456789", 86, 68, (230, 225, 210, 255))
    out.scaled(S).save(path)


if __name__ == "__main__":
    out = os.path.join(HERE, "..", "..", "assets", "fight_font.png")
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    atlas = build_atlas()
    atlas.save(out)
    print("fight_font.png: %dx%d, %d Zeichen -> %s" % (atlas.w, atlas.h, len(GLYPHS), out))
    if "--preview" in sys.argv:
        p = sys.argv[sys.argv.index("--preview") + 1]
        preview(p)
        print("Vorschau:", p)
